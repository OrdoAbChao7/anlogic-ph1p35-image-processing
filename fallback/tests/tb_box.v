`timescale 1ns/1ps
module tb_box;
reg clk=0,rst=0,v=0,u=0;wire ov,ol,ou;wire [95:0] od;
box_draw_96 #(.IMG_WIDTH(8),.IMG_HEIGHT(2)) dut(clk,rst,v,1'b0,u,96'd0,11'd0,11'd0,11'd3,11'd0,1'b1,ov,ol,ou,od);
always #5 clk=~clk;
task beat;input vv,uu;input [95:0] expected;begin @(negedge clk);v=vv;u=uu;@(posedge clk);#1;if(ov!==vv||ou!==uu||(vv&&od!==expected))begin $display("FAIL box v=%b sof=%b data=%h expected=%h",ov,ou,od,expected);$fatal(1);end end endtask
initial begin repeat(2)@(negedge clk);rst=1;
beat(1,1,{4{24'hffff00}});beat(1,0,0);
beat(0,1,0);beat(1,0,{4{24'hffff00}});beat(1,0,0);
$display("PASS box coordinates and SOF pixel alignment");$finish;end
endmodule
