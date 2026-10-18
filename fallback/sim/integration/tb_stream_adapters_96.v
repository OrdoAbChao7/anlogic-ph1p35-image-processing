`timescale 1ns/1ps

module tb_stream_adapters_96;
  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg rst_n = 1'b0;
  reg tuser = 1'b0;
  reg tlast = 1'b0;
  reg tvalid = 1'b0;
  reg [15:0] frame_id = 16'd0;
  reg [95:0] tdata = 96'd0;

  wire motion_frame_start;
  wire motion_frame_end;
  wire motion_sample_valid;
  wire [15:0] motion_frame_id;
  wire motion_sample_x;
  wire motion_sample_y;
  wire [7:0] motion_y_value;
  wire motion_adapter_invalid;
  wire stats_valid;
  wire [15:0] stats_frame_id;
  wire [31:0] sum_r;
  wire [31:0] sum_g;
  wire [31:0] sum_b;
  wire [31:0] pixel_count;
  wire [7:0] mean_luma;
  wire stats_invalid;
  wire motion_summary_valid;
  wire motion_baseline_ready;
  wire motion_valid;
  wire motion;
  wire [23:0] motion_count;

  motion_grid_adapter_96 #(
    .INPUT_WIDTH(16), .INPUT_HEIGHT(12), .GRID_WIDTH(2), .GRID_HEIGHT(2),
    .X_STEP(8), .Y_STEP(6)
  ) u_motion_adapter (
    .I_clk(clk), .I_rst_n(rst_n), .I_tuser(tuser), .I_tlast(tlast),
    .I_tvalid(tvalid), .I_frame_id(frame_id), .I_tdata(tdata),
    .O_frame_start(motion_frame_start), .O_frame_end(motion_frame_end),
    .O_sample_valid(motion_sample_valid), .O_frame_id(motion_frame_id),
    .O_sample_x(motion_sample_x), .O_sample_y(motion_sample_y),
    .O_y_value(motion_y_value), .O_invalid(motion_adapter_invalid)
  );

  frame_stats_96 #(
    .INPUT_WIDTH(16), .INPUT_HEIGHT(12)
  ) u_stats (
    .I_clk(clk), .I_rst_n(rst_n), .I_tuser(tuser), .I_tlast(tlast),
    .I_tvalid(tvalid), .I_frame_id(frame_id), .I_tdata(tdata),
    .O_stats_valid(stats_valid), .O_frame_id(stats_frame_id),
    .O_sum_r(sum_r), .O_sum_g(sum_g), .O_sum_b(sum_b),
    .O_pixel_count(pixel_count), .O_mean_luma(mean_luma),
    .O_invalid(stats_invalid)
  );

  motion_diff_160 #(
    .IMG_WIDTH(2), .IMG_HEIGHT(2), .THRESHOLD(5)
  ) u_motion (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_start(motion_frame_start),
    .I_frame_end(motion_frame_end), .I_sample_valid(motion_sample_valid),
    .I_frame_id(motion_frame_id), .I_sample_x(motion_sample_x),
    .I_sample_y(motion_sample_y), .I_y_value(motion_y_value),
    .O_summary_valid(motion_summary_valid), .O_baseline_ready(motion_baseline_ready),
    .O_motion_valid(motion_valid), .O_motion(motion), .O_motion_count(motion_count),
    .O_xmin(), .O_xmax(), .O_ymin(), .O_ymax(), .O_frame_gap(), .O_invalid()
  );

  reg stats_seen;
  reg motion_seen;
  always @(posedge clk) begin
    if (stats_valid) begin
      stats_seen <= 1'b1;
      if (sum_g != 32'd9600 || sum_b != 32'd4800 || pixel_count != 32'd192 ||
          ((stats_frame_id == 16'd1) && (sum_r != 32'd19200 || mean_luma != 8'd58)) ||
          ((stats_frame_id == 16'd2) && (sum_r != 32'd19600 || mean_luma != 8'd59)))
        $fatal(1, "frame statistics mismatch r=%0d g=%0d b=%0d n=%0d y=%0d", sum_r, sum_g, sum_b, pixel_count, mean_luma);
    end
    if (motion_valid) begin
      motion_seen <= 1'b1;
      if (!motion || motion_count == 0)
        $fatal(1, "motion adapter did not publish changed sample");
    end
  end

  task send_frame;
    input [15:0] id;
    input change_first_sample;
    integer row;
    integer group;
    reg [23:0] pixel;
    begin
      frame_id = id;
      for (row = 0; row < 12; row = row + 1) begin
        for (group = 0; group < 4; group = group + 1) begin
          @(negedge clk);
          tuser = (row == 0 && group == 0);
          tlast = (group == 3);
          tvalid = 1'b1;
          pixel = (change_first_sample && row == 0 && group == 0) ?
                  24'hc83219 : 24'h643219;
          tdata = {pixel, pixel, pixel, pixel};
          @(posedge clk);
        end
      end
      @(negedge clk);
      tuser = 1'b0;
      tlast = 1'b0;
      tvalid = 1'b0;
    end
  endtask

  initial begin
    stats_seen = 1'b0;
    motion_seen = 1'b0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    send_frame(16'd1, 1'b0);
    send_frame(16'd2, 1'b1);
    repeat (8) @(posedge clk);
    if (!stats_seen || !motion_seen)
      $fatal(1, "adapter outputs missing stats_seen=%b motion_seen=%b", stats_seen, motion_seen);
    if (motion_adapter_invalid || stats_invalid)
      $fatal(1, "adapter reported invalid raster contract");
    $display("TB_STREAM_ADAPTERS_96_PASS");
    $finish;
  end
endmodule
