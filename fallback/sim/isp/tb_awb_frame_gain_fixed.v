`timescale 1ns/1ps

module tb_awb_frame_gain_fixed;
  localparam [31:0] FRAME_PIXELS = 32'd921600;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg stats_valid = 1'b0;
  reg [31:0] sum_r = 0, sum_g = 0, sum_b = 0, pixel_count = 0;
  reg [7:0] mean_luma = 0;
  wire [15:0] gain_r, gain_g, gain_b;
  wire gain_update_valid, scene_protected;

  always #5 clk = ~clk;

  awb_frame_gain_controller #(
    .MAX_STEP(8), .SCENE_JUMP(40),
    .USE_FIXED_PIXEL_COUNT(1), .FIXED_PIXEL_COUNT(FRAME_PIXELS)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_stats_valid(stats_valid),
    .I_sum_r(sum_r), .I_sum_g(sum_g), .I_sum_b(sum_b),
    .I_pixel_count(pixel_count), .I_mean_luma(mean_luma),
    .O_gain_r(gain_r), .O_gain_g(gain_g), .O_gain_b(gain_b),
    .O_gain_update_valid(gain_update_valid), .O_scene_protected(scene_protected)
  );

  task send_means;
    input [7:0] r_mean;
    input [7:0] g_mean;
    input [7:0] b_mean;
    input [7:0] luma;
    input [31:0] count;
    begin
      @(negedge clk);
      sum_r = r_mean * FRAME_PIXELS;
      sum_g = g_mean * FRAME_PIXELS;
      sum_b = b_mean * FRAME_PIXELS;
      pixel_count = count;
      mean_luma = luma;
      stats_valid = 1'b1;
      @(posedge clk); #1;
      stats_valid = 1'b0;
      sum_r = 0; sum_g = 0; sum_b = 0; pixel_count = 0; mean_luma = 0;
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    send_means(8'd100, 8'd100, 8'd100, 8'd100, FRAME_PIXELS);
    if (!gain_update_valid || scene_protected || gain_r !== 16'd256 ||
        gain_g !== 16'd256 || gain_b !== 16'd256)
      $fatal(1, "fixed-count balanced frame failed");

    send_means(8'd120, 8'd120, 8'd180, 8'd120, FRAME_PIXELS);
    if (!gain_update_valid || scene_protected || gain_r !== 16'd264 ||
        gain_g !== 16'd256 || gain_b !== 16'd248)
      $fatal(1, "fixed-count gain threshold mismatch r=%0d b=%0d", gain_r, gain_b);

    send_means(8'd120, 8'd120, 8'd180, 8'd120, FRAME_PIXELS);
    if (!gain_update_valid || gain_r !== 16'd272 || gain_b !== 16'd240)
      $fatal(1, "fixed-count smoothing mismatch r=%0d b=%0d", gain_r, gain_b);

    send_means(8'd100, 8'd100, 8'd100, 8'd100, FRAME_PIXELS - 1);
    if (gain_update_valid || !scene_protected || gain_r !== 16'd272 || gain_b !== 16'd240)
      $fatal(1, "partial-frame statistics were accepted");

    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    send_means(8'd255, 8'd254, 8'd254, 8'd239, FRAME_PIXELS);
    if (!gain_update_valid || scene_protected || gain_r !== 16'd255 ||
        gain_g !== 16'd256 || gain_b !== 16'd256)
      $fatal(1, "fixed reciprocal maximum-range boundary mismatch r=%0d g=%0d b=%0d",
        gain_r, gain_g, gain_b);

    send_means(8'd255, 8'd255, 8'd254, 8'd239, FRAME_PIXELS);
    if (!gain_update_valid || scene_protected || gain_r !== 16'd255 ||
        gain_g !== 16'd256 || gain_b !== 16'd256)
      $fatal(1, "fixed RGB target-average boundary mismatch r=%0d g=%0d b=%0d",
        gain_r, gain_g, gain_b);

    $display("TB_AWB_FRAME_GAIN_FIXED_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in fixed-count AWB testbench");
  end
endmodule
