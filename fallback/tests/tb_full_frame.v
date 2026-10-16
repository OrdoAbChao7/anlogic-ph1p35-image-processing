`timescale 1ns/1ps
module tb_full_frame;
reg clk=0,rst=0,v=0,u=0;wire [10:0] xmin,ymin,xmax,ymax;wire [19:0] area;wire valid;
color_detect_96 dut(clk,rst,v,1'b0,u,{4{24'h640000}},xmin,ymin,xmax,ymax,area,valid);
always #5 clk=~clk;
integer i;
initial begin repeat(2)@(negedge clk);rst=1;v=1;u=1;
for(i=0;i<230400;i=i+1)begin @(posedge clk);#1;@(negedge clk);u=0;end
v=0;repeat(3)@(posedge clk);#1;
if(area!==20'd921600||xmin!==0||ymin!==0||xmax!==1279||ymax!==719||valid!==1)$fatal(1,"full frame mismatch area=%0d",area);
$display("PASS full frame 921600 pixels bbox 0,0,1279,719");$finish;end endmodule
