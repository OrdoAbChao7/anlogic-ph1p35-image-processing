`timescale 1ns/1ps

// Bounded newest-first trajectory storage. This is a point history, not a
// frame buffer: only I_push events write one coordinate pair per frame.
module trajectory_history #(
  parameter integer HISTORY_DEPTH = 8,
  parameter integer COORD_WIDTH   = 11
)(
  input  wire                              I_clk,
  input  wire                              I_rst_n,
  input  wire                              I_push,
  input  wire                              I_new_track,
  input  wire [COORD_WIDTH-1:0]            I_cx,
  input  wire [COORD_WIDTH-1:0]            I_cy,
  output wire [HISTORY_DEPTH*COORD_WIDTH-1:0] O_x_flat,
  output wire [HISTORY_DEPTH*COORD_WIDTH-1:0] O_y_flat,
  output reg  [HISTORY_DEPTH-1:0]          O_valid_mask,
  output reg  [$clog2(HISTORY_DEPTH+1)-1:0] O_count
);

  reg [COORD_WIDTH-1:0] x_hist [0:HISTORY_DEPTH-1];
  reg [COORD_WIDTH-1:0] y_hist [0:HISTORY_DEPTH-1];
  integer i;

  genvar g;
  generate
    for (g = 0; g < HISTORY_DEPTH; g = g + 1) begin : FLAT_POINTS
      assign O_x_flat[g*COORD_WIDTH +: COORD_WIDTH] = x_hist[g];
      assign O_y_flat[g*COORD_WIDTH +: COORD_WIDTH] = y_hist[g];
    end
  endgenerate

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      O_valid_mask <= {HISTORY_DEPTH{1'b0}};
      O_count      <= {($clog2(HISTORY_DEPTH+1)){1'b0}};
      for (i = 0; i < HISTORY_DEPTH; i = i + 1) begin
        x_hist[i] <= {COORD_WIDTH{1'b0}};
        y_hist[i] <= {COORD_WIDTH{1'b0}};
      end
    end else if (I_push) begin
      if (I_new_track) begin
        x_hist[0] <= I_cx;
        y_hist[0] <= I_cy;
        O_valid_mask <= {{(HISTORY_DEPTH-1){1'b0}},1'b1};
        O_count <= {{($clog2(HISTORY_DEPTH+1)-1){1'b0}},1'b1};
        for (i = 1; i < HISTORY_DEPTH; i = i + 1) begin
          x_hist[i] <= {COORD_WIDTH{1'b0}};
          y_hist[i] <= {COORD_WIDTH{1'b0}};
        end
      end else begin
        for (i = HISTORY_DEPTH-1; i > 0; i = i - 1) begin
          x_hist[i] <= x_hist[i-1];
          y_hist[i] <= y_hist[i-1];
        end
        x_hist[0] <= I_cx;
        y_hist[0] <= I_cy;
        O_valid_mask <= (O_valid_mask << 1) | {{(HISTORY_DEPTH-1){1'b0}},1'b1};
        if (O_count < HISTORY_DEPTH)
          O_count <= O_count + 1'b1;
      end
    end
  end
endmodule
