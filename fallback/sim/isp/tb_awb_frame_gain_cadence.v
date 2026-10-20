`timescale 1ns/1ps

module tb_awb_frame_gain_cadence;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg stats_valid = 1'b0;
  reg [31:0] sum_r = 32'd50;
  reg [31:0] sum_g = 32'd100;
  reg [31:0] sum_b = 32'd100;
  reg [31:0] pixel_count = 32'd1;
  reg [7:0] mean_luma = 8'd100;
  wire [15:0] gain_r, gain_g, gain_b;
  wire gain_update_valid, scene_protected;

  reg [95:0] tdata = 96'd0;
  reg tlast = 1'b0;
  reg tuser = 1'b0;
  reg tvalid = 1'b0;
  wire input_ready;
  wire [95:0] out_data;
  wire out_last, out_user, out_valid;
  integer output_count = 0;

  always #5 clk = ~clk;

  awb_frame_gain_controller #(.MAX_STEP(8)) controller (
    .I_clk(clk), .I_rst_n(rst_n),
    .I_frame_stats_valid(stats_valid),
    .I_sum_r(sum_r), .I_sum_g(sum_g), .I_sum_b(sum_b),
    .I_pixel_count(pixel_count), .I_mean_luma(mean_luma),
    .O_gain_r(gain_r), .O_gain_g(gain_g), .O_gain_b(gain_b),
    .O_gain_update_valid(gain_update_valid),
    .O_scene_protected(scene_protected)
  );

  axis_gain_rgb96 pixel_stage (
    .I_clk(clk), .I_rst_n(rst_n), .I_tdata(tdata),
    .I_tlast(tlast), .I_tuser(tuser), .I_tvalid(tvalid),
    .I_tready(1'b1), .I_gain_r_q8_8(gain_r[9:0]),
    .I_gain_g_q8_8(gain_g[9:0]), .I_gain_b_q8_8(gain_b[9:0]),
    .O_tready(input_ready), .O_tdata(out_data), .O_tlast(out_last),
    .O_tuser(out_user), .O_tvalid(out_valid)
  );

  always @(posedge clk) begin
    if (rst_n && out_valid) begin
      case (output_count)
        0: begin
          if (out_data !== {4{24'h646464}} || !out_user || out_last)
            $fatal(1, "SOF simultaneous with controller update must use pre-edge gains");
        end
        1: begin
          if (out_data !== {4{24'h676461}} || !out_user || !out_last)
            $fatal(1, "first SOF after gain update must use the new frame gains");
        end
        default: $fatal(1, "unexpected extra gain output beat");
      endcase
      output_count = output_count + 1;
    end
  end

  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1'b1;

    // A stats update and frame-start acceptance on the same edge is
    // deterministic: the pixel stage samples the controller's pre-edge gain.
    @(negedge clk);
    stats_valid = 1'b1;
    tdata = {4{24'h646464}};
    tuser = 1'b1;
    tvalid = 1'b1;
    @(posedge clk);
    #1;
    if (!gain_update_valid || gain_r != 16'd264 || gain_g != 16'd256 ||
        gain_b != 16'd248 || scene_protected)
      $fatal(1, "controller did not publish the expected bounded update");
    // The next cycle is already the following frame's SOF: no blanking or
    // minimum inter-frame gap is assumed by this contract.
    @(negedge clk);
    stats_valid = 1'b0;
    tdata = {4{24'h646464}};
    tlast = 1'b1;
    tuser = 1'b1;
    tvalid = 1'b1;
    @(posedge clk);
    #1;
    tvalid = 1'b0;
    tlast = 1'b0;
    tuser = 1'b0;
    repeat (4) @(posedge clk);
    if (output_count != 2)
      $fatal(1, "expected two frame-start pixels, observed %0d", output_count);
    $display("TB_AWB_FRAME_GAIN_CADENCE_PASS");
    $finish;
  end
endmodule
