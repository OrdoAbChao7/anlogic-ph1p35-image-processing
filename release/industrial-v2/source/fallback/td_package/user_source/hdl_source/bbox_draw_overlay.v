`timescale 1ns / 1ps
// ============================================================================
// Module: bbox_draw_overlay
// Description: Real-time HDMI streaming bounding box overlay generator.
// Reference:
//   - 05_vision_bbox_template (bounding_box.v) pixel replacement architecture
// ============================================================================

module bbox_draw_overlay #(
  parameter integer IMG_WIDTH          = 1280,
  parameter integer IMG_HEIGHT         = 720,
  parameter integer LINE_THICKNESS     = 2,
  parameter integer USE_INTERNAL_COORD = 0,
  parameter [23:0]  COLOR_PASS         = 24'h10b981, // Green (PASS)
  parameter [23:0]  COLOR_NG           = 24'hef4444  // Red (NG)
)(
  input  wire        I_clk,
  input  wire        I_rst_n,

  // Streaming video input (HDMI pixel clock domain)
  input  wire        I_de,
  input  wire        I_hsync,
  input  wire        I_vsync,
  input  wire [23:0] I_rgb,
  input  wire [10:0] I_x,                  // Current pixel column coordinate
  input  wire [10:0] I_y,                  // Current pixel row coordinate

  // Latched target bounding box inputs
  input  wire        I_detected,
  input  wire [10:0] I_xmin,
  input  wire [10:0] I_xmax,
  input  wire [10:0] I_ymin,
  input  wire [10:0] I_ymax,
  input  wire        I_pass,
  input  wire        I_ng,

  // Pipelined video output (1-cycle delay)
  output reg         O_de,
  output reg         O_hsync,
  output reg         O_vsync,
  output reg  [23:0] O_rgb
);

  // Self-contained pixel coordinate tracker from I_de and I_vsync
  reg [11:0] x_cnt;
  reg [11:0] y_cnt;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      x_cnt <= 12'd0;
      y_cnt <= 12'd0;
    end else begin
      if (I_vsync) begin
        x_cnt <= 12'd0;
        y_cnt <= 12'd0;
      end else if (I_de) begin
        if (x_cnt == IMG_WIDTH - 1) begin
          x_cnt <= 12'd0;
          y_cnt <= (y_cnt == IMG_HEIGHT - 1) ? 12'd0 : (y_cnt + 12'd1);
        end else begin
          x_cnt <= x_cnt + 12'd1;
        end
      end else begin
        x_cnt <= 12'd0;
      end
    end
  end

  wire [10:0] cur_x = (USE_INTERNAL_COORD) ? x_cnt[10:0] : I_x;
  wire [10:0] cur_y = (USE_INTERNAL_COORD) ? y_cnt[10:0] : I_y;

  // Border detection logic
  wire is_x_left   = (cur_x >= I_xmin) && (cur_x < I_xmin + LINE_THICKNESS);
  wire is_x_right  = (cur_x <= I_xmax) && (cur_x > I_xmax - LINE_THICKNESS);
  wire is_y_top    = (cur_y >= I_ymin) && (cur_y < I_ymin + LINE_THICKNESS);
  wire is_y_bottom = (cur_y <= I_ymax) && (cur_y > I_ymax - LINE_THICKNESS);

  wire is_x_span   = (cur_x >= I_xmin) && (cur_x <= I_xmax);
  wire is_y_span   = (cur_y >= I_ymin) && (cur_y <= I_ymax);

  wire is_border   = I_detected && (((is_x_left | is_x_right) & is_y_span) |
                                    ((is_y_top  | is_y_bottom) & is_x_span));

  wire [23:0] target_box_color = I_pass ? COLOR_PASS : COLOR_NG;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      O_de    <= 1'b0;
      O_hsync <= 1'b0;
      O_vsync <= 1'b0;
      O_rgb   <= 24'd0;
    end else begin
      O_de    <= I_de;
      O_hsync <= I_hsync;
      O_vsync <= I_vsync;
      if (I_de) begin
        if (is_border) O_rgb <= target_box_color;
        else O_rgb <= I_rgb;
      end else begin
        O_rgb <= 24'd0;
      end
    end
  end

endmodule
