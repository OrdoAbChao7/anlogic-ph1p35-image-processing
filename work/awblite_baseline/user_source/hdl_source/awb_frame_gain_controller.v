`timescale 1ns/1ps

// Frame-statistics AWB controller. Gains are Q8.8 and change only when a
// complete-frame statistics event is accepted. The pixel stage snapshots the
// pre-edge gain if SOF and a stats update coincide; the first later accepted
// SOF snapshots the new gain. No minimum frame-to-frame gap is required.
module awb_frame_gain_controller #(
  parameter integer MIN_GAIN    = 128,
  parameter integer MAX_GAIN    = 512,
  parameter integer MAX_STEP    = 8,
  parameter integer SMOOTH_SHIFT = 2,
  parameter integer LUMA_MIN    = 16,
  parameter integer LUMA_MAX    = 240,
  parameter integer SCENE_JUMP  = 40,
  parameter integer USE_FIXED_PIXEL_COUNT = 0,
  parameter [31:0] FIXED_PIXEL_COUNT = 32'd921600
)(
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_frame_stats_valid,
  input  wire [31:0] I_sum_r,
  input  wire [31:0] I_sum_g,
  input  wire [31:0] I_sum_b,
  input  wire [31:0] I_pixel_count,
  input  wire [7:0]  I_mean_luma,
  output reg  [15:0] O_gain_r,
  output reg  [15:0] O_gain_g,
  output reg  [15:0] O_gain_b,
  output reg         O_gain_update_valid,
  output reg         O_scene_protected
);

  reg        previous_luma_valid;
  reg [7:0]  previous_luma;

  // For the fixed 1280x720 formal stream, 921600 = 3600 * 256.
  // This Q32 reciprocal is exact over all legal 8-bit channel sums and avoids
  // a wide run-time divider on the frame-statistics-to-gain path.
  localparam [31:0] FIXED_MAX_CHANNEL_SUM = 32'd235008000;
  localparam [9:0] MIN_GAIN_Q8 = MIN_GAIN;
  localparam [9:0] MAX_GAIN_Q8 = MAX_GAIN;
  localparam integer STEP_QUANTUM = (1 << SMOOTH_SHIFT);

  function [7:0] fixed_mean;
    input [31:0] channel_sum;
    reg [19:0] sum_div_256;
    reg [40:0] reciprocal_product;
    begin
      if (channel_sum > FIXED_MAX_CHANNEL_SUM) begin
        fixed_mean = 8'd255;
      end else begin
        // 235008000 / 256 = 918000, which fits in 20 bits.
        sum_div_256 = channel_sum[27:8];
        reciprocal_product = sum_div_256 * 21'd1193047;
        fixed_mean = reciprocal_product[39:32];
      end
    end
  endfunction

  function [7:0] fixed_average3;
    input [9:0] channel_mean_sum;
    reg [18:0] reciprocal_product;
    begin
      // For sums 0..765, floor(sum * 683 / 2048) equals floor(sum / 3).
      reciprocal_product = {9'd0, channel_mean_sum} * 19'd683;
      fixed_average3 = reciprocal_product[18:11];
    end
  endfunction

  function [15:0] smooth_gain_from_means;
    input [15:0] current_gain;
    input [7:0] mean_channel;
    input [7:0] target_mean_8;
    reg [16:0] numerator;
    reg [17:0] current_product;
    reg [17:0] desired_min_product;
    reg [17:0] desired_max_product;
    reg [17:0] step_increment;
    reg [17:0] candidate_threshold;
    reg [15:0] desired_value;
    integer step_index;
    integer selected_step;
    integer signed delta;
    integer signed magnitude;
    integer signed smooth_step;
    integer signed next_value;
    reg direct_result;
    begin
      direct_result = 1'b0;
      desired_value = 16'd256;
      next_value = current_gain;
      if (mean_channel == 0) begin
        desired_value = 16'd256;
      end else begin
        numerator = {target_mean_8, 8'd0} + (mean_channel >> 1);
        desired_min_product = {10'd0, mean_channel} * {8'd0, MIN_GAIN_Q8};
        desired_max_product = {10'd0, mean_channel} *
                              {8'd0, (MAX_GAIN_Q8 + 10'd1)};
        if (numerator < desired_min_product) begin
          desired_value = MIN_GAIN;
        end else if (numerator >= desired_max_product) begin
          desired_value = MAX_GAIN;
        end else begin
          current_product = {10'd0, mean_channel} * {8'd0, current_gain[9:0]};
          step_increment = {10'd0, mean_channel} << SMOOTH_SHIFT;
          if (numerator >= (current_product + mean_channel)) begin
            selected_step = 1;
            for (step_index = 2; step_index <= MAX_STEP; step_index = step_index + 1) begin
              candidate_threshold = current_product + (step_increment * step_index);
              if (numerator >= candidate_threshold)
                selected_step = step_index;
            end
            next_value = current_gain + selected_step;
            if (next_value > MAX_GAIN)
              next_value = MAX_GAIN;
            direct_result = 1'b1;
          end else if (numerator < current_product) begin
            selected_step = 1;
            for (step_index = 2; step_index <= MAX_STEP; step_index = step_index + 1) begin
              if (current_gain >= (step_index * STEP_QUANTUM)) begin
                candidate_threshold = current_product -
                                      (step_increment * step_index) + mean_channel;
                if (numerator < candidate_threshold)
                  selected_step = step_index;
              end
            end
            next_value = current_gain - selected_step;
            if (next_value < MIN_GAIN)
              next_value = MIN_GAIN;
            direct_result = 1'b1;
          end else begin
            next_value = current_gain;
            direct_result = 1'b1;
          end
        end
      end
      if (!direct_result) begin
        delta = $signed({1'b0, desired_value}) - $signed({1'b0, current_gain});
        if (delta == 0) begin
          next_value = current_gain;
        end else begin
          magnitude = (delta < 0) ? -delta : delta;
          smooth_step = magnitude >>> SMOOTH_SHIFT;
          if (smooth_step < 1)
            smooth_step = 1;
          if (smooth_step > MAX_STEP)
            smooth_step = MAX_STEP;
          next_value = current_gain + ((delta > 0) ? smooth_step : -smooth_step);
          if (next_value < MIN_GAIN)
            next_value = MIN_GAIN;
          if (next_value > MAX_GAIN)
            next_value = MAX_GAIN;
        end
      end
      smooth_gain_from_means = next_value[15:0];
    end
  endfunction

  wire [31:0] mean_r;
  wire [31:0] mean_g;
  wire [31:0] mean_b;
  generate
    if (USE_FIXED_PIXEL_COUNT != 0) begin : g_fixed_frame_mean
      assign mean_r = {24'd0, fixed_mean(I_sum_r)};
      assign mean_g = {24'd0, fixed_mean(I_sum_g)};
      assign mean_b = {24'd0, fixed_mean(I_sum_b)};
    end else begin : g_runtime_frame_mean
      assign mean_r = (I_pixel_count != 0) ? (I_sum_r / I_pixel_count) : 32'd0;
      assign mean_g = (I_pixel_count != 0) ? (I_sum_g / I_pixel_count) : 32'd0;
      assign mean_b = (I_pixel_count != 0) ? (I_sum_b / I_pixel_count) : 32'd0;
    end
  endgenerate
  wire [31:0] target_mean;
  generate
    if (USE_FIXED_PIXEL_COUNT != 0) begin : g_fixed_target_mean
      wire [9:0] fixed_target_mean_sum;
      assign fixed_target_mean_sum = {2'd0, mean_r[7:0]} +
                                     {2'd0, mean_g[7:0]} +
                                     {2'd0, mean_b[7:0]};
      assign target_mean = {24'd0, fixed_average3(fixed_target_mean_sum)};
    end else begin : g_runtime_target_mean
      assign target_mean = (mean_r + mean_g + mean_b) / 3;
    end
  endgenerate
  wire [7:0] luma_delta = (I_mean_luma >= previous_luma) ?
                           (I_mean_luma - previous_luma) :
                           (previous_luma - I_mean_luma);
  wire scene_jump_now = previous_luma_valid && (luma_delta > SCENE_JUMP);
  wire fixed_count_invalid = USE_FIXED_PIXEL_COUNT &&
                             (I_pixel_count != FIXED_PIXEL_COUNT);
  wire scene_protected_now = (I_pixel_count == 0) || fixed_count_invalid ||
                             (I_mean_luma < LUMA_MIN) ||
                             (I_mean_luma > LUMA_MAX) || scene_jump_now;

  function [15:0] desired_gain;
    input [31:0] mean_channel;
    input [31:0] target;
    reg [63:0] numerator;
    reg [31:0] raw;
    begin
      if (mean_channel == 0) begin
        desired_gain = 16'd256;
      end else begin
        numerator = (target * 64'd256) + (mean_channel / 2);
        raw = numerator / mean_channel;
        if (raw < MIN_GAIN)
          desired_gain = MIN_GAIN;
        else if (raw > MAX_GAIN)
          desired_gain = MAX_GAIN;
        else
          desired_gain = raw[15:0];
      end
    end
  endfunction

  function [15:0] smooth_gain;
    input [15:0] current;
    input [15:0] desired;
    integer signed delta;
    integer signed magnitude;
    integer signed step;
    integer signed next_value;
    begin
      delta = $signed({1'b0, desired}) - $signed({1'b0, current});
      if (delta == 0) begin
        next_value = current;
      end else begin
        magnitude = (delta < 0) ? -delta : delta;
        step = magnitude >>> SMOOTH_SHIFT;
        if (step < 1)
          step = 1;
        if (step > MAX_STEP)
          step = MAX_STEP;
        next_value = current + ((delta > 0) ? step : -step);
        if (next_value < MIN_GAIN)
          next_value = MIN_GAIN;
        if (next_value > MAX_GAIN)
          next_value = MAX_GAIN;
      end
      smooth_gain = next_value[15:0];
    end
  endfunction

  wire [15:0] desired_r = desired_gain(mean_r, target_mean);
  wire [15:0] desired_b = desired_gain(mean_b, target_mean);
  wire [15:0] next_r = USE_FIXED_PIXEL_COUNT ?
                        smooth_gain_from_means(O_gain_r, mean_r[7:0], target_mean[7:0]) :
                        smooth_gain(O_gain_r, desired_r);
  wire [15:0] next_b = USE_FIXED_PIXEL_COUNT ?
                        smooth_gain_from_means(O_gain_b, mean_b[7:0], target_mean[7:0]) :
                        smooth_gain(O_gain_b, desired_b);

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      O_gain_r            <= 16'd256;
      O_gain_g            <= 16'd256;
      O_gain_b            <= 16'd256;
      O_gain_update_valid <= 1'b0;
      O_scene_protected   <= 1'b0;
      previous_luma_valid <= 1'b0;
      previous_luma       <= 8'd0;
    end else begin
      O_gain_update_valid <= 1'b0;
      O_scene_protected   <= 1'b0;
      if (I_frame_stats_valid) begin
        if ((I_pixel_count != 0) && !fixed_count_invalid) begin
          previous_luma_valid <= 1'b1;
          previous_luma       <= I_mean_luma;
        end
        O_scene_protected <= scene_protected_now;
        if (!scene_protected_now) begin
          O_gain_r            <= next_r;
          O_gain_g            <= 16'd256;
          O_gain_b            <= next_b;
          O_gain_update_valid <= 1'b1;
        end
      end
    end
  end
endmodule
