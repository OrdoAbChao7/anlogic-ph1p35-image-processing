`timescale 1ns/1ps

// Fixed-point dimension and single-target shape checker.
// Inputs are inclusive pixel BBox endpoints and a calibrated Q16.16 mm/pixel
// scale. Results are published only on I_result_valid and are explicitly
// invalid when calibration or geometry is unavailable.
module dimension_calibrator_baseline #(
  parameter integer COORD_WIDTH = 11,
  parameter integer USE_STATIC_CONFIG = 0,
  parameter [31:0] STATIC_SCALE_X_Q16_16 = 32'd0,
  parameter [31:0] STATIC_SCALE_Y_Q16_16 = 32'd0,
  parameter [31:0] STATIC_NOMINAL_WIDTH_Q16_16 = 32'd0,
  parameter [31:0] STATIC_NOMINAL_HEIGHT_Q16_16 = 32'd0,
  parameter [31:0] STATIC_TOLERANCE_WIDTH_Q16_16 = 32'd0,
  parameter [31:0] STATIC_TOLERANCE_HEIGHT_Q16_16 = 32'd0,
  parameter [8:0]  STATIC_OCCUPANCY_MIN_Q8 = 9'd0,
  parameter [15:0] STATIC_ASPECT_MIN_Q8 = 16'd0,
  parameter [15:0] STATIC_ASPECT_MAX_Q8 = 16'hffff
)(
  input  wire                     I_clk,
  input  wire                     I_rst_n,
  input  wire                     I_result_valid,
  input  wire                     I_calibration_valid,
  input  wire [COORD_WIDTH-1:0]   I_xmin,
  input  wire [COORD_WIDTH-1:0]   I_xmax,
  input  wire [COORD_WIDTH-1:0]   I_ymin,
  input  wire [COORD_WIDTH-1:0]   I_ymax,
  input  wire [19:0]              I_area,
  input  wire [31:0]              I_scale_x_q16_16,
  input  wire [31:0]              I_scale_y_q16_16,
  input  wire [31:0]              I_nominal_width_q16_16,
  input  wire [31:0]              I_nominal_height_q16_16,
  input  wire [31:0]              I_tolerance_width_q16_16,
  input  wire [31:0]              I_tolerance_height_q16_16,
  input  wire [8:0]               I_occupancy_min_q8,
  input  wire [15:0]              I_aspect_min_q8,
  input  wire [15:0]              I_aspect_max_q8,
  output reg                      O_valid,
  output reg                      O_invalid,
  output reg                      O_dimension_valid,
  output reg                      O_shape_valid,
  output reg  [31:0]              O_width_mm_q16_16,
  output reg  [31:0]              O_height_mm_q16_16,
  output reg  [8:0]               O_occupancy_q8,
  output reg  [15:0]              O_aspect_q8
);

  // The detector contract uses 11-bit coordinates and a 20-bit area. Keep
  // the frame-result arithmetic at the widths required by those contracts;
  // widening every operand to 64 bits creates unnecessarily large
  // combinational multipliers/dividers in the TD implementation.
  localparam integer PIXEL_WIDTH = COORD_WIDTH + 1;
  localparam integer BBOX_AREA_WIDTH = PIXEL_WIDTH * 2;
  localparam integer SCALE_PRODUCT_WIDTH = PIXEL_WIDTH + 32;
  localparam integer OCCUPANCY_PRODUCT_WIDTH = 20 + 9;
  localparam integer ASPECT_PRODUCT_WIDTH = PIXEL_WIDTH + 9;
  localparam integer OCCUPANCY_COMPARE_WIDTH = BBOX_AREA_WIDTH + 9;
  localparam integer ASPECT_COMPARE_WIDTH = PIXEL_WIDTH + 17;

  // The formal PH1P35 candidate may specialize its provisional fixture values
  // at elaboration time. Generic instances retain the runtime configuration
  // interface used by unit tests and future calibrated builds.
  wire [31:0] scale_x_q16_16 = USE_STATIC_CONFIG ?
                                STATIC_SCALE_X_Q16_16 : I_scale_x_q16_16;
  wire [31:0] scale_y_q16_16 = USE_STATIC_CONFIG ?
                                STATIC_SCALE_Y_Q16_16 : I_scale_y_q16_16;
  wire [31:0] nominal_width_q16_16 = USE_STATIC_CONFIG ?
                                      STATIC_NOMINAL_WIDTH_Q16_16 : I_nominal_width_q16_16;
  wire [31:0] nominal_height_q16_16 = USE_STATIC_CONFIG ?
                                       STATIC_NOMINAL_HEIGHT_Q16_16 : I_nominal_height_q16_16;
  wire [31:0] tolerance_width_q16_16 = USE_STATIC_CONFIG ?
                                        STATIC_TOLERANCE_WIDTH_Q16_16 : I_tolerance_width_q16_16;
  wire [31:0] tolerance_height_q16_16 = USE_STATIC_CONFIG ?
                                         STATIC_TOLERANCE_HEIGHT_Q16_16 : I_tolerance_height_q16_16;
  wire [8:0] occupancy_min_q8 = USE_STATIC_CONFIG ?
                                  STATIC_OCCUPANCY_MIN_Q8 : I_occupancy_min_q8;
  wire [15:0] aspect_min_q8 = USE_STATIC_CONFIG ?
                                STATIC_ASPECT_MIN_Q8 : I_aspect_min_q8;
  wire [15:0] aspect_max_q8 = USE_STATIC_CONFIG ?
                                STATIC_ASPECT_MAX_Q8 : I_aspect_max_q8;

  wire [PIXEL_WIDTH-1:0] width_px = (I_xmax >= I_xmin) ?
                                     ({1'b0, I_xmax} - {1'b0, I_xmin} +
                                      {{COORD_WIDTH{1'b0}}, 1'b1}) : 0;
  wire [PIXEL_WIDTH-1:0] height_px = (I_ymax >= I_ymin) ?
                                      ({1'b0, I_ymax} - {1'b0, I_ymin} +
                                       {{COORD_WIDTH{1'b0}}, 1'b1}) : 0;
  wire bbox_valid = (I_xmax >= I_xmin) && (I_ymax >= I_ymin) &&
                    (width_px != 0) && (height_px != 0);
  wire [BBOX_AREA_WIDTH-1:0] width_px_bbox =
      {{(BBOX_AREA_WIDTH-PIXEL_WIDTH){1'b0}}, width_px};
  wire [BBOX_AREA_WIDTH-1:0] height_px_bbox =
      {{(BBOX_AREA_WIDTH-PIXEL_WIDTH){1'b0}}, height_px};
  wire [BBOX_AREA_WIDTH-1:0] bbox_area = width_px_bbox * height_px_bbox;

  wire [SCALE_PRODUCT_WIDTH-1:0] width_px_scale =
      {{(SCALE_PRODUCT_WIDTH-PIXEL_WIDTH){1'b0}}, width_px};
  wire [SCALE_PRODUCT_WIDTH-1:0] height_px_scale =
      {{(SCALE_PRODUCT_WIDTH-PIXEL_WIDTH){1'b0}}, height_px};
  wire [SCALE_PRODUCT_WIDTH-1:0] scale_x_ext =
      {{(SCALE_PRODUCT_WIDTH-32){1'b0}}, scale_x_q16_16};
  wire [SCALE_PRODUCT_WIDTH-1:0] scale_y_ext =
      {{(SCALE_PRODUCT_WIDTH-32){1'b0}}, scale_y_q16_16};
  wire [SCALE_PRODUCT_WIDTH-1:0] width_product = width_px_scale * scale_x_ext;
  wire [SCALE_PRODUCT_WIDTH-1:0] height_product = height_px_scale * scale_y_ext;

  wire [OCCUPANCY_PRODUCT_WIDTH-1:0] area_ext =
      {{(OCCUPANCY_PRODUCT_WIDTH-20){1'b0}}, I_area};
  wire [OCCUPANCY_PRODUCT_WIDTH-1:0] occupancy_scale =
      {{(OCCUPANCY_PRODUCT_WIDTH-9){1'b0}}, 9'd256};
  wire [OCCUPANCY_PRODUCT_WIDTH-1:0] occupancy_product = area_ext * occupancy_scale;
  wire [OCCUPANCY_PRODUCT_WIDTH-1:0] occupancy_denominator =
      {{(OCCUPANCY_PRODUCT_WIDTH-BBOX_AREA_WIDTH){1'b0}}, bbox_area};
  wire [OCCUPANCY_PRODUCT_WIDTH-1:0] occupancy_raw = (bbox_area != 0) ?
                               (occupancy_product / occupancy_denominator) : 0;

  // For the pass/fail predicate, compare cross-products directly. This is
  // exactly equivalent to comparing floor(numerator / denominator) with the
  // integer threshold, and lets synthesis discard the variable dividers when
  // the optional numeric telemetry outputs are not consumed.
  wire [OCCUPANCY_COMPARE_WIDTH-1:0] bbox_area_ext_occ =
      {{(OCCUPANCY_COMPARE_WIDTH-BBOX_AREA_WIDTH){1'b0}}, bbox_area};
  wire [OCCUPANCY_COMPARE_WIDTH-1:0] occupancy_min_ext =
      {{(OCCUPANCY_COMPARE_WIDTH-9){1'b0}}, occupancy_min_q8};
  wire [OCCUPANCY_COMPARE_WIDTH-1:0] occupancy_product_ext =
      {{(OCCUPANCY_COMPARE_WIDTH-OCCUPANCY_PRODUCT_WIDTH){1'b0}}, occupancy_product};
  wire [OCCUPANCY_COMPARE_WIDTH-1:0] bbox_occupancy_min_product =
      bbox_area_ext_occ * occupancy_min_ext;
  wire occupancy_min_met = (occupancy_min_q8 <= 9'd256) &&
                           (occupancy_product_ext >= bbox_occupancy_min_product);

  wire [ASPECT_PRODUCT_WIDTH-1:0] width_px_aspect =
      {{(ASPECT_PRODUCT_WIDTH-PIXEL_WIDTH){1'b0}}, width_px};
  wire [ASPECT_PRODUCT_WIDTH-1:0] aspect_scale =
      {{(ASPECT_PRODUCT_WIDTH-9){1'b0}}, 9'd256};
  wire [ASPECT_PRODUCT_WIDTH-1:0] aspect_product = width_px_aspect * aspect_scale;
  wire [ASPECT_PRODUCT_WIDTH-1:0] height_px_aspect =
      {{(ASPECT_PRODUCT_WIDTH-PIXEL_WIDTH){1'b0}}, height_px};
  wire [ASPECT_PRODUCT_WIDTH-1:0] aspect_raw = (height_px != 0) ?
                            (aspect_product / height_px_aspect) : 0;
  wire [ASPECT_COMPARE_WIDTH-1:0] width_scaled_aspect =
      {{(ASPECT_COMPARE_WIDTH-PIXEL_WIDTH){1'b0}}, width_px} << 8;
  wire [ASPECT_COMPARE_WIDTH-1:0] height_px_ext_aspect =
      {{(ASPECT_COMPARE_WIDTH-PIXEL_WIDTH){1'b0}}, height_px};
  wire [ASPECT_COMPARE_WIDTH-1:0] aspect_min_ext =
      {{(ASPECT_COMPARE_WIDTH-16){1'b0}}, aspect_min_q8};
  wire [16:0] aspect_max_exclusive = {1'b0, aspect_max_q8} + 17'd1;
  wire [ASPECT_COMPARE_WIDTH-1:0] height_aspect_min_product =
      height_px_ext_aspect * aspect_min_ext;
  wire [ASPECT_COMPARE_WIDTH-1:0] height_aspect_max_product =
      height_px_ext_aspect * aspect_max_exclusive;
  wire aspect_min_met = width_scaled_aspect >= height_aspect_min_product;
  wire aspect_max_met = (aspect_max_q8 == 16'hffff) ||
                        (width_scaled_aspect < height_aspect_max_product);
  wire [8:0] occupancy_calc = (occupancy_raw > 256) ?
                               9'd256 : occupancy_raw[8:0];
  wire [15:0] aspect_calc = (aspect_raw > 65535) ?
                             16'hffff : aspect_raw[15:0];
  wire [31:0] width_low = (nominal_width_q16_16 >= tolerance_width_q16_16) ?
                           (nominal_width_q16_16 - tolerance_width_q16_16) : 0;
  wire [31:0] width_high = nominal_width_q16_16 + tolerance_width_q16_16;
  wire [31:0] height_low = (nominal_height_q16_16 >= tolerance_height_q16_16) ?
                            (nominal_height_q16_16 - tolerance_height_q16_16) : 0;
  wire [31:0] height_high = nominal_height_q16_16 + tolerance_height_q16_16;
  wire dimension_valid_now = bbox_valid &&
                             (width_product >= width_low) &&
                             (width_product <= width_high) &&
                             (height_product >= height_low) &&
                             (height_product <= height_high) &&
                             !(|width_product[SCALE_PRODUCT_WIDTH-1:32]) &&
                             !(|height_product[SCALE_PRODUCT_WIDTH-1:32]);
  wire shape_valid_now = dimension_valid_now &&
                         occupancy_min_met && aspect_min_met && aspect_max_met;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      O_valid            <= 1'b0;
      O_invalid          <= 1'b0;
      O_dimension_valid  <= 1'b0;
      O_shape_valid      <= 1'b0;
      O_width_mm_q16_16  <= 32'd0;
      O_height_mm_q16_16 <= 32'd0;
      O_occupancy_q8     <= 9'd0;
      O_aspect_q8        <= 16'd0;
    end else begin
      O_valid           <= 1'b0;
      O_invalid         <= 1'b0;
      O_dimension_valid <= 1'b0;
      O_shape_valid     <= 1'b0;
      if (I_result_valid) begin
        if (!I_calibration_valid || !bbox_valid ||
            (|width_product[SCALE_PRODUCT_WIDTH-1:32]) ||
            (|height_product[SCALE_PRODUCT_WIDTH-1:32])) begin
          O_invalid <= 1'b1;
        end else begin
          O_valid           <= 1'b1;
          O_dimension_valid <= dimension_valid_now;
          O_shape_valid     <= shape_valid_now;
          O_width_mm_q16_16 <= width_product[31:0];
          O_height_mm_q16_16 <= height_product[31:0];
          O_occupancy_q8     <= occupancy_calc;
          O_aspect_q8        <= aspect_calc;
        end
      end
    end
  end
endmodule
