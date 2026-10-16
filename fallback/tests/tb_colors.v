`timescale 1ns/1ps
module tb_colors;
reg clk=0,rst=0,v=0,u=0;reg [95:0] data=0;
wire [10:0] xmin,ymin,xmax,ymax;wire [19:0] area;wire valid;
color_detect_96 #(.IMG_WIDTH(4),.IMG_HEIGHT(1)) dut(clk,rst,v,1'b0,u,data,xmin,ymin,xmax,ymax,area,valid);
always #5 clk=~clk;
integer i,j,r,g,b,cb,cr,hits,x0,x1,seed;
initial begin seed=32'h24681357;repeat(2)@(negedge clk);rst=1;
for(i=0;i<4096;i=i+1)begin
hits=0;x0=3;x1=0;
for(j=0;j<4;j=j+1)begin
r=($random(seed)&255);g=($random(seed)&255);b=($random(seed)&255);
if(i<256)begin r=i;g=40;b=40;end
cb=(512*b-173*r-339*g+131072)/1024;
cr=(512*r-429*g-83*b+131072)/1024;
data[95-j*24 -:24]={r[7:0],g[7:0],b[7:0]};
if(cb>85&&cb<125&&cr>135&&cr<200)begin hits=hits+1;if(j<x0)x0=j;if(j>x1)x1=j;end
end
v=1;u=1;@(posedge clk);#1;@(negedge clk);v=0;u=0;@(posedge clk);#1;
if(area!==hits||valid!==(hits!=0)||(hits!=0&&(xmin!==x0||xmax!==x1)))$fatal(1,"color batch %0d mismatch area=%0d expected=%0d",i,area,hits);
@(negedge clk);
end
$display("PASS 16384 RGB pixels against unsigned fixed-point formula");$finish;end endmodule
