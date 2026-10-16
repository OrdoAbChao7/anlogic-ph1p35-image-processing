`timescale 1ns/1ps
module tb_pipeline;
reg clk=0,rst=0,v=0,u=0,l=0;reg [95:0] d=0;
wire ov,ou,ol;wire [95:0] od;wire [10:0] x0,y0,x1,y1;wire [19:0] area;wire valid;
industrial_overlay_96 #(.IMG_WIDTH(8),.IMG_HEIGHT(2)) dut(clk,rst,v,u,l,d,v,u,l,d,ov,ou,ol,od,x0,y0,x1,y1,area,valid);
always #5 clk=~clk;
integer i,count=0;reg [95:0] expected;
always @(posedge clk)begin #2;if(rst&&ov)begin
if(count<4)expected={4{24'h640000}};else if(count<8)expected={4{24'hffff00}};else expected=0;
if(count>=12||od!==expected||ou!==((count%4)==0)||ol!==((count%2)==1))$fatal(1,"pipeline beat %0d data=%h expected=%h sof=%b last=%b",count,od,expected,ou,ol);
count=count+1;end end
initial begin repeat(2)@(negedge clk);rst=1;
for(i=0;i<12;i=i+1)begin v=1;u=((i%4)==0);l=((i%2)==1);d=i<4?{4{24'h640000}}:96'd0;@(negedge clk);end
v=0;u=0;l=0;repeat(5)@(negedge clk);
if(count!=12||area!==0||valid!==0)$fatal(1,"pipeline count/empty-result mismatch");
$display("PASS back-to-back frames: raw, previous-frame box, empty-frame removal");$finish;end endmodule
