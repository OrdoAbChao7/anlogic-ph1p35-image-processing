`timescale 1ns/1ps
// ============================================================================
// E1 — cycle-differential for the BBox pre-computation pipeline.
//
// Stimulus reproduces the REAL producer timing of the Industrial V2 top:
//   cycle T   : color_detect_96_v2 commits the final BBox / area
//   cycle T+1 : ind_result_event is high (defect_classifier toggles one clock
//               after O_frame_sync, and ind_v2_toggle_d delays it by one more)
//   edge  T+2 : dimension_calibrator commits its result
//
// Three instances run on identical stimulus:
//   VAR0 baseline RTL (frozen AWB-Lite)
//   VAR1 candidate RTL with USE_BBOX_PIPELINE=0  (must be bit-identical)
//   VAR2 candidate RTL with USE_BBOX_PIPELINE=1  (E1 change)
// ============================================================================

module cal_probe #(
  parameter integer VARIANT = 0,
  parameter integer USE_STATIC = 1,
  parameter [8:0]   STATIC_OCC = 9'd200
)(
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_result_valid,
  input  wire        I_calibration_valid,
  input  wire [10:0] I_xmin, I_xmax, I_ymin, I_ymax,
  input  wire [19:0] I_area,
  input  wire [8:0]  I_occupancy_min_q8,
  input  wire [15:0] I_aspect_min_q8,
  input  wire [15:0] I_aspect_max_q8,
  output wire [92:0] O_result
);
  wire o_valid, o_invalid, o_dimension_valid, o_shape_valid;
  wire [31:0] o_width, o_height;
  wire [8:0]  o_occupancy;
  wire [15:0] o_aspect;
  assign O_result = {o_valid, o_invalid, o_dimension_valid, o_shape_valid,
                     o_width, o_height, o_occupancy, o_aspect};

  generate
    if (VARIANT == 0) begin : g_baseline
      dimension_calibrator_baseline #(
        .COORD_WIDTH(11), .USE_STATIC_CONFIG(USE_STATIC),
        .STATIC_SCALE_X_Q16_16(32'd32768),
        .STATIC_SCALE_Y_Q16_16(32'd16384),
        .STATIC_NOMINAL_WIDTH_Q16_16(32'd3932160),
        .STATIC_NOMINAL_HEIGHT_Q16_16(32'd1310720),
        .STATIC_TOLERANCE_WIDTH_Q16_16(32'd131072),
        .STATIC_TOLERANCE_HEIGHT_Q16_16(32'd131072),
        .STATIC_OCCUPANCY_MIN_Q8(STATIC_OCC),
        .STATIC_ASPECT_MIN_Q8(16'd320), .STATIC_ASPECT_MAX_Q8(16'd448)
      ) dut (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_result_valid(I_result_valid),
        .I_calibration_valid(I_calibration_valid),
        .I_xmin(I_xmin), .I_xmax(I_xmax), .I_ymin(I_ymin), .I_ymax(I_ymax),
        .I_area(I_area), .I_scale_x_q16_16(32'd32768), .I_scale_y_q16_16(32'd16384),
        .I_nominal_width_q16_16(32'd3932160), .I_nominal_height_q16_16(32'd1310720),
        .I_tolerance_width_q16_16(32'd131072), .I_tolerance_height_q16_16(32'd131072),
        .I_occupancy_min_q8(I_occupancy_min_q8),
        .I_aspect_min_q8(I_aspect_min_q8), .I_aspect_max_q8(I_aspect_max_q8),
        .O_valid(o_valid), .O_invalid(o_invalid),
        .O_dimension_valid(o_dimension_valid), .O_shape_valid(o_shape_valid),
        .O_width_mm_q16_16(o_width), .O_height_mm_q16_16(o_height),
        .O_occupancy_q8(o_occupancy), .O_aspect_q8(o_aspect)
      );
    end else if (VARIANT == 1) begin : g_cand_nopipe
      dimension_calibrator_candidate #(
        .COORD_WIDTH(11), .USE_STATIC_CONFIG(USE_STATIC), .USE_BBOX_PIPELINE(0),
        .STATIC_SCALE_X_Q16_16(32'd32768),
        .STATIC_SCALE_Y_Q16_16(32'd16384),
        .STATIC_NOMINAL_WIDTH_Q16_16(32'd3932160),
        .STATIC_NOMINAL_HEIGHT_Q16_16(32'd1310720),
        .STATIC_TOLERANCE_WIDTH_Q16_16(32'd131072),
        .STATIC_TOLERANCE_HEIGHT_Q16_16(32'd131072),
        .STATIC_OCCUPANCY_MIN_Q8(STATIC_OCC),
        .STATIC_ASPECT_MIN_Q8(16'd320), .STATIC_ASPECT_MAX_Q8(16'd448)
      ) dut (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_result_valid(I_result_valid),
        .I_calibration_valid(I_calibration_valid),
        .I_xmin(I_xmin), .I_xmax(I_xmax), .I_ymin(I_ymin), .I_ymax(I_ymax),
        .I_area(I_area), .I_scale_x_q16_16(32'd32768), .I_scale_y_q16_16(32'd16384),
        .I_nominal_width_q16_16(32'd3932160), .I_nominal_height_q16_16(32'd1310720),
        .I_tolerance_width_q16_16(32'd131072), .I_tolerance_height_q16_16(32'd131072),
        .I_occupancy_min_q8(I_occupancy_min_q8),
        .I_aspect_min_q8(I_aspect_min_q8), .I_aspect_max_q8(I_aspect_max_q8),
        .O_valid(o_valid), .O_invalid(o_invalid),
        .O_dimension_valid(o_dimension_valid), .O_shape_valid(o_shape_valid),
        .O_width_mm_q16_16(o_width), .O_height_mm_q16_16(o_height),
        .O_occupancy_q8(o_occupancy), .O_aspect_q8(o_aspect)
      );
    end else begin : g_cand_pipe
      dimension_calibrator_candidate #(
        .COORD_WIDTH(11), .USE_STATIC_CONFIG(USE_STATIC), .USE_BBOX_PIPELINE(1),
        .STATIC_SCALE_X_Q16_16(32'd32768),
        .STATIC_SCALE_Y_Q16_16(32'd16384),
        .STATIC_NOMINAL_WIDTH_Q16_16(32'd3932160),
        .STATIC_NOMINAL_HEIGHT_Q16_16(32'd1310720),
        .STATIC_TOLERANCE_WIDTH_Q16_16(32'd131072),
        .STATIC_TOLERANCE_HEIGHT_Q16_16(32'd131072),
        .STATIC_OCCUPANCY_MIN_Q8(STATIC_OCC),
        .STATIC_ASPECT_MIN_Q8(16'd320), .STATIC_ASPECT_MAX_Q8(16'd448)
      ) dut (
        .I_clk(I_clk), .I_rst_n(I_rst_n), .I_result_valid(I_result_valid),
        .I_calibration_valid(I_calibration_valid),
        .I_xmin(I_xmin), .I_xmax(I_xmax), .I_ymin(I_ymin), .I_ymax(I_ymax),
        .I_area(I_area), .I_scale_x_q16_16(32'd32768), .I_scale_y_q16_16(32'd16384),
        .I_nominal_width_q16_16(32'd3932160), .I_nominal_height_q16_16(32'd1310720),
        .I_tolerance_width_q16_16(32'd131072), .I_tolerance_height_q16_16(32'd131072),
        .I_occupancy_min_q8(I_occupancy_min_q8),
        .I_aspect_min_q8(I_aspect_min_q8), .I_aspect_max_q8(I_aspect_max_q8),
        .O_valid(o_valid), .O_invalid(o_invalid),
        .O_dimension_valid(o_dimension_valid), .O_shape_valid(o_shape_valid),
        .O_width_mm_q16_16(o_width), .O_height_mm_q16_16(o_height),
        .O_occupancy_q8(o_occupancy), .O_aspect_q8(o_aspect)
      );
    end
  endgenerate
endmodule

module tb_e1_bbox_pipe_diff;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg result_valid = 1'b0;
  reg calibration_valid = 1'b1;
  reg [10:0] xmin = 0, xmax = 0, ymin = 0, ymax = 0;
  reg [19:0] area = 0;
  reg [8:0]  occ_min = 9'd200;
  reg [15:0] asp_min = 16'd320;
  reg [15:0] asp_max = 16'd448;

  wire [92:0] base_s, cand0_s, cand1_s;   // static config
  wire [92:0] base_d, cand0_d, cand1_d;   // dynamic config

  integer checks = 0, frames = 0, i;

  always #5 clk = ~clk;

  cal_probe #(0,1,9'd200) bs (clk, rst_n, result_valid, calibration_valid,
    xmin, xmax, ymin, ymax, area, occ_min, asp_min, asp_max, base_s);
  cal_probe #(1,1,9'd200) c0s (clk, rst_n, result_valid, calibration_valid,
    xmin, xmax, ymin, ymax, area, occ_min, asp_min, asp_max, cand0_s);
  cal_probe #(2,1,9'd200) c1s (clk, rst_n, result_valid, calibration_valid,
    xmin, xmax, ymin, ymax, area, occ_min, asp_min, asp_max, cand1_s);

  cal_probe #(0,0,9'd0) bd (clk, rst_n, result_valid, calibration_valid,
    xmin, xmax, ymin, ymax, area, occ_min, asp_min, asp_max, base_d);
  cal_probe #(1,0,9'd0) c0d (clk, rst_n, result_valid, calibration_valid,
    xmin, xmax, ymin, ymax, area, occ_min, asp_min, asp_max, cand0_d);
  cal_probe #(2,0,9'd0) c1d (clk, rst_n, result_valid, calibration_valid,
    xmin, xmax, ymin, ymax, area, occ_min, asp_min, asp_max, cand1_d);

  // One producer frame: BBox committed in cycle T, result event in cycle T+1,
  // outputs sampled after edge T+2.
  task commit_frame;
    input integer ax, bx, ay, by, ap, cal_ok, occ, amin, amax;
    begin
      @(negedge clk);
      xmin = ax; xmax = bx; ymin = ay; ymax = by; area = ap;
      calibration_valid = cal_ok;
      occ_min = occ; asp_min = amin; asp_max = amax;
      result_valid = 1'b0;

      @(negedge clk);            // cycle T+1: same operands, event high
      result_valid = 1'b1;

      @(posedge clk); #1;        // edge T+2: result committed
      if (base_s !== cand0_s)
        $fatal(1, "S/no-pipe mismatch frame=%0d base=%h cand0=%h", frames, base_s, cand0_s);
      if (base_s !== cand1_s)
        $fatal(1, "S/pipeline mismatch frame=%0d base=%h cand1=%h", frames, base_s, cand1_s);
      if (base_d !== cand0_d)
        $fatal(1, "D/no-pipe mismatch frame=%0d base=%h cand0=%h", frames, base_d, cand0_d);
      if (base_d !== cand1_d)
        $fatal(1, "D/pipeline mismatch frame=%0d base=%h cand1=%h", frames, base_d, cand1_d);
      checks = checks + 1;
      frames = frames + 1;

      @(negedge clk);
      result_valid = 1'b0;
      // idle cycle with the same operands (exercises no-commit behaviour)
      @(posedge clk); #1;
      if (base_s !== cand0_s || base_s !== cand1_s ||
          base_d !== cand0_d || base_d !== cand1_d)
        $fatal(1, "idle-cycle mismatch frame=%0d", frames);
      checks = checks + 1;
      @(negedge clk);
    end
  endtask

  // Contract-sensitivity proof: drive a deliberately NON-compliant producer
  // (operands change in the result cycle). The baseline must follow the result
  // cycle operands; the pipelined candidate must follow the previous cycle's
  // operands. This proves the pipeline register really exists and is not a
  // folded-through no-op.
  task prove_pipeline_is_real;
    reg [92:0] b_before, c_before;
    begin
      @(negedge clk);
      rst_n = 1'b1;
      xmin = 10; xmax = 129; ymin = 20; ymax = 99; area = 7500;
      calibration_valid = 1'b1; occ_min = 9'd200;
      asp_min = 16'd320; asp_max = 16'd448; result_valid = 1'b0;
      @(negedge clk);
      // Non-compliant: change operands in the same cycle as the result event.
      xmin = 0; xmax = 2047; ymin = 0; ymax = 2047; area = 20'd0;
      result_valid = 1'b1;
      @(posedge clk); #1;
      if (base_s === cand1_s)
        $fatal(1, "pipeline not observable: candidate matched baseline under non-compliant stimulus");
      b_before = base_s; c_before = cand1_s;
      $display("PROVE_PIPELINE_IS_REAL base=%h cand_pipe=%h (differ as expected)", b_before, c_before);
      checks = checks + 1;
      @(negedge clk); result_valid = 1'b0;
      repeat (2) @(posedge clk);
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    @(negedge clk); rst_n = 1'b1;

    // Production calibration: 120x80 px, scale 0.5/0.25 mm/px, nominal 60x20 mm,
    // aspect Q8 384, occupancy threshold Q8 200.
    commit_frame(10,129,20,99,7499,1,200, 320,448);
    commit_frame(10,129,20,99,7500,1,200, 320,448);
    commit_frame(10,129,20,99,1048575,1,200, 320,448);
    commit_frame(10,129,20,99,7500,1,201, 320,448);
    commit_frame(10,129,20,99,7500,1,199, 320,448);
    commit_frame(10,129,20,99,7500,1,257, 320,448);
    commit_frame(10,129,20,99,7500,1,256, 320,448);

    // Geometry edges.
    commit_frame(0,0,0,0,1,1,200, 320,448);              // 1x1
    commit_frame(2047,0,0,0,1,1,200, 320,448);           // inverted
    commit_frame(0,2047,0,2047,4194304,1,200, 320,448);  // full frame, area clamp
    commit_frame(0,2047,0,0,2047,1,200, 320,448);        // 1 px tall
    commit_frame(5,5,7,7,1,1,200, 320,448);              // single pixel

    // Calibration invalid.
    commit_frame(10,129,20,99,7500,0,200, 320,448);

    // Aspect edges: width*256 vs height*min/max.
    commit_frame(10,129,20,99,7500,1,200, 0,16'hffff);
    commit_frame(10,129,20,99,7500,1,200, 16'hffff,16'hffff);
    commit_frame(10,129,20,99,7500,1,200, 0,0);

    // Reset in the middle of the sequence.
    @(negedge clk); rst_n = 1'b0; result_valid = 1'b0;
    repeat (2) @(posedge clk); #1;
    if (base_s[92:89] !== 4'b0000 || cand0_s[92:89] !== 4'b0000 ||
        cand1_s[92:89] !== 4'b0000 || base_s[88:0] !== 89'd0 ||
        cand0_s[88:0] !== 89'd0 || cand1_s[88:0] !== 89'd0)
      $fatal(1, "reset contract mismatch");
    checks = checks + 1;
    @(negedge clk); rst_n = 1'b1;

    // Deterministic sweep across legal and illegal geometry / area / threshold.
    for (i = 0; i < 512; i = i + 1)
      commit_frame(10 + (i % 7),
                   10 + 60 + ((i * 13) % 97),
                   20 + (i % 5),
                   20 + 30 + ((i * 17) % 71),
                   (i * 7919) % 1048576,
                   (i % 11) != 0,
                   i % 300,
                   (i % 3 == 0) ? 16'd0 : 16'd320,
                   (i % 5 == 0) ? 16'hffff : 16'd448);

    prove_pipeline_is_real;

    $display("TB_E1_BBOX_PIPE_DIFF_PASS checks=%0d frames=%0d", checks, frames);
    $finish;
  end

  initial begin
    #4000000;
    $fatal(1, "timeout");
  end
endmodule
