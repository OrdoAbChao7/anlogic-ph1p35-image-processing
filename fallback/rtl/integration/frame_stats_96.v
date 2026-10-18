`timescale 1ns/1ps

// Atomic RGB statistics for the four-pixel 96-bit ISP stream. The accumulator
// resets at I_tuser and publishes only on the final line's I_tlast beat. The
// first RGB888 pixel of each 24-bit lane is used consistently with the fixed
// detector packing, so the contract is explicit even before hardware capture.
module frame_stats_96 #(
  parameter integer INPUT_WIDTH  = 1280,
  parameter integer INPUT_HEIGHT = 720,
  parameter integer FRAME_ID_WIDTH = 16
)(
  input  wire                         I_clk,
  input  wire                         I_rst_n,
  input  wire                         I_tuser,
  input  wire                         I_tlast,
  input  wire                         I_tvalid,
  input  wire [FRAME_ID_WIDTH-1:0]    I_frame_id,
  input  wire [95:0]                  I_tdata,
  output reg                          O_stats_valid,
  output reg  [FRAME_ID_WIDTH-1:0]    O_frame_id,
  output reg  [31:0]                  O_sum_r,
  output reg  [31:0]                  O_sum_g,
  output reg  [31:0]                  O_sum_b,
  output reg  [31:0]                  O_pixel_count,
  output reg  [7:0]                   O_mean_luma,
  output reg                          O_invalid
);

  localparam integer GROUPS_PER_LINE = INPUT_WIDTH / 4;
  localparam integer ROW_WIDTH = (INPUT_HEIGHT <= 1) ? 1 : $clog2(INPUT_HEIGHT);

  reg [ROW_WIDTH-1:0] row_index;
  reg [31:0] sum_r_acc;
  reg [31:0] sum_g_acc;
  reg [31:0] sum_b_acc;
  reg [31:0] pixel_count_acc;
  reg frame_seen;

  wire [7:0] r0 = I_tdata[95:88];
  wire [7:0] g0 = I_tdata[87:80];
  wire [7:0] b0 = I_tdata[79:72];
  wire [7:0] r1 = I_tdata[71:64];
  wire [7:0] g1 = I_tdata[63:56];
  wire [7:0] b1 = I_tdata[55:48];
  wire [7:0] r2 = I_tdata[47:40];
  wire [7:0] g2 = I_tdata[39:32];
  wire [7:0] b2 = I_tdata[31:24];
  wire [7:0] r3 = I_tdata[23:16];
  wire [7:0] g3 = I_tdata[15:8];
  wire [7:0] b3 = I_tdata[7:0];

  wire [31:0] beat_r = r0 + r1 + r2 + r3;
  wire [31:0] beat_g = g0 + g1 + g2 + g3;
  wire [31:0] beat_b = b0 + b1 + b2 + b3;
  wire [31:0] base_r = I_tuser ? 32'd0 : sum_r_acc;
  wire [31:0] base_g = I_tuser ? 32'd0 : sum_g_acc;
  wire [31:0] base_b = I_tuser ? 32'd0 : sum_b_acc;
  wire [31:0] base_count = I_tuser ? 32'd0 : pixel_count_acc;
  wire [ROW_WIDTH-1:0] base_row = I_tuser ? {ROW_WIDTH{1'b0}} : row_index;
  wire [31:0] final_r = base_r + beat_r;
  wire [31:0] final_g = base_g + beat_g;
  wire [31:0] final_b = base_b + beat_b;
  wire [31:0] final_count = base_count + 32'd4;
  wire frame_end = I_tvalid && I_tlast && (base_row == INPUT_HEIGHT-1);
  wire [63:0] luma_numerator = final_r + final_g + final_b;
  wire [63:0] luma_denominator = final_count * 64'd3;
  wire [63:0] mean_luma_calc = (luma_denominator != 0) ?
                                (luma_numerator / luma_denominator) : 0;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      row_index       <= {ROW_WIDTH{1'b0}};
      sum_r_acc       <= 32'd0;
      sum_g_acc       <= 32'd0;
      sum_b_acc       <= 32'd0;
      pixel_count_acc <= 32'd0;
      frame_seen      <= 1'b0;
      O_stats_valid   <= 1'b0;
      O_frame_id      <= {FRAME_ID_WIDTH{1'b0}};
      O_sum_r         <= 32'd0;
      O_sum_g         <= 32'd0;
      O_sum_b         <= 32'd0;
      O_pixel_count   <= 32'd0;
      O_mean_luma     <= 8'd0;
      O_invalid       <= 1'b0;
    end else begin
      O_stats_valid <= 1'b0;
      O_invalid     <= 1'b0;
      if (I_tvalid) begin
        if (!I_tuser && !frame_seen)
          O_invalid <= 1'b1;
        if (frame_end) begin
          O_stats_valid <= 1'b1;
          O_frame_id    <= I_frame_id;
          O_sum_r       <= final_r;
          O_sum_g       <= final_g;
          O_sum_b       <= final_b;
          O_pixel_count <= final_count;
          O_mean_luma   <= (mean_luma_calc > 255) ? 8'd255 : mean_luma_calc[7:0];
          row_index       <= {ROW_WIDTH{1'b0}};
          sum_r_acc       <= 32'd0;
          sum_g_acc       <= 32'd0;
          sum_b_acc       <= 32'd0;
          pixel_count_acc <= 32'd0;
          frame_seen      <= 1'b0;
        end else begin
          row_index       <= I_tlast ? base_row + 1'b1 : base_row;
          sum_r_acc       <= final_r;
          sum_g_acc       <= final_g;
          sum_b_acc       <= final_b;
          pixel_count_acc <= final_count;
          frame_seen      <= 1'b1;
        end
      end
    end
  end
endmodule
