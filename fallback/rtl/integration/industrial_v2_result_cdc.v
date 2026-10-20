`timescale 1ns/1ps

// Asynchronous assertion with two-clock synchronous deassertion. Instantiate
// once per destination clock domain; the asynchronous lock may release at any
// phase relative to each local clock.
module reset_release_sync (
  input  wire I_clk,
  input  wire I_async_rst_n,
  output wire O_rst_n
);
  reg [1:0] release_pipe;

  always @(posedge I_clk or negedge I_async_rst_n) begin
    if (!I_async_rst_n)
      release_pipe <= 2'b00;
    else
      release_pipe <= {release_pipe[0], 1'b1};
  end

  assign O_rst_n = release_pipe[1];
endmodule

// Stable-payload/toggle CDC for one-frame industrial results.
//
// The source domain captures the complete payload before changing the toggle.
// The destination domain synchronizes the toggle and the held payload through
// two registers, then waits one additional cycle before publishing. A new
// source event while a previous event is pending is reported as overflow; it
// is never silently presented as a valid complete result.
module industrial_v2_result_cdc (
  input  wire        I_src_clk,
  input  wire        I_dst_clk,
  input  wire        I_src_rst_n,
  input  wire        I_dst_rst_n,
  input  wire        I_src_toggle,
  input  wire [15:0] I_src_frame_id,
  input  wire [10:0] I_src_xmin,
  input  wire [10:0] I_src_xmax,
  input  wire [10:0] I_src_ymin,
  input  wire [10:0] I_src_ymax,
  input  wire [10:0] I_src_cx,
  input  wire [10:0] I_src_cy,
  input  wire [31:0] I_src_width_mm_q16_16,
  input  wire [31:0] I_src_height_mm_q16_16,
  input  wire        I_src_detected,
  input  wire        I_src_pass,
  input  wire        I_src_ng,
  input  wire        I_src_invalid,
  input  wire        I_src_dimension_valid,
  input  wire        I_src_shape_valid,
  input  wire        I_src_motion_valid,
  input  wire        I_src_motion,
  input  wire [23:0] I_src_motion_count,
  input  wire [15:0] I_src_pass_count,
  input  wire [15:0] I_src_ng_count,
  input  wire        I_src_sort_pulse,
  input  wire        I_src_safe_enable,
  input  wire        I_src_proc_valid,
  input  wire [31:0] I_src_proc_cycles,
  output reg         O_dst_valid,
  output reg  [15:0] O_dst_frame_id,
  output reg  [10:0] O_dst_xmin,
  output reg  [10:0] O_dst_xmax,
  output reg  [10:0] O_dst_ymin,
  output reg  [10:0] O_dst_ymax,
  output reg  [10:0] O_dst_cx,
  output reg  [10:0] O_dst_cy,
  output reg  [31:0] O_dst_width_mm_q16_16,
  output reg  [31:0] O_dst_height_mm_q16_16,
  output reg         O_dst_detected,
  output reg         O_dst_pass,
  output reg         O_dst_ng,
  output reg         O_dst_invalid,
  output reg         O_dst_dimension_valid,
  output reg         O_dst_shape_valid,
  output reg         O_dst_motion_valid,
  output reg         O_dst_motion,
  output reg  [23:0] O_dst_motion_count,
  output reg  [15:0] O_dst_pass_count,
  output reg  [15:0] O_dst_ng_count,
  output reg         O_dst_sort_pulse,
  output reg         O_dst_safe_enable,
  output reg         O_dst_proc_valid,
  output reg  [31:0] O_dst_proc_cycles,
  output reg         O_dst_overflow
);

  reg src_toggle_hold;
  reg [15:0] src_frame_id_hold;
  reg [10:0] src_xmin_hold, src_xmax_hold, src_ymin_hold, src_ymax_hold;
  reg [10:0] src_cx_hold, src_cy_hold;
  reg [31:0] src_width_hold, src_height_hold;
  reg src_detected_hold, src_pass_hold, src_ng_hold, src_invalid_hold;
  reg src_dimension_valid_hold, src_shape_valid_hold;
  reg src_motion_valid_hold, src_motion_hold;
  reg [23:0] src_motion_count_hold;
  reg [15:0] src_pass_count_hold, src_ng_count_hold;
  reg src_sort_pulse_hold, src_safe_enable_hold;
  reg src_proc_valid_hold;
  reg [31:0] src_proc_cycles_hold;

  reg toggle_meta;
  reg toggle_sync;
  reg toggle_seen;
  reg event_pending;
  reg [15:0] payload_meta_frame_id, payload_sync_frame_id;
  reg [10:0] payload_meta_xmin, payload_sync_xmin;
  reg [10:0] payload_meta_xmax, payload_sync_xmax;
  reg [10:0] payload_meta_ymin, payload_sync_ymin;
  reg [10:0] payload_meta_ymax, payload_sync_ymax;
  reg [10:0] payload_meta_cx, payload_sync_cx;
  reg [10:0] payload_meta_cy, payload_sync_cy;
  reg [31:0] payload_meta_width, payload_sync_width;
  reg [31:0] payload_meta_height, payload_sync_height;
  reg payload_meta_detected, payload_sync_detected;
  reg payload_meta_pass, payload_sync_pass;
  reg payload_meta_ng, payload_sync_ng;
  reg payload_meta_invalid, payload_sync_invalid;
  reg payload_meta_dimension_valid, payload_sync_dimension_valid;
  reg payload_meta_shape_valid, payload_sync_shape_valid;
  reg payload_meta_motion_valid, payload_sync_motion_valid;
  reg payload_meta_motion, payload_sync_motion;
  reg [23:0] payload_meta_motion_count, payload_sync_motion_count;
  reg [15:0] payload_meta_pass_count, payload_sync_pass_count;
  reg [15:0] payload_meta_ng_count, payload_sync_ng_count;
  reg payload_meta_sort_pulse, payload_sync_sort_pulse;
  reg payload_meta_safe_enable, payload_sync_safe_enable;
  reg payload_meta_proc_valid, payload_sync_proc_valid;
  reg [31:0] payload_meta_proc_cycles, payload_sync_proc_cycles;

  always @(posedge I_src_clk or negedge I_src_rst_n) begin
    if (!I_src_rst_n) begin
      src_toggle_hold <= 1'b0;
      src_frame_id_hold <= 16'd0;
      src_xmin_hold <= 11'd0;
      src_xmax_hold <= 11'd0;
      src_ymin_hold <= 11'd0;
      src_ymax_hold <= 11'd0;
      src_cx_hold <= 11'd0;
      src_cy_hold <= 11'd0;
      src_width_hold <= 32'd0;
      src_height_hold <= 32'd0;
      src_detected_hold <= 1'b0;
      src_pass_hold <= 1'b0;
      src_ng_hold <= 1'b0;
      src_invalid_hold <= 1'b0;
      src_dimension_valid_hold <= 1'b0;
      src_shape_valid_hold <= 1'b0;
      src_motion_valid_hold <= 1'b0;
      src_motion_hold <= 1'b0;
      src_motion_count_hold <= 24'd0;
      src_pass_count_hold <= 16'd0;
      src_ng_count_hold <= 16'd0;
      src_sort_pulse_hold <= 1'b0;
      src_safe_enable_hold <= 1'b0;
      src_proc_valid_hold <= 1'b0;
      src_proc_cycles_hold <= 32'd0;
    end else if (I_src_toggle != src_toggle_hold) begin
      src_frame_id_hold <= I_src_frame_id;
      src_xmin_hold <= I_src_xmin;
      src_xmax_hold <= I_src_xmax;
      src_ymin_hold <= I_src_ymin;
      src_ymax_hold <= I_src_ymax;
      src_cx_hold <= I_src_cx;
      src_cy_hold <= I_src_cy;
      src_width_hold <= I_src_width_mm_q16_16;
      src_height_hold <= I_src_height_mm_q16_16;
      src_detected_hold <= I_src_detected;
      src_pass_hold <= I_src_pass;
      src_ng_hold <= I_src_ng;
      src_invalid_hold <= I_src_invalid;
      src_dimension_valid_hold <= I_src_dimension_valid;
      src_shape_valid_hold <= I_src_shape_valid;
      src_motion_valid_hold <= I_src_motion_valid;
      src_motion_hold <= I_src_motion;
      src_motion_count_hold <= I_src_motion_count;
      src_pass_count_hold <= I_src_pass_count;
      src_ng_count_hold <= I_src_ng_count;
      src_sort_pulse_hold <= I_src_sort_pulse;
      src_safe_enable_hold <= I_src_safe_enable;
      src_proc_valid_hold <= I_src_proc_valid;
      src_proc_cycles_hold <= I_src_proc_valid ? I_src_proc_cycles : 32'd0;
      src_toggle_hold <= I_src_toggle;
    end
  end

  always @(posedge I_dst_clk or negedge I_dst_rst_n) begin
    if (!I_dst_rst_n) begin
      toggle_meta <= 1'b0;
      toggle_sync <= 1'b0;
      toggle_seen <= 1'b0;
      event_pending <= 1'b0;
      payload_meta_frame_id <= 16'd0;
      payload_sync_frame_id <= 16'd0;
      payload_meta_xmin <= 11'd0; payload_sync_xmin <= 11'd0;
      payload_meta_xmax <= 11'd0; payload_sync_xmax <= 11'd0;
      payload_meta_ymin <= 11'd0; payload_sync_ymin <= 11'd0;
      payload_meta_ymax <= 11'd0; payload_sync_ymax <= 11'd0;
      payload_meta_cx <= 11'd0; payload_sync_cx <= 11'd0;
      payload_meta_cy <= 11'd0; payload_sync_cy <= 11'd0;
      payload_meta_width <= 32'd0; payload_sync_width <= 32'd0;
      payload_meta_height <= 32'd0; payload_sync_height <= 32'd0;
      payload_meta_detected <= 1'b0; payload_sync_detected <= 1'b0;
      payload_meta_pass <= 1'b0; payload_sync_pass <= 1'b0;
      payload_meta_ng <= 1'b0; payload_sync_ng <= 1'b0;
      payload_meta_invalid <= 1'b0; payload_sync_invalid <= 1'b0;
      payload_meta_dimension_valid <= 1'b0; payload_sync_dimension_valid <= 1'b0;
      payload_meta_shape_valid <= 1'b0; payload_sync_shape_valid <= 1'b0;
      payload_meta_motion_valid <= 1'b0; payload_sync_motion_valid <= 1'b0;
      payload_meta_motion <= 1'b0; payload_sync_motion <= 1'b0;
      payload_meta_motion_count <= 24'd0; payload_sync_motion_count <= 24'd0;
      payload_meta_pass_count <= 16'd0; payload_sync_pass_count <= 16'd0;
      payload_meta_ng_count <= 16'd0; payload_sync_ng_count <= 16'd0;
      payload_meta_sort_pulse <= 1'b0; payload_sync_sort_pulse <= 1'b0;
      payload_meta_safe_enable <= 1'b0; payload_sync_safe_enable <= 1'b0;
      payload_meta_proc_valid <= 1'b0; payload_sync_proc_valid <= 1'b0;
      payload_meta_proc_cycles <= 32'd0; payload_sync_proc_cycles <= 32'd0;
      O_dst_valid <= 1'b0;
      O_dst_frame_id <= 16'd0;
      O_dst_xmin <= 11'd0; O_dst_xmax <= 11'd0;
      O_dst_ymin <= 11'd0; O_dst_ymax <= 11'd0;
      O_dst_cx <= 11'd0; O_dst_cy <= 11'd0;
      O_dst_width_mm_q16_16 <= 32'd0;
      O_dst_height_mm_q16_16 <= 32'd0;
      O_dst_detected <= 1'b0; O_dst_pass <= 1'b0;
      O_dst_ng <= 1'b0; O_dst_invalid <= 1'b0;
      O_dst_dimension_valid <= 1'b0; O_dst_shape_valid <= 1'b0;
      O_dst_motion_valid <= 1'b0;
      O_dst_motion <= 1'b0; O_dst_motion_count <= 24'd0;
      O_dst_pass_count <= 16'd0; O_dst_ng_count <= 16'd0;
      O_dst_sort_pulse <= 1'b0; O_dst_safe_enable <= 1'b0;
      O_dst_proc_valid <= 1'b0; O_dst_proc_cycles <= 32'd0;
      O_dst_overflow <= 1'b0;
    end else begin
      toggle_meta <= src_toggle_hold;
      toggle_sync <= toggle_meta;
      payload_meta_frame_id <= src_frame_id_hold;
      payload_sync_frame_id <= payload_meta_frame_id;
      payload_meta_xmin <= src_xmin_hold; payload_sync_xmin <= payload_meta_xmin;
      payload_meta_xmax <= src_xmax_hold; payload_sync_xmax <= payload_meta_xmax;
      payload_meta_ymin <= src_ymin_hold; payload_sync_ymin <= payload_meta_ymin;
      payload_meta_ymax <= src_ymax_hold; payload_sync_ymax <= payload_meta_ymax;
      payload_meta_cx <= src_cx_hold; payload_sync_cx <= payload_meta_cx;
      payload_meta_cy <= src_cy_hold; payload_sync_cy <= payload_meta_cy;
      payload_meta_width <= src_width_hold; payload_sync_width <= payload_meta_width;
      payload_meta_height <= src_height_hold; payload_sync_height <= payload_meta_height;
      payload_meta_detected <= src_detected_hold; payload_sync_detected <= payload_meta_detected;
      payload_meta_pass <= src_pass_hold; payload_sync_pass <= payload_meta_pass;
      payload_meta_ng <= src_ng_hold; payload_sync_ng <= payload_meta_ng;
      payload_meta_invalid <= src_invalid_hold; payload_sync_invalid <= payload_meta_invalid;
      payload_meta_dimension_valid <= src_dimension_valid_hold; payload_sync_dimension_valid <= payload_meta_dimension_valid;
      payload_meta_shape_valid <= src_shape_valid_hold; payload_sync_shape_valid <= payload_meta_shape_valid;
      payload_meta_motion_valid <= src_motion_valid_hold; payload_sync_motion_valid <= payload_meta_motion_valid;
      payload_meta_motion <= src_motion_hold; payload_sync_motion <= payload_meta_motion;
      payload_meta_motion_count <= src_motion_count_hold; payload_sync_motion_count <= payload_meta_motion_count;
      payload_meta_pass_count <= src_pass_count_hold; payload_sync_pass_count <= payload_meta_pass_count;
      payload_meta_ng_count <= src_ng_count_hold; payload_sync_ng_count <= payload_meta_ng_count;
      payload_meta_sort_pulse <= src_sort_pulse_hold; payload_sync_sort_pulse <= payload_meta_sort_pulse;
      payload_meta_safe_enable <= src_safe_enable_hold; payload_sync_safe_enable <= payload_meta_safe_enable;
      payload_meta_proc_valid <= src_proc_valid_hold; payload_sync_proc_valid <= payload_meta_proc_valid;
      payload_meta_proc_cycles <= src_proc_cycles_hold; payload_sync_proc_cycles <= payload_meta_proc_cycles;

      O_dst_valid <= 1'b0;
      O_dst_overflow <= 1'b0;
      if (toggle_sync != toggle_seen) begin
        if (event_pending)
          O_dst_overflow <= 1'b1;
        // A newly observed toggle is acknowledged immediately. The payload
        // itself is published on the following destination cycle, after the
        // synchronized bus has had one full cycle to settle.
        toggle_seen <= toggle_sync;
        event_pending <= 1'b1;
      end
      if (event_pending) begin
        O_dst_valid <= 1'b1;
        O_dst_frame_id <= payload_sync_frame_id;
        O_dst_xmin <= payload_sync_xmin; O_dst_xmax <= payload_sync_xmax;
        O_dst_ymin <= payload_sync_ymin; O_dst_ymax <= payload_sync_ymax;
        O_dst_cx <= payload_sync_cx; O_dst_cy <= payload_sync_cy;
        O_dst_width_mm_q16_16 <= payload_sync_width;
        O_dst_height_mm_q16_16 <= payload_sync_height;
        O_dst_detected <= payload_sync_detected;
        O_dst_pass <= payload_sync_pass;
        O_dst_ng <= payload_sync_ng;
        O_dst_invalid <= payload_sync_invalid;
        O_dst_dimension_valid <= payload_sync_dimension_valid;
        O_dst_shape_valid <= payload_sync_shape_valid;
        O_dst_motion_valid <= payload_sync_motion_valid;
        O_dst_motion <= payload_sync_motion;
        O_dst_motion_count <= payload_sync_motion_count;
        O_dst_pass_count <= payload_sync_pass_count;
        O_dst_ng_count <= payload_sync_ng_count;
        O_dst_sort_pulse <= payload_sync_sort_pulse;
        O_dst_safe_enable <= payload_sync_safe_enable;
        O_dst_proc_valid <= payload_sync_proc_valid;
        O_dst_proc_cycles <= payload_sync_proc_cycles;
        event_pending <= 1'b0;
      end
    end
  end
endmodule
