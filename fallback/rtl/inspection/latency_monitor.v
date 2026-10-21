`timescale 1ns/1ps

// Single-entry internal latency ledger.
//
// The monitor measures tagged processing and video publication latency from
// one frame-domain input event. It never fabricates an end-to-end number:
// processing and video stages are reported independently, while E2E remains
// explicitly N/A until a downstream timing contract exists.
module latency_monitor #(
  parameter integer COUNTER_WIDTH = 32,
  // Default covers two active 1280x720 rasters; smaller unit tests can override.
  parameter integer TIMEOUT_CYCLES = (2 * 1280 * 720)
)(
  input  wire                         I_clk,
  input  wire                         I_rst_n,
  input  wire                         I_input_valid,
  input  wire [15:0]                  I_input_frame_id,
  input  wire                         I_result_valid,
  input  wire [15:0]                  I_result_frame_id,
  input  wire                         I_video_valid,
  input  wire [15:0]                  I_video_frame_id,
  output reg                          O_proc_valid,
  output reg  [COUNTER_WIDTH-1:0]     O_proc_cycles,
  output reg                          O_video_valid,
  output reg  [COUNTER_WIDTH-1:0]     O_video_cycles,
  output reg                          O_e2e_valid,
  output reg  [COUNTER_WIDTH-1:0]     O_e2e_cycles,
  output reg                          O_frame_gap,
  output reg                          O_tag_mismatch,
  output reg                          O_timeout
);

  reg [COUNTER_WIDTH-1:0] cycle_counter;
  reg [COUNTER_WIDTH-1:0] input_timestamp;
  reg [COUNTER_WIDTH-1:0] stage_event_edges;
  reg [COUNTER_WIDTH-1:0] age;
  reg [15:0]              active_frame_id;
  reg [15:0]              last_input_id;
  reg                     have_input;
  reg                     pending;
  reg                     result_seen;
  reg                     video_seen;

  wire result_match_now = pending && I_result_valid &&
                          (I_result_frame_id == active_frame_id);
  wire video_match_now = pending && I_video_valid &&
                         (I_video_frame_id == active_frame_id);
  wire complete_now = (result_seen || result_match_now) &&
                      (video_seen || video_match_now);

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      cycle_counter    <= {COUNTER_WIDTH{1'b0}};
      input_timestamp  <= {COUNTER_WIDTH{1'b0}};
      stage_event_edges <= {COUNTER_WIDTH{1'b0}};
      age              <= {COUNTER_WIDTH{1'b0}};
      active_frame_id  <= 16'd0;
      last_input_id    <= 16'd0;
      have_input       <= 1'b0;
      pending          <= 1'b0;
      result_seen      <= 1'b0;
      video_seen       <= 1'b0;
      O_proc_valid     <= 1'b0;
      O_proc_cycles    <= {COUNTER_WIDTH{1'b0}};
      O_video_valid    <= 1'b0;
      O_video_cycles   <= {COUNTER_WIDTH{1'b0}};
      O_e2e_valid      <= 1'b0;
      O_e2e_cycles     <= {COUNTER_WIDTH{1'b0}};
      O_frame_gap      <= 1'b0;
      O_tag_mismatch   <= 1'b0;
      O_timeout        <= 1'b0;
    end else begin
      cycle_counter  <= cycle_counter + {{(COUNTER_WIDTH-1){1'b0}}, 1'b1};
      O_proc_valid   <= 1'b0;
      O_video_valid  <= 1'b0;
      O_e2e_valid    <= 1'b0;
      O_e2e_cycles   <= {COUNTER_WIDTH{1'b0}};
      O_frame_gap    <= 1'b0;
      O_tag_mismatch <= 1'b0;
      O_timeout      <= 1'b0;

      // A new input starts a new atomic frame measurement. It intentionally
      // replaces an older pending frame rather than inventing a result for it.
      if (I_input_valid) begin
        O_frame_gap     <= have_input &&
                           (I_input_frame_id != (last_input_id + 16'd1));
        have_input      <= 1'b1;
        last_input_id   <= I_input_frame_id;
        active_frame_id <= I_input_frame_id;
        input_timestamp <= cycle_counter;
        stage_event_edges <= {COUNTER_WIDTH{1'b0}};
        age             <= {COUNTER_WIDTH{1'b0}};
        pending         <= 1'b1;
        result_seen     <= 1'b0;
        video_seen      <= 1'b0;
      end else begin
        // The free-running timestamp includes the current observation edge.
        // Keep a count of earlier result/video edges so the published value
        // matches the event-domain model, where observations take no time.
        if (I_result_valid || I_video_valid)
          stage_event_edges <= stage_event_edges + {{(COUNTER_WIDTH-1){1'b0}}, 1'b1};

        // A result/video event without a matching active frame is an explicit
        // tag error, including a result arriving after timeout.
        if (I_result_valid) begin
          if (result_match_now) begin
            O_proc_valid  <= 1'b1;
            O_proc_cycles <= cycle_counter - input_timestamp -
                             stage_event_edges - {{(COUNTER_WIDTH-1){1'b0}}, 1'b1};
            result_seen   <= 1'b1;
          end else begin
            O_tag_mismatch <= 1'b1;
          end
        end
        if (I_video_valid) begin
          if (video_match_now) begin
            O_video_valid  <= 1'b1;
            O_video_cycles <= cycle_counter - input_timestamp -
                              stage_event_edges - {{(COUNTER_WIDTH-1){1'b0}}, 1'b1};
            video_seen     <= 1'b1;
          end else begin
            O_tag_mismatch <= 1'b1;
          end
        end

        if (pending) begin
          if (complete_now) begin
            pending     <= 1'b0;
            age         <= {COUNTER_WIDTH{1'b0}};
            result_seen <= 1'b0;
            video_seen  <= 1'b0;
          end else if (!(I_result_valid || I_video_valid) &&
                       (age >= TIMEOUT_CYCLES - 1)) begin
            pending     <= 1'b0;
            age         <= {COUNTER_WIDTH{1'b0}};
            result_seen <= 1'b0;
            video_seen  <= 1'b0;
            O_timeout   <= 1'b1;
          end else if (!(I_result_valid || I_video_valid)) begin
            age <= age + {{(COUNTER_WIDTH-1){1'b0}}, 1'b1};
          end
        end
      end
    end
  end
endmodule
