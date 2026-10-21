`timescale 1ns/1ps

module tb_axis_gain_rgb96;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg [95:0] tdata = 96'd0;
  reg tlast = 1'b0;
  reg tuser = 1'b0;
  reg tvalid = 1'b0;
  reg downstream_ready = 1'b1;
  reg [9:0] gain_r = 10'd256;
  reg [9:0] gain_g = 10'd256;
  reg [9:0] gain_b = 10'd256;
  wire source_ready;
  wire [95:0] out_data;
  wire out_last, out_user, out_valid;

  always #5 clk = ~clk;

  axis_gain_rgb96 dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_tdata(tdata), .I_tlast(tlast),
    .I_tuser(tuser), .I_tvalid(tvalid), .I_tready(downstream_ready),
    .I_gain_r_q8_8(gain_r), .I_gain_g_q8_8(gain_g), .I_gain_b_q8_8(gain_b),
    .O_tready(source_ready), .O_tdata(out_data), .O_tlast(out_last),
    .O_tuser(out_user), .O_tvalid(out_valid)
  );

  task push_beat;
    input [95:0] value;
    input [95:0] expected_scaled;
    input last_value;
    input user_value;
    begin
      @(negedge clk);
      tdata = value;
      tlast = last_value;
      tuser = user_value;
      tvalid = 1'b1;
      while (!source_ready) @(negedge clk);
      @(posedge clk); #1;
      if (out_valid)
        $fatal(1, "gain output appeared before the product pipeline latency");
      @(negedge clk);
      tvalid = 1'b0;
      tlast = 1'b0;
      tuser = 1'b0;
      @(posedge clk); #1;
      if (!out_valid || out_data === 96'dx)
        $fatal(1, "gain product stage did not produce a valid beat");
      if (out_last !== last_value || out_user !== user_value)
        $fatal(1, "AXI sidebands were not delayed with pixel data");
      if (out_data !== expected_scaled)
        $fatal(1, "gain/rounding mismatch: got %h expected %h", out_data, expected_scaled);
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    gain_r = 10'd384;
    gain_g = 10'd256;
    gain_b = 10'd128;
    push_beat({4{24'h64c8fa}}, {4{24'h96c87d}}, 1'b0, 1'b1);

    // Allow the frame-start snapshot to settle, then prove later controller
    // changes cannot alter pixels in the current frame.
    @(posedge clk); #1;
    gain_r = 10'd512;
    gain_g = 10'd512;
    gain_b = 10'd512;
    push_beat({4{24'h01c8fa}}, {4{24'h02c87d}}, 1'b1, 1'b0);

    push_beat({4{24'hc8c8fa}}, {4{24'hffc87d}}, 1'b1, 1'b0);

    // Hold one output while downstream is stalled and verify the registered
    // pixel and sidebands remain stable until the transfer is accepted.
    downstream_ready = 1'b0;
    if (!out_valid || out_data !== {4{24'hffc87d}})
      $fatal(1, "output did not hold the preceding beat under backpressure");
    @(negedge clk);
    tdata = {4{24'h102030}};
    tlast = 1'b0;
    tuser = 1'b0;
    tvalid = 1'b1;
    if (!out_valid || !source_ready)
      $fatal(1, "elastic input slot did not accept one beat under output stall");
    @(posedge clk); #1;
    if (!out_valid || source_ready)
      $fatal(1, "backpressure was not propagated after the elastic input slot filled");
    if (out_data !== {4{24'hffc87d}})
      $fatal(1, "stalled payload changed before acceptance: %h", out_data);
    @(negedge clk);
    tvalid = 1'b0;
    downstream_ready = 1'b1;
    @(posedge clk); #1;
    if (!out_valid || out_data !== {4{24'h182018}} || out_last || out_user)
      $fatal(1, "queued input was not accepted after ready returned: %h", out_data);
    @(posedge clk); #1;
    if (out_valid)
      $fatal(1, "final beat was not consumed after ready returned");

    $display("TB_AXIS_GAIN_RGB96_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in AWB gain stream testbench");
  end
endmodule
