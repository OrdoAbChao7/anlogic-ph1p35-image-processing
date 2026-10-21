`timescale 1ns/1ps

module tb_frame_tag_monitor;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg input_valid = 1'b0;
  reg [15:0] input_id = 0;
  reg result_valid = 1'b0;
  reg [15:0] result_id = 0;
  reg video_valid = 1'b0;
  reg [15:0] video_id = 0;
  wire pending;
  wire [15:0] active_id;
  wire frame_gap, result_match, video_match, tag_mismatch, timeout;

  always #5 clk = ~clk;

  frame_tag_monitor #(.TIMEOUT_CYCLES(3)) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_input_valid(input_valid),
    .I_input_frame_id(input_id), .I_result_valid(result_valid),
    .I_result_frame_id(result_id), .I_video_valid(video_valid),
    .I_video_frame_id(video_id), .O_pending(pending),
    .O_active_frame_id(active_id), .O_frame_gap(frame_gap),
    .O_result_match(result_match), .O_video_match(video_match),
    .O_tag_mismatch(tag_mismatch), .O_timeout(timeout)
  );

  task clear_inputs;
    begin
      input_valid = 1'b0; result_valid = 1'b0; video_valid = 1'b0;
    end
  endtask

  task input_frame;
    input [15:0] id;
    begin
      @(negedge clk); clear_inputs; input_id = id; input_valid = 1'b1;
      @(posedge clk); #1;
      input_valid = 1'b0;
    end
  endtask

  task result_frame;
    input [15:0] id;
    begin
      @(negedge clk); clear_inputs; result_id = id; result_valid = 1'b1;
      @(posedge clk); #1;
      result_valid = 1'b0;
    end
  endtask

  task video_frame;
    input [15:0] id;
    begin
      @(negedge clk); clear_inputs; video_id = id; video_valid = 1'b1;
      @(posedge clk); #1;
      video_valid = 1'b0;
    end
  endtask

  task idle_cycle;
    begin
      @(negedge clk); clear_inputs;
      @(posedge clk); #1;
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    input_frame(16'd10);
    if (!pending || active_id != 10 || frame_gap || tag_mismatch)
      $fatal(1, "first input tag mismatch");
    result_frame(16'd10);
    if (!result_match || tag_mismatch)
      $fatal(1, "matching result tag failed");
    video_frame(16'd10);
    if (!video_match || tag_mismatch || pending)
      $fatal(1, "matching video tag failed");

    input_frame(16'd12);
    if (!frame_gap || !pending)
      $fatal(1, "input frame gap not reported");
    result_frame(16'd11);
    if (!tag_mismatch || result_match)
      $fatal(1, "result tag mismatch not reported");
    video_frame(16'd12);
    if (!video_match || tag_mismatch)
      $fatal(1, "current video tag should match");

    input_frame(16'd20);
    idle_cycle;
    idle_cycle;
    idle_cycle;
    if (!timeout || pending)
      $fatal(1, "timeout did not clear pending tag");

    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    input_frame(16'd30);
    if (frame_gap || !pending)
      $fatal(1, "reset did not restore first-frame semantics");

    $display("TB_FRAME_TAG_MONITOR_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in frame tag monitor testbench");
  end
endmodule
