`timescale 1ns/1ps

// Frame-statistics AWB controller. Gains are Q8.8 and change only when a
// complete-frame statistics event is accepted. The pixel stream can therefore
// use the registered gain for the whole following frame.
module awb_frame_gain_controller #(
  parameter integer MIN_GAIN    = 128,
  parameter integer MAX_GAIN    = 512,
  parameter integer MAX_STEP    = 8,
  parameter integer SMOOTH_SHIFT = 2,
  parameter integer LUMA_MIN    = 16,
  parameter integer LUMA_MAX    = 240,
  parameter integer SCENE_JUMP  = 40
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

  wire [31:0] mean_r = (I_pixel_count != 0) ? (I_sum_r / I_pixel_count) : 32'd0;
  wire [31:0] mean_g = (I_pixel_count != 0) ? (I_sum_g / I_pixel_count) : 32'd0;
  wire [31:0] mean_b = (I_pixel_count != 0) ? (I_sum_b / I_pixel_count) : 32'd0;
  wire [31:0] target_mean = (mean_r + mean_g + mean_b) / 3;
  wire [7:0] luma_delta = (I_mean_luma >= previous_luma) ?
                           (I_mean_luma - previous_luma) :
                           (previous_luma - I_mean_luma);
  wire scene_jump_now = previous_luma_valid && (luma_delta > SCENE_JUMP);
  wire scene_protected_now = (I_pixel_count == 0) ||
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
  wire [15:0] next_r = smooth_gain(O_gain_r, desired_r);
  wire [15:0] next_b = smooth_gain(O_gain_b, desired_b);

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
        if (I_pixel_count != 0) begin
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
