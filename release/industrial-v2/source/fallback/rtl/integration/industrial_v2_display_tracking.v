`timescale 1ns/1ps

// HDMI-domain tracking and trajectory overlay.
//
// Result fields arrive through an explicit CDC and are consumed as frame
// events. Pixel coordinates are generated in this same HDMI clock domain, so
// the overlay never samples a CSI/source-clock counter asynchronously.
module industrial_v2_display_tracking #(
  parameter integer IMG_WIDTH = 1280,
  parameter integer IMG_HEIGHT = 720,
  parameter integer HISTORY_DEPTH = 8
)(
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_frame_valid,
  input  wire [15:0] I_frame_id,
  input  wire        I_detected,
  input  wire        I_invalid,
  input  wire [10:0] I_cx,
  input  wire [10:0] I_cy,
  input  wire        I_de,
  input  wire        I_hsync,
  input  wire        I_vsync,
  input  wire [23:0] I_rgb,
  output wire        O_de,
  output wire        O_hsync,
  output wire        O_vsync,
  output wire [23:0] O_rgb,
  output wire        O_track_valid,
  output wire        O_track_enter,
  output wire        O_track_exit,
  output wire [1:0]  O_tracking_state,
  output wire [10:0] O_track_cx,
  output wire [10:0] O_track_cy
);

  wire        tracker_result_valid;
  wire [1:0]  tracker_state;
  wire        tracker_valid_pulse;
  wire        tracker_enter_pulse;
  wire        tracker_exit_pulse;
  wire        tracker_frame_gap;
  wire [10:0] tracker_cx;
  wire [10:0] tracker_cy;
  wire signed [11:0] tracker_dx;
  wire signed [11:0] tracker_dy;
  wire [3:0] tracker_direction;
  wire [2:0] tracker_lost_frames;

  temporal_tracker u_temporal_tracker (
    .I_clk          (I_clk),
    .I_rst_n        (I_rst_n),
    .I_frame_valid  (I_frame_valid),
    .I_frame_id     (I_frame_id),
    .I_detected     (I_detected),
    .I_invalid      (I_invalid),
    .I_cx           (I_cx),
    .I_cy           (I_cy),
    .O_result_valid (tracker_result_valid),
    .O_state        (tracker_state),
    .O_track_valid  (tracker_valid_pulse),
    .O_enter        (tracker_enter_pulse),
    .O_exit         (tracker_exit_pulse),
    .O_frame_gap    (tracker_frame_gap),
    .O_static       (),
    .O_cx           (tracker_cx),
    .O_cy           (tracker_cy),
    .O_dx           (tracker_dx),
    .O_dy           (tracker_dy),
    .O_direction    (tracker_direction),
    .O_lost_frames  (tracker_lost_frames)
  );

  wire tracking_level = (tracker_state == 2'd1);
  wire target_enter = I_frame_valid && I_detected && !I_invalid && !tracking_level;
  wire target_exit = I_frame_valid && (!I_detected || I_invalid) && tracking_level;
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
    .I_push       (I_frame_valid && I_detected && !I_invalid),
    .I_new_track  (target_enter),
    .I_cx         (I_cx),
    .I_cy         (I_cy),
    .O_x_flat     (history_x_flat),
    .O_y_flat     (history_y_flat),
    .O_valid_mask (history_valid_mask),
    .O_count      (history_count)
  );

  reg [11:0] video_x;
  reg [11:0] video_y;
  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      video_x <= 12'd0;
      video_y <= 12'd0;
    end else if (I_vsync) begin
      video_x <= 12'd0;
      video_y <= 12'd0;
    end else if (I_de) begin
      if (video_x == IMG_WIDTH-1) begin
        video_x <= 12'd0;
        video_y <= (video_y == IMG_HEIGHT-1) ? 12'd0 : video_y + 1'b1;
      end else begin
        video_x <= video_x + 1'b1;
      end
    end
  end

  tracking_overlay #(
    .IMG_WIDTH      (IMG_WIDTH),
    .IMG_HEIGHT     (IMG_HEIGHT),
    .HISTORY_DEPTH  (HISTORY_DEPTH),
    .COORD_WIDTH    (11)
  ) u_tracking_overlay (
    .I_clk          (I_clk),
    .I_rst_n        (I_rst_n),
    .I_de           (I_de),
    .I_hsync        (I_hsync),
    .I_vsync        (I_vsync),
    .I_rgb          (I_rgb),
    .I_x            (video_x[10:0]),
    .I_y            (video_y[10:0]),
    .I_track_valid  (tracking_level),
    .I_valid_mask   (history_valid_mask),
    .I_x_flat       (history_x_flat),
    .I_y_flat       (history_y_flat),
    .O_de           (O_de),
    .O_hsync        (O_hsync),
    .O_vsync        (O_vsync),
    .O_rgb          (O_rgb)
  );

  assign O_track_valid = tracking_level;
  assign O_track_enter = target_enter;
  assign O_track_exit  = target_exit;
  assign O_tracking_state = tracker_state;
  assign O_track_cx = tracker_cx;
  assign O_track_cy = tracker_cy;
endmodule
