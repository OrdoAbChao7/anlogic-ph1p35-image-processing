`define MOTION_DIFF_USE_PH1P_HISTORY_ERAM 1
`timescale 1ns/1ps

// Isolated G8-R1 candidate. A committed history bank is read while the other
// bank receives the current frame. Both read data and pixel metadata pass
// through a one-cycle synchronous-read pipeline; the frame-end decision waits
// for the final in-flight sample before atomically swapping banks.
module motion_diff_160 #(
  parameter integer IMG_WIDTH       = 160,
  parameter integer IMG_HEIGHT      = 120,
  parameter integer THRESHOLD       = 8,
  parameter integer COUNT_WIDTH     = 24,
  parameter integer FRAME_ID_WIDTH  = 16,
`ifdef MOTION_DIFF_USE_PH1P_HISTORY_ERAM
  parameter integer USE_PH1P_HISTORY_ERAM = 1,
`else
  parameter integer USE_PH1P_HISTORY_ERAM = 0,
`endif
  parameter integer X_WIDTH         = (IMG_WIDTH <= 1) ? 1 : $clog2(IMG_WIDTH),
  parameter integer Y_WIDTH         = (IMG_HEIGHT <= 1) ? 1 : $clog2(IMG_HEIGHT)
)(
  input  wire                         I_clk,
  input  wire                         I_rst_n,
  input  wire                         I_frame_start,
  input  wire                         I_frame_end,
  input  wire                         I_sample_valid,
  input  wire                         I_frame_invalid,
  input  wire [FRAME_ID_WIDTH-1:0]    I_frame_id,
  input  wire [X_WIDTH-1:0]           I_sample_x,
  input  wire [Y_WIDTH-1:0]           I_sample_y,
  input  wire [7:0]                   I_y_value,
  output reg                          O_summary_valid,
  output reg                          O_baseline_ready,
  output reg                          O_motion_valid,
  output reg                          O_motion,
  output reg  [COUNT_WIDTH-1:0]       O_motion_count,
  output reg  [X_WIDTH-1:0]           O_xmin,
  output reg  [X_WIDTH-1:0]           O_xmax,
  output reg  [Y_WIDTH-1:0]           O_ymin,
  output reg  [Y_WIDTH-1:0]           O_ymax,
  output reg                          O_frame_gap,
  output reg                          O_invalid
);

  localparam integer DEPTH = IMG_WIDTH * IMG_HEIGHT;
  localparam integer ADDR_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH);
  localparam integer SAMPLE_COUNT_WIDTH = (DEPTH <= 1) ? 1 : $clog2(DEPTH + 1);
  localparam integer MOTION_ACCUM_WIDTH =
      (COUNT_WIDTH < SAMPLE_COUNT_WIDTH) ? COUNT_WIDTH : SAMPLE_COUNT_WIDTH;

  reg                         have_history;
  reg                         active_bank;
  reg [FRAME_ID_WIDTH-1:0]    last_frame_id;
  reg [FRAME_ID_WIDTH-1:0]    active_frame_id;
  reg                         frame_active;
  reg                         frame_compare_valid;
  reg                         frame_gap_latched;
  reg                         frame_invalid;
  reg [SAMPLE_COUNT_WIDTH-1:0] issued_sample_count;
  reg [SAMPLE_COUNT_WIDTH-1:0] processed_sample_count;
  reg [MOTION_ACCUM_WIDTH-1:0] motion_count_accum;
  reg                         motion_seen;
  reg [X_WIDTH-1:0]           xmin_accum;
  reg [X_WIDTH-1:0]           xmax_accum;
  reg [Y_WIDTH-1:0]           ymin_accum;
  reg [Y_WIDTH-1:0]           ymax_accum;

  reg                         sample_pipe_valid;
  reg                         sample_pipe_compare_valid;
  reg [7:0]                   sample_pipe_value;
  reg [X_WIDTH-1:0]           sample_pipe_x;
  reg [Y_WIDTH-1:0]           sample_pipe_y;
  wire [7:0]                  history_read_data;
  reg                         frame_end_d;
  reg                         frame_end_invalid_d;

  wire sample_coord_valid = (I_sample_x < IMG_WIDTH) &&
                            (I_sample_y < IMG_HEIGHT);
  wire [ADDR_WIDTH-1:0] sample_addr = I_sample_y * IMG_WIDTH + I_sample_x;
  wire [ADDR_WIDTH-1:0] history_addr = sample_coord_valid ?
      sample_addr : {ADDR_WIDTH{1'b0}};
  wire sample_sequence_valid = (issued_sample_count < DEPTH) &&
                               (sample_addr == issued_sample_count);
  wire input_sample_valid = I_sample_valid && frame_active &&
                            !I_frame_start && sample_coord_valid &&
                            sample_sequence_valid && !frame_invalid &&
                            !I_frame_invalid;
  wire input_sample_bad = I_sample_valid && !input_sample_valid;
  wire history_write_en = input_sample_valid;

  // Each bank is read synchronously while the opposite bank is written. Thus
  // no physical bank sees a read/write collision on a sample cycle.
  generate
    if (USE_PH1P_HISTORY_ERAM != 0) begin : g_ph1p_history_eram
      wire [7:0] read_data_a;
      wire [7:0] read_data_b;
      wire write_a = history_write_en && active_bank;
      wire write_b = history_write_en && !active_bank;
`ifdef MOTION_ERAM_SIMULATION
      (* ram_style = "block" *) reg [7:0] history_mem_a [0:DEPTH-1];
      (* ram_style = "block" *) reg [7:0] history_mem_b [0:DEPTH-1];
      reg [7:0] read_data_a_reg;
      reg [7:0] read_data_b_reg;
      always @(posedge I_clk) begin
        if (sample_coord_valid) begin
          read_data_a_reg <= history_mem_a[history_addr];
          read_data_b_reg <= history_mem_b[history_addr];
        end else begin
          read_data_a_reg <= 8'd0;
          read_data_b_reg <= 8'd0;
        end
        if (write_a)
          history_mem_a[history_addr] <= I_y_value;
        if (write_b)
          history_mem_b[history_addr] <= I_y_value;
      end
      assign read_data_a = read_data_a_reg;
      assign read_data_b = read_data_b_reg;
