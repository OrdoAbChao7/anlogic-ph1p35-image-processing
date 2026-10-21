`timescale 1ns/1ps
// ============================================================================
// E4 — colour detector cycle-differential.
//
// Baseline and candidate are driven with an identical AXI-Stream RGB888
// 4-pixel-per-beat raster and every output is compared every cycle.
//
// Stimulus:
//   frame 0 - one moving red rectangle
//   frame 1 - two rectangles, different sizes/positions
//   frame 2 - pseudo-random per-pixel red/grey, so the 4-bit morphology mask
//             takes arbitrary values and exercises every popcount /
//             lowest-set / highest-set combination
// ============================================================================
module tb_e4_detect_diff;
  localparam integer IMG_W = 1280;
  localparam integer IMG_H = 720;
  localparam integer GROUPS = IMG_W / 4;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg        tvalid = 1'b0;
  reg        tlast  = 1'b0;
  reg        tuser  = 1'b0;
  reg [95:0] tdata  = 96'd0;

  wire [10:0] b_xmin, b_xmax, b_ymin, b_ymax, b_cx, b_cy;
  wire [19:0] b_area;
  wire        b_det, b_inv, b_sync;

  wire [10:0] c_xmin, c_xmax, c_ymin, c_ymax, c_cx, c_cy;
  wire [19:0] c_area;
  wire        c_det, c_inv, c_sync;

  always #5 clk = ~clk;

  color_detect_96_v2_baseline #(
    .IMG_WIDTH(IMG_W), .IMG_HEIGHT(IMG_H)
  ) u_base (
    .I_clk(clk), .I_rst_n(rst_n), .I_tvalid(tvalid), .I_tlast(tlast),
    .I_tuser(tuser), .I_tdata(tdata),
    .O_xmin(b_xmin), .O_xmax(b_xmax), .O_ymin(b_ymin), .O_ymax(b_ymax),
    .O_cx(b_cx), .O_cy(b_cy), .O_area(b_area),
    .O_detected(b_det), .O_invalid(b_inv), .O_frame_sync(b_sync));

  color_detect_96_v2_candidate #(
    .IMG_WIDTH(IMG_W), .IMG_HEIGHT(IMG_H)
  ) u_cand (
    .I_clk(clk), .I_rst_n(rst_n), .I_tvalid(tvalid), .I_tlast(tlast),
    .I_tuser(tuser), .I_tdata(tdata),
    .O_xmin(c_xmin), .O_xmax(c_xmax), .O_ymin(c_ymin), .O_ymax(c_ymax),
    .O_cx(c_cx), .O_cy(c_cy), .O_area(c_area),
    .O_detected(c_det), .O_invalid(c_inv), .O_frame_sync(c_sync));

  localparam [23:0] RED  = {8'd120, 8'd30, 8'd30};
  localparam [23:0] RED2 = {8'd140, 8'd35, 8'd28};
  localparam [23:0] GREY = {8'd128, 8'd128, 8'd128};
  localparam [23:0] DARK = {8'd40, 8'd40, 8'd40};

  integer checks = 0, beats = 0, syncs_b = 0, det_b = 0;
  integer area_max = 0;
  integer f, x, y, g, k;
  reg [15:0] lfsr;
  reg [23:0] p0, p1, p2, p3;
  reg        v0, v1, v2, v3;

  function [23:0] pick_red;
    input integer fx, px, py;
    begin
      case (fx)
        0: pick_red = ((px >= 100) && (px < 500) && (py >= 50)  && (py < 300)) ? RED  : GREY;
        1: pick_red = (((px >= 600) && (px < 900) && (py >= 200) && (py < 600)) ||
                       ((px >= 1000) && (px < 1100) && (py >= 100) && (py < 150))) ? RED2 : GREY;
        default: pick_red = GREY;
      endcase
    end
  endfunction

  always @(negedge clk) begin
    if (rst_n) begin
      if ({c_xmin,c_xmax,c_ymin,c_ymax,c_cx,c_cy,c_area,c_det,c_inv,c_sync} !==
          {b_xmin,b_xmax,b_ymin,b_ymax,b_cx,b_cy,b_area,b_det,b_inv,b_sync})
        $fatal(1, "detector mismatch t=%0t beat=%0d base=%h cand=%h",
               $time, beats,
               {b_xmin,b_xmax,b_ymin,b_ymax,b_cx,b_cy,b_area,b_det,b_inv,b_sync},
               {c_xmin,c_xmax,c_ymin,c_ymax,c_cx,c_cy,c_area,c_det,c_inv,c_sync});
      checks = checks + 1;
      if ((beats > 400) &&
          (^{b_xmin,b_xmax,b_ymin,b_ymax,b_cx,b_cy,b_area,b_det,b_inv,b_sync} === 1'bx))
        $fatal(1, "baseline outputs contain X at beat=%0d (morph model not behaving)", beats);
      if (b_area > area_max) area_max = b_area;
      if (b_sync) begin
        syncs_b = syncs_b + 1;
        if (b_det) det_b = det_b + 1;
      end
    end
  end

  initial begin
    lfsr = 16'hACE1;
    repeat (3) @(posedge clk);
    @(negedge clk); rst_n = 1'b1;

    for (f = 0; f < 3; f = f + 1) begin
      for (y = 0; y < IMG_H; y = y + 1) begin
        for (g = 0; g < GROUPS; g = g + 1) begin
          x = g * 4;
          if (f == 2) begin
            lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            p0 = lfsr[0] ? RED : (lfsr[1] ? RED2 : GREY);
            lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            p1 = lfsr[0] ? RED : (lfsr[1] ? DARK : GREY);
            lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            p2 = lfsr[0] ? RED2 : (lfsr[1] ? RED : GREY);
            lfsr = {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
            p3 = lfsr[0] ? RED : GREY;
          end else begin
            p0 = pick_red(f, x+0, y);
            p1 = pick_red(f, x+1, y);
            p2 = pick_red(f, x+2, y);
            p3 = pick_red(f, x+3, y);
          end
          @(negedge clk);
          tdata  = {p0, p1, p2, p3};
          tvalid = 1'b1;
          tlast  = (g == GROUPS-1);
          tuser  = (y == 0) && (g == 0);
          beats  = beats + 1;
        end
      end
      for (k = 0; k < 2048; k = k + 1) begin
        @(negedge clk);
        tvalid = 1'b0; tlast = 1'b0; tuser = 1'b0; tdata = 96'd0;
      end
    end

    @(negedge clk);
    tvalid = 1'b0; tlast = 1'b0; tuser = 1'b0; tdata = 96'd0;
    repeat (4096) @(posedge clk);

    if (syncs_b < 3) $fatal(1, "only %0d frame syncs observed", syncs_b);
    if (det_b == 0)  $fatal(1, "detector never reported a target");
    $display("TB_E4_DETECT_DIFF_PASS checks=%0d beats=%0d frame_syncs=%0d detections=%0d max_area=%0d",
             checks, beats, syncs_b, det_b, area_max);
    $finish;
  end

  initial begin
    #20000000;
    $fatal(1, "timeout");
  end
endmodule
