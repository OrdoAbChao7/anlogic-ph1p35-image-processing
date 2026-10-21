`timescale 1ns/1ps
// E4 Gate A/B harness — self-contained detector top so the pad count stays
// small. The stimulus is generated internally from a 16-bit LFSR so that the
// 4-bit morphology mask takes arbitrary values and every popcount /
// lowest-set / highest-set path is exercised in the netlist.
//
// Both arms share this file byte-for-byte; only the detector RTL differs.
module industrial_detect_gate_top (
  input  wire        I_clk,
  input  wire        I_rst_n,
  output wire [10:0] O_xmin,
  output wire [10:0] O_xmax,
  output wire [10:0] O_ymin,
  output wire [10:0] O_ymax,
  output wire [19:0] O_area
);
  localparam integer IMG_W  = 1280;
  localparam integer IMG_H  = 720;
  localparam integer GROUPS = IMG_W / 4;   // 320
  localparam integer GB     = 9;           // $clog2(GROUPS+1)

  localparam [23:0] RED  = 24'h785E1E;     // passes the Cb/Cr window
  localparam [23:0] GREY = 24'h808080;     // rejected

  reg [GB-1:0] gcnt;
  reg [10:0]   ycnt;
  reg [15:0]   lfsr;
  reg          tvalid, tlast, tuser;
  reg [95:0]   tdata;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      gcnt <= {GB{1'b0}}; ycnt <= 11'd0; lfsr <= 16'hACE1;
      tvalid <= 1'b0; tlast <= 1'b0; tuser <= 1'b0; tdata <= 96'd0;
    end else begin
      lfsr   <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
      tvalid <= 1'b1;
      tlast  <= (gcnt == GROUPS-1);
      tuser  <= (ycnt == 11'd0) && (gcnt == {GB{1'b0}});
      tdata  <= {(lfsr[0] ? RED : GREY), (lfsr[3] ? RED : GREY),
                 (lfsr[6] ? RED : GREY), (lfsr[9] ? RED : GREY)};
      if (gcnt == GROUPS-1) begin
        gcnt <= {GB{1'b0}};
        ycnt <= (ycnt == IMG_H-1) ? 11'd0 : ycnt + 11'd1;
      end else begin
        gcnt <= gcnt + {{(GB-1){1'b0}}, 1'b1};
      end
    end
  end

  color_detect_96_v2 #(
    .IMG_WIDTH(IMG_W), .IMG_HEIGHT(IMG_H)
  ) dut (
    .I_clk(I_clk), .I_rst_n(I_rst_n),
    .I_tvalid(tvalid), .I_tlast(tlast), .I_tuser(tuser), .I_tdata(tdata),
    .O_xmin(O_xmin), .O_xmax(O_xmax), .O_ymin(O_ymin), .O_ymax(O_ymax),
    .O_cx(), .O_cy(), .O_area(O_area),
    .O_detected(), .O_invalid(), .O_frame_sync()
  );
endmodule
