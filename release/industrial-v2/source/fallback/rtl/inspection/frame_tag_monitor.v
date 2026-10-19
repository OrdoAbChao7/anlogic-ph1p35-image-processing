`timescale 1ns/1ps

// Bounded frame-tag ledger for internal latency measurements. It accepts one
// pending input frame at a time and never fabricates a tag for a missing frame.
module frame_tag_monitor #(
  parameter integer TIMEOUT_CYCLES = 1024
)(
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_input_valid,
  input  wire [15:0] I_input_frame_id,
  input  wire        I_result_valid,
  input  wire [15:0] I_result_frame_id,
  input  wire        I_video_valid,
  input  wire [15:0] I_video_frame_id,
  output reg         O_pending,
  output reg  [15:0] O_active_frame_id,
  output reg         O_frame_gap,
  output reg         O_result_match,
  output reg         O_video_match,
  output reg         O_tag_mismatch,
  output reg         O_timeout
);

  reg        have_input;
  reg [15:0] last_input_id;
  reg        result_seen;
  reg        video_seen;
  reg [31:0] age;

  wire result_match_now = O_pending && I_result_valid &&
                          (I_result_frame_id == O_active_frame_id);
  wire video_match_now = O_pending && I_video_valid &&
                         (I_video_frame_id == O_active_frame_id);
  wire complete_now = (result_seen || result_match_now) &&
                      (video_seen || video_match_now);

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      have_input      <= 1'b0;
      last_input_id   <= 16'd0;
      O_pending       <= 1'b0;
      O_active_frame_id <= 16'd0;
      result_seen     <= 1'b0;
      video_seen      <= 1'b0;
      age             <= 32'd0;
      O_frame_gap     <= 1'b0;
      O_result_match  <= 1'b0;
      O_video_match   <= 1'b0;
      O_tag_mismatch  <= 1'b0;
      O_timeout       <= 1'b0;
    end else begin
      O_frame_gap    <= 1'b0;
      O_result_match <= 1'b0;
      O_video_match  <= 1'b0;
      O_tag_mismatch <= 1'b0;
      O_timeout      <= 1'b0;

      if (I_input_valid) begin
        O_frame_gap <= have_input &&
                       (I_input_frame_id != (last_input_id + 16'd1));
        have_input       <= 1'b1;
        last_input_id    <= I_input_frame_id;
        O_pending        <= 1'b1;
        O_active_frame_id <= I_input_frame_id;
        result_seen      <= 1'b0;
        video_seen       <= 1'b0;
        age              <= 32'd0;
      end else if (O_pending) begin
        if (I_result_valid) begin
          if (result_match_now) begin
            O_result_match <= 1'b1;
            result_seen    <= 1'b1;
          end else begin
            O_tag_mismatch <= 1'b1;
          end
        end
        if (I_video_valid) begin
          if (video_match_now) begin
            O_video_match <= 1'b1;
            video_seen    <= 1'b1;
          end else begin
            O_tag_mismatch <= 1'b1;
          end
        end

        if (complete_now) begin
          O_pending <= 1'b0;
          age       <= 32'd0;
        end else if (age >= TIMEOUT_CYCLES - 1) begin
          O_timeout <= 1'b1;
          O_pending <= 1'b0;
          age       <= 32'd0;
          result_seen <= 1'b0;
          video_seen  <= 1'b0;
        end else begin
          age <= age + 32'd1;
        end
      end
    end
  end
endmodule
