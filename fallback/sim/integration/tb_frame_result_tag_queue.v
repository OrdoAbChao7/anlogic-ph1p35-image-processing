`timescale 1ns/1ps

module tb_frame_result_tag_queue;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg push = 1'b0;
  reg pop = 1'b0;
  reg [15:0] push_frame_id = 16'd0;
  wire [15:0] result_frame_id;
  wire result_tag_valid;
  wire tag_fault;

  always #5 clk = ~clk;

  frame_result_tag_queue #(.FRAME_ID_WIDTH(16), .DEPTH(2)) dut (
    .I_clk(clk), .I_rst_n(rst_n),
    .I_push(push), .I_push_frame_id(push_frame_id), .I_pop(pop),
    .O_result_frame_id(result_frame_id),
    .O_result_tag_valid(result_tag_valid), .O_tag_fault(tag_fault)
  );

  task enqueue;
    input [15:0] id;
    begin
      @(negedge clk);
      push_frame_id = id;
      push = 1'b1;
      @(posedge clk);
      #1 push = 1'b0;
    end
  endtask

  task dequeue_expect;
    input [15:0] id;
    begin
      @(negedge clk);
      pop = 1'b1;
      #1;
      if (!result_tag_valid || result_frame_id != id)
        $fatal(1, "result tag mismatch got_valid=%b got_id=%0d expected=%0d",
               result_tag_valid, result_frame_id, id);
      @(posedge clk);
      #1 pop = 1'b0;
    end
  endtask

  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    enqueue(16'd41);
    enqueue(16'd42);
    dequeue_expect(16'd41);
    dequeue_expect(16'd42);
    if (tag_fault)
      $fatal(1, "valid in-order tags unexpectedly faulted");

    enqueue(16'd43);
    enqueue(16'd44);
    enqueue(16'd45);
    if (!tag_fault || result_tag_valid)
      $fatal(1, "tag overflow must fail closed");
    $display("TB_FRAME_RESULT_TAG_QUEUE_PASS");
    $finish;
  end
endmodule
