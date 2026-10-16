`timescale 1ns / 1ps
// ============================================================================
// Module: defect_classifier
// Description: Real-time FPGA industrial dimension measurement & PASS/NG decision.
// Reference:
//   - 03_geometry_recognition: streaming geometry statistics
// ============================================================================

module defect_classifier #(
  parameter integer NOMINAL_WIDTH  = 120,
  parameter integer WIDTH_TOL      = 15,
  parameter integer NOMINAL_HEIGHT = 80,
  parameter integer HEIGHT_TOL     = 12
)(
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_frame_sync,         // Pulses high for 1 cycle at frame latch
  input  wire        I_detected,           // 1 if object recognized
  input  wire [10:0] I_xmin,
  input  wire [10:0] I_xmax,
  input  wire [10:0] I_ymin,
  input  wire [10:0] I_ymax,
  input  wire [18:0] I_area,

  output reg  [10:0] O_width,              // Measured width in px: xmax - xmin + 1
  output reg  [10:0] O_height,             // Measured height in px: ymax - ymin + 1
  output reg         O_pass,               // 1 = workpiece dimensions within tolerance
  output reg         O_ng,                 // 1 = workpiece dimensions out of tolerance
  output reg         O_no_obj,             // 1 = no workpiece on conveyor
  output reg         O_led_pass,           // Direct LED driver (Active High)
  output reg         O_led_ng              // Direct LED driver (Active High)
);

  wire [10:0] calc_w = (I_xmax >= I_xmin) ? (I_xmax - I_xmin + 11'd1) : 11'd0;
  wire [10:0] calc_h = (I_ymax >= I_ymin) ? (I_ymax - I_ymin + 11'd1) : 11'd0;

  wire w_ok = (calc_w >= (NOMINAL_WIDTH - WIDTH_TOL)) && (calc_w <= (NOMINAL_WIDTH + WIDTH_TOL));
  wire h_ok = (calc_h >= (NOMINAL_HEIGHT - HEIGHT_TOL)) && (calc_h <= (NOMINAL_HEIGHT + HEIGHT_TOL));

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      O_width    <= 11'd0;
      O_height   <= 11'd0;
      O_pass     <= 1'b0;
      O_ng       <= 1'b0;
      O_no_obj   <= 1'b1;
      O_led_pass <= 1'b0;
      O_led_ng   <= 1'b0;
    end else if (I_frame_sync) begin
      if (I_detected) begin
        O_width  <= calc_w;
        O_height <= calc_h;
        O_no_obj <= 1'b0;
        if (w_ok && h_ok) begin
          O_pass     <= 1'b1;
          O_ng       <= 1'b0;
          O_led_pass <= 1'b1;
          O_led_ng   <= 1'b0;
        end else begin
          O_pass     <= 1'b0;
          O_ng       <= 1'b1;
          O_led_pass <= 1'b0;
          O_led_ng   <= 1'b1;
        end
      end else begin
        O_width    <= 11'd0;
        O_height   <= 11'd0;
        O_pass     <= 1'b0;
        O_ng       <= 1'b0;
        O_no_obj   <= 1'b1;
        O_led_pass <= 1'b0;
        O_led_ng   <= 1'b0;
      end
    end
  end

endmodule
