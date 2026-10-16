`timescale 1ns/1ps
module tb_pack_line;
reg clk=0,rst=0,v=0,u=0;wire sof,ov,last;wire [127:0] od;
data_96bit_to_128bit dut(clk,rst,u,v,96'h123456123456123456123456,sof,ov,od,last);
always #5 clk=~clk;
integer i,words=0,line_ends=0;
always @(posedge clk)begin #1;if(rst)begin
if(ov)begin words=words+1;if(last!==((words%240)==0))$fatal(1,"packed TLAST not aligned with word%0d",words);end
else if(last)$fatal(1,"TLAST without valid");
if(last)line_ends=line_ends+1;
end end
initial begin repeat(2)@(negedge clk);rst=1;u=1;v=1;
for(i=0;i<640;i=i+1)begin @(negedge clk);u=0;end
v=0;repeat(2)@(negedge clk);
if(words!=480||line_ends!=2)$fatal(1,"packed line count mismatch %0d %0d",words,line_ends);
$display("PASS 2x1280 pixels produce 2x240 aligned 128-bit words");$finish;end endmodule
