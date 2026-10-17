`timescale 1ns/1ps
module tb_video_cartoon_region_fill;
  parameter W=32, H=12;
  reg clk=0;
  always #5 clk=~clk;
  reg rst_n=0, vs=0, hs=0, de=0, edge_req=0, toon_req=0, keep=0;
  reg [23:0] rgb=0, overlay=0;
  wire ovs,ohs,ode;
  wire [23:0] out_rgb;
  wire [1:0] mode;
  video_cartoon #(.WIDTH(W),.HEIGHT(H)) dut(
    .clk(clk),.rst_n(rst_n),.i_vs(vs),.i_hs(hs),.i_de(de),.i_rgb(rgb),
    .i_edge_req(edge_req),.i_toon_req(toon_req),.i_overlay(keep),.i_overlay_rgb(overlay),
    .o_vs(ovs),.o_hs(ohs),.o_de(ode),.o_rgb(out_rgb),.o_mode(mode));
  reg [54:0] stimulus;
  reg [28:0] expected;
  reg [4095:0] filename;
  integer fd, n, cycle=0;
  initial begin
    if(!$value$plusargs("VECTORS=%s",filename)) $fatal(1,"Missing VECTORS");
    fd=$fopen(filename,"r");
    if(fd==0) $fatal(1,"Cannot open vectors");
    while(!$feof(fd)) begin
      n=$fscanf(fd,"%h %h\n",stimulus,expected);
      if(n!=2) $fatal(1,"Malformed vector at %0d",cycle);
      @(negedge clk);
      {rst_n,vs,hs,de,edge_req,toon_req,keep,rgb,overlay}=stimulus;
      @(posedge clk); #1;
      if({ovs,ohs,ode,mode,out_rgb} !== expected)
        $fatal(1,"Cycle %0d got %h expected %h; input de=%b rgb=%h",cycle,
               {ovs,ohs,ode,mode,out_rgb},expected,de,rgb);
      cycle=cycle+1;
    end
    $display("PASS %0d cycles, %0dx%0d, RGB/DE/HS/VS/mode matched",cycle,W,H);
    $fclose(fd);
    $finish;
  end
endmodule
