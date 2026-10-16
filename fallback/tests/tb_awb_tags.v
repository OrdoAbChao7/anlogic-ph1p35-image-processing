`timescale 1ns/1ps
module tb_awb_tags;
reg clk=0,rst=0,v=0,u=0;wire ov,ou,ol,ready;wire [95:0] od;
awb #(.IMG_WIDTH(256),.IMG_HEIGHT(3)) dut(clk,rst,1'b0,u,{4{24'h282828}},v,ready,ol,ou,od,ov,1'b1);
always #5 clk=~clk;
integer f,r,i,words=0,starts=0;
always @(posedge clk)begin #1;if(rst)begin
 if(ou)begin if(!ov||words%192!=0)$fatal(1,"AWB SOF not on first frame group words=%0d valid=%b",words,ov);starts=starts+1;end
 if(ov)words=words+1;
end end
initial begin repeat(3)@(negedge clk);rst=1;
for(f=0;f<2;f=f+1)begin
u=1;@(negedge clk);u=0;
for(r=0;r<3;r=r+1)begin v=1;repeat(64)@(negedge clk);v=0;repeat(80)@(negedge clk);end
end
repeat(80)@(negedge clk);
if(words!=384||starts!=2)$fatal(1,"AWB count words=%0d starts=%0d",words,starts);
$display("PASS AWB first-valid SOF alignment: 2 frames x192 groups (dependency models)");$finish;end endmodule
