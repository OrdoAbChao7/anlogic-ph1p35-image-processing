`timescale 1ns/1ps

module tb_industrial_v2_feature_spine;
  reg clk = 1'b0;
  always #5 clk = ~clk;

  reg rst_n = 1'b0;
  reg frame_start = 1'b0;
  reg frame_valid = 1'b0;
  reg [15:0] frame_id = 16'd0;
  reg result_valid = 1'b0;
  reg [15:0] result_frame_id = 16'd0;
  reg [15:0] video_frame_id = 16'd0;
  reg detected = 1'b0;
  reg invalid = 1'b0;
  reg [10:0] xmin = 11'd10;
  reg [10:0] xmax = 11'd129;
  reg [10:0] ymin = 11'd20;
  reg [10:0] ymax = 11'd99;
  reg [10:0] cx = 11'd50;
  reg [10:0] cy = 11'd50;
  reg [19:0] area = 20'd9600;
  reg verdict_valid = 1'b0;
  reg verdict_pass = 1'b0;
  reg verdict_invalid = 1'b0;

  reg motion_frame_start = 1'b0;
  reg motion_frame_end = 1'b0;
  reg motion_sample_valid = 1'b0;
  reg [15:0] motion_frame_id = 16'd0;
  reg [7:0] motion_sample_x = 8'd0;
  reg [6:0] motion_sample_y = 7'd0;
  reg [7:0] motion_y_value = 8'd20;

  reg video_valid = 1'b0;
  reg video_de = 1'b0;
  reg video_hsync = 1'b0;
  reg video_vsync = 1'b0;
  reg [23:0] video_rgb = 24'h102030;
  reg [10:0] video_x = 11'd0;
  reg [10:0] video_y = 11'd0;

  reg frame_stats_valid = 1'b0;
  reg [31:0] sum_r = 32'd100;
  reg [31:0] sum_g = 32'd100;
  reg [31:0] sum_b = 32'd100;
  reg [31:0] pixel_count = 32'd1;
  reg [7:0] mean_luma = 8'd100;

  reg calibration_valid = 1'b1;
  reg [31:0] scale_x_q16_16 = 32'd32768;
  reg [31:0] scale_y_q16_16 = 32'd16384;
  reg [31:0] nominal_width_q16_16 = 32'd3932160;
  reg [31:0] nominal_height_q16_16 = 32'd1310720;
  reg [31:0] tolerance_width_q16_16 = 32'd131072;
  reg [31:0] tolerance_height_q16_16 = 32'd131072;
  reg [8:0] occupancy_min_q8 = 9'd200;
  reg [15:0] aspect_min_q8 = 16'd320;
  reg [15:0] aspect_max_q8 = 16'd448;

  reg arm = 1'b1;
  reg external_fault = 1'b0;
  reg clear_fault = 1'b0;

  wire video_de_o;
  wire video_hsync_o;
  wire video_vsync_o;
  wire [23:0] video_rgb_o;
  wire [15:0] gain_r;
  wire [15:0] gain_g;
  wire [15:0] gain_b;
  wire gain_update_valid;
  wire scene_protected;
  wire dimension_valid;
  wire shape_valid;
  wire calibration_invalid;
  wire [31:0] width_mm;
  wire [31:0] height_mm;
  wire [8:0] occupancy_q8;
  wire [15:0] aspect_q8;
  wire safe_enable;
  wire sort_request;
  wire sort_pulse;
  wire sort_busy;
  wire sort_accepted;
  wire sort_rejected;
  wire sort_timeout;
  wire [15:0] pass_count;
  wire [15:0] ng_count;
  wire track_valid;
  wire [1:0] tracking_state;
  wire [10:0] track_cx;
  wire [10:0] track_cy;
  wire track_enter;
  wire track_exit;
  wire motion_valid;
  wire motion;
  wire [23:0] motion_count;
  wire latency_proc_valid;
  wire [31:0] latency_proc_cycles;
  wire latency_video_valid;
  wire [31:0] latency_video_cycles;
  wire latency_e2e_valid;
  wire [31:0] latency_e2e_cycles;
  wire frame_gap;
  wire tag_mismatch;

  industrial_v2_feature_spine #(
    .HISTORY_DEPTH(4),
    .MOTION_WIDTH(4),
    .MOTION_HEIGHT(2),
    .MOTION_THRESHOLD(8),
    .SORT_TRIGGER_X(90),
    .SORT_PULSE_CYCLES(3)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n),
    .I_frame_start(frame_start), .I_frame_valid(frame_valid),
    .I_frame_id(frame_id), .I_result_valid(result_valid),
    .I_result_tag_valid(1'b1), .I_result_frame_id(result_frame_id),
    .I_video_frame_id(video_frame_id),
    .I_detected(detected), .I_invalid(invalid),
    .I_xmin(xmin), .I_xmax(xmax), .I_ymin(ymin), .I_ymax(ymax),
    .I_cx(cx), .I_cy(cy), .I_area(area),
    .I_verdict_valid(verdict_valid), .I_verdict_pass(verdict_pass),
    .I_verdict_invalid(verdict_invalid),
    .I_motion_frame_start(motion_frame_start),
    .I_motion_frame_end(motion_frame_end),
    .I_motion_sample_valid(motion_sample_valid),
    .I_motion_frame_id(motion_frame_id),
    .I_motion_sample_x(motion_sample_x),
    .I_motion_sample_y(motion_sample_y),
    .I_motion_y_value(motion_y_value),
    .I_video_valid(video_valid), .I_video_de(video_de),
    .I_video_hsync(video_hsync), .I_video_vsync(video_vsync),
    .I_video_rgb(video_rgb), .I_video_x(video_x), .I_video_y(video_y),
    .O_video_de(video_de_o), .O_video_hsync(video_hsync_o),
    .O_video_vsync(video_vsync_o), .O_video_rgb(video_rgb_o),
    .I_frame_stats_valid(frame_stats_valid), .I_sum_r(sum_r),
    .I_sum_g(sum_g), .I_sum_b(sum_b), .I_pixel_count(pixel_count),
    .I_mean_luma(mean_luma), .O_gain_r(gain_r), .O_gain_g(gain_g),
    .O_gain_b(gain_b), .O_gain_update_valid(gain_update_valid),
    .O_scene_protected(scene_protected),
    .I_calibration_valid(calibration_valid),
    .I_scale_x_q16_16(scale_x_q16_16), .I_scale_y_q16_16(scale_y_q16_16),
    .I_nominal_width_q16_16(nominal_width_q16_16),
    .I_nominal_height_q16_16(nominal_height_q16_16),
    .I_tolerance_width_q16_16(tolerance_width_q16_16),
    .I_tolerance_height_q16_16(tolerance_height_q16_16),
    .I_occupancy_min_q8(occupancy_min_q8),
    .I_aspect_min_q8(aspect_min_q8), .I_aspect_max_q8(aspect_max_q8),
    .O_dimension_valid(dimension_valid), .O_shape_valid(shape_valid),
    .O_calibration_invalid(calibration_invalid), .O_width_mm_q16_16(width_mm),
    .O_height_mm_q16_16(height_mm), .O_occupancy_q8(occupancy_q8),
    .O_aspect_q8(aspect_q8),
    .I_arm(arm), .I_external_fault(external_fault),
    .I_clear_fault(clear_fault), .O_safe_enable(safe_enable),
    .O_sort_request(sort_request), .O_sort_pulse(sort_pulse),
    .O_sort_busy(sort_busy), .O_sort_accepted(sort_accepted),
    .O_sort_rejected(sort_rejected), .O_sort_timeout(sort_timeout),
    .O_pass_count(pass_count), .O_ng_count(ng_count),
    .O_track_valid(track_valid), .O_tracking_state(tracking_state),
    .O_track_cx(track_cx), .O_track_cy(track_cy),
    .O_track_enter(track_enter), .O_track_exit(track_exit),
    .O_motion_valid(motion_valid), .O_motion(motion),
    .O_motion_count(motion_count),
    .O_latency_proc_valid(latency_proc_valid),
    .O_latency_proc_cycles(latency_proc_cycles),
    .O_latency_video_valid(latency_video_valid),
    .O_latency_video_cycles(latency_video_cycles),
    .O_latency_e2e_valid(latency_e2e_valid),
    .O_latency_e2e_cycles(latency_e2e_cycles),
    .O_frame_gap(frame_gap), .O_tag_mismatch(tag_mismatch)
  );

  task clear_events;
    begin
      frame_start = 1'b0;
      frame_valid = 1'b0;
      result_valid = 1'b0;
      verdict_valid = 1'b0;
      video_valid = 1'b0;
      video_de = 1'b0;
      frame_stats_valid = 1'b0;
    end
  endtask

  task send_result;
    input [15:0] id;
    input [10:0] center_x;
    begin
      @(negedge clk);
      frame_id = id;
      result_frame_id = id;
      cx = center_x;
      frame_valid = 1'b1;
      result_valid = 1'b1;
      detected = 1'b1;
      invalid = 1'b0;
      verdict_valid = 1'b1;
      verdict_pass = 1'b1;
      verdict_invalid = 1'b0;
      @(negedge clk);
      clear_events();
    end
  endtask

  task send_motion_frame;
    input [15:0] id;
    input [7:0] changed_x;
    integer i;
    integer x_i;
    integer y_i;
    begin
      @(negedge clk);
      motion_frame_id = id;
      motion_frame_start = 1'b1;
      @(negedge clk);
      motion_frame_start = 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        x_i = i % 4;
        y_i = i / 4;
        motion_sample_x = x_i[7:0];
        motion_sample_y = y_i[6:0];
        motion_y_value = (x_i == changed_x && y_i == 0) ? 8'd80 : 8'd20;
        motion_sample_valid = 1'b1;
        motion_frame_end = (i == 7);
        @(negedge clk);
        motion_frame_end = 1'b0;
      end
      motion_sample_valid = 1'b0;
    end
  endtask

  integer guard;
  initial begin
    clear_events();
    repeat (3) @(negedge clk);
    rst_n = 1'b1;

    send_result(16'd1, 11'd50);
    if (!track_valid || !shape_valid || !dimension_valid)
      $fatal(1, "tracker/calibration result did not publish");

    frame_stats_valid = 1'b1;
    @(negedge clk);
    frame_stats_valid = 1'b0;
    if (!gain_update_valid || gain_r != 16'd256 || gain_g != 16'd256 || gain_b != 16'd256)
      $fatal(1, "AWB gain update did not publish expected neutral gains");

    send_result(16'd2, 11'd90);
    if (!sort_request || !safe_enable)
      $fatal(1, "sort request did not publish at the result boundary");
    @(negedge clk);
    if (!sort_accepted || !sort_pulse || !safe_enable)
      $fatal(1, "sort event did not reach the safe pulse boundary");

    send_motion_frame(16'd10, 8'd255);
    send_motion_frame(16'd11, 8'd2);
    if (!motion_valid || !motion || motion_count == 0)
      $fatal(1, "motion summary did not detect changed fixed-grid sample");

    @(negedge clk);
    video_valid = 1'b1;
    video_de = 1'b1;
    video_frame_id = 16'd2;
    video_x = 11'd50;
    video_y = 11'd50;
    @(negedge clk);
    video_valid = 1'b0;
    video_de = 1'b0;
    if (video_rgb_o === 24'hx)
      $fatal(1, "tracking overlay output is unknown");

    $display("TB_INDUSTRIAL_V2_FEATURE_SPINE_PASS");
    $finish;
  end
endmodule
