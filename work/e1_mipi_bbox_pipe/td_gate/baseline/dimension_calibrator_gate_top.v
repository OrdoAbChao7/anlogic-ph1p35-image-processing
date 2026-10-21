`timescale 1ns/1ps
// E1 Gate A/B harness (69 IO: 68 in / 1 out) — same shape as the frozen R4
// module-Gate harness so the baseline number is directly comparable.
//
// Producer model: BBox / area / calibration commit on edge T; the result event
// arrives one cycle later (T+1). This reproduces color_detect_96_v2 ->
// defect_classifier -> ind_v2_toggle_d in the real top.
//
// Only O_shape_valid is exposed: in the production top the numeric telemetry
// (O_occupancy_q8 / O_aspect_q8) is dead, and O_width_mm/O_height_mm are plain
// taps of width_product/height_product that add no logic to the shape cone.
// O_dimension_valid is retained inside the cone because shape_valid_now
// ANDs it.
module dimension_calibrator_gate_top (
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_result_valid,
  input  wire        I_calibration_valid,
  input  wire [10:0] I_xmin, I_xmax, I_ymin, I_ymax,
  input  wire [19:0] I_area,
  output wire        O_shape_valid
);
  reg result_valid_r1, result_valid_r;
  reg calibration_valid_r;
  reg [10:0] xmin_r, xmax_r, ymin_r, ymax_r;
  reg [19:0] area_r;
  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      result_valid_r1 <= 1'b0; result_valid_r <= 1'b0;
      calibration_valid_r <= 1'b0;
      xmin_r <= 0; xmax_r <= 0; ymin_r <= 0; ymax_r <= 0; area_r <= 0;
    end else begin
      result_valid_r1 <= I_result_valid;
      result_valid_r  <= result_valid_r1;
      calibration_valid_r <= I_calibration_valid;
      xmin_r <= I_xmin; xmax_r <= I_xmax; ymin_r <= I_ymin; ymax_r <= I_ymax;
      area_r <= I_area;
    end
  end

  dimension_calibrator #(
    .COORD_WIDTH(11), .USE_STATIC_CONFIG(1),
    .STATIC_SCALE_X_Q16_16(32'd32768), .STATIC_SCALE_Y_Q16_16(32'd16384),
    .STATIC_NOMINAL_WIDTH_Q16_16(32'd3932160),
    .STATIC_NOMINAL_HEIGHT_Q16_16(32'd1310720),
    .STATIC_TOLERANCE_WIDTH_Q16_16(32'd131072),
    .STATIC_TOLERANCE_HEIGHT_Q16_16(32'd131072),
    .STATIC_OCCUPANCY_MIN_Q8(9'd200),
    .STATIC_ASPECT_MIN_Q8(16'd320), .STATIC_ASPECT_MAX_Q8(16'd448)
  ) dut (
    .I_clk(I_clk), .I_rst_n(I_rst_n), .I_result_valid(result_valid_r),
    .I_calibration_valid(calibration_valid_r), .I_xmin(xmin_r), .I_xmax(xmax_r),
    .I_ymin(ymin_r), .I_ymax(ymax_r), .I_area(area_r),
    .I_scale_x_q16_16(32'd32768), .I_scale_y_q16_16(32'd16384),
    .I_nominal_width_q16_16(32'd3932160), .I_nominal_height_q16_16(32'd1310720),
    .I_tolerance_width_q16_16(32'd131072), .I_tolerance_height_q16_16(32'd131072),
    .I_occupancy_min_q8(9'd200), .I_aspect_min_q8(16'd320), .I_aspect_max_q8(16'd448),
    .O_valid(), .O_invalid(), .O_dimension_valid(), .O_shape_valid(O_shape_valid),
    .O_width_mm_q16_16(), .O_height_mm_q16_16(), .O_occupancy_q8(), .O_aspect_q8()
  );
endmodule
