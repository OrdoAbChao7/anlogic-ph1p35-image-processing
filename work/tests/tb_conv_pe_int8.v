`timescale 1ns / 1ps

module tb_conv_pe_int8;

  reg        clk;
  reg        rst_n;
  reg        clr_acc;
  reg        valid_in;
  reg signed [7:0]  act_in;
  reg signed [7:0]  w_in;
  reg signed [31:0] bias_in;
  reg [3:0]  shift_val;

  wire       valid_out;
  wire signed [7:0] act_out;

  conv_pe_int8 u_pe (
    .clk(clk),
    .rst_n(rst_n),
    .clr_acc(clr_acc),
    .valid_in(valid_in),
    .act_in(act_in),
    .w_in(w_in),
    .bias_in(bias_in),
    .shift_val(shift_val),
    .valid_out(valid_out),
    .act_out(act_out)
  );

  always #5 clk = ~clk; // 100MHz

  integer i;
  initial begin
    clk = 0;
    rst_n = 0;
    clr_acc = 0;
    valid_in = 0;
    act_in = 0;
    w_in = 0;
    bias_in = 32'd256;
    shift_val = 4'd8; // shift right by 8

    #20 rst_n = 1;

    // First cycle of dot product
    @(posedge clk);
    clr_acc = 1;
    valid_in = 1;
    act_in = 8'sd10;
    w_in = 8'sd5; // 10 * 5 = 50

    @(posedge clk);
    clr_acc = 0;
    act_in = 8'sd10;
    w_in = 8'sd10; // 10 * 10 = 100

    @(posedge clk);
    act_in = 8'sd5;
    w_in = 8'sd6; // 5 * 6 = 30
    // Expected Sum = Bias(256) + 50 + 100 + 30 = 436.
    // Scaled >> 8 = 436 >> 8 = 1.

    @(posedge clk);
    valid_in = 0;

    @(posedge clk);
    clr_acc = 1; // trigger output latch
    @(posedge clk);
    clr_acc = 0;

    @(posedge clk);
    $display("Test PE Output: act_out = %d, valid_out = %b", act_out, valid_out);
    if (act_out == 8'sd1) begin
      $display("PE SIMULATION PASS: Bit-exact Match with Fixed-Point Arithmetic!");
    end else begin
      $display("PE SIMULATION FAILED: Mismatch!");
      $fatal(1);
    end

    #50 $finish;
  end

endmodule
