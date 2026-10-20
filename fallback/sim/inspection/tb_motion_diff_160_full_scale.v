`timescale 1ns/1ps

// Full-grid regression for the 160x120 motion counter resource contract.
module tb_motion_diff_160_full_scale #(
  parameter integer USE_PH1P_HISTORY_ERAM = 0
);
  localparam integer W = 160;
  localparam integer H = 120;
  localparam integer DEPTH = W * H;
  localparam integer EXPECTED_COUNT_WIDTH = $clog2(DEPTH + 1);
  localparam integer XW = $clog2(W);
  localparam integer YW = $clog2(H);
  localparam integer PORT_COUNT_WIDTH = 24;

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
  wire [PORT_COUNT_WIDTH-1:0] motion_count;
  wire [XW-1:0] xmin, xmax;
  wire [YW-1:0] ymin, ymax;
  wire frame_gap, invalid;

  always #5 clk = ~clk;

  motion_diff_160 #(
    .IMG_WIDTH(W), .IMG_HEIGHT(H), .THRESHOLD(8),
    .COUNT_WIDTH(PORT_COUNT_WIDTH), .X_WIDTH(XW), .Y_WIDTH(YW),
    .USE_PH1P_HISTORY_ERAM(USE_PH1P_HISTORY_ERAM)
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

  task send_dense_frame;
    input [15:0] id;
    input [7:0] value;
    integer i;
    begin
      start_frame(id);
      for (i = 0; i < DEPTH; i = i + 1) begin
        @(negedge clk); clear_inputs;
        sample_x = i % W;
        sample_y = i / W;
        sample_value = value;
        sample_valid = 1'b1;
        frame_end = (i == DEPTH - 1);
        @(posedge clk); #1; clear_inputs;
      end
    end
  endtask

  initial begin
    if ($bits(dut.motion_count_accum) != EXPECTED_COUNT_WIDTH)
      $fatal(1, "motion accumulator width=%0d expected=%0d",
        $bits(dut.motion_count_accum), EXPECTED_COUNT_WIDTH);
    if ($bits(motion_count) != PORT_COUNT_WIDTH)
      $fatal(1, "external motion count width changed: %0d", $bits(motion_count));

    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    send_dense_frame(16'd20, 8'd0);
    if (!summary_valid || !baseline_ready || motion_valid || invalid)
      $fatal(1, "baseline full-grid frame contract failed");

    send_dense_frame(16'd21, 8'd255);
    if (!summary_valid || !motion_valid || !motion || invalid ||
        motion_count !== DEPTH || xmin !== 0 || xmax !== W - 1 ||
        ymin !== 0 || ymax !== H - 1)
      $fatal(1, "maximum motion frame contract failed count=%0d bbox=%0d,%0d,%0d,%0d",
        motion_count, xmin, xmax, ymin, ymax);

    $display("TB_MOTION_DIFF_160_FULL_SCALE_PASS count=%0d width=%0d",
      motion_count, $bits(dut.motion_count_accum));
    $finish;
  end

  initial begin
    #2000000;
    $fatal(1, "timeout in full-scale motion diff testbench");
  end
endmodule
