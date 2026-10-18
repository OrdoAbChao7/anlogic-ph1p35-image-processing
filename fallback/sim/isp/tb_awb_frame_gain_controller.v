`timescale 1ns/1ps

module tb_awb_frame_gain_controller;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg stats_valid = 1'b0;
  reg [31:0] sum_r = 0, sum_g = 0, sum_b = 0, pixel_count = 0;
  reg [7:0] mean_luma = 0;
  wire [15:0] gain_r, gain_g, gain_b;
  wire gain_update_valid, scene_protected;

  always #5 clk = ~clk;

  awb_frame_gain_controller #(.MAX_STEP(8), .SCENE_JUMP(40)) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_stats_valid(stats_valid),
    .I_sum_r(sum_r), .I_sum_g(sum_g), .I_sum_b(sum_b),
    .I_pixel_count(pixel_count), .I_mean_luma(mean_luma),
    .O_gain_r(gain_r), .O_gain_g(gain_g), .O_gain_b(gain_b),
    .O_gain_update_valid(gain_update_valid),
    .O_scene_protected(scene_protected)
  );

  task clear_stats;
    begin stats_valid=1'b0; sum_r=0; sum_g=0; sum_b=0; pixel_count=0; mean_luma=0; end
  endtask

  task send_stats;
    input [31:0] r;
    input [31:0] g;
    input [31:0] b;
    input [31:0] count;
    input [7:0] luma;
    begin
      @(negedge clk); clear_stats;
      sum_r=r; sum_g=g; sum_b=b; pixel_count=count; mean_luma=luma; stats_valid=1'b1;
      @(posedge clk); #1; clear_stats;
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n=1'b1;

    send_stats(32'd1600,32'd1600,32'd1600,32'd16,8'd100);
    if (!gain_update_valid || scene_protected || gain_r!==16'd256 ||
        gain_g!==16'd256 || gain_b!==16'd256)
      $fatal(1, "balanced gain contract failed");

    send_stats(32'd1920,32'd1920,32'd2880,32'd16,8'd120);
    if (!gain_update_valid || scene_protected || gain_r!==16'd264 ||
        gain_g!==16'd256 || gain_b!==16'd248)
      $fatal(1, "blue cast gain step failed r=%0d g=%0d b=%0d", gain_r, gain_g, gain_b);

    send_stats(32'd1920,32'd1920,32'd2880,32'd16,8'd120);
    if (!gain_update_valid || gain_r!==16'd272 || gain_b!==16'd240)
      $fatal(1, "frame-boundary smoothing failed r=%0d b=%0d", gain_r, gain_b);

    send_stats(32'd32,32'd32,32'd32,32'd16,8'd2);
    if (gain_update_valid || !scene_protected || gain_r!==16'd272 || gain_b!==16'd240)
      $fatal(1, "dark scene protection failed");

    send_stats(32'd1600,32'd1920,32'd1280,32'd16,8'd100);
    if (gain_update_valid || !scene_protected)
      $fatal(1, "luma jump protection failed");

    send_stats(32'd1600,32'd1920,32'd1280,32'd16,8'd100);
    if (!gain_update_valid || scene_protected)
      $fatal(1, "stable scene update failed");

    send_stats(32'd0,32'd0,32'd0,32'd0,8'd100);
    if (gain_update_valid || !scene_protected)
      $fatal(1, "empty statistics protection failed");

    rst_n=1'b0;
    #1;
    if (gain_r!==16'd256 || gain_g!==16'd256 || gain_b!==16'd256)
      $fatal(1, "reset gain contract failed");
    $display("TB_AWB_FRAME_GAIN_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in awb frame gain testbench");
  end
endmodule
