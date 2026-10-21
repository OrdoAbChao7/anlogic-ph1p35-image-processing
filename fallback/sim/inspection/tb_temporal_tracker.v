`timescale 1ns/1ps

module tb_temporal_tracker;
  localparam [1:0] STATE_NO_OBJECT = 2'd0;
  localparam [1:0] STATE_TRACKING  = 2'd1;
  localparam [1:0] STATE_LOST      = 2'd2;
  localparam [1:0] STATE_INVALID   = 2'd3;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg frame_valid = 1'b0;
  reg [15:0] frame_id = 16'd0;
  reg detected = 1'b0;
  reg invalid = 1'b0;
  reg [10:0] cx = 11'd0;
  reg [10:0] cy = 11'd0;

  wire result_valid;
  wire [1:0] state;
  wire track_valid, enter_event, exit_event, frame_gap, static_target;
  wire [10:0] out_cx, out_cy;
  wire signed [11:0] dx, dy;
  wire [3:0] direction;
  wire [2:0] lost_frames;

  always #5 clk = ~clk;

  temporal_tracker #(
    .MAX_STEP_X(10),
    .MAX_STEP_Y(10),
    .MAX_LOST_FRAMES(2)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_valid(frame_valid),
    .I_frame_id(frame_id), .I_detected(detected), .I_invalid(invalid),
    .I_cx(cx), .I_cy(cy), .O_result_valid(result_valid), .O_state(state),
    .O_track_valid(track_valid), .O_enter(enter_event), .O_exit(exit_event),
    .O_frame_gap(frame_gap), .O_static(static_target), .O_cx(out_cx),
    .O_cy(out_cy), .O_dx(dx), .O_dy(dy), .O_direction(direction),
    .O_lost_frames(lost_frames)
  );

  task send_frame;
    input [15:0] id;
    input det;
    input inv;
    input [10:0] in_cx;
    input [10:0] in_cy;
    begin
      @(negedge clk);
      frame_id = id;
      detected = det;
      invalid = inv;
      cx = in_cx;
      cy = in_cy;
      frame_valid = 1'b1;
      @(posedge clk);
      #1;
      frame_valid = 1'b0;
      detected = 1'b0;
      invalid = 1'b0;
    end
  endtask

  task expect_common;
    input [1:0] expected_state;
    input expected_track;
    input expected_enter;
    input expected_exit;
    input expected_gap;
    input integer expected_lost;
    begin
      if (!result_valid || state !== expected_state || track_valid !== expected_track ||
          enter_event !== expected_enter || exit_event !== expected_exit ||
          frame_gap !== expected_gap || lost_frames !== expected_lost) begin
        $fatal(1, "tracker mismatch state=%b/%b valid=%b enter=%b/%b exit=%b/%b gap=%b/%b lost=%0d/%0d center=%0d,%0d dx=%0d dy=%0d",
          state, expected_state, track_valid, enter_event, expected_enter,
          exit_event, expected_exit, frame_gap, expected_gap,
          lost_frames, expected_lost, out_cx, out_cy, dx, dy);
      end
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    send_frame(16'd10, 1'b1, 1'b0, 11'd100, 11'd80);
    expect_common(STATE_TRACKING, 1'b1, 1'b1, 1'b0, 1'b0, 0);
    if (!static_target || out_cx != 100 || out_cy != 80 || direction != 4'd1)
      $fatal(1, "initial static target mismatch");

    send_frame(16'd11, 1'b1, 1'b0, 11'd100, 11'd80);
    expect_common(STATE_TRACKING, 1'b1, 1'b0, 1'b0, 1'b0, 0);
    if (!static_target || dx !== 0 || dy !== 0 || direction != 4'd1)
      $fatal(1, "static update mismatch");

    send_frame(16'd12, 1'b1, 1'b0, 11'd105, 11'd88);
    expect_common(STATE_TRACKING, 1'b1, 1'b0, 1'b0, 1'b0, 0);
    if (static_target || dx !== 5 || dy !== 8 || direction != 4'd9)
      $fatal(1, "motion update mismatch dx=%0d dy=%0d dir=%0d", dx, dy, direction);

    send_frame(16'd13, 1'b0, 1'b0, 11'd0, 11'd0);
    expect_common(STATE_LOST, 1'b0, 1'b0, 1'b0, 1'b0, 1);
    send_frame(16'd14, 1'b0, 1'b0, 11'd0, 11'd0);
    expect_common(STATE_LOST, 1'b0, 1'b0, 1'b0, 1'b0, 2);
    send_frame(16'd15, 1'b1, 1'b0, 11'd106, 11'd89);
    expect_common(STATE_TRACKING, 1'b1, 1'b0, 1'b0, 1'b0, 0);
    if (dx !== 1 || dy !== 1 || direction != 4'd9)
      $fatal(1, "lost recovery mismatch");

    send_frame(16'd16, 1'b0, 1'b0, 11'd0, 11'd0);
    send_frame(16'd17, 1'b0, 1'b0, 11'd0, 11'd0);
    send_frame(16'd18, 1'b0, 1'b0, 11'd0, 11'd0);
    expect_common(STATE_NO_OBJECT, 1'b0, 1'b0, 1'b1, 1'b0, 2);

    send_frame(16'd19, 1'b1, 1'b0, 11'd300, 11'd200);
    expect_common(STATE_TRACKING, 1'b1, 1'b1, 1'b0, 1'b0, 0);

    send_frame(16'd20, 1'b1, 1'b0, 11'd100, 11'd100);
    expect_common(STATE_LOST, 1'b0, 1'b0, 1'b0, 1'b0, 1);
    send_frame(16'd21, 1'b1, 1'b0, 11'd100, 11'd100);
    expect_common(STATE_TRACKING, 1'b1, 1'b1, 1'b0, 1'b0, 0);

    send_frame(16'd23, 1'b1, 1'b1, 11'd101, 11'd101);
    expect_common(STATE_INVALID, 1'b0, 1'b0, 1'b0, 1'b1, 0);
    if (out_cx !== 100 || out_cy !== 100)
      $fatal(1, "invalid result changed center");
    send_frame(16'd26, 1'b1, 1'b0, 11'd102, 11'd102);
    expect_common(STATE_TRACKING, 1'b1, 1'b1, 1'b0, 1'b1, 0);

    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    send_frame(16'd40, 1'b1, 1'b0, 11'd7, 11'd9);
    expect_common(STATE_TRACKING, 1'b1, 1'b1, 1'b0, 1'b0, 0);

    $display("TB_TEMPORAL_TRACKER_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in temporal tracker testbench");
  end
endmodule
