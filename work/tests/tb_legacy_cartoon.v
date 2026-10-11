`timescale 1ns/1ps
module tb_legacy_cartoon;
  reg clk=0;
  always #5 clk=~clk;
  cartoon_chan #(.IMG_WIDTH(16),.IMG_HEIGHT(8)) dut(
    .clk(clk),.rst_n(1'b0),.valid(1'b0),.tuser(1'b0),.tlast(1'b0),
    .c0(8'd0),.c1(8'd0),.c2(8'd0),.c3(8'd0),
    .o0(),.o1(),.o2(),.o3(),.o_valid(),.o_tlast(),.o_tuser());
  initial begin
    #1;
    if(dut.udiv(16'd100,16'd10)!==16'd10)
      $fatal(1,"Legacy division: 100/10 expected 10, actual %0d",dut.udiv(16'd100,16'd10));
    $finish;
  end
endmodule
