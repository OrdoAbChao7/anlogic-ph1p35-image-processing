`timescale 1ns / 1ps

// Project-owned integration guard around the vendor VTC implementation.
//
// The vendor source remains in fallback/td_package as an untouched baseline.
// This source keeps the same uivtc module/ports and adds two explicit
// contracts needed by the industrial top:
//   1. DE/HS/VS are inactive while the internal reset synchronizer is running.
//   2. USER/LAST/DE pipeline registers have a known reset value.
//
// The TD build copies this module to user_source/hdl_source/vtc/uivtc.v in its
// isolated work tree. The production geometry is still configured at the top
// level (1280x720 active, 1650x750 total).
module uivtc #(
  parameter H_ActiveSize  = 1920,
  parameter H_FrameSize   = 1920 + 88 + 44 + 148,
  parameter H_SyncStart   = 1920 + 88,
  parameter H_SyncEnd     = 1920 + 88 + 44,
  parameter V_ActiveSize  = 1080,
  parameter V_FrameSize   = 1080 + 4 + 5 + 36,
  parameter V_SyncStart   = 1080 + 4,
  parameter V_SyncEnd     = 1080 + 4 + 5
)(
  input  wire I_vtc_rstn,
  input  wire I_vtc_clk,
  output wire O_vtc_vs,
  output wire O_vtc_hs,
  output wire O_vtc_de_valid,
  output wire O_vtc_user,
  output wire O_vtc_last
);

  reg [11:0] hcnt;
  reg [11:0] vcnt;
  reg [2:0]  rst_cnt;
  wire       rst_sync = rst_cnt[2];

  always @(posedge I_vtc_clk or negedge I_vtc_rstn) begin
    if (!I_vtc_rstn)
      rst_cnt <= 3'd0;
    else if (!rst_cnt[2])
      rst_cnt <= rst_cnt + 1'b1;
  end

  always @(posedge I_vtc_clk) begin
    if (!rst_sync)
      hcnt <= 12'd0;
    else if (hcnt < (H_FrameSize - 1'b1))
      hcnt <= hcnt + 1'b1;
    else
      hcnt <= 12'd0;
  end

  always @(posedge I_vtc_clk) begin
    if (!rst_sync)
      vcnt <= 12'd0;
    else if (hcnt == (H_ActiveSize - 1'b1))
      vcnt <= (vcnt == (V_FrameSize - 1'b1)) ? 12'd0 : vcnt + 1'b1;
  end

  wire hs_valid = rst_sync && (hcnt < H_ActiveSize);
  wire vs_valid = rst_sync && (vcnt < V_ActiveSize);
  wire vtc_hs   = rst_sync && (hcnt >= H_SyncStart && hcnt < H_SyncEnd);
  wire vtc_vs   = rst_sync && (vcnt > V_SyncStart && vcnt <= V_SyncEnd);
  wire vtc_de   = hs_valid && vs_valid;

  reg vtc_vs_r1;
  reg vtc_hs_r1;
  reg vtc_user_r1;
  reg vtc_user_r2;
  reg vtc_valid_r1;
  reg vtc_valid_r2;
  reg vtc_last_r2;
  reg vs_start;

  always @(posedge I_vtc_clk) begin
    if (!rst_sync)
      vs_start <= 1'b0;
    else if (vtc_user_r1)
      vs_start <= 1'b0;
    else if (vtc_vs && !vtc_vs_r1)
      vs_start <= 1'b1;
  end

  always @(posedge I_vtc_clk) begin
    if (!rst_sync) begin
      vtc_vs_r1    <= 1'b0;
      vtc_hs_r1    <= 1'b0;
      vtc_user_r1  <= 1'b0;
      vtc_last_r2  <= 1'b0;
      vtc_valid_r1 <= 1'b0;
      vtc_valid_r2 <= 1'b0;
      vtc_user_r2  <= 1'b0;
    end else begin
      vtc_vs_r1    <= vtc_vs;
      vtc_hs_r1    <= vtc_hs;
      vtc_user_r1  <= ~vtc_user_r1 & vs_start & vtc_de;
      vtc_last_r2  <= ~vtc_de & vtc_valid_r1;
      vtc_valid_r1 <= vtc_de;
      vtc_valid_r2 <= vtc_valid_r1;
      vtc_user_r2  <= vtc_user_r1;
    end
  end

  assign O_vtc_vs       = vtc_vs_r1;
  assign O_vtc_hs       = vtc_hs_r1;
  assign O_vtc_de_valid = vtc_valid_r2;
  assign O_vtc_user     = vtc_user_r2;
  assign O_vtc_last     = vtc_last_r2;

endmodule
