`timescale 1ns/1ps

module tb_motion_diff_160_eram_equivalence;
  localparam integer W = 4;
  localparam integer H = 3;
  localparam integer XW = $clog2(W);
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
  integer j;

  wire [5:0] baseline_status;
  wire [5:0] eram_status;
  wire [CW-1:0] baseline_count, eram_count;
  wire [XW-1:0] baseline_xmin, baseline_xmax, eram_xmin, eram_xmax;
  wire [YW-1:0] baseline_ymin, baseline_ymax, eram_ymin, eram_ymax;

  always #5 clk = ~clk;

  motion_diff_160 #(
    .IMG_WIDTH(W), .IMG_HEIGHT(H), .THRESHOLD(5), .COUNT_WIDTH(CW),
    .X_WIDTH(XW), .Y_WIDTH(YW), .USE_PH1P_HISTORY_ERAM(0)
  ) baseline (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_start(frame_start),
    .I_frame_end(frame_end), .I_sample_valid(sample_valid),
    .I_frame_id(frame_id), .I_sample_x(sample_x), .I_sample_y(sample_y),
    .I_y_value(sample_value), .O_summary_valid(baseline_status[5]),
    .O_baseline_ready(baseline_status[4]), .O_motion_valid(baseline_status[3]),
    .O_motion(baseline_status[2]), .O_motion_count(baseline_count),
    .O_xmin(baseline_xmin), .O_xmax(baseline_xmax),
    .O_ymin(baseline_ymin), .O_ymax(baseline_ymax),
    .O_frame_gap(baseline_status[1]), .O_invalid(baseline_status[0])
  );

  motion_diff_160 #(
    .IMG_WIDTH(W), .IMG_HEIGHT(H), .THRESHOLD(5), .COUNT_WIDTH(CW),
    .X_WIDTH(XW), .Y_WIDTH(YW), .USE_PH1P_HISTORY_ERAM(1)
  ) candidate (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_start(frame_start),
    .I_frame_end(frame_end), .I_sample_valid(sample_valid),
    .I_frame_id(frame_id), .I_sample_x(sample_x), .I_sample_y(sample_y),
    .I_y_value(sample_value), .O_summary_valid(eram_status[5]),
    .O_baseline_ready(eram_status[4]), .O_motion_valid(eram_status[3]),
    .O_motion(eram_status[2]), .O_motion_count(eram_count),
    .O_xmin(eram_xmin), .O_xmax(eram_xmax),
    .O_ymin(eram_ymin), .O_ymax(eram_ymax),
    .O_frame_gap(eram_status[1]), .O_invalid(eram_status[0])
  );

  task clear_inputs;
    begin
      frame_start = 1'b0;
      frame_end = 1'b0;
      sample_valid = 1'b0;
    end
  endtask

  task check_equivalence;
    begin
      if (baseline_status !== eram_status || baseline_count !== eram_count ||
          baseline_xmin !== eram_xmin || baseline_xmax !== eram_xmax ||
          baseline_ymin !== eram_ymin || baseline_ymax !== eram_ymax)
        $fatal(1, "ERAM model diverged at frame=%0d x=%0d y=%0d status=%b/%b count=%0d/%0d",
          frame_id, sample_x, sample_y, baseline_status, eram_status,
          baseline_count, eram_count);
    end
  endtask

  task start_frame;
    input [15:0] id;
    begin
      @(negedge clk); clear_inputs; frame_id = id; frame_start = 1'b1;
      @(posedge clk); #1; clear_inputs; check_equivalence;
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
      @(posedge clk); #1; clear_inputs; check_equivalence;
    end
  endtask

  task send_uniform_frame;
    input [15:0] id;
    input [7:0] value;
    integer i;
    begin
      start_frame(id);
      for (i = 0; i < W * H; i = i + 1)
        send_sample(i % W, i / W, value, (i == W * H - 1));
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    send_uniform_frame(16'd10, 8'd0);
    if (!baseline_status[5] || !baseline_status[4] || baseline_status[3])
      $fatal(1, "initial frame did not establish history");

    send_uniform_frame(16'd11, 8'd0);
    if (!baseline_status[5] || !baseline_status[3] || baseline_status[2] ||
        baseline_count !== 0)
      $fatal(1, "static frame contract failed");

    // Invalid frame samples still update history in the existing contract.
    // The next valid frame reuses its expected ID and must see both writes.
    start_frame(16'd12);
    send_sample(1, 0, 8'd200, 0);
    send_sample(2, 0, 8'd200, 1);
    if (baseline_status[5] || !baseline_status[0])
      $fatal(1, "partial frame was not reported invalid");

    start_frame(16'd12);
    for (j = 0; j < W * H; j = j + 1)
      send_sample(j % W, j / W, 8'd0, (j == W * H - 1));
    if (!baseline_status[5] || !baseline_status[3] || !baseline_status[2] ||
        baseline_status[1] || baseline_status[0] || baseline_count !== 2 ||
        baseline_xmin !== 1 || baseline_xmax !== 2 ||
        baseline_ymin !== 0 || baseline_ymax !== 0)
      $fatal(1, "read-before-write / invalid-frame history semantics changed");

    send_uniform_frame(16'd13, 8'd0);
    if (!baseline_status[5] || !baseline_status[3] || baseline_status[2] ||
        baseline_count !== 0)
      $fatal(1, "ERAM history did not refresh after valid frame");

    $display("TB_MOTION_DIFF_160_ERAM_EQUIVALENCE_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in ERAM motion equivalence testbench");
  end
endmodule
