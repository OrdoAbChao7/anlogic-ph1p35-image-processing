`timescale 1ns/1ps
module tb_pack;
reg clk=0,rst=0,v=0,u=0;reg [95:0] d=0;wire fsout,ov;wire [127:0] od;
data_96bit_to_128bit dut(clk,rst,u,v,d,fsout,ov,od);
always #5 clk=~clk;
task beat;input vv,uu;input [95:0] dd;begin @(negedge clk);v=vv;u=uu;d=dd;@(posedge clk);#1;end endtask
initial begin repeat(2)@(negedge clk);rst=1;beat(0,1,0);
beat(1,0,96'h0102030405060708090a0b0c);beat(0,0,0);beat(1,0,96'h0d0e0f101112131415161718);
if(ov!==1||od!==128'h0102030405060708090a0b0c0d0e0f10)$fatal(1,"packer loses partial data across valid pause");
beat(1,0,96'h191a1b1c1d1e1f2021222324);if(ov!==1||od!==128'h1112131415161718191a1b1c1d1e1f20)$fatal(1,"packer word2 mismatch");
beat(1,0,96'h25262728292a2b2c2d2e2f30);if(ov!==1||od!==128'h2122232425262728292a2b2c2d2e2f30)$fatal(1,"packer word3 mismatch");
$display("PASS packer reset, stalls, byte ordering");$finish;end endmodule
