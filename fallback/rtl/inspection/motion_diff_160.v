`timescale 1ns/1ps

// Fixed-grid cross-frame luminance difference monitor.
//
// The upstream adapter supplies one sample per cycle from a fixed ROI grid.
// I_frame_start is a standalone control cycle; samples follow it and the last
// sample asserts I_frame_end. The history array is intentionally only the
// 160x120 sampled ROI, not a full video frame. The array is written after the
// old value is used, so a sample is never compared with its just-written value.
module motion_diff_160 #(
  parameter integer IMG_WIDTH       = 160,
  parameter integer IMG_HEIGHT      = 120,
  parameter integer THRESHOLD       = 8,
  parameter integer COUNT_WIDTH     = 24,
  parameter integer FRAME_ID_WIDTH  = 16,
  parameter integer X_WIDTH         = (IMG_WIDTH <= 1) ? 1 : $clog2(IMG_WIDTH),
  parameter integer Y_WIDTH         = (IMG_HEIGHT <= 1) ? 1 : $clog2(IMG_HEIGHT)
)(
  input  wire                         I_clk,
  input  wire                         I_rst_n,
  input  wire                         I_frame_start,
  input  wire                         I_frame_end,
  input  wire                         I_sample_valid,
  input  wire [FRAME_ID_WIDTH-1:0]    I_frame_id,
  input  wire [X_WIDTH-1:0]            I_sample_x,
  input  wire [Y_WIDTH-1:0]            I_sample_y,
  input  wire [7:0]                    I_y_value,
  output reg                          O_summary_valid,
  output reg                          O_baseline_ready,
  output reg                          O_motion_valid,
  output reg                          O_motion,
  output reg  [COUNT_WIDTH-1:0]        O_motion_count,
  output reg  [X_WIDTH-1:0]            O_xmin,
  output reg  [X_WIDTH-1:0]            O_xmax,
  output reg  [Y_WIDTH-1:0]            O_ymin,
  output reg  [Y_WIDTH-1:0]            O_ymax,
  output reg                          O_frame_gap,
  output reg                          O_invalid
);

  localparam integer DEPTH = IMG_WIDTH * IMG_HEIGHT;
  localparam integer ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam integer SAMPLE_COUNT_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH + 1);

  // The vendor-independent branch is suitable for simulation and synthesis
  // inference. A later TD-specific resource trial may replace this storage
  // with the PH1P native ERAM wrapper without changing the stream contract.
  (* ram_style = "block" *) reg [7:0] history_mem [0:DEPTH-1];

  reg                         have_history;
  reg [FRAME_ID_WIDTH-1:0]    last_frame_id;
  reg [FRAME_ID_WIDTH-1:0]    active_frame_id;
  reg                         frame_active;
  reg                         frame_compare_valid;
  reg                         frame_gap_latched;
  reg                         frame_invalid;
  reg                         frame_sample_seen;
  reg [SAMPLE_COUNT_WIDTH-1:0] sample_count;
  reg [COUNT_WIDTH-1:0]       motion_count_accum;
  reg                         motion_seen;
  reg [X_WIDTH-1:0]           xmin_accum;
  reg [X_WIDTH-1:0]           xmax_accum;
  reg [Y_WIDTH-1:0]           ymin_accum;
  reg [Y_WIDTH-1:0]           ymax_accum;

  wire sample_coord_valid = (I_sample_x < IMG_WIDTH) &&
                            (I_sample_y < IMG_HEIGHT);
  wire [ADDR_WIDTH-1:0] sample_addr = I_sample_y * IMG_WIDTH + I_sample_x;
  wire [7:0] history_value = sample_coord_valid ? history_mem[sample_addr] : 8'd0;
  wire [8:0] abs_diff = (I_y_value >= history_value) ?
                        ({1'b0, I_y_value} - {1'b0, history_value}) :
                        ({1'b0, history_value} - {1'b0, I_y_value});
  wire frame_gap_now = have_history &&
                       (I_frame_id != (last_frame_id +
                         {{(FRAME_ID_WIDTH-1){1'b0}}, 1'b1}));
  wire current_sample_valid = I_sample_valid && frame_active &&
                              sample_coord_valid;
  wire motion_now = current_sample_valid && frame_compare_valid &&
                    (abs_diff > THRESHOLD);
  wire [SAMPLE_COUNT_WIDTH-1:0] final_sample_count =
      sample_count + (current_sample_valid ?
        {{(SAMPLE_COUNT_WIDTH-1){1'b0}}, 1'b1} :
        {SAMPLE_COUNT_WIDTH{1'b0}});
  wire final_sample_seen = frame_sample_seen || current_sample_valid;
  wire final_invalid = frame_invalid || !current_sample_valid ||
                       (final_sample_count != DEPTH);
  wire [COUNT_WIDTH-1:0] final_motion_count =
      motion_count_accum + (motion_now ?
        {{(COUNT_WIDTH-1){1'b0}}, 1'b1} :
        {COUNT_WIDTH{1'b0}});
  wire final_motion_seen = motion_seen || motion_now;
  wire [X_WIDTH-1:0] next_xmin = motion_now ?
      (motion_seen ? ((I_sample_x < xmin_accum) ? I_sample_x : xmin_accum) : I_sample_x) :
      xmin_accum;
  wire [X_WIDTH-1:0] next_xmax = motion_now ?
      (motion_seen ? ((I_sample_x > xmax_accum) ? I_sample_x : xmax_accum) : I_sample_x) :
      xmax_accum;
  wire [Y_WIDTH-1:0] next_ymin = motion_now ?
      (motion_seen ? ((I_sample_y < ymin_accum) ? I_sample_y : ymin_accum) : I_sample_y) :
      ymin_accum;
  wire [Y_WIDTH-1:0] next_ymax = motion_now ?
      (motion_seen ? ((I_sample_y > ymax_accum) ? I_sample_y : ymax_accum) : I_sample_y) :
      ymax_accum;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      have_history        <= 1'b0;
      last_frame_id       <= {FRAME_ID_WIDTH{1'b0}};
      active_frame_id     <= {FRAME_ID_WIDTH{1'b0}};
      frame_active        <= 1'b0;
      frame_compare_valid <= 1'b0;
      frame_gap_latched   <= 1'b0;
      frame_invalid       <= 1'b0;
      frame_sample_seen   <= 1'b0;
      sample_count        <= {SAMPLE_COUNT_WIDTH{1'b0}};
      motion_count_accum  <= {COUNT_WIDTH{1'b0}};
      motion_seen         <= 1'b0;
      xmin_accum          <= {X_WIDTH{1'b0}};
      xmax_accum          <= {X_WIDTH{1'b0}};
      ymin_accum          <= {Y_WIDTH{1'b0}};
      ymax_accum          <= {Y_WIDTH{1'b0}};
      O_summary_valid     <= 1'b0;
      O_baseline_ready    <= 1'b0;
      O_motion_valid      <= 1'b0;
      O_motion            <= 1'b0;
      O_motion_count      <= {COUNT_WIDTH{1'b0}};
      O_xmin              <= {X_WIDTH{1'b0}};
      O_xmax              <= {X_WIDTH{1'b0}};
      O_ymin              <= {Y_WIDTH{1'b0}};
      O_ymax              <= {Y_WIDTH{1'b0}};
      O_frame_gap         <= 1'b0;
      O_invalid           <= 1'b0;
    end else begin
      O_summary_valid  <= 1'b0;
      O_baseline_ready <= 1'b0;
      O_motion_valid   <= 1'b0;
      O_motion         <= 1'b0;
      O_motion_count   <= {COUNT_WIDTH{1'b0}};
      O_xmin           <= {X_WIDTH{1'b0}};
      O_xmax           <= {X_WIDTH{1'b0}};
      O_ymin           <= {Y_WIDTH{1'b0}};
      O_ymax           <= {Y_WIDTH{1'b0}};
      O_frame_gap      <= 1'b0;
      O_invalid        <= 1'b0;

      // Frame start is a standalone cycle so the history decision is stable
      // for every sample in the frame.
      if (I_frame_start) begin
        frame_active        <= 1'b1;
        active_frame_id     <= I_frame_id;
        frame_gap_latched   <= frame_gap_now;
        frame_compare_valid <= have_history && !frame_gap_now;
        frame_invalid       <= 1'b0;
        frame_sample_seen   <= 1'b0;
        sample_count        <= {SAMPLE_COUNT_WIDTH{1'b0}};
        motion_count_accum  <= {COUNT_WIDTH{1'b0}};
        motion_seen         <= 1'b0;
        xmin_accum          <= {X_WIDTH{1'b0}};
        xmax_accum          <= {X_WIDTH{1'b0}};
        ymin_accum          <= {Y_WIDTH{1'b0}};
        ymax_accum          <= {Y_WIDTH{1'b0}};
      end

      if (I_sample_valid) begin
        if (!frame_active) begin
          frame_invalid <= 1'b1;
        end else if (!sample_coord_valid) begin
          frame_invalid <= 1'b1;
        end else begin
          history_mem[sample_addr] <= I_y_value;
          frame_sample_seen        <= 1'b1;
          sample_count             <= sample_count +
                                      {{(SAMPLE_COUNT_WIDTH-1){1'b0}}, 1'b1};
          if (motion_now) begin
            motion_count_accum <= final_motion_count;
            motion_seen        <= 1'b1;
            xmin_accum         <= next_xmin;
            xmax_accum         <= next_xmax;
            ymin_accum         <= next_ymin;
            ymax_accum         <= next_ymax;
          end
        end
      end

      if (I_frame_end) begin
        O_frame_gap <= frame_gap_latched;
        if (!final_invalid && final_sample_seen) begin
          O_summary_valid  <= 1'b1;
          O_baseline_ready <= 1'b1;
          have_history     <= 1'b1;
          last_frame_id    <= active_frame_id;
          if (frame_compare_valid && !frame_gap_latched && have_history) begin
            O_motion_valid <= 1'b1;
            O_motion       <= final_motion_seen;
            O_motion_count <= final_motion_count;
            if (final_motion_seen) begin
              O_xmin <= next_xmin;
              O_xmax <= next_xmax;
              O_ymin <= next_ymin;
              O_ymax <= next_ymax;
            end
          end
        end else begin
          O_invalid <= 1'b1;
        end
        frame_active        <= 1'b0;
        frame_compare_valid <= 1'b0;
        frame_invalid       <= 1'b0;
        frame_sample_seen   <= 1'b0;
      end
    end
  end
endmodule
