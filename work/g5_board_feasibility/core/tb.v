module tb;
reg clk=0;always #5 clk=~clk;
reg rst,ce,iv;reg [71:0] a,b;reg signed [31:0] bias;
wire ov;wire signed [7:0] q;reg ev;reg [7:0] eq;
integer f,n,t=0,checked=0;
int8_core dut(clk,rst,ce,iv,a,b,bias,ov,q);
initial begin
f=$fopen("vectors.txt","r");
while(!$feof(f)) begin
 @(negedge clk);n=$fscanf(f,"%d %d %d %h %h %h %d %h\n",rst,ce,iv,a,b,bias,ev,eq);
 if(n==8) begin
 @(posedge clk);#1;
 if(ov!==ev || (ev && q!==eq) || (rst && q!==0)) begin
 $display("FAIL cycle=%0d ov=%d ev=%d q=%d eq=%d",t,ov,ev,q,$signed(eq));$fatal(1);
 end
 t=t+1;if(ev)checked=checked+1;
 end
end
$display("PASS cycles=%0d valid_or_held_checks=%0d reset/stall/continuous/fullscale",t,checked);$finish;
end
endmodule
