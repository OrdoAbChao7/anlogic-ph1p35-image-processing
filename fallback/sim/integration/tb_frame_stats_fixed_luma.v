`timescale 1ns/1ps

module tb_frame_stats_fixed_luma;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg tuser = 1'b0;
  reg tlast = 1'b0;
  reg tvalid = 1'b0;
  reg [15:0] frame_id = 16'd0;
  reg [95:0] tdata = 96'd0;
  integer current_row = 0;
  integer current_group = 0;
  integer frame_end_delay = 0;
  reg [15:0] expected_frame_id = 0;
  integer completed_frames = 0;
  reg [31:0] expected_sum_r;
  reg [31:0] expected_pixel_count;

  wire stats_valid;
  wire [15:0] stats_frame_id;
  wire [31:0] sum_r, sum_g, sum_b, pixel_count;
  wire [7:0] mean_luma;
  wire stats_invalid;

  always #5 clk = ~clk;

  frame_stats_96 #(
    .INPUT_WIDTH(1280), .INPUT_HEIGHT(720), .USE_FIXED_FRAME_SIZE(1)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_tuser(tuser), .I_tlast(tlast),
    .I_tvalid(tvalid), .I_frame_id(frame_id), .I_tdata(tdata),
    .O_stats_valid(stats_valid), .O_frame_id(stats_frame_id),
    .O_sum_r(sum_r), .O_sum_g(sum_g), .O_sum_b(sum_b),
    .O_pixel_count(pixel_count), .O_mean_luma(mean_luma),
    .O_invalid(stats_invalid)
  );

  always @(posedge clk) begin
    if (!rst_n) begin
      frame_end_delay = 0;
    end else if (tvalid && tlast && current_row == 719 &&
                 ((frame_id == 16'd4 && current_group == 319) ||
                  (frame_id != 16'd4 && current_group == 3))) begin
      if (stats_valid)
        $fatal(1, "fixed-frame statistics must be deferred through the luma stage");
      if (frame_end_delay != 0)
        $fatal(1, "unexpected overlapping fixed-frame result");
      frame_end_delay = 3;
      expected_frame_id = frame_id;
      expected_sum_r = (frame_id == 16'd4) ? 32'd73728000 :
                       ((frame_id == 16'd1) ? 32'd921600 :
                        ((frame_id == 16'd2) ? 32'd921599 : 32'd921601));
      expected_pixel_count = (frame_id == 16'd4) ? 32'd921600 : 32'd11520;
    end else if (frame_end_delay == 3) begin
      if (stats_valid)
        $fatal(1, "fixed-frame result was published before the first deferred luma cycle");
      frame_end_delay = 2;
    end else if (frame_end_delay == 2) begin
      if (stats_valid)
        $fatal(1, "fixed-frame result was published before the reciprocal stage");
      frame_end_delay = 1;
    end else if (frame_end_delay == 1) begin
      if (!stats_valid || stats_frame_id != expected_frame_id)
        $fatal(1, "fixed-frame statistics valid/frame ID misaligned id=%0d valid=%b",
               stats_frame_id, stats_valid);
      if (sum_r != expected_sum_r ||
          sum_g != ((expected_frame_id == 16'd4) ? 32'd73728000 : 32'd921600) ||
          sum_b != ((expected_frame_id == 16'd4) ? 32'd73728000 : 32'd921600) ||
          pixel_count != expected_pixel_count || stats_invalid !== 1'b1)
        $fatal(1, "fixed-frame sums/count/invalid mismatch id=%0d r=%0d g=%0d b=%0d n=%0d invalid=%b",
               stats_frame_id, sum_r, sum_g, sum_b, pixel_count, stats_invalid);
      if (((expected_frame_id == 16'd2) && mean_luma != 8'd0) ||
          ((expected_frame_id == 16'd4) && mean_luma != 8'd80) ||
          ((expected_frame_id != 16'd2 && expected_frame_id != 16'd4) &&
           mean_luma != 8'd1))
        $fatal(1, "fixed reciprocal boundary mismatch id=%0d mean=%0d",
               stats_frame_id, mean_luma);
      completed_frames = completed_frames + 1;
      frame_end_delay = 0;
    end
  end

  task send_frame;
    input [15:0] id;
    integer row;
    integer group;
    begin
      frame_id = id;
      for (row = 0; row < 720; row = row + 1) begin
        for (group = 0; group < 4; group = group + 1) begin
          @(negedge clk);
          current_row = row;
          current_group = group;
          tuser = (row == 0 && group == 0);
          tlast = (group == 3);
          tvalid = 1'b1;
          if (row == 0 && group == 0 && id == 16'd2)
            tdata = {24'h4f5050, 24'h505050, 24'h505050, 24'h505050};
          else if (row == 0 && group == 0 && id == 16'd3)
            tdata = {24'h515050, 24'h505050, 24'h505050, 24'h505050};
          else
            tdata = {4{24'h505050}};
          @(posedge clk);
        end
      end
      @(negedge clk);
      tuser = 1'b0;
      tlast = 1'b0;
      tvalid = 1'b0;
    end
  endtask

  task send_full_frame_without_sof;
    input [15:0] id;
    integer row;
    integer group;
    begin
      frame_id = id;
      for (row = 0; row < 720; row = row + 1) begin
        for (group = 0; group < 320; group = group + 1) begin
          @(negedge clk);
          current_row = row;
          current_group = group;
          tuser = 1'b0;
          tlast = (group == 319);
          tvalid = 1'b1;
          tdata = {4{24'h505050}};
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
    expected_sum_r = 0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    send_frame(16'd1);
    send_frame(16'd2);
    send_frame(16'd3);
    send_full_frame_without_sof(16'd4);
    repeat (5) @(posedge clk);
    if (completed_frames != 4 || frame_end_delay != 0)
      $fatal(1, "missing fixed statistics completed=%0d pending=%0d",
             completed_frames, frame_end_delay);
    $display("TB_FRAME_STATS_FIXED_LUMA_PASS");
    $finish;
  end

  initial begin
    #200000000;
    $fatal(1, "timeout in fixed luma pipeline testbench");
  end
endmodule
