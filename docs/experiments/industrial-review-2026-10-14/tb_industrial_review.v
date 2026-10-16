
`timescale 1ns/1ps
module tb;
reg clk=0,rst=0,v=0,u=0,last=0;reg [95:0] data=0;
wire [10:0] xmin,ymin,xmax,ymax;wire [18:0] area;wire valid;
integer failures=0,i;
color_detect_96 dut(clk,rst,v,last,u,data,xmin,ymin,xmax,ymax,area,valid);
always #5 clk=~clk;
task tick;input vv,uu;input [23:0] rgb;begin @(negedge clk);v=vv;u=uu;data={4{rgb}};@(posedge clk);#1;end endtask
task reset;begin @(negedge clk);rst=0;v=0;u=0;@(posedge clk);#1;@(negedge clk);rst=1;end endtask
task check;input ok;input [511:0] label;begin if(ok)$display("PASS %0s",label);else begin $display("FAIL %0s: area=%0d xmin=%0d xmax=%0d valid=%0d",label,area,xmin,xmax,valid);failures=failures+1;end end endtask
initial begin
reset;tick(0,1,0);tick(1,0,24'h640000);check(area==4 && xmin==0 && xmax==3,"four-pixel accumulation and xmin");
reset;tick(0,1,0);tick(1,0,24'h7f2828);$display("COLOR R127 cb=%0d cr=%0d t=%0d",dut.cb0[17:10],dut.cr0[17:10],dut.t0);check(dut.t0==1,"R127 G40 B40 inside fixed threshold");
tick(1,0,24'h802828);$display("COLOR R128 cb=%0d cr=%0d t=%0d",dut.cb0[17:10],dut.cr0[17:10],dut.t0);check(dut.t0==1,"R128 G40 B40 inside fixed threshold");
reset;tick(0,1,0);for(i=0;i<230400;i=i+1)tick(1,0,24'h640000);check(area==921600,"full 1280x720 foreground area");$display("FRAME BEFORE area=%0d",area);tick(0,1,0);check(area==921600,"previous frame preserved at next SOF");tick(0,0,0);check(valid==0,"valid_frame pulse clears after SOF");
reset;tick(0,1,0);tick(0,0,0);check(valid==0,"empty scene must not remain target-valid");
reset;tick(1,1,24'h640000);check(area==4,"SOF coincident with valid consumes first pixel group");
$display("TOTAL_FAILURES=%0d",failures);if(failures)$fatal(1,"audit vectors found defects");$finish;
end
endmodule
