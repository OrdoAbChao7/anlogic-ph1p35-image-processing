`timescale 1ns/1ps

module tb_industrial_v2_display_tracking;
  reg clk = 1'b0;
  always #5 clk = ~clk;
  reg rst_n = 1'b0;
  reg frame_valid = 1'b0;
  reg [15:0] frame_id = 16'd0;
  reg detected = 1'b0;
  reg invalid = 1'b0;
  reg [10:0] cx = 11'd3;
  reg [10:0] cy = 11'd1;
  reg de = 1'b0;
  reg hs = 1'b0;
  reg vs = 1'b0;
  reg [23:0] rgb = 24'h112233;
  wire out_de, out_hs, out_vs;
  wire [23:0] out_rgb;
  wire track_valid, track_enter, track_exit;
  wire [1:0] tracking_state;
  wire [10:0] track_cx, track_cy;

  industrial_v2_display_tracking #(
    .IMG_WIDTH(8), .IMG_HEIGHT(4), .HISTORY_DEPTH(4)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_valid(frame_valid),
    .I_frame_id(frame_id), .I_detected(detected), .I_invalid(invalid),
    .I_cx(cx), .I_cy(cy), .I_de(de), .I_hsync(hs), .I_vsync(vs),
    .I_rgb(rgb), .O_de(out_de), .O_hsync(out_hs), .O_vsync(out_vs),
    .O_rgb(out_rgb), .O_track_valid(track_valid), .O_track_enter(track_enter),
    .O_track_exit(track_exit), .O_tracking_state(tracking_state),
    .O_track_cx(track_cx), .O_track_cy(track_cy)
  );

  integer i;
  reg saw_known;
  initial begin
    saw_known = 1'b0;
    repeat (3) @(negedge clk);
    rst_n = 1'b1;

    @(negedge clk);
    frame_id = 16'd1;
    frame_valid = 1'b1;
    detected = 1'b1;
    @(negedge clk);
    frame_valid = 1'b0;
    if (!track_valid || tracking_state != 2'd1 || track_cx != 11'd3 || track_cy != 11'd1)
      $fatal(1, "display tracking state did not publish");

    @(negedge clk);
    vs = 1'b1;
    @(negedge clk);
    vs = 1'b0;
    for (i = 0; i < 32; i = i + 1) begin
      @(negedge clk);
      de = 1'b1;
      hs = 1'b0;
      @(negedge clk);
      if (out_rgb !== 24'hx)
        saw_known = 1'b1;
      if ((i % 8) == 7)
        de = 1'b0;
    end
    de = 1'b0;
    if (!saw_known)
      $fatal(1, "display overlay output remained unknown");
    $display("TB_INDUSTRIAL_V2_DISPLAY_TRACKING_PASS");
    $finish;
  end
endmodule