`else
      PH1P_LOGIC_ERAM #(
        .DATA_WIDTH_A(8), .DATA_WIDTH_B(8),
        .ADDR_WIDTH_A(ADDR_WIDTH), .ADDR_WIDTH_B(ADDR_WIDTH),
        .DATA_DEPTH_A(DEPTH), .DATA_DEPTH_B(DEPTH),
        .MODE("SP"), .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
        .WRITEMODE_A("READBEFOREWRITE"), .WRITEMODE_B("NORMAL"),
        .IMPLEMENT("20K(FAST)"), .ECC_ENCODE("DISABLE"),
        .ECC_DECODE("DISABLE"), .CLKMODE("ASYNC"),
        .SSROVERCE("DISABLE"), .OREGSET_A("RESET"),
        .OREGSET_B("RESET"), .RESETMODE_A("ASYNC"),
        .RESETMODE_B("ASYNC"), .ASYNC_RESET_RELEASE_A("ASYNC"),
        .ASYNC_RESET_RELEASE_B("ASYNC"), .INIT_FILE("NONE"),
        .FILL_ALL("NONE")
      ) history_ram_a (
        .dia(I_y_value), .dib(8'd0), .addra(history_addr),
        .addrb({ADDR_WIDTH{1'b0}}), .cea(1'b1), .ceb(1'b0),
        .ocea(1'b0), .oceb(1'b0), .clka(I_clk), .clkb(I_clk),
        .wea(write_a), .web(1'b0), .bea(1'b0), .beb(1'b0),
        .rsta(1'b0), .rstb(1'b0), .doa(read_data_a), .dob(),
        .ecc_sbiterr(), .ecc_dbiterr(),
        .ecc_sbiterrinj(1'b0), .ecc_dbiterrinj(1'b0)
      );
      PH1P_LOGIC_ERAM #(
        .DATA_WIDTH_A(8), .DATA_WIDTH_B(8),
        .ADDR_WIDTH_A(ADDR_WIDTH), .ADDR_WIDTH_B(ADDR_WIDTH),
        .DATA_DEPTH_A(DEPTH), .DATA_DEPTH_B(DEPTH),
        .MODE("SP"), .REGMODE_A("NOREG"), .REGMODE_B("NOREG"),
        .WRITEMODE_A("READBEFOREWRITE"), .WRITEMODE_B("NORMAL"),
        .IMPLEMENT("20K(FAST)"), .ECC_ENCODE("DISABLE"),
        .ECC_DECODE("DISABLE"), .CLKMODE("ASYNC"),
        .SSROVERCE("DISABLE"), .OREGSET_A("RESET"),
        .OREGSET_B("RESET"), .RESETMODE_A("ASYNC"),
        .RESETMODE_B("ASYNC"), .ASYNC_RESET_RELEASE_A("ASYNC"),
        .ASYNC_RESET_RELEASE_B("ASYNC"), .INIT_FILE("NONE"),
        .FILL_ALL("NONE")
      ) history_ram_b (
        .dia(I_y_value), .dib(8'd0), .addra(history_addr),
        .addrb({ADDR_WIDTH{1'b0}}), .cea(1'b1), .ceb(1'b0),
        .ocea(1'b0), .oceb(1'b0), .clka(I_clk), .clkb(I_clk),
        .wea(write_b), .web(1'b0), .bea(1'b0), .beb(1'b0),
        .rsta(1'b0), .rstb(1'b0), .doa(read_data_b), .dob(),
        .ecc_sbiterr(), .ecc_dbiterr(),
        .ecc_sbiterrinj(1'b0), .ecc_dbiterrinj(1'b0)
      );
`endif
      assign history_read_data = active_bank ? read_data_b : read_data_a;
    end else begin : g_inferred_history_ram
      (* ram_style = "block" *) reg [7:0] history_mem_a [0:DEPTH-1];
      (* ram_style = "block" *) reg [7:0] history_mem_b [0:DEPTH-1];
      reg [7:0] history_read_data_reg;
      always @(posedge I_clk) begin
        if (sample_coord_valid) begin
          if (active_bank)
            history_read_data_reg <= history_mem_b[history_addr];
          else
            history_read_data_reg <= history_mem_a[history_addr];
        end else begin
          history_read_data_reg <= 8'd0;
        end
        if (history_write_en) begin
          if (active_bank)
            history_mem_a[history_addr] <= I_y_value;
          else
            history_mem_b[history_addr] <= I_y_value;
        end
      end
      assign history_read_data = history_read_data_reg;
    end
  endgenerate

  wire [8:0] abs_diff = (sample_pipe_value >= history_read_data) ?
      ({1'b0, sample_pipe_value} - {1'b0, history_read_data}) :
      ({1'b0, history_read_data} - {1'b0, sample_pipe_value});
  wire [SAMPLE_COUNT_WIDTH-1:0] final_processed_count =
      processed_sample_count + (sample_pipe_valid ?
        {{(SAMPLE_COUNT_WIDTH-1){1'b0}}, 1'b1} :
        {SAMPLE_COUNT_WIDTH{1'b0}});
  wire frame_end_invalid = !frame_active || frame_invalid || frame_end_invalid_d ||
                           (issued_sample_count != DEPTH) ||
                           (final_processed_count != DEPTH);
  wire frame_end_commits = frame_end_d && !frame_end_invalid;
  wire [FRAME_ID_WIDTH-1:0] committed_frame_id_for_gap =
      frame_end_commits ? active_frame_id : last_frame_id;
  wire frame_gap_now = (have_history || frame_end_commits) &&
      (I_frame_id != (committed_frame_id_for_gap +
                      {{(FRAME_ID_WIDTH-1){1'b0}}, 1'b1}));
  wire motion_now = sample_pipe_valid && sample_pipe_compare_valid &&
                    (abs_diff > THRESHOLD);
  wire [MOTION_ACCUM_WIDTH-1:0] final_motion_count =
      motion_count_accum + (motion_now ?
        {{(MOTION_ACCUM_WIDTH-1){1'b0}}, 1'b1} :
        {MOTION_ACCUM_WIDTH{1'b0}});
  wire final_motion_seen = motion_seen || motion_now;
  wire [X_WIDTH-1:0] next_xmin = motion_now ?
      (motion_seen ? ((sample_pipe_x < xmin_accum) ? sample_pipe_x : xmin_accum) : sample_pipe_x) :
      xmin_accum;
  wire [X_WIDTH-1:0] next_xmax = motion_now ?
      (motion_seen ? ((sample_pipe_x > xmax_accum) ? sample_pipe_x : xmax_accum) : sample_pipe_x) :
      xmax_accum;
  wire [Y_WIDTH-1:0] next_ymin = motion_now ?
      (motion_seen ? ((sample_pipe_y < ymin_accum) ? sample_pipe_y : ymin_accum) : sample_pipe_y) :
      ymin_accum;
  wire [Y_WIDTH-1:0] next_ymax = motion_now ?
      (motion_seen ? ((sample_pipe_y > ymax_accum) ? sample_pipe_y : ymax_accum) : sample_pipe_y) :
      ymax_accum;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      have_history           <= 1'b0;
      active_bank            <= 1'b0;
      last_frame_id          <= {FRAME_ID_WIDTH{1'b0}};
      active_frame_id        <= {FRAME_ID_WIDTH{1'b0}};
      frame_active           <= 1'b0;
      frame_compare_valid    <= 1'b0;
      frame_gap_latched      <= 1'b0;
      frame_invalid          <= 1'b0;
      issued_sample_count    <= {SAMPLE_COUNT_WIDTH{1'b0}};
      processed_sample_count <= {SAMPLE_COUNT_WIDTH{1'b0}};
      motion_count_accum     <= {MOTION_ACCUM_WIDTH{1'b0}};
      motion_seen            <= 1'b0;
      xmin_accum             <= {X_WIDTH{1'b0}};
      xmax_accum             <= {X_WIDTH{1'b0}};
      ymin_accum             <= {Y_WIDTH{1'b0}};
      ymax_accum             <= {Y_WIDTH{1'b0}};
      sample_pipe_valid      <= 1'b0;
      sample_pipe_compare_valid <= 1'b0;
      sample_pipe_value      <= 8'd0;
      sample_pipe_x          <= {X_WIDTH{1'b0}};
      sample_pipe_y          <= {Y_WIDTH{1'b0}};
      frame_end_d            <= 1'b0;
      frame_end_invalid_d    <= 1'b0;
      O_summary_valid        <= 1'b0;
      O_baseline_ready       <= 1'b0;
      O_motion_valid         <= 1'b0;
      O_motion               <= 1'b0;
      O_motion_count         <= {COUNT_WIDTH{1'b0}};
      O_xmin                 <= {X_WIDTH{1'b0}};
      O_xmax                 <= {X_WIDTH{1'b0}};
      O_ymin                 <= {Y_WIDTH{1'b0}};
      O_ymax                 <= {Y_WIDTH{1'b0}};
      O_frame_gap            <= 1'b0;
      O_invalid              <= 1'b0;
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

      sample_pipe_valid <= input_sample_valid;
      if (input_sample_valid) begin
        sample_pipe_compare_valid <= frame_compare_valid;
        sample_pipe_value <= I_y_value;
        sample_pipe_x <= I_sample_x;
        sample_pipe_y <= I_sample_y;
        issued_sample_count <= issued_sample_count + 1'b1;
      end

      if (sample_pipe_valid && frame_active && (!I_frame_start || frame_end_d)) begin
        processed_sample_count <= processed_sample_count + 1'b1;
        if (motion_now) begin
          motion_count_accum <= final_motion_count;
          motion_seen <= 1'b1;
          xmin_accum <= next_xmin;
          xmax_accum <= next_xmax;
          ymin_accum <= next_ymin;
          ymax_accum <= next_ymax;
        end
      end

      if (I_frame_start) begin
        // A back-to-back SOF can arrive on the cycle a deferred frame_end is
        // retired. Publish/commit the previous frame first, then initialize
        // the new frame below; otherwise the SOF branch would discard the
        // pending transaction and falsely mark the new frame invalid.
        if (frame_end_d) begin
          O_frame_gap <= !frame_end_invalid && frame_gap_latched;
          if (!frame_end_invalid) begin
            O_summary_valid  <= 1'b1;
            O_baseline_ready <= 1'b1;
            have_history     <= 1'b1;
            active_bank      <= !active_bank;
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
            O_baseline_ready <= have_history;
            O_invalid <= 1'b1;
          end
        end else if (frame_active) begin
          O_invalid        <= 1'b1;
          O_baseline_ready <= have_history;
        end
        frame_active           <= 1'b1;
        active_frame_id        <= I_frame_id;
        frame_gap_latched      <= frame_gap_now;
        frame_compare_valid    <= (have_history || frame_end_commits) &&
                                  !frame_gap_now;
        frame_invalid          <= I_frame_invalid || I_sample_valid;
        issued_sample_count    <= {SAMPLE_COUNT_WIDTH{1'b0}};
        processed_sample_count <= {SAMPLE_COUNT_WIDTH{1'b0}};
        motion_count_accum     <= {MOTION_ACCUM_WIDTH{1'b0}};
        motion_seen            <= 1'b0;
        xmin_accum             <= {X_WIDTH{1'b0}};
        xmax_accum             <= {X_WIDTH{1'b0}};
        ymin_accum             <= {Y_WIDTH{1'b0}};
        ymax_accum             <= {Y_WIDTH{1'b0}};
        sample_pipe_valid      <= 1'b0;
        sample_pipe_compare_valid <= 1'b0;
        frame_end_d            <= 1'b0;
        frame_end_invalid_d    <= 1'b0;
      end else begin
        if (input_sample_bad || I_frame_invalid)
          frame_invalid <= 1'b1;

        frame_end_d <= I_frame_end;
        if (I_frame_end)
          frame_end_invalid_d <= frame_invalid || input_sample_bad || I_frame_invalid;
        else
          frame_end_invalid_d <= 1'b0;

        if (frame_end_d) begin
          O_frame_gap <= !frame_end_invalid && frame_gap_latched;
          if (!frame_end_invalid) begin
            O_summary_valid  <= 1'b1;
            O_baseline_ready <= 1'b1;
            have_history     <= 1'b1;
            active_bank      <= !active_bank;
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
            O_baseline_ready <= have_history;
            O_invalid <= 1'b1;
          end
          frame_active           <= 1'b0;
          frame_compare_valid    <= 1'b0;
          frame_invalid          <= 1'b0;
          issued_sample_count    <= {SAMPLE_COUNT_WIDTH{1'b0}};
          processed_sample_count <= {SAMPLE_COUNT_WIDTH{1'b0}};
          motion_count_accum     <= {MOTION_ACCUM_WIDTH{1'b0}};
          motion_seen            <= 1'b0;
          sample_pipe_valid      <= 1'b0;
          sample_pipe_compare_valid <= 1'b0;
          frame_end_d            <= 1'b0;
          frame_end_invalid_d    <= 1'b0;
        end
      end
    end
  end
endmodule
