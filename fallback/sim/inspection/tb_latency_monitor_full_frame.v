`timescale 1ns/1ps

module tb_latency_monitor_full_frame;
  localparam integer FRAME_CYCLES = 1280 * 720;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg input_valid = 1'b0;
  reg [15:0] input_frame_id = 16'd0;
  reg result_valid = 1'b0;
  reg [15:0] result_frame_id = 16'd0;
  wire proc_valid;
  wire [31:0] proc_cycles;
  wire frame_pending;
  wire frame_result_match;
  wire frame_tag_mismatch;
  wire frame_timeout;
  wire latency_tag_mismatch;
  wire latency_timeout;

  always #5 clk = ~clk;

  latency_monitor u_latency_monitor (
    .I_clk(clk), .I_rst_n(rst_n),
    .I_input_valid(input_valid), .I_input_frame_id(input_frame_id),
    .I_result_valid(result_valid), .I_result_frame_id(result_frame_id),
    .I_video_valid(1'b0), .I_video_frame_id(16'd0),
    .O_proc_valid(proc_valid), .O_proc_cycles(proc_cycles),
    .O_video_valid(), .O_video_cycles(),
    .O_e2e_valid(), .O_e2e_cycles(), .O_frame_gap(),
    .O_tag_mismatch(latency_tag_mismatch), .O_timeout(latency_timeout)
  );

  frame_tag_monitor u_frame_tag_monitor (
    .I_clk(clk), .I_rst_n(rst_n),
    .I_input_valid(input_valid), .I_input_frame_id(input_frame_id),
    .I_result_valid(result_valid), .I_result_frame_id(result_frame_id),
    .I_video_valid(1'b0), .I_video_frame_id(16'd0),
    .O_pending(frame_pending), .O_active_frame_id(), .O_frame_gap(),
    .O_result_match(frame_result_match), .O_video_match(),
    .O_tag_mismatch(frame_tag_mismatch), .O_timeout(frame_timeout)
  );

  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1'b1;

    @(negedge clk);
    input_frame_id = 16'd42;
    input_valid = 1'b1;
    @(negedge clk);
    input_valid = 1'b0;

    repeat (FRAME_CYCLES) @(posedge clk);
    @(negedge clk);
    result_frame_id = 16'd42;
    result_valid = 1'b1;
    @(posedge clk);
    #1;
    if (!proc_valid || proc_cycles <= 32'd1024 || latency_tag_mismatch || latency_timeout)
      $fatal(1, "full-raster PROC result lost: valid=%b cycles=%0d mismatch=%b timeout=%b",
        proc_valid, proc_cycles, latency_tag_mismatch, latency_timeout);
    if (!frame_result_match || frame_tag_mismatch || frame_timeout || !frame_pending)
      $fatal(1, "full-raster frame tag lost: match=%b mismatch=%b timeout=%b pending=%b",
        frame_result_match, frame_tag_mismatch, frame_timeout, frame_pending);

    $display("TB_LATENCY_MONITOR_FULL_FRAME_PASS cycles=%0d", proc_cycles);
    $finish;
  end

  initial begin
    #30000000;
    $fatal(1, "timeout in full-frame latency monitor testbench");
  end
endmodule
