`timescale 1ns/1ps

module tb_industrial_osd_bcd;
  reg clk = 1'b0;
  always #5 clk = ~clk;

  reg rst_n = 1'b0;
  reg vsync = 1'b0;
  reg hsync = 1'b0;
  reg de = 1'b0;
  reg [23:0] rgb = 24'h0;
  wire ovs, ohs, ode;
  wire [23:0] out_rgb;

  industrial_osd_overlay #(
    .IMG_WIDTH(16), .IMG_HEIGHT(8), .LOGO_W(0), .LOGO_H(0)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vsync), .I_hsync(hsync),
    .I_de(de), .I_rgb(rgb), .I_mode(2'd0), .I_detected(1'b0),
    .I_pass(1'b0), .I_ng(1'b0), .I_invalid(1'b0),
    .I_width(11'd120), .I_height(11'd80),
    .O_vsync(ovs), .O_hsync(ohs), .O_de(ode), .O_rgb(out_rgb)
  );

  task tick;
    begin @(posedge clk); #1; end
  endtask

  task frame_start;
    begin
      vsync = 1'b1;
      tick;
      vsync = 1'b0;
      tick;
    end
  endtask

  initial begin
    repeat (2) tick;
    rst_n = 1'b1;

    frame_start;
    if (dut.frame_digits !== 40'h0000000001)
      $fatal(1, "frame 1 BCD mismatch: %h", dut.frame_digits);
    if (dut.width_digits !== 16'h0120 || dut.height_digits !== 16'h0080)
      $fatal(1, "dimension BCD mismatch: W=%h H=%h", dut.width_digits, dut.height_digits);

    frame_start;
    if (dut.frame_digits !== 40'h0000000002)
      $fatal(1, "frame 2 BCD mismatch: %h", dut.frame_digits);

    // Exercise carry across the least-significant digit without a full raster.
    dut.frame_digits = 40'h0000000009;
    frame_start;
    if (dut.frame_digits !== 40'h0000000010)
      $fatal(1, "BCD carry mismatch: %h", dut.frame_digits);

    $display("TB_INDUSTRIAL_OSD_BCD_PASS");
    $finish;
  end
endmodule
