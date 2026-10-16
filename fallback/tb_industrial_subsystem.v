`timescale 1ns / 1ps
// ============================================================================
// Testbench: tb_industrial_subsystem
// Verifies:
//   1. color_detect_96_v2 double-buffered steady latching & 4-pixel lane processing
//   2. defect_classifier PASS/NG dimension decision & LED drivers
//   3. bbox_draw_overlay HDMI streaming border pixel replacement
// ============================================================================

module tb_industrial_subsystem;

  reg         clk;
  reg         rst_n;

  // 96-bit 4-pixel stream signals
  reg         tvalid;
  reg         tlast;
  reg         tuser;
  reg  [95:0] tdata;

  // Color detect v2 outputs
  wire [10:0] xmin, xmax, ymin, ymax, cx, cy;
  wire [19:0] area;
  wire        detected;
  wire        detect_invalid;
  wire        frame_sync;

  // Defect classifier outputs
  wire [10:0] meas_w, meas_h;
  wire        is_pass, is_ng, is_no_obj, is_invalid, led_det;
  wire        led_pass, led_ng;

  // HDMI overlay signals
  reg         hdmi_de, hdmi_hsync, hdmi_vsync;
  reg  [23:0] hdmi_rgb;
  reg  [10:0] hdmi_x, hdmi_y;
  wire        out_de, out_hsync, out_vsync;
  wire [23:0] out_rgb;

  // Clock generation: 50 MHz (20ns period)
  always #10 clk = ~clk;

  // Instantiate color_detect_96_v2
  color_detect_96_v2 #(
    .IMG_WIDTH(1280),
    .IMG_HEIGHT(720),
    .CB_MIN(85),
    .CB_MAX(125),
    .CR_MIN(135),
    .CR_MAX(200),
    .MIN_AREA(10)
  ) u_detect (
    .I_clk(clk),
    .I_rst_n(rst_n),
    .I_tvalid(tvalid),
    .I_tlast(tlast),
    .I_tuser(tuser),
    .I_tdata(tdata),
    .O_xmin(xmin),
    .O_xmax(xmax),
    .O_ymin(ymin),
    .O_ymax(ymax),
    .O_cx(cx),
    .O_cy(cy),
    .O_area(area),
    .O_detected(detected),
    .O_frame_sync(frame_sync)
  );

  // Instantiate defect_classifier
  defect_classifier #(
    .NOMINAL_WIDTH(120),
    .WIDTH_TOL(15),
    .NOMINAL_HEIGHT(80),
    .HEIGHT_TOL(12)
  ) u_classifier (
    .I_clk(clk),
    .I_rst_n(rst_n),
    .I_frame_sync(frame_sync),
    .I_detected(detected),
    .I_xmin(xmin),
    .I_xmax(xmax),
    .I_ymin(ymin),
    .I_ymax(ymax),
    .I_area(area),
    .O_width(meas_w),
    .O_height(meas_h),
    .O_pass(is_pass),
    .O_ng(is_ng),
    .O_no_obj(is_no_obj),
    .O_led_pass(led_pass),
    .O_led_ng(led_ng)
  );

  // Instantiate bbox_draw_overlay
  bbox_draw_overlay #(
    .LINE_THICKNESS(2),
    .COLOR_PASS(24'h10b981),
    .COLOR_NG(24'hef4444)
  ) u_overlay (
    .I_clk(clk),
    .I_rst_n(rst_n),
    .I_de(hdmi_de),
    .I_hsync(hdmi_hsync),
    .I_vsync(hdmi_vsync),
    .I_rgb(hdmi_rgb),
    .I_x(hdmi_x),
    .I_y(hdmi_y),
    .I_detected(detected),
    .I_xmin(xmin),
    .I_xmax(xmax),
    .I_ymin(ymin),
    .I_ymax(ymax),
    .I_pass(is_pass),
    .I_ng(is_ng),
    .O_de(out_de),
    .O_hsync(out_hsync),
    .O_vsync(out_vsync),
    .O_rgb(out_rgb)
  );

  // Helper task to simulate sending an active frame with a synthetic rectangular part
  // part_x: start column, part_w: width in pixels, part_y: start row, part_h: height in rows
  task send_frame;
    input [10:0] part_x;
    input [10:0] part_w;
    input [10:0] part_y;
    input [10:0] part_h;
    input        has_part;
    integer r, g_idx;
    reg [11:0] cur_col;
    reg in_part0, in_part1, in_part2, in_part3;
    begin
      // Send frame start strobe (tuser)
      @(posedge clk);
      #1;
      tuser  <= 1'b1;
      tvalid <= 1'b0;
      @(posedge clk);
      #1;
      tuser  <= 1'b0;

      // Scan rows
      for (r = 0; r < 720; r = r + 1) begin
        for (g_idx = 0; g_idx < 320; g_idx = g_idx + 1) begin
          cur_col = g_idx << 2;

          if (has_part && (r >= part_y && r < part_y + part_h)) begin
            in_part0 = (cur_col     >= part_x && cur_col     < part_x + part_w);
            in_part1 = (cur_col + 1 >= part_x && cur_col + 1 < part_x + part_w);
            in_part2 = (cur_col + 2 >= part_x && cur_col + 2 < part_x + part_w);
            in_part3 = (cur_col + 3 >= part_x && cur_col + 3 < part_x + part_w);
          end else begin
            in_part0 = 0; in_part1 = 0; in_part2 = 0; in_part3 = 0;
          end

          // Pack 4 pixels (Calibrated red workpiece: R=150, G=30, B=30 vs dark background: R=45, G=50, B=55)
          tdata[95:72] <= in_part0 ? 24'h961e1e : 24'h2d3237;
          tdata[71:48] <= in_part1 ? 24'h961e1e : 24'h2d3237;
          tdata[47:24] <= in_part2 ? 24'h961e1e : 24'h2d3237;
          tdata[23:0]  <= in_part3 ? 24'h961e1e : 24'h2d3237;
          tvalid       <= 1'b1;
          tlast        <= (g_idx == 319);
          @(posedge clk);
          #1;
        end
        tvalid <= 1'b0;
        tlast  <= 1'b0;
        repeat(4) begin
          @(posedge clk);
          #1;
        end
      end
    end
  endtask

  initial begin
    clk        = 0;
    rst_n      = 0;
    tvalid     = 0;
    tlast      = 0;
    tuser      = 0;
    tdata      = 0;
    hdmi_de    = 0;
    hdmi_hsync = 0;
    hdmi_vsync = 0;
    hdmi_rgb   = 24'h2d3237;
    hdmi_x     = 0;
    hdmi_y     = 0;

    #40 rst_n = 1;
    #20;

    $display("================================================================================");
    $display("TESTBENCH: FPGA INDUSTRIAL INSPECTION SUBSYSTEM VERIFICATION");
    $display("================================================================================");

    // -------------------------------------------------------------------------
    // Frame 1: Standard nominal part (X=580, W=120, Y=320, H=80) -> Expect PASS
    // -------------------------------------------------------------------------
    $display("\n>>> Simulating Frame 1: Standard Workpiece (Nominal 120x80) <<<");
    send_frame(580, 120, 320, 80, 1);

    repeat(1400) @(posedge clk);
    #5;

    $display("Frame 1 Latch: detected=%b, xmin=%d, xmax=%d, ymin=%d, ymax=%d, Area=%d",
             detected, xmin, xmax, ymin, ymax, area);
    $display("Frame 1 Decision: Measured W=%d, H=%d, PASS=%b, NG=%b, LED_PASS=%b, LED_NG=%b",
             meas_w, meas_h, is_pass, is_ng, led_pass, led_ng);

    if (detected == 1 && is_pass == 1 && is_ng == 0 && led_pass == 1 && meas_w == 120 && meas_h == 80) begin
      $display("[PASS] Frame 1 Standard Workpiece Correctly Verified as PASS!");
    end else begin
      $display("[FAIL] Frame 1 Verification Failed!");
      $fatal(1);
    end

    // Test HDMI overlay on Frame 1 result: check if pixel on border (580, 320) outputs green
    hdmi_de  <= 1'b1;
    hdmi_x   <= 580;
    hdmi_y   <= 320;
    hdmi_rgb <= 24'h2d3237;
    @(posedge clk);
    #2;
    $display("HDMI Overlay at border (580, 320): Output RGB = 0x%06x (Expected 0x10b981 GREEN)", out_rgb);
    if (out_rgb == 24'h10b981) begin
      $display("[PASS] HDMI Overlay correctly painted PASS Green Border!");
    end else begin
      $display("[FAIL] HDMI Overlay border color mismatch!");
      $fatal(1);
    end

    // -------------------------------------------------------------------------
    // Frame 2: Oversized defective part (X=580, W=165, Y=320, H=80) -> Expect NG
    // -------------------------------------------------------------------------
    $display("\n>>> Simulating Frame 2: Oversized Workpiece (Width 165 > 135) <<<");
    send_frame(580, 165, 320, 80, 1);

    repeat(1400) @(posedge clk);
    #5;

    $display("Frame 2 Latch: detected=%b, xmin=%d, xmax=%d, ymin=%d, ymax=%d, Area=%d",
             detected, xmin, xmax, ymin, ymax, area);
    $display("Frame 2 Decision: Measured W=%d, H=%d, PASS=%b, NG=%b, LED_PASS=%b, LED_NG=%b",
             meas_w, meas_h, is_pass, is_ng, led_pass, led_ng);

    if (detected == 1 && is_pass == 0 && is_ng == 1 && led_ng == 1 && meas_w == 165) begin
      $display("[PASS] Frame 2 Defective Workpiece Correctly Verified as NG!");
    end else begin
      $display("[FAIL] Frame 2 Verification Failed!");
      $fatal(1);
    end

    // Test HDMI overlay on Frame 2 result: check if pixel on border (580, 320) outputs red
    hdmi_de  <= 1'b1;
    hdmi_x   <= 580;
    hdmi_y   <= 320;
    hdmi_rgb <= 24'h2d3237;
    @(posedge clk);
    #2;
    $display("HDMI Overlay at border (580, 320): Output RGB = 0x%06x (Expected 0xef4444 RED)", out_rgb);
    if (out_rgb == 24'hef4444) begin
      $display("[PASS] HDMI Overlay correctly painted NG Red Border!");
    end else begin
      $display("[FAIL] HDMI Overlay NG border color mismatch!");
      $fatal(1);
    end

    // -------------------------------------------------------------------------
    // Frame 3: Empty Conveyor (No Workpiece) -> Expect NO_OBJECT
    // -------------------------------------------------------------------------
    $display("\n>>> Simulating Frame 3: Empty Conveyor (No Workpiece) <<<");
    send_frame(0, 0, 0, 0, 0);

    repeat(1400) @(posedge clk);
    #5;

    $display("Frame 3 Latch: detected=%b, Area=%d, NO_OBJ=%b, PASS=%b, NG=%b",
             detected, area, is_no_obj, is_pass, is_ng);

    if (detected == 0 && is_no_obj == 1 && is_pass == 0 && is_ng == 0 && led_pass == 0 && led_ng == 0) begin
      $display("[PASS] Frame 3 Empty Scene Correctly Verified as NO_OBJECT!");
    end else begin
      $display("[FAIL] Frame 3 Verification Failed!");
      $fatal(1);
    end

    $display("\n================================================================================");
    $display(">>> ALL INDUSTRIAL INSPECTION SUBSYSTEM RTL SIMULATION TESTS PASSED! <<<");
    $display("================================================================================");

    #100 $finish;
  end

endmodule
