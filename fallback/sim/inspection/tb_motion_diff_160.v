`timescale 1ns/1ps

module tb_motion_diff_160;
  localparam integer W = 4;
  localparam integer H = 3;
  localparam integer XW = $clog2(W + 1);
  localparam integer YW = $clog2(H);
  localparam integer CW = 8;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg frame_start = 1'b0;
  reg frame_end = 1'b0;
  reg sample_valid = 1'b0;
  reg [15:0] frame_id = 0;
  reg [XW-1:0] sample_x = 0;
  reg [YW-1:0] sample_y = 0;
  reg [7:0] sample_value = 0;
  wire summary_valid;
  wire baseline_ready;
  wire motion_valid;
  wire motion;
  wire [CW-1:0] motion_count;
  wire [XW-1:0] xmin, xmax;
  wire [YW-1:0] ymin, ymax;
  wire frame_gap, invalid;

  always #5 clk = ~clk;

  motion_diff_160 #(
    .IMG_WIDTH(W), .IMG_HEIGHT(H), .THRESHOLD(5), .COUNT_WIDTH(CW),
    .X_WIDTH(XW)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_start(frame_start),
    .I_frame_end(frame_end), .I_sample_valid(sample_valid),
    .I_frame_id(frame_id), .I_sample_x(sample_x), .I_sample_y(sample_y),
    .I_y_value(sample_value), .O_summary_valid(summary_valid),
    .O_baseline_ready(baseline_ready), .O_motion_valid(motion_valid),
    .O_motion(motion), .O_motion_count(motion_count), .O_xmin(xmin),
    .O_xmax(xmax), .O_ymin(ymin), .O_ymax(ymax), .O_frame_gap(frame_gap),
    .O_invalid(invalid)
  );

  task clear_inputs;
    begin
      frame_start = 1'b0;
      frame_end = 1'b0;
      sample_valid = 1'b0;
    end
  endtask

  task start_frame;
    input [15:0] id;
    begin
      @(negedge clk); clear_inputs; frame_id = id; frame_start = 1'b1;
      @(posedge clk); #1; clear_inputs;
    end
  endtask

  task send_sample;
    input integer x;
    input integer y;
    input [7:0] value;
    input integer last;
    begin
      @(negedge clk); clear_inputs;
      sample_x = x; sample_y = y; sample_value = value;
      sample_valid = 1'b1; frame_end = last;
      @(posedge clk); #1; clear_inputs;
    end
  endtask

  // pattern 0: uniform 20; pattern 1: 2x2 patch at x=1..2,y=0..1;
  // pattern 2: uniform 80; pattern 3: one exact-threshold sample;
  // pattern 4: one above-threshold sample; pattern 5: one invalid coordinate.
  task send_pattern;
    input [15:0] id;
    input integer pattern;
    integer i, x, y;
    reg [7:0] value;
    begin
      start_frame(id);
      for (i = 0; i < W*H; i = i + 1) begin
        x = i % W; y = i / W; value = 8'd20;
        if (pattern == 1 && x >= 1 && x <= 2 && y <= 1) value = 8'd50;
        if (pattern >= 2) value = 8'd80;
        if (pattern == 3 && x == 0 && y == 0) value = 8'd85;
        if (pattern == 4 && x == 0 && y == 0) value = 8'd91;
        if (pattern == 5 && i == 0) x = W;
        send_sample(x, y, value, (i == W*H-1));
      end
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    send_pattern(16'd10, 0);
    if (!summary_valid || !baseline_ready || motion_valid || motion || invalid)
      $fatal(1, "first frame contract failed");

    send_pattern(16'd11, 0);
    if (!summary_valid || !motion_valid || motion || motion_count !== 0)
      $fatal(1, "static frame contract failed");

    send_pattern(16'd12, 1);
    if (!summary_valid || !motion_valid || !motion || motion_count !== 4 ||
        xmin !== 1 || xmax !== 2 || ymin !== 0 || ymax !== 1)
      $fatal(1, "local motion contract failed count=%0d bbox=%0d,%0d,%0d,%0d",
        motion_count, xmin, xmax, ymin, ymax);

    send_pattern(16'd13, 1);
    if (!summary_valid || !motion_valid || motion || motion_count !== 0)
      $fatal(1, "stable changed patch incorrectly reported motion");

    send_pattern(16'd15, 2);
    if (!summary_valid || !frame_gap || motion_valid || motion || invalid)
      $fatal(1, "frame gap contract failed");

    send_pattern(16'd16, 2);
    if (!summary_valid || !motion_valid || motion)
      $fatal(1, "gap refresh baseline failed");

    send_pattern(16'd17, 3);
    if (!summary_valid || !motion_valid || motion || motion_count !== 0)
      $fatal(1, "strict threshold contract failed");

    send_pattern(16'd18, 4);
    if (!summary_valid || !motion_valid || !motion || motion_count !== 1 ||
        xmin !== 0 || xmax !== 0 || ymin !== 0 || ymax !== 0)
      $fatal(1, "above threshold contract failed");

    send_pattern(16'd19, 5);
    if (summary_valid || !invalid)
      $fatal(1, "invalid coordinate contract failed");

    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    send_pattern(16'd1, 2);
    if (!summary_valid || motion_valid || frame_gap || invalid)
      $fatal(1, "reset first-frame contract failed");

    $display("TB_MOTION_DIFF_160_PASS");
    $finish;
  end

  initial begin
    #1000000;
    $fatal(1, "timeout in motion diff testbench");
  end
endmodule
