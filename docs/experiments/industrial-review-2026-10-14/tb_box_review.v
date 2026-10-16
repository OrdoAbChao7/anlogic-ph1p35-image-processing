`timescale 1ns/1ps
module tb_box; reg clk=0,rst=0,v=0,u=0;wire ov,ol,ou;wire [95:0] od;
box_draw_96 dut(clk,rst,v,1'b0,u,96'd0,11'd0,11'd0,11'd3,11'd0,1'b1,ov,ol,ou,od);
always #5 clk=~clk;
initial begin #2; @(negedge clk);rst=1;v=1;u=1;@(posedge clk);#1;$display("SOF_WITH_VALID next_x_grp=%0d expected=1",dut.x_grp);@(negedge clk);u=0;@(posedge clk);#1;@(negedge clk);v=0;u=1;@(posedge clk);#1;$display("SOF_WITHOUT_VALID next_x_grp=%0d expected=0",dut.x_grp);if(dut.x_grp!=0)$fatal(1,"frame coordinate reset defect");$finish;end endmodule
