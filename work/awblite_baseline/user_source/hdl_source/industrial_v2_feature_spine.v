`timescale 1ns/1ps

// ============================================================================
// Industrial Vision V2 feature spine
//
// This is the explicit frame-result integration contract for G2-G7. It keeps
// the pixel-domain overlay, frame-result domain, fixed-ROI motion samples,
// frame statistics, calibration and actuator safety boundaries visible in one
// synthesizable module. It is intentionally independent of vendor MIPI/DDR/
// HDMI IP: the formal top may connect those boundaries only after the G1 gate
// and TD source-list review are complete.
//
// No port in this module implies a PH1P35 pin assignment or a hardware result.
// ============================================================================

module industrial_v2_feature_spine #(
  parameter integer HISTORY_DEPTH = 8,
  parameter integer MOTION_WIDTH  = 160,
  parameter integer MOTION_HEIGHT = 120,
  parameter integer MOTION_THRESHOLD = 8,
  parameter integer SORT_TRIGGER_X = 100,
  parameter integer SORT_PULSE_CYCLES = 3,
  parameter integer USE_STATIC_CAL_CONFIG = 0,
  parameter [31:0] STATIC_SCALE_X_Q16_16 = 32'd0,
  parameter [31:0] STATIC_SCALE_Y_Q16_16 = 32'd0,
  parameter [31:0] STATIC_NOMINAL_WIDTH_Q16_16 = 32'd0,
  parameter [31:0] STATIC_NOMINAL_HEIGHT_Q16_16 = 32'd0,
  parameter [31:0] STATIC_TOLERANCE_WIDTH_Q16_16 = 32'd0,
  parameter [31:0] STATIC_TOLERANCE_HEIGHT_Q16_16 = 32'd0,
  parameter [8:0]  STATIC_OCCUPANCY_MIN_Q8 = 9'd0,
  parameter [15:0] STATIC_ASPECT_MIN_Q8 = 16'd0,
  parameter [15:0] STATIC_ASPECT_MAX_Q8 = 16'hffff,
  parameter integer USE_FIXED_AWB_PIXEL_COUNT = 0,
  parameter [31:0] FIXED_AWB_PIXEL_COUNT = 32'd921600,
  parameter integer ENABLE_V2_FRAME_AWB = 1
)(
  input  wire        I_clk,
  input  wire        I_rst_n,

  // Frame-result event contract. One atomic result is expected per frame.
  input  wire        I_frame_start,
  input  wire        I_frame_valid,
  input  wire [15:0] I_frame_id,
  input  wire        I_result_valid,
  input  wire        I_result_tag_valid,
  input  wire [15:0] I_result_frame_id,
  input  wire [15:0] I_video_frame_id,
  input  wire        I_detected,
  input  wire        I_invalid,
  input  wire [10:0] I_xmin,
  input  wire [10:0] I_xmax,
  input  wire [10:0] I_ymin,
  input  wire [10:0] I_ymax,
  input  wire [10:0] I_cx,
  input  wire [10:0] I_cy,
  input  wire [19:0] I_area,
  input  wire        I_verdict_valid,
  input  wire        I_verdict_pass,
  input  wire        I_verdict_invalid,

  // Optional fixed-grid motion sampler contract.
  input  wire        I_motion_frame_start,
  input  wire        I_motion_frame_end,
  input  wire        I_motion_frame_invalid,
  input  wire        I_motion_sample_valid,
  input  wire [15:0] I_motion_frame_id,
  input  wire [7:0]  I_motion_sample_x,
  input  wire [6:0]  I_motion_sample_y,
  input  wire [7:0]  I_motion_y_value,

  // HDMI-domain video contract for trajectory overlay.
  input  wire        I_video_valid,
  input  wire        I_video_de,
  input  wire        I_video_hsync,
  input  wire        I_video_vsync,
  input  wire [23:0] I_video_rgb,
  input  wire [10:0] I_video_x,
  input  wire [10:0] I_video_y,
  output wire        O_video_de,
  output wire        O_video_hsync,
  output wire        O_video_vsync,
  output wire [23:0] O_video_rgb,

  // Frame-statistics AWB contract.
  input  wire        I_frame_stats_valid,
  input  wire [31:0] I_sum_r,
  input  wire [31:0] I_sum_g,
  input  wire [31:0] I_sum_b,
  input  wire [31:0] I_pixel_count,
  input  wire [7:0]  I_mean_luma,
  output wire [15:0] O_gain_r,
  output wire [15:0] O_gain_g,
  output wire [15:0] O_gain_b,
  output wire        O_gain_update_valid,
  output wire        O_scene_protected,

  // Physical calibration and shape contract.
  input  wire        I_calibration_valid,
  input  wire [31:0] I_scale_x_q16_16,
  input  wire [31:0] I_scale_y_q16_16,
  input  wire [31:0] I_nominal_width_q16_16,
  input  wire [31:0] I_nominal_height_q16_16,
  input  wire [31:0] I_tolerance_width_q16_16,
  input  wire [31:0] I_tolerance_height_q16_16,
  input  wire [8:0]  I_occupancy_min_q8,
  input  wire [15:0] I_aspect_min_q8,
  input  wire [15:0] I_aspect_max_q8,
  output wire        O_dimension_valid,
  output wire        O_shape_valid,
  output wire        O_calibration_invalid,
  output wire [31:0] O_width_mm_q16_16,
  output wire [31:0] O_height_mm_q16_16,
  output wire [8:0]  O_occupancy_q8,
  output wire [15:0] O_aspect_q8,

  // External control stays abstract until official GPIO/electrical evidence.
  input  wire        I_arm,
  input  wire        I_external_fault,
  input  wire        I_clear_fault,
  output wire        O_safe_enable,
  output wire        O_sort_request,
  output wire        O_sort_pulse,
  output wire        O_sort_busy,
  output wire        O_sort_accepted,
  output wire        O_sort_rejected,
  output wire        O_sort_timeout,
  output wire [15:0] O_pass_count,
  output wire [15:0] O_ng_count,

  // Tracking and latency telemetry.
  output wire        O_track_valid,
  output wire [1:0]  O_tracking_state,
  output wire [10:0] O_track_cx,
  output wire [10:0] O_track_cy,
  output wire        O_track_enter,
  output wire        O_track_exit,
  output wire        O_motion_valid,
  output wire        O_motion,
  output wire [23:0] O_motion_count,
  output wire        O_latency_proc_valid,
  output wire [31:0] O_latency_proc_cycles,
  output wire        O_latency_video_valid,
  output wire [31:0] O_latency_video_cycles,
  output wire        O_latency_e2e_valid,
  output wire [31:0] O_latency_e2e_cycles,
  output wire        O_frame_gap,
  output wire        O_tag_mismatch
);

  wire        tracker_result_valid;
  wire [1:0]  tracker_state;
  wire        tracker_valid;
  wire        tracker_enter;
  wire        tracker_exit;
  wire        tracker_frame_gap;
  wire [10:0] tracker_cx;
  wire [10:0] tracker_cy;
  wire signed [11:0] tracker_dx;
  wire signed [11:0] tracker_dy;
  wire [3:0]  tracker_direction;
  wire [2:0]  tracker_lost_frames;
  wire         tracker_tracking_level;
  wire         spine_target_enter;
  wire         spine_target_exit;
  wire         spine_tracking_lost;
  wire         tag_mismatch;
  wire         latency_frame_gap;
  wire         latency_tag_mismatch;
  wire         latency_timeout;
  localparam integer MOTION_X_WIDTH = (MOTION_WIDTH <= 1) ? 1 : $clog2(MOTION_WIDTH);
  localparam integer MOTION_Y_WIDTH = (MOTION_HEIGHT <= 1) ? 1 : $clog2(MOTION_HEIGHT);
  wire [MOTION_X_WIDTH-1:0] motion_sample_x_narrow;
  wire [MOTION_Y_WIDTH-1:0] motion_sample_y_narrow;
  assign motion_sample_x_narrow = I_motion_sample_x;
  assign motion_sample_y_narrow = I_motion_sample_y;
  // The tracker emits event pulses only on a result cycle. The state output
  // is the persistent association contract used by idle-gap-safe consumers.
  assign tracker_tracking_level = (tracker_state == 2'd1);
  assign spine_target_enter = I_result_valid && I_result_tag_valid &&
                              I_detected && !I_invalid &&
                              !tracker_tracking_level;
  assign spine_target_exit = I_result_valid &&
                             (!I_result_tag_valid || !I_detected || I_invalid) &&
                             tracker_tracking_level;
  assign spine_tracking_lost = I_result_valid &&
                               ((tracker_state == 2'd2) || I_invalid ||
                                !I_result_tag_valid);

  temporal_tracker u_temporal_tracker (
    .I_clk          (I_clk),
    .I_rst_n        (I_rst_n),
    .I_frame_valid  (I_result_valid),
    .I_frame_id     (I_result_frame_id),
    .I_detected     (I_detected),
    .I_invalid      (I_invalid || !I_result_tag_valid),
    .I_cx           (I_cx),
    .I_cy           (I_cy),
    .O_result_valid (tracker_result_valid),
    .O_state        (tracker_state),
    .O_track_valid  (tracker_valid),
    .O_enter        (tracker_enter),
    .O_exit         (tracker_exit),
    .O_frame_gap    (tracker_frame_gap),
    .O_static       (),
    .O_cx           (tracker_cx),
    .O_cy           (tracker_cy),
    .O_dx           (tracker_dx),
    .O_dy           (tracker_dy),
    .O_direction    (tracker_direction),
    .O_lost_frames  (tracker_lost_frames)
  );

  wire [HISTORY_DEPTH*11-1:0] history_x_flat;
  wire [HISTORY_DEPTH*11-1:0] history_y_flat;
  wire [HISTORY_DEPTH-1:0] history_valid_mask;
  wire [$clog2(HISTORY_DEPTH+1)-1:0] history_count;

  trajectory_history #(
    .HISTORY_DEPTH (HISTORY_DEPTH),
    .COORD_WIDTH   (11)
  ) u_trajectory_history (
    .I_clk        (I_clk),
    .I_rst_n      (I_rst_n),
    .I_push       (I_result_valid && I_result_tag_valid &&
                   I_detected && !I_invalid),
    .I_new_track  (spine_target_enter),
    .I_cx         (I_cx),
    .I_cy         (I_cy),
    .O_x_flat     (history_x_flat),
    .O_y_flat     (history_y_flat),
    .O_valid_mask (history_valid_mask),
    .O_count      (history_count)
  );

  tracking_overlay #(
    .HISTORY_DEPTH (HISTORY_DEPTH),
    .COORD_WIDTH   (11)
  ) u_tracking_overlay (
    .I_clk          (I_clk),
    .I_rst_n        (I_rst_n),
    .I_de           (I_video_de && I_video_valid),
    .I_hsync        (I_video_hsync),
    .I_vsync        (I_video_vsync),
    .I_rgb          (I_video_rgb),
    .I_x            (I_video_x),
    .I_y            (I_video_y),
    .I_track_valid  (tracker_tracking_level),
    .I_valid_mask   (history_valid_mask),
    .I_x_flat       (history_x_flat),
    .I_y_flat       (history_y_flat),
    .O_de           (O_video_de),
    .O_hsync        (O_video_hsync),
    .O_vsync        (O_video_vsync),
    .O_rgb          (O_video_rgb)
  );

  frame_tag_monitor u_frame_tag_monitor (
    .I_clk             (I_clk),
    .I_rst_n           (I_rst_n),
    .I_input_valid     (I_frame_valid),
    .I_input_frame_id  (I_frame_id),
    .I_result_valid    (I_result_valid && I_result_tag_valid),
    .I_result_frame_id (I_result_frame_id),
    .I_video_valid     (I_video_valid),
    .I_video_frame_id  (I_video_frame_id),
    .O_pending         (),
    .O_active_frame_id (),
    .O_frame_gap       (),
    .O_result_match    (),
    .O_video_match     (),
    .O_tag_mismatch    (tag_mismatch),
    .O_timeout         ()
  );

  latency_monitor u_latency_monitor (
    .I_clk             (I_clk),
    .I_rst_n           (I_rst_n),
    .I_input_valid     (I_frame_valid),
    .I_input_frame_id  (I_frame_id),
    .I_result_valid    (I_result_valid && I_result_tag_valid),
    .I_result_frame_id (I_result_frame_id),
    .I_video_valid     (I_video_valid),
    .I_video_frame_id  (I_video_frame_id),
    .O_proc_valid      (O_latency_proc_valid),
    .O_proc_cycles     (O_latency_proc_cycles),
    .O_video_valid     (O_latency_video_valid),
    .O_video_cycles    (O_latency_video_cycles),
    .O_e2e_valid       (O_latency_e2e_valid),
    .O_e2e_cycles      (O_latency_e2e_cycles),
    .O_frame_gap       (latency_frame_gap),
    .O_tag_mismatch    (latency_tag_mismatch),
    .O_timeout         (latency_timeout)
  );

  motion_diff_160 #(
    .IMG_WIDTH      (MOTION_WIDTH),
    .IMG_HEIGHT     (MOTION_HEIGHT),
    .THRESHOLD      (MOTION_THRESHOLD)
  ) u_motion_diff_160 (
    .I_clk          (I_clk),
    .I_rst_n        (I_rst_n),
    .I_frame_start  (I_motion_frame_start),
    .I_frame_end    (I_motion_frame_end),
    .I_frame_invalid(I_motion_frame_invalid),
    .I_sample_valid (I_motion_sample_valid),
    .I_frame_id     (I_motion_frame_id),
    .I_sample_x     (motion_sample_x_narrow),
    .I_sample_y     (motion_sample_y_narrow),
    .I_y_value      (I_motion_y_value),
    .O_summary_valid(),
    .O_baseline_ready(),
    .O_motion_valid (O_motion_valid),
    .O_motion       (O_motion),
    .O_motion_count (O_motion_count),
    .O_xmin         (),
    .O_xmax         (),
    .O_ymin         (),
    .O_ymax         (),
    .O_frame_gap    (),
    .O_invalid      ()
  );

  generate
    if (ENABLE_V2_FRAME_AWB != 0) begin : gen_v2_frame_awb
      awb_frame_gain_controller #(
        .USE_FIXED_PIXEL_COUNT (USE_FIXED_AWB_PIXEL_COUNT),
        .FIXED_PIXEL_COUNT     (FIXED_AWB_PIXEL_COUNT)
      ) u_awb_frame_gain_controller (
        .I_clk                  (I_clk),
        .I_rst_n                (I_rst_n),
        .I_frame_stats_valid    (I_frame_stats_valid),
        .I_sum_r                (I_sum_r),
        .I_sum_g                (I_sum_g),
        .I_sum_b                (I_sum_b),
        .I_pixel_count          (I_pixel_count),
        .I_mean_luma            (I_mean_luma),
        .O_gain_r               (O_gain_r),
        .O_gain_g               (O_gain_g),
        .O_gain_b               (O_gain_b),
        .O_gain_update_valid    (O_gain_update_valid),
        .O_scene_protected      (O_scene_protected)
      );
    end else begin : gen_v2_frame_awb_lite
      assign O_gain_r = 16'd256;
      assign O_gain_g = 16'd256;
      assign O_gain_b = 16'd256;
      assign O_gain_update_valid = 1'b0;
      assign O_scene_protected = 1'b0;
    end
  endgenerate

  wire calibration_valid;
  wire calibration_invalid;

  dimension_calibrator #(
    .USE_STATIC_CONFIG              (USE_STATIC_CAL_CONFIG),
    .STATIC_SCALE_X_Q16_16           (STATIC_SCALE_X_Q16_16),
    .STATIC_SCALE_Y_Q16_16           (STATIC_SCALE_Y_Q16_16),
    .STATIC_NOMINAL_WIDTH_Q16_16     (STATIC_NOMINAL_WIDTH_Q16_16),
    .STATIC_NOMINAL_HEIGHT_Q16_16    (STATIC_NOMINAL_HEIGHT_Q16_16),
    .STATIC_TOLERANCE_WIDTH_Q16_16   (STATIC_TOLERANCE_WIDTH_Q16_16),
    .STATIC_TOLERANCE_HEIGHT_Q16_16  (STATIC_TOLERANCE_HEIGHT_Q16_16),
    .STATIC_OCCUPANCY_MIN_Q8         (STATIC_OCCUPANCY_MIN_Q8),
    .STATIC_ASPECT_MIN_Q8            (STATIC_ASPECT_MIN_Q8),
    .STATIC_ASPECT_MAX_Q8            (STATIC_ASPECT_MAX_Q8)
  ) u_dimension_calibrator (
    .I_clk                       (I_clk),
    .I_rst_n                     (I_rst_n),
    .I_result_valid              (I_result_valid),
    .I_calibration_valid         (I_calibration_valid),
    .I_xmin                      (I_xmin),
    .I_xmax                      (I_xmax),
    .I_ymin                      (I_ymin),
    .I_ymax                      (I_ymax),
    .I_area                      (I_area),
    .I_scale_x_q16_16            (I_scale_x_q16_16),
    .I_scale_y_q16_16            (I_scale_y_q16_16),
    .I_nominal_width_q16_16      (I_nominal_width_q16_16),
    .I_nominal_height_q16_16     (I_nominal_height_q16_16),
    .I_tolerance_width_q16_16    (I_tolerance_width_q16_16),
    .I_tolerance_height_q16_16   (I_tolerance_height_q16_16),
    .I_occupancy_min_q8          (I_occupancy_min_q8),
    .I_aspect_min_q8             (I_aspect_min_q8),
    .I_aspect_max_q8             (I_aspect_max_q8),
    .O_valid                     (calibration_valid),
    .O_invalid                   (calibration_invalid),
    .O_dimension_valid           (O_dimension_valid),
    .O_shape_valid               (O_shape_valid),
    .O_width_mm_q16_16           (O_width_mm_q16_16),
    .O_height_mm_q16_16          (O_height_mm_q16_16),
    .O_occupancy_q8              (O_occupancy_q8),
    .O_aspect_q8                 (O_aspect_q8)
  );

  wire safety_invalid = I_invalid || I_verdict_invalid || calibration_invalid;
  wire sort_request;
  wire sort_control_fault;

  sort_event_controller #(
    .TRIGGER_X    (SORT_TRIGGER_X),
    .CENTER_WIDTH (11),
    .COUNT_WIDTH  (16)
  ) u_sort_event_controller (
    .I_clk            (I_clk),
    .I_rst_n          (I_rst_n),
    .I_frame_valid    (I_frame_valid),
    .I_track_valid    (tracker_tracking_level),
    .I_target_enter   (spine_target_enter),
    .I_target_exit    (spine_target_exit),
    .I_tracking_lost  (spine_tracking_lost),
    .I_verdict_valid  (I_verdict_valid),
    .I_verdict_pass   (I_verdict_pass),
    .I_verdict_invalid(safety_invalid),
    .I_center_x       (I_cx),
    .O_enter_event    (),
    .O_pass_event     (),
    .O_ng_event       (),
    .O_sort_request   (sort_request),
    .O_control_fault  (sort_control_fault),
    .O_active         (),
    .O_classified     (),
    .O_triggered      (),
    .O_pass_count     (O_pass_count),
    .O_ng_count       (O_ng_count)
  );

  sort_safety_interlock u_sort_safety_interlock (
    .I_clk            (I_clk),
    .I_rst_n          (I_rst_n),
    .I_arm            (I_arm),
    .I_invalid        (safety_invalid),
    .I_tracking_lost  (spine_tracking_lost || sort_control_fault),
    .I_external_fault (I_external_fault),
    .I_clear_fault    (I_clear_fault),
    .O_safe_enable    (O_safe_enable),
    .O_request_allowed(),
    .O_safe_hold      (),
    .O_fault_latched  ()
  );

  sort_pulse_generator #(
    .PULSE_CYCLES (SORT_PULSE_CYCLES)
  ) u_sort_pulse_generator (
    .I_clk        (I_clk),
    .I_rst_n      (I_rst_n),
    .I_request    (sort_request),
    .I_enable     (O_safe_enable),
    .O_pulse      (O_sort_pulse),
    .O_busy       (O_sort_busy),
    .O_accepted   (O_sort_accepted),
    .O_rejected   (O_sort_rejected),
    .O_timeout    (O_sort_timeout)
  );

  assign O_sort_request = sort_request;
  assign O_track_valid  = tracker_tracking_level;
  assign O_tracking_state = tracker_state;
  assign O_track_cx     = tracker_cx;
  assign O_track_cy     = tracker_cy;
  assign O_track_enter  = spine_target_enter;
  assign O_track_exit   = spine_target_exit;
  assign O_frame_gap    = tracker_frame_gap || latency_frame_gap;
  assign O_tag_mismatch = tag_mismatch || latency_tag_mismatch || latency_timeout ||
                          (I_result_valid && !I_result_tag_valid);
  assign O_calibration_invalid = calibration_invalid;

endmodule
