`timescale 1ns/1ps

module tb_latency_monitor;
  localparam integer CW = 4;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg input_valid = 1'b0;
  reg [15:0] input_id = 0;
  reg result_valid = 1'b0;
  reg [15:0] result_id = 0;
  reg video_valid = 1'b0;
  reg [15:0] video_id = 0;
  wire proc_valid, video_measure_valid, e2e_valid;
  wire [CW-1:0] proc_cycles, video_cycles, e2e_cycles;
  wire frame_gap, tag_mismatch, timeout;

  always #5 clk = ~clk;

  latency_monitor #(.COUNTER_WIDTH(CW), .TIMEOUT_CYCLES(12)) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_input_valid(input_valid),
    .I_input_frame_id(input_id), .I_result_valid(result_valid),
    .I_result_frame_id(result_id), .I_video_valid(video_valid),
    .I_video_frame_id(video_id), .O_proc_valid(proc_valid),
    .O_proc_cycles(proc_cycles), .O_video_valid(video_measure_valid),
    .O_video_cycles(video_cycles), .O_e2e_valid(e2e_valid),
    .O_e2e_cycles(e2e_cycles), .O_frame_gap(frame_gap),
    .O_tag_mismatch(tag_mismatch), .O_timeout(timeout)
  );

  task clear_inputs;
    begin input_valid=0; result_valid=0; video_valid=0; end
  endtask

  task idle_cycle;
    begin @(negedge clk); clear_inputs; @(posedge clk); #1; end
  endtask

  task send_input;
    input [15:0] id;
    begin
      @(negedge clk); clear_inputs; input_id=id; input_valid=1;
      @(posedge clk); #1; input_valid=0;
    end
  endtask

  task send_result;
    input [15:0] id;
    begin
      @(negedge clk); clear_inputs; result_id=id; result_valid=1;
      @(posedge clk); #1; result_valid=0;
    end
  endtask

  task send_video;
    input [15:0] id;
    begin
      @(negedge clk); clear_inputs; video_id=id; video_valid=1;
      @(posedge clk); #1; video_valid=0;
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n=1;

    send_input(16'd10);
    repeat (5) idle_cycle;
    send_result(16'd10);
    if (!proc_valid || proc_cycles !== 5 || tag_mismatch)
      $fatal(1, "PROC latency mismatch valid=%b cycles=%0d mismatch=%b",
        proc_valid, proc_cycles, tag_mismatch);
    repeat (3) idle_cycle;
    send_video(16'd10);
    if (!video_measure_valid || video_cycles !== 8 || tag_mismatch)
      $fatal(1, "VIDEO latency mismatch valid=%b cycles=%0d mismatch=%b",
        video_measure_valid, video_cycles, tag_mismatch);
    if (e2e_valid || e2e_cycles !== 0)
      $fatal(1, "E2E should remain N/A valid=%b cycles=%0d", e2e_valid, e2e_cycles);

    send_input(16'd12);
    if (!frame_gap)
      $fatal(1, "frame gap was not reported");
    send_result(16'd11);
    if (!tag_mismatch || proc_valid)
      $fatal(1, "tag mismatch incorrectly published PROC");
    repeat (2) idle_cycle;
    send_result(16'd12);
    if (!proc_valid || proc_cycles !== 2)
      $fatal(1, "matching result after mismatch failed");

    send_input(16'd20);
    repeat (12) idle_cycle;
    if (!timeout)
      $fatal(1, "latency timeout was not published");
    send_result(16'd20);
    if (!tag_mismatch || proc_valid)
      $fatal(1, "late result was accepted after timeout");

    rst_n=1'b0;
    repeat (2) @(posedge clk);
    rst_n=1'b1;
    repeat (14) idle_cycle;
    send_input(16'd30);
    repeat (5) idle_cycle;
    send_result(16'd30);
    if (!proc_valid || proc_cycles !== 5)
      $fatal(1, "counter wrap subtraction mismatch cycles=%0d", proc_cycles);

    $display("TB_LATENCY_MONITOR_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in latency monitor testbench");
  end
endmodule
