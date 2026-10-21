`timescale 1ns/1ps
// ============================================================================
// E2 — OSD overlay pipeline cycle-differential.
//
// Baseline has 1 cycle of output latency; the pipelined candidate has 3.
// Every cycle the candidate's {vsync,hsync,de,rgb} is compared against the
// baseline's value from two cycles earlier, so the test asserts BOTH
//   (a) the pixel content for every (x,y) is unchanged, and
//   (b) the extra latency is a constant 2 cycles.
// ============================================================================
module tb_osd_pipe_diff;
  reg clk = 1'b0;
  reg rst_n = 1'b0;

  // ---- raster -------------------------------------------------------------
  localparam H_ACTIVE = 1280, H_TOTAL = 1650;
  localparam V_ACTIVE = 720,  V_TOTAL = 750;
  integer hc = 0, vc = 0;
  reg vsync, hsync, de;
  reg [23:0] rgb;

  always #5 clk = ~clk;

  always @(posedge clk) begin
    if (!rst_n) begin
      hc <= 0; vc <= 0;
    end else if (hc == H_TOTAL-1) begin
      hc <= 0;
      vc <= (vc == V_TOTAL-1) ? 0 : vc + 1;
    end else begin
      hc <= hc + 1;
    end
  end

  always @* begin
    hsync = (hc >= H_ACTIVE);
    vsync = (vc >= V_ACTIVE);
    de    = (hc < H_ACTIVE) && (vc < V_ACTIVE);
    rgb   = {hc[7:0], vc[7:0], (hc[7:0] ^ vc[7:0])};
  end

  // ---- frame-varying result bus -------------------------------------------
  reg [3:0] frame_no = 4'd0;
  reg       vsync_d = 1'b0;
  always @(posedge clk) begin
    if (!rst_n) begin frame_no <= 4'd0; vsync_d <= 1'b0; end
    else begin
      vsync_d <= vsync;
      if (vsync && !vsync_d) frame_no <= frame_no + 4'd1;
    end
  end

  wire [1:0]  i_mode    = frame_no[1:0];
  wire        i_detected= frame_no[0];
  wire        i_pass    = (frame_no % 3) == 0;
  wire        i_ng      = (frame_no % 3) == 1;
  wire        i_invalid = (frame_no % 5) == 3;
  wire [10:0] i_width   = 11'd120 + {7'd0, frame_no} * 11'd7;
  wire [10:0] i_height  = 11'd80  + {7'd0, frame_no} * 11'd3;
  wire        i_proc_valid = frame_no[2];
  wire [31:0] i_proc_cycles = 32'h1000 + {28'd0, frame_no} * 32'd13;
  wire        i_motion_valid = frame_no[1];
  wire        i_motion = frame_no[3];
  wire [23:0] i_motion_count = {20'd0, frame_no} * 24'd5;
  wire [15:0] i_pass_count = 16'd100 + {12'd0, frame_no};
  wire [15:0] i_ng_count   = 16'd7   + {12'd0, frame_no};
  wire        i_sort_pulse = frame_no[2];
  wire        i_safe_enable = ~frame_no[3];
  wire        i_dimension_valid = frame_no[0];
  wire        i_shape_valid = ~frame_no[0];
  wire        i_scale_provisional = frame_no[1];
  wire [31:0] i_width_mm  = {16'd60, 16'd0};
  wire [31:0] i_height_mm = {16'd20, 16'd0};

  wire b_vs, b_hs, b_de, c_vs, c_hs, c_de;
  wire [23:0] b_rgb, c_rgb;

  industrial_osd_overlay_baseline #(.IMG_WIDTH(H_ACTIVE), .IMG_HEIGHT(V_ACTIVE),
                                    .LOGO_W(160), .LOGO_H(160)) u_base (
    .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vsync), .I_hsync(hsync), .I_de(de),
    .I_rgb(rgb), .I_mode(i_mode), .I_detected(i_detected), .I_pass(i_pass),
    .I_ng(i_ng), .I_invalid(i_invalid), .I_width(i_width), .I_height(i_height),
    .I_proc_valid(i_proc_valid), .I_proc_cycles(i_proc_cycles),
    .I_motion_valid(i_motion_valid), .I_motion(i_motion),
    .I_motion_count(i_motion_count), .I_pass_count(i_pass_count),
    .I_ng_count(i_ng_count), .I_sort_pulse(i_sort_pulse),
    .I_safe_enable(i_safe_enable), .I_dimension_valid(i_dimension_valid),
    .I_shape_valid(i_shape_valid), .I_scale_provisional(i_scale_provisional),
    .I_width_mm_q16_16(i_width_mm), .I_height_mm_q16_16(i_height_mm),
    .O_vsync(b_vs), .O_hsync(b_hs), .O_de(b_de), .O_rgb(b_rgb));

  industrial_osd_overlay_candidate #(.IMG_WIDTH(H_ACTIVE), .IMG_HEIGHT(V_ACTIVE),
                                     .LOGO_W(160), .LOGO_H(160)) u_cand (
    .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vsync), .I_hsync(hsync), .I_de(de),
    .I_rgb(rgb), .I_mode(i_mode), .I_detected(i_detected), .I_pass(i_pass),
    .I_ng(i_ng), .I_invalid(i_invalid), .I_width(i_width), .I_height(i_height),
    .I_proc_valid(i_proc_valid), .I_proc_cycles(i_proc_cycles),
    .I_motion_valid(i_motion_valid), .I_motion(i_motion),
    .I_motion_count(i_motion_count), .I_pass_count(i_pass_count),
    .I_ng_count(i_ng_count), .I_sort_pulse(i_sort_pulse),
    .I_safe_enable(i_safe_enable), .I_dimension_valid(i_dimension_valid),
    .I_shape_valid(i_shape_valid), .I_scale_provisional(i_scale_provisional),
    .I_width_mm_q16_16(i_width_mm), .I_height_mm_q16_16(i_height_mm),
    .O_vsync(c_vs), .O_hsync(c_hs), .O_de(c_de), .O_rgb(c_rgb));

  // baseline output delayed by two cycles
  reg [26:0] d0, d1, d2;
  always @(posedge clk) begin
    if (!rst_n) begin d0 <= 27'd0; d1 <= 27'd0; d2 <= 27'd0; end
    else begin
      d0 <= {b_vs, b_hs, b_de, b_rgb};
      d1 <= d0;
      d2 <= d1;
    end
  end

  integer checks = 0, pixels = 0, logo_pixels = 0, text_pixels = 0;
  integer vsync_rises = 0;
  reg     vsync_q = 1'b0;

  // At negedge N: d0 = baseline(N-1), d1 = baseline(N-2).
  // Candidate latency 3 vs baseline latency 1 => c(N) must equal d1.
  always @(negedge clk) begin
    if (rst_n) begin
      if ({c_vs, c_hs, c_de, c_rgb} !== d1)
        $fatal(1, "OSD mismatch t=%0t cand=%h baseline_d1=%h (hc=%0d vc=%0d)",
               $time, {c_vs,c_hs,c_de,c_rgb}, d1, hc, vc);
      checks = checks + 1;
      if (c_de) begin
        pixels = pixels + 1;
        if ((hc < 160) && (vc < 160)) logo_pixels = logo_pixels + 1;
        if ((hc >= 180) && (hc < 436)) text_pixels = text_pixels + 1;
      end
      if (vsync && !vsync_q) vsync_rises = vsync_rises + 1;
    end
    vsync_q = vsync;
  end

  initial begin
    repeat (5) @(posedge clk);
    @(negedge clk); rst_n = 1'b1;

    // Two complete frames: 2 * H_TOTAL * V_TOTAL clocks, plus margin.
    repeat (2*1650*750 + 200) @(posedge clk);
    if (pixels == 0) $fatal(1, "no active pixels observed");
    if (logo_pixels == 0) $fatal(1, "logo region never exercised");
    if (text_pixels == 0) $fatal(1, "text region never exercised");
    if (vsync_rises < 2) $fatal(1, "fewer than two vsync edges: %0d", vsync_rises);
    $display("TB_OSD_PIPE_DIFF_PASS checks=%0d de_pixels=%0d logo=%0d text_region=%0d vsync_rises=%0d",
             checks, pixels, logo_pixels, text_pixels, vsync_rises);
    $finish;
  end

  initial begin
    #40000000;
    $fatal(1, "timeout");
  end
endmodule
