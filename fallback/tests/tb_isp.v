`timescale 1ns/1ps
module tb_isp;
reg clk=0,rst=0,v=0,u=0,l=0,mode=0;reg [39:0] d=0;
wire [127:0] od;wire ov,ou,ol,ready;wire [10:0] x0,y0,x1,y1;wire [19:0] area;wire valid;
isp_top dut(clk,rst,l,u,d,v,10'd0,1'b1,od,ol,ou,ov,ready,mode,x0,y0,x1,y1,area,valid);
always #5 clk=~clk;
integer i,f,words=0,starts=0,j,pix,x,y,ch,frame;reg [7:0] expected;
always @(posedge clk)begin #1;if(rst)begin
 if(ou)starts=starts+1;
 if(ov)begin
 frame=words/172800;
 for(j=0;j<16;j=j+1)begin
 pix=((words%172800)*16+j)/3;ch=((words%172800)*16+j)%3;x=pix%1280;y=pix/1280;
 expected=0;
 if(frame==0&&ch==0)expected=100;
 if(frame==1&&(x==0||x==1279||y==0||y==719)&&ch<2)expected=255;
 if(od[127-j*8 -:8]!==expected)$fatal(1,"ISP frame%0d word%0d byte%0d x%0d y%0d got%h expected%h",frame,words,j,x,y,od[127-j*8 -:8],expected);
 end
 if(ol!==((words%240)==239))$fatal(1,"ISP output TLAST misaligned");
 words=words+1;
 end
end end
initial begin repeat(3)@(negedge clk);rst=1;
for(f=0;f<3;f=f+1)begin
 if(f==2)mode=1;repeat(5)@(negedge clk);
 for(i=0;i<230400;i=i+1)begin v=1;u=(i==0);l=((i%320)==319);d=(f==0)?40'h0000640000:40'd0;@(negedge clk);end
 v=0;u=0;l=0;repeat(10)@(negedge clk);
end
repeat(10)@(negedge clk);
if(words!=518400||starts!=3||valid!==0)$fatal(1,"ISP word/SOF/empty mismatch words=%0d starts=%0d",words,starts);
$display("PASS ISP full-size 3-frame routing, mode switch, overlay and packing (upstream models)");$finish;end endmodule
