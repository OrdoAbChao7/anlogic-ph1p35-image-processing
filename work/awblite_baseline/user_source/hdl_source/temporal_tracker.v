`timescale 1ns/1ps

// Frame-result-domain single-target association.
//
// The module consumes one atomic detector result per I_frame_valid event. It
// does not inspect the pixel stream and therefore cannot introduce a second
// video clock boundary. Invalid results never update the stored center.
module temporal_tracker #(
  parameter integer MAX_STEP_X = 64,
  parameter integer MAX_STEP_Y = 64,
  parameter integer MAX_LOST_FRAMES = 3
)(
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_frame_valid,
  input  wire [15:0] I_frame_id,
  input  wire        I_detected,
  input  wire        I_invalid,
  input  wire [10:0] I_cx,
  input  wire [10:0] I_cy,
  output reg         O_result_valid,
  output reg  [1:0]  O_state,
  output reg         O_track_valid,
  output reg         O_enter,
  output reg         O_exit,
  output reg         O_frame_gap,
  output reg         O_static,
  output reg  [10:0] O_cx,
  output reg  [10:0] O_cy,
  output reg signed [11:0] O_dx,
  output reg signed [11:0] O_dy,
  output reg  [3:0]  O_direction,
  output reg  [2:0]  O_lost_frames
);

  localparam [1:0] STATE_NO_OBJECT = 2'd0;
  localparam [1:0] STATE_TRACKING  = 2'd1;
  localparam [1:0] STATE_LOST      = 2'd2;
  localparam [1:0] STATE_INVALID   = 2'd3;

  localparam [3:0] DIR_NONE       = 4'd0;
  localparam [3:0] DIR_STATIC     = 4'd1;
  localparam [3:0] DIR_LEFT       = 4'd2;
  localparam [3:0] DIR_RIGHT      = 4'd3;
  localparam [3:0] DIR_UP         = 4'd4;
  localparam [3:0] DIR_DOWN       = 4'd5;
  localparam [3:0] DIR_UP_LEFT    = 4'd6;
  localparam [3:0] DIR_UP_RIGHT   = 4'd7;
  localparam [3:0] DIR_DOWN_LEFT  = 4'd8;
  localparam [3:0] DIR_DOWN_RIGHT = 4'd9;

  reg        active;
  reg        have_frame;
  reg [15:0] last_frame_id;
  reg [10:0] last_cx;
  reg [10:0] last_cy;
  reg [2:0]  lost_count;

  wire signed [11:0] candidate_dx = $signed({1'b0, I_cx}) -
                                     $signed({1'b0, last_cx});
  wire signed [11:0] candidate_dy = $signed({1'b0, I_cy}) -
                                     $signed({1'b0, last_cy});
  wire [11:0] abs_dx = candidate_dx < 0 ? -candidate_dx : candidate_dx;
  wire [11:0] abs_dy = candidate_dy < 0 ? -candidate_dy : candidate_dy;
  wire within_gate = (abs_dx <= MAX_STEP_X) && (abs_dy <= MAX_STEP_Y);
  wire frame_gap_now = have_frame &&
                       (I_frame_id != (last_frame_id + 16'd1));

  function [3:0] direction_for;
    input signed [11:0] dx_in;
    input signed [11:0] dy_in;
    begin
      if ((dx_in == 0) && (dy_in == 0)) direction_for = DIR_STATIC;
      else if ((dx_in < 0) && (dy_in == 0)) direction_for = DIR_LEFT;
      else if ((dx_in > 0) && (dy_in == 0)) direction_for = DIR_RIGHT;
      else if ((dx_in == 0) && (dy_in < 0)) direction_for = DIR_UP;
      else if ((dx_in == 0) && (dy_in > 0)) direction_for = DIR_DOWN;
      else if ((dx_in < 0) && (dy_in < 0)) direction_for = DIR_UP_LEFT;
      else if ((dx_in > 0) && (dy_in < 0)) direction_for = DIR_UP_RIGHT;
      else if ((dx_in < 0) && (dy_in > 0)) direction_for = DIR_DOWN_LEFT;
      else direction_for = DIR_DOWN_RIGHT;
    end
  endfunction

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      active          <= 1'b0;
      have_frame      <= 1'b0;
      last_frame_id   <= 16'd0;
      last_cx         <= 11'd0;
      last_cy         <= 11'd0;
      lost_count      <= 3'd0;
      O_result_valid  <= 1'b0;
      O_state         <= STATE_NO_OBJECT;
      O_track_valid   <= 1'b0;
      O_enter         <= 1'b0;
      O_exit          <= 1'b0;
      O_frame_gap     <= 1'b0;
      O_static        <= 1'b0;
      O_cx            <= 11'd0;
      O_cy            <= 11'd0;
      O_dx            <= 12'sd0;
      O_dy            <= 12'sd0;
      O_direction     <= DIR_NONE;
      O_lost_frames   <= 3'd0;
    end else begin
      O_result_valid <= 1'b0;
      O_enter        <= 1'b0;
      O_exit         <= 1'b0;
      O_frame_gap    <= 1'b0;
      O_track_valid  <= 1'b0;
      O_static       <= 1'b0;
      O_dx           <= 12'sd0;
      O_dy           <= 12'sd0;
      O_direction    <= DIR_NONE;

      if (I_frame_valid) begin
        O_result_valid <= 1'b1;
        O_frame_gap    <= frame_gap_now;
        have_frame     <= 1'b1;
        last_frame_id  <= I_frame_id;

        if (I_invalid) begin
          active        <= 1'b0;
          lost_count    <= 3'd0;
          O_lost_frames <= 3'd0;
          O_state       <= STATE_INVALID;
        end else if (!I_detected) begin
          if (!active) begin
            O_state <= STATE_NO_OBJECT;
          end else if (lost_count < MAX_LOST_FRAMES) begin
            lost_count    <= lost_count + 3'd1;
            O_lost_frames <= lost_count + 3'd1;
            O_state       <= STATE_LOST;
          end else begin
            active        <= 1'b0;
            O_state       <= STATE_NO_OBJECT;
            O_exit        <= 1'b1;
            O_lost_frames <= lost_count;
          end
        end else if (!active) begin
          active        <= 1'b1;
          lost_count    <= 3'd0;
          O_lost_frames <= 3'd0;
          last_cx       <= I_cx;
          last_cy       <= I_cy;
          O_cx          <= I_cx;
          O_cy          <= I_cy;
          O_state       <= STATE_TRACKING;
          O_track_valid <= 1'b1;
          O_enter       <= 1'b1;
          O_static      <= 1'b1;
          O_direction   <= DIR_STATIC;
        end else if (within_gate) begin
          last_cx       <= I_cx;
          last_cy       <= I_cy;
          O_cx          <= I_cx;
          O_cy          <= I_cy;
          O_dx          <= candidate_dx;
          O_dy          <= candidate_dy;
          O_state       <= STATE_TRACKING;
          O_track_valid <= 1'b1;
          O_static      <= (candidate_dx == 0) && (candidate_dy == 0);
          O_direction   <= direction_for(candidate_dx, candidate_dy);
          lost_count    <= 3'd0;
          O_lost_frames <= 3'd0;
        end else if (lost_count != 0) begin
          active        <= 1'b1;
          lost_count    <= 3'd0;
          O_lost_frames <= 3'd0;
          last_cx       <= I_cx;
          last_cy       <= I_cy;
          O_cx          <= I_cx;
          O_cy          <= I_cy;
          O_state       <= STATE_TRACKING;
          O_track_valid <= 1'b1;
          O_enter       <= 1'b1;
          O_static      <= 1'b1;
          O_direction   <= DIR_STATIC;
        end else begin
          lost_count    <= 3'd1;
          O_lost_frames <= 3'd1;
          O_state       <= STATE_LOST;
        end
      end
    end
  end
endmodule
