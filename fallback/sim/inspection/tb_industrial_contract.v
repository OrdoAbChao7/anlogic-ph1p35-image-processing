`timescale 1ns / 1ps

// Small-geometry system contract for the fixed-red detector/classifier path.
// The 1280x720 full-frame and Python Golden tests remain separate; this test
// exercises the same RTL modules through classification and reset/valid
// behavior without multiplying the long full-frame simulation time.
module tb_industrial_contract;

  localparam integer W = 32;
  localparam integer H = 16;
  localparam integer GROUPS = W / 4;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg tvalid = 1'b0;
  reg tlast = 1'b0;
  reg tuser = 1'b0;
  reg [95:0] tdata = 96'd0;
  reg red_map [0:W*H-1];

  wire [10:0] xmin, xmax, ymin, ymax, cx, cy;
  wire [19:0] area;
  wire detected, detect_invalid, frame_sync;
  wire [10:0] meas_w, meas_h;
  wire is_pass, is_ng, is_no_obj, is_invalid;
  wire led_pass, led_ng, led_det;

  wire [10:0] invalid_xmin, invalid_xmax, invalid_ymin, invalid_ymax;
  wire [19:0] invalid_area;
  wire invalid_detected, invalid_detect_invalid, invalid_frame_sync;
  wire [10:0] invalid_meas_w, invalid_meas_h;
  wire invalid_is_pass, invalid_is_ng, invalid_is_no_obj, invalid_is_invalid;
  wire invalid_led_pass, invalid_led_ng, invalid_led_det;

  wire [10:0] roi_xmin, roi_xmax, roi_ymin, roi_ymax, roi_cx, roi_cy;
  wire [19:0] roi_area;
  wire roi_detected, roi_invalid, roi_frame_sync;

  integer x, y, i;

  always #5 clk = ~clk;

  color_detect_96_v2 #(
    .IMG_WIDTH(W), .IMG_HEIGHT(H), .MIN_AREA(1)
  ) u_detect (
    .I_clk(clk), .I_rst_n(rst_n), .I_tvalid(tvalid), .I_tlast(tlast),
    .I_tuser(tuser), .I_tdata(tdata), .O_xmin(xmin), .O_xmax(xmax),
    .O_ymin(ymin), .O_ymax(ymax), .O_cx(cx), .O_cy(cy), .O_area(area),
    .O_detected(detected), .O_invalid(detect_invalid), .O_frame_sync(frame_sync)
  );

  defect_classifier #(
    .NOMINAL_WIDTH(8), .WIDTH_TOL(1),
    .NOMINAL_HEIGHT(6), .HEIGHT_TOL(1), .MIN_AREA(1)
  ) u_classifier (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_sync(frame_sync),
    .I_detected(detected), .I_invalid(detect_invalid),
    .I_xmin(xmin), .I_xmax(xmax), .I_ymin(ymin), .I_ymax(ymax),
    .I_area(area), .O_width(meas_w), .O_height(meas_h),
    .O_pass(is_pass), .O_ng(is_ng), .O_no_obj(is_no_obj),
    .O_invalid(is_invalid), .O_status(), .O_led_pass(led_pass),
    .O_led_ng(led_ng), .O_led_det(led_det), .O_result_toggle()
  );

  // The same stream is observed by a statically invalid ROI instance.  This
  // verifies that the invalid result reaches the classifier, not just the
  // detector's internal flag.
  color_detect_96_v2 #(
    .IMG_WIDTH(W), .IMG_HEIGHT(H), .MIN_AREA(1),
    .ROI_X(1), .ROI_Y(0), .ROI_WIDTH(0), .ROI_HEIGHT(4)
  ) u_invalid_detect (
    .I_clk(clk), .I_rst_n(rst_n), .I_tvalid(tvalid), .I_tlast(tlast),
    .I_tuser(tuser), .I_tdata(tdata), .O_xmin(invalid_xmin),
    .O_xmax(invalid_xmax), .O_ymin(invalid_ymin), .O_ymax(invalid_ymax),
    .O_cx(), .O_cy(), .O_area(invalid_area),
    .O_detected(invalid_detected), .O_invalid(invalid_detect_invalid),
    .O_frame_sync(invalid_frame_sync)
  );

  defect_classifier #(
    .NOMINAL_WIDTH(8), .WIDTH_TOL(1),
    .NOMINAL_HEIGHT(6), .HEIGHT_TOL(1), .MIN_AREA(1)
  ) u_invalid_classifier (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_sync(invalid_frame_sync),
    .I_detected(invalid_detected), .I_invalid(invalid_detect_invalid),
    .I_xmin(invalid_xmin), .I_xmax(invalid_xmax),
    .I_ymin(invalid_ymin), .I_ymax(invalid_ymax), .I_area(invalid_area),
    .O_width(invalid_meas_w), .O_height(invalid_meas_h),
    .O_pass(invalid_is_pass), .O_ng(invalid_is_ng),
    .O_no_obj(invalid_is_no_obj), .O_invalid(invalid_is_invalid),
    .O_status(), .O_led_pass(invalid_led_pass),
    .O_led_ng(invalid_led_ng), .O_led_det(invalid_led_det),
    .O_result_toggle()
  );

  // Explicit half-open ROI [8,24) x [4,12) for boundary and masking tests.
  color_detect_96_v2 #(
    .IMG_WIDTH(W), .IMG_HEIGHT(H), .MIN_AREA(1),
    .ROI_X(8), .ROI_Y(4), .ROI_WIDTH(16), .ROI_HEIGHT(8)
  ) u_roi_detect (
    .I_clk(clk), .I_rst_n(rst_n), .I_tvalid(tvalid), .I_tlast(tlast),
    .I_tuser(tuser), .I_tdata(tdata), .O_xmin(roi_xmin), .O_xmax(roi_xmax),
    .O_ymin(roi_ymin), .O_ymax(roi_ymax), .O_cx(roi_cx), .O_cy(roi_cy),
    .O_area(roi_area), .O_detected(roi_detected), .O_invalid(roi_invalid),
    .O_frame_sync(roi_frame_sync)
  );

  task clear_map;
    begin
      for (i = 0; i < W * H; i = i + 1)
        red_map[i] = 1'b0;
    end
  endtask

  task set_rect;
    input integer left;
    input integer top;
    input integer width;
    input integer height;
    integer rx, ry;
    begin
      for (ry = top; ry < top + height; ry = ry + 1)
        for (rx = left; rx < left + width; rx = rx + 1)
          if ((rx >= 0) && (rx < W) && (ry >= 0) && (ry < H))
            red_map[ry * W + rx] = 1'b1;
    end
  endtask

  function [23:0] pixel_at;
    input integer px;
    input integer py;
    begin
      pixel_at = red_map[py * W + px] ? 24'h961e1e : 24'h2d3237;
    end
  endfunction

  task drive_group;
    input integer py;
    input integer group;
    input integer with_gap;
    integer base_x;
    begin
      base_x = group * 4;
      @(negedge clk);
      tvalid = 1'b1;
      tlast  = (group == GROUPS - 1);
      tuser  = (py == 0) && (group == 0);
      tdata[95:72] = pixel_at(base_x,     py);
      tdata[71:48] = pixel_at(base_x + 1, py);
      tdata[47:24] = pixel_at(base_x + 2, py);
      tdata[23:0]  = pixel_at(base_x + 3, py);
      if (with_gap) begin
        @(negedge clk);
        tvalid = 1'b0;
        tlast  = 1'b0;
        tuser  = 1'b0;
        tdata  = 96'd0;
      end
    end
  endtask

  task send_map;
    input integer with_gap;
    integer py, group;
    begin
      for (py = 0; py < H; py = py + 1)
        for (group = 0; group < GROUPS; group = group + 1)
          drive_group(py, group, with_gap);
      @(negedge clk);
      tvalid = 1'b0;
      tlast  = 1'b0;
      tuser  = 1'b0;
      tdata  = 96'd0;
    end
  endtask

  task send_prefix;
    input integer rows;
    integer py, group;
    begin
      for (py = 0; py < rows; py = py + 1)
        for (group = 0; group < GROUPS; group = group + 1)
          drive_group(py, group, 0);
      @(negedge clk);
      tvalid = 1'b0;
      tlast  = 1'b0;
      tuser  = 1'b0;
      tdata  = 96'd0;
    end
  endtask

  task settle;
    begin
      repeat (100) @(posedge clk);
      #1;
    end
  endtask

  task expect_pass;
    input integer expected_width;
    input integer expected_height;
    begin
      if (!(is_pass && !is_ng && !is_no_obj && !is_invalid &&
            led_pass && !led_ng && led_det &&
            meas_w == expected_width && meas_h == expected_height)) begin
        $fatal(1, "PASS mismatch: det=%b pass=%b ng=%b no=%b inv=%b led=%b%b%b size=%0d,%0d bbox=%0d,%0d,%0d,%0d",
               detected, is_pass, is_ng, is_no_obj, is_invalid,
               led_pass, led_ng, led_det, meas_w, meas_h,
               xmin, xmax, ymin, ymax);
      end
    end
  endtask

  task expect_ng;
    begin
      if (!(is_ng && !is_pass && !is_no_obj && !is_invalid &&
            !led_pass && led_ng && led_det))
        $fatal(1, "NG mismatch: det=%b pass=%b ng=%b no=%b inv=%b led=%b%b%b size=%0d,%0d",
               detected, is_pass, is_ng, is_no_obj, is_invalid,
               led_pass, led_ng, led_det, meas_w, meas_h);
    end
  endtask

  task expect_no_object;
    begin
      if (!(is_no_obj && !is_pass && !is_ng && !is_invalid &&
            !led_pass && !led_ng && !led_det && !detected))
        $fatal(1, "NO_OBJECT mismatch: det=%b pass=%b ng=%b no=%b inv=%b led=%b%b%b area=%0d",
               detected, is_pass, is_ng, is_no_obj, is_invalid,
               led_pass, led_ng, led_det, area);
    end
  endtask

  task expect_invalid;
    begin
      if (!(invalid_is_invalid && !invalid_is_pass && !invalid_is_ng &&
            !invalid_is_no_obj && invalid_led_pass && invalid_led_ng &&
            !invalid_led_det))
        $fatal(1, "INVALID mismatch: det=%b pass=%b ng=%b no=%b inv=%b led=%b%b%b",
               invalid_detected, invalid_is_pass, invalid_is_ng,
               invalid_is_no_obj, invalid_is_invalid,
               invalid_led_pass, invalid_led_ng, invalid_led_det);
    end
  endtask

  initial begin
    clear_map();
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);

    // Nominal 8x6 object: PASS and exact dimensions.
    clear_map(); set_rect(12, 5, 8, 6); send_map(0); settle; expect_pass(8, 6);
    $display("PASS nominal object");

    // Width and height over tolerance: NG.
    clear_map(); set_rect(11, 5, 10, 6); send_map(0); settle; expect_ng();
    $display("PASS oversized width NG");
    clear_map(); set_rect(12, 4, 8, 8); send_map(0); settle; expect_ng();
    $display("PASS oversized height NG");

    // Width and height under tolerance: NG.
    clear_map(); set_rect(13, 5, 6, 6); send_map(0); settle; expect_ng();
    $display("PASS undersized width NG");
    clear_map(); set_rect(12, 6, 8, 4); send_map(0); settle; expect_ng();
    $display("PASS undersized height NG");

    // Empty scene clears the previous result and LEDs.
    clear_map(); send_map(0); settle; expect_no_object();
    $display("PASS empty scene NO_OBJECT");

    // ROI masking ignores red interference outside [8,24) x [4,12).
    clear_map(); set_rect(0, 0, 4, 16); set_rect(12, 5, 8, 6);
    send_map(0); settle;
    if (!(roi_detected && !roi_invalid && roi_area == 20'd48 &&
          roi_xmin == 12 && roi_xmax == 19 && roi_ymin == 5 && roi_ymax == 10))
      $fatal(1, "ROI external interference mismatch: det=%b inv=%b area=%0d bbox=%0d,%0d,%0d,%0d",
             roi_detected, roi_invalid, roi_area, roi_xmin, roi_xmax, roi_ymin, roi_ymax);
    $display("PASS ROI external interference masked");

    // A target touching the ROI top-left edge uses BORDER_REPLICATE.
    clear_map(); set_rect(8, 4, 8, 6); send_map(1); settle;
    if (!(roi_detected && !roi_invalid && roi_area == 20'd48 &&
          roi_xmin == 8 && roi_xmax == 15 && roi_ymin == 4 && roi_ymax == 9))
      $fatal(1, "ROI edge replicate mismatch: det=%b inv=%b area=%0d bbox=%0d,%0d,%0d,%0d",
             roi_detected, roi_invalid, roi_area, roi_xmin, roi_xmax, roi_ymin, roi_ymax);
    $display("PASS ROI edge BORDER_REPLICATE");

    // A target crossing the left edge is clipped to the ROI before opening.
    clear_map(); set_rect(4, 4, 8, 6); send_map(0); settle;
    if (!(roi_detected && !roi_invalid && roi_area == 20'd24 &&
          roi_xmin == 8 && roi_xmax == 11 && roi_ymin == 4 && roi_ymax == 9))
      $fatal(1, "ROI half-target mismatch: det=%b inv=%b area=%0d bbox=%0d,%0d,%0d,%0d",
             roi_detected, roi_invalid, roi_area, roi_xmin, roi_xmax, roi_ymin, roi_ymax);
    $display("PASS ROI half-target clipping");

    // Border-replicated opening preserves a valid object touching image edges.
    clear_map(); set_rect(0, 0, 8, 6); send_map(1); settle; expect_pass(8, 6);
    $display("PASS edge object and intermittent valid");

    // Reset in the middle of a raster must not publish a partial result.
    clear_map(); set_rect(12, 5, 8, 6); send_prefix(5);
    rst_n = 1'b0;
    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
    send_map(0); settle; expect_pass(8, 6);
    $display("PASS frame reset recovery");

    // The invalid-ROI branch runs in parallel on the same stream.
    expect_invalid();
    $display("PASS invalid ROI propagated to classifier");

    $display("PASS industrial detector/classifier contract: dimensions, status, LED, edge, gaps, reset, invalid ROI");
    $finish;
  end

  initial begin
    #2000000;
    $fatal(1, "timeout in industrial contract testbench");
  end

endmodule
