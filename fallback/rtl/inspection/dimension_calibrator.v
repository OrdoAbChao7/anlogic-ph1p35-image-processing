`timescale 1ns/1ps

// Fixed-point dimension and single-target shape checker.
// Inputs are inclusive pixel BBox endpoints and a calibrated Q16.16 mm/pixel
// scale. Results are published only on I_result_valid and are explicitly
// invalid when calibration or geometry is unavailable.
module dimension_calibrator #(
  parameter integer COORD_WIDTH = 11
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

  wire [COORD_WIDTH:0] width_px = (I_xmax >= I_xmin) ?
                                   (I_xmax - I_xmin + 1'b1) : 0;
  wire [COORD_WIDTH:0] height_px = (I_ymax >= I_ymin) ?
                                    (I_ymax - I_ymin + 1'b1) : 0;
  wire bbox_valid = (I_xmax >= I_xmin) && (I_ymax >= I_ymin) &&
                    (width_px != 0) && (height_px != 0);
  wire [63:0] width_px_ext = width_px;
  wire [63:0] height_px_ext = height_px;
  wire [63:0] area_ext = I_area;
  wire [63:0] bbox_area = width_px_ext * height_px_ext;
  wire [63:0] width_product = width_px_ext * I_scale_x_q16_16;
  wire [63:0] height_product = height_px_ext * I_scale_y_q16_16;
  wire [63:0] occupancy_product = area_ext * 64'd256;
  wire [63:0] aspect_product = width_px_ext * 64'd256;
  wire [63:0] occupancy_raw = (bbox_area != 0) ?
                               (occupancy_product / bbox_area) : 0;
  wire [63:0] aspect_raw = (height_px != 0) ?
                            (aspect_product / height_px_ext) : 0;
  wire [8:0] occupancy_calc = (occupancy_raw > 256) ?
                               9'd256 : occupancy_raw[8:0];
  wire [15:0] aspect_calc = (aspect_raw > 65535) ?
                             16'hffff : aspect_raw[15:0];
  wire [31:0] width_low = (I_nominal_width_q16_16 >= I_tolerance_width_q16_16) ?
                           (I_nominal_width_q16_16 - I_tolerance_width_q16_16) : 0;
  wire [31:0] width_high = I_nominal_width_q16_16 + I_tolerance_width_q16_16;
  wire [31:0] height_low = (I_nominal_height_q16_16 >= I_tolerance_height_q16_16) ?
                            (I_nominal_height_q16_16 - I_tolerance_height_q16_16) : 0;
  wire [31:0] height_high = I_nominal_height_q16_16 + I_tolerance_height_q16_16;
  wire dimension_valid_now = bbox_valid &&
                             (width_product >= width_low) &&
                             (width_product <= width_high) &&
                             (height_product >= height_low) &&
                             (height_product <= height_high) &&
                             !(|width_product[63:32]) &&
                             !(|height_product[63:32]);
  wire shape_valid_now = dimension_valid_now &&
                         (occupancy_calc >= I_occupancy_min_q8) &&
                         (aspect_calc >= I_aspect_min_q8) &&
                         (aspect_calc <= I_aspect_max_q8);

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
            (|width_product[63:32]) || (|height_product[63:32])) begin
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
