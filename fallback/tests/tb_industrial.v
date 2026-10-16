`timescale 1ns/1ps
module tb_industrial;
reg clk=0,rst=0,v=0,u=0,last=0; reg [95:0] data=0;
wire [10:0] xmin,ymin,xmax,ymax;wire [19:0] area;wire valid;
color_detect_96 #(.IMG_WIDTH(8),.IMG_HEIGHT(2)) dut(clk,rst,v,last,u,data,xmin,ymin,xmax,ymax,area,valid);
always #5 clk=~clk;
task beat; input vv,uu,ll;input [95:0] dd;begin @(negedge clk);v=vv;u=uu;last=ll;data=dd;@(posedge clk);#1;end endtask
task drain;begin repeat(4)beat(0,0,0,0);end endtask
task expect_frame;input [19:0] a;input [10:0] x0,y0,x1,y1;begin if(area!==a||xmin!==x0||ymin!==y0||xmax!==x1||ymax!==y1||valid!==(a!=0))begin $display("FAIL area=%0d bbox=%0d,%0d,%0d,%0d valid=%b expected=%0d",area,xmin,ymin,xmax,ymax,valid,a);$fatal(1);end end endtask
initial begin
repeat(2)@(negedge clk);rst=1;
// Simultaneous SOF and first valid group, signed-boundary target in lane0.
beat(1,1,0,{24'h802828,72'd0});beat(1,0,1,0);beat(0,0,0,0);beat(1,0,0,0);beat(1,0,1,{72'd0,24'h640000});drain;
expect_frame(2,0,0,7,1);
// Independent SOF; preserve published result while the next frame accumulates.
beat(0,1,0,0);beat(1,0,0,{4{24'h640000}});drain;expect_frame(2,0,0,7,1);
beat(1,0,1,{4{24'h640000}});beat(1,0,0,{4{24'h640000}});beat(1,0,1,{4{24'h640000}});drain;expect_frame(16,0,0,7,1);
// A complete empty frame removes the previous detection.
beat(0,1,0,0);repeat(4)beat(1,0,0,0);drain;expect_frame(0,0,0,0,0);
// Partial frame followed by SOF must not leak the partial target.
beat(1,1,0,{4{24'h640000}});beat(1,1,0,0);repeat(3)beat(1,0,0,0);drain;expect_frame(0,0,0,0,0);
$display("PASS industrial published-frame contract");$finish;end
endmodule
