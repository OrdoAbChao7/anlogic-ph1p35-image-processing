`timescale 1ns / 1ps
// ============================================================================
// Fixed red-part measurement classifier.
//
// Status encoding:
//   2'b00 NO_OBJECT, 2'b01 PASS, 2'b10 NG, 2'b11 INVALID.
// A status is changed only at the detector frame publication event.
// The three active-high LED outputs use a distinct status code:
//   PASS      = 3'b101 (pass + detected)
//   NG        = 3'b011 (ng + detected)
//   NO_OBJECT = 3'b000
//   INVALID   = 3'b110 (pass + ng, no detected)
// The INVALID code deliberately lights both result indicators so that it
// cannot be confused with a quiet NO_OBJECT state when mapped to board LEDs.
// ============================================================================

module defect_classifier #(
  parameter integer NOMINAL_WIDTH  = 120,
  parameter integer WIDTH_TOL      = 15,
  parameter integer NOMINAL_HEIGHT = 80,
  parameter integer HEIGHT_TOL     = 12,
  parameter integer MIN_AREA       = 100
)(
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_frame_sync,
  input  wire        I_detected,
  input  wire        I_invalid,
  input  wire [10:0] I_xmin,
  input  wire [10:0] I_xmax,
  input  wire [10:0] I_ymin,
  input  wire [10:0] I_ymax,
  input  wire [19:0] I_area,

  output reg  [10:0] O_width,
  output reg  [10:0] O_height,
  output reg         O_pass,
  output reg         O_ng,
  output reg         O_no_obj,
  output reg         O_invalid,
  output reg  [1:0]  O_status,
  output reg         O_led_pass,
  output reg         O_led_ng,
  output reg         O_led_det,
  output reg         O_result_toggle
);

  localparam [1:0] STATUS_NO_OBJECT = 2'b00;
  localparam [1:0] STATUS_PASS      = 2'b01;
  localparam [1:0] STATUS_NG        = 2'b10;
  localparam [1:0] STATUS_INVALID   = 2'b11;

  wire bbox_order_valid = (I_xmax >= I_xmin) && (I_ymax >= I_ymin);
  wire [10:0] calc_w = bbox_order_valid ? (I_xmax - I_xmin + 11'd1) : 11'd0;
  wire [10:0] calc_h = bbox_order_valid ? (I_ymax - I_ymin + 11'd1) : 11'd0;
  wire width_ok = (calc_w >= (NOMINAL_WIDTH - WIDTH_TOL)) &&
                  (calc_w <= (NOMINAL_WIDTH + WIDTH_TOL));
  wire height_ok = (calc_h >= (NOMINAL_HEIGHT - HEIGHT_TOL)) &&
                   (calc_h <= (NOMINAL_HEIGHT + HEIGHT_TOL));
  wire object_valid = I_detected && (I_area >= MIN_AREA);

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      O_width    <= 11'd0;
      O_height   <= 11'd0;
      O_pass     <= 1'b0;
      O_ng       <= 1'b0;
      O_no_obj   <= 1'b0;
      O_invalid  <= 1'b1;
      O_status   <= STATUS_INVALID;
      O_led_pass <= 1'b1;
      O_led_ng   <= 1'b1;
      O_led_det  <= 1'b0;
      O_result_toggle <= 1'b0;
    end else if (I_frame_sync) begin
      O_width    <= object_valid && bbox_order_valid ? calc_w : 11'd0;
      O_height   <= object_valid && bbox_order_valid ? calc_h : 11'd0;
      O_pass     <= 1'b0;
      O_ng       <= 1'b0;
      O_no_obj   <= 1'b0;
      O_invalid  <= 1'b0;
      O_led_pass <= 1'b0;
      O_led_ng   <= 1'b0;
      O_led_det  <= 1'b0;
      O_result_toggle <= ~O_result_toggle;

      // INVALID has priority over all measurements.
      if ((I_invalid === 1'b1) || (object_valid && !bbox_order_valid)) begin
        O_invalid <= 1'b1;
        O_status  <= STATUS_INVALID;
        O_led_pass <= 1'b1;
        O_led_ng   <= 1'b1;
        O_led_det  <= 1'b0;
      end else if (!object_valid) begin
        O_no_obj  <= 1'b1;
        O_status  <= STATUS_NO_OBJECT;
      end else if (width_ok && height_ok) begin
        O_pass     <= 1'b1;
        O_status   <= STATUS_PASS;
        O_led_pass <= 1'b1;
        O_led_det  <= 1'b1;
      end else begin
        O_ng     <= 1'b1;
        O_status <= STATUS_NG;
        O_led_ng <= 1'b1;
        O_led_det <= 1'b1;
      end
    end
  end

endmodule
