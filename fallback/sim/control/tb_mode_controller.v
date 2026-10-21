`timescale 1ns/1ps
module tb_mode_controller;
  reg clk=0, rst_n=0, key_edge_n=1, key_cartoon_n=1, frame_start=0;
  wire [1:0] mode;
  wire edge_req, cartoon_req;
  mode_controller #(.DEBOUNCE_CYCLES(3)) dut(
    .I_clk(clk), .I_rst_n(rst_n),
    .I_key_edge_n(key_edge_n), .I_key_cartoon_n(key_cartoon_n),
    .I_frame_start(frame_start), .O_mode(mode),
    .O_edge_req(edge_req), .O_cartoon_req(cartoon_req)
  );
  always #5 clk=~clk;
  task tick;
    begin @(negedge clk); end
  endtask
  task frame;
    begin frame_start=1; tick; frame_start=0; end
  endtask
  initial begin
    repeat(2) tick;
    rst_n=1;
    if(mode!==0) $fatal(1,"reset mode");
    // A short bounce must not select Sobel.
    key_edge_n=0; tick; key_edge_n=1; repeat(3) tick;
    frame;
    if(mode!==0) $fatal(1,"bounce changed mode");
    // One debounced click requests Sobel but commits only on a frame edge.
    key_edge_n=0; repeat(5) tick; key_edge_n=1; repeat(5) tick;
    if(mode!==0) $fatal(1,"changed before frame");
    frame;
    if(mode!==1 || !edge_req || cartoon_req) $fatal(1,"Sobel frame commit");
    // A held key must not generate another click.
    repeat(8) tick; frame;
    if(mode!==1) $fatal(1,"held key retriggered");
    // The second click advances to Cartoon, and the third wraps to Original.
    key_edge_n=0; repeat(5) tick; key_edge_n=1; repeat(5) tick; frame;
    if(mode!==2 || edge_req || !cartoon_req) $fatal(1,"Cartoon frame commit");
    key_edge_n=0; repeat(5) tick; key_edge_n=1; repeat(5) tick; frame;
    if(mode!==0 || edge_req || cartoon_req) $fatal(1,"Original frame commit");
    // The reserved second key does not change the display mode.
    key_cartoon_n=0; repeat(5) tick; key_cartoon_n=1; repeat(5) tick; frame;
    if(mode!==0) $fatal(1,"reserved key changed mode");
    $display("TB_MODE_CONTROLLER_PASS");
    $finish;
  end
endmodule
