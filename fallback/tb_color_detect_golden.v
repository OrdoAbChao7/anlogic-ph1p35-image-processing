`timescale 1ns/1ps

module tb_color_detect_golden #(
  parameter integer W = 16,
  parameter integer H = 8,
  parameter integer ROI_X = 0,
  parameter integer ROI_Y = 0,
  parameter integer ROI_W = 0,
  parameter integer ROI_H = 0,
  parameter integer EXPECTED_FRAMES = 5
);
  reg clk = 0;
  always #5 clk = ~clk;

  reg rst_n = 0;
  reg tvalid = 0, tlast = 0, tuser = 0;
  reg [95:0] tdata = 0;
  wire [10:0] xmin, xmax, ymin, ymax, cx, cy;
  wire [19:0] area;
  wire detected, invalid, frame_sync;

  color_detect_96_v2 #(
    .IMG_WIDTH(W), .IMG_HEIGHT(H), .MIN_AREA(1),
    .ROI_X(ROI_X), .ROI_Y(ROI_Y), .ROI_WIDTH(ROI_W), .ROI_HEIGHT(ROI_H)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_tvalid(tvalid), .I_tlast(tlast),
    .I_tuser(tuser), .I_tdata(tdata), .O_xmin(xmin), .O_xmax(xmax),
    .O_ymin(ymin), .O_ymax(ymax), .O_cx(cx), .O_cy(cy), .O_area(area),
    .O_detected(detected), .O_invalid(invalid), .O_frame_sync(frame_sync)
  );

  integer stimulus_fd, expected_fd, n, observed_frames = 0;
  integer exp_area, exp_xmin, exp_xmax, exp_ymin, exp_ymax;
  integer exp_detected, exp_invalid;
  reg [4095:0] stimulus_path;
  reg [4095:0] expected_path;
  integer stimulus_valid, stimulus_last, stimulus_user;

  always @(posedge clk) begin
    #1;
    if (frame_sync) begin
      if ($fscanf(expected_fd, "%d %d %d %d %d %d %d\n",
                  exp_area, exp_xmin, exp_xmax, exp_ymin, exp_ymax,
                  exp_detected, exp_invalid) != 7)
        $fatal(1, "missing expected frame %0d", observed_frames);
      if (area !== exp_area[19:0] || xmin !== exp_xmin[10:0] ||
          xmax !== exp_xmax[10:0] || ymin !== exp_ymin[10:0] ||
          ymax !== exp_ymax[10:0] || detected !== exp_detected[0] ||
          invalid !== exp_invalid[0]) begin
        $fatal(1, "frame %0d mismatch: got area=%0d bbox=%0d,%0d,%0d,%0d det=%0d inv=%0d; expected area=%0d bbox=%0d,%0d,%0d,%0d det=%0d inv=%0d",
               observed_frames, area, xmin, xmax, ymin, ymax, detected, invalid,
               exp_area, exp_xmin, exp_xmax, exp_ymin, exp_ymax,
               exp_detected, exp_invalid);
      end
      observed_frames = observed_frames + 1;
    end
  end

  initial begin
    if (!$value$plusargs("STIMULUS=%s", stimulus_path))
      $fatal(1, "missing +STIMULUS");
    if (!$value$plusargs("EXPECTED=%s", expected_path))
      $fatal(1, "missing +EXPECTED");
    stimulus_fd = $fopen(stimulus_path, "r");
    expected_fd = $fopen(expected_path, "r");
    if (stimulus_fd == 0 || expected_fd == 0)
      $fatal(1, "cannot open vector files");

    repeat (3) @(negedge clk);
    rst_n = 1;
    while (!$feof(stimulus_fd)) begin
      n = $fscanf(stimulus_fd, "%d %d %d %h\n",
                  stimulus_valid, stimulus_last, stimulus_user, tdata);
      if (n != 4)
        $fatal(1, "malformed stimulus vector");
      @(negedge clk);
      tvalid = stimulus_valid;
      tlast  = stimulus_last;
      tuser  = stimulus_user;
      // tdata is assigned directly by fscanf for a stable cycle.
      @(posedge clk);
    end
    tvalid = 0;
    tlast = 0;
    tuser = 0;
    repeat (500) @(posedge clk);
    if (observed_frames != EXPECTED_FRAMES)
      $fatal(1, "observed %0d frames, expected %0d", observed_frames, EXPECTED_FRAMES);
    $display("PASS color_detect_96_v2 against Python hardware golden (%0d frames)", observed_frames);
    $finish;
  end
endmodule
