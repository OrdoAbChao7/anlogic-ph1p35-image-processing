`timescale 1ns/1ps

// HDMI-domain bounded trajectory point overlay. The history is supplied as
// frame-stable flattened coordinates; this module only performs eight small
// point-distance checks per pixel and preserves a one-cycle video delay.
module tracking_overlay #(
  parameter integer IMG_WIDTH = 1280,
  parameter integer IMG_HEIGHT = 720,
  parameter integer HISTORY_DEPTH = 8,
  parameter integer COORD_WIDTH = 11,
  parameter integer POINT_RADIUS = 2,
  parameter [23:0] TRACK_COLOR = 24'h22d3ee
)(
  input  wire                                  I_clk,
  input  wire                                  I_rst_n,
  input  wire                                  I_de,
  input  wire                                  I_hsync,
  input  wire                                  I_vsync,
  input  wire [23:0]                           I_rgb,
  input  wire [COORD_WIDTH-1:0]                I_x,
  input  wire [COORD_WIDTH-1:0]                I_y,
  input  wire                                  I_track_valid,
  input  wire [HISTORY_DEPTH-1:0]              I_valid_mask,
  input  wire [HISTORY_DEPTH*COORD_WIDTH-1:0]  I_x_flat,
  input  wire [HISTORY_DEPTH*COORD_WIDTH-1:0]  I_y_flat,
  output reg                                   O_de,
  output reg                                   O_hsync,
  output reg                                   O_vsync,
  output reg  [23:0]                           O_rgb
);

  integer i;
  integer point_x_i;
  integer point_y_i;
  integer delta_x_i;
  integer delta_y_i;
  reg     point_hit;

  always @* begin
    point_hit = 1'b0;
    point_x_i = 0;
    point_y_i = 0;
    delta_x_i = 0;
    delta_y_i = 0;
    if (I_de && I_track_valid) begin
      for (i = 0; i < HISTORY_DEPTH; i = i + 1) begin
        point_x_i = I_x_flat[i*COORD_WIDTH +: COORD_WIDTH];
        point_y_i = I_y_flat[i*COORD_WIDTH +: COORD_WIDTH];
        delta_x_i = (I_x >= point_x_i) ? (I_x - point_x_i) : (point_x_i - I_x);
        delta_y_i = (I_y >= point_y_i) ? (I_y - point_y_i) : (point_y_i - I_y);
        if (I_valid_mask[i] && (delta_x_i <= POINT_RADIUS) &&
            (delta_y_i <= POINT_RADIUS))
          point_hit = 1'b1;
      end
    end
  end

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
      if (!I_de)
        O_rgb <= 24'd0;
      else if (point_hit)
        O_rgb <= TRACK_COLOR;
      else
        O_rgb <= I_rgb;
    end
  end
endmodule
