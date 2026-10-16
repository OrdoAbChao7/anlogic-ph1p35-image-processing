`timescale 1ns / 1ps
// ============================================================================
// Streaming 3x3 morphology for a four-pixel-per-cycle binary video stream.
//
// Contract:
//   * I_tuser starts a frame and may be asserted without I_tvalid.
//   * I_tlast marks the final group of a row.  The fixed raster parameters are
//     authoritative for the row/frame counters; malformed rasters are reported
//     through O_invalid.
//   * The module emits exactly IMG_WIDTH/4 groups for each of IMG_HEIGHT rows.
//     It drains a replicated bottom row internally before O_frame_end pulses.
//   * The two row memories hold one bit per pixel group (four bits per word).
//     No full-frame register or memory is used.
//   * Border policy is BORDER_REPLICATE, including the ROI/image boundary that
//     is presented to this module.
//
// OPERATION=0: erosion (3x3 AND)
// OPERATION=1: dilation (3x3 OR)
// ============================================================================

module morph_filter_96 #(
  parameter integer IMG_WIDTH  = 1280,
  parameter integer IMG_HEIGHT = 720,
  parameter integer OPERATION  = 0
)(
  input  wire       I_clk,
  input  wire       I_rst_n,
  input  wire       I_tvalid,
  input  wire       I_tlast,
  input  wire       I_tuser,
  input  wire [3:0] I_mask,

  output reg        O_tvalid,
  output reg        O_tlast,
  output reg        O_tuser,
  output reg  [3:0] O_mask,
  output reg        O_frame_end,
  output reg        O_invalid
);

  localparam integer GROUPS = IMG_WIDTH / 4;
  localparam integer GROUP_BITS = (GROUPS <= 1) ? 1 : $clog2(GROUPS + 1);

  // Ping-pong row memories.  A word contains four binary pixels.
  reg [3:0] row_mem0 [0:GROUPS-1];
  reg [3:0] row_mem1 [0:GROUPS-1];

  reg                    active;
  reg                    virtual_row;
  reg                    flush_pending;
  reg [11:0]             row_index;
  reg [GROUP_BITS-1:0]  group_index;
  reg [GROUP_BITS-1:0]  last_group_index;
  reg                    seen_last;

  reg [3:0] left_top,  left_mid,  left_bot;
  reg [3:0] prev_top,  prev_mid,  prev_bot;

  wire [3:0] mem0_group = row_mem0[group_index];
  wire [3:0] mem1_group = row_mem1[group_index];

  // The current triplet is the vertical window for the row being accepted.
  // For row zero no previous row exists, so the current row is replicated.
  // For the synthetic bottom row, the last captured row is replicated.
  reg [3:0] cur_top;
  reg [3:0] cur_mid;
  reg [3:0] cur_bot;
  always @* begin
    cur_top = 4'd0;
    cur_mid = 4'd0;
    cur_bot = 4'd0;

    if (virtual_row) begin
      if (IMG_HEIGHT <= 1) begin
        cur_top = row_mem0[group_index];
        cur_mid = row_mem0[group_index];
        cur_bot = row_mem0[group_index];
      end else if (((IMG_HEIGHT - 2) & 1) == 1) begin
        cur_top = row_mem1[group_index];
        cur_mid = row_mem0[group_index];
        cur_bot = row_mem0[group_index];
      end else begin
        cur_top = row_mem0[group_index];
        cur_mid = row_mem1[group_index];
        cur_bot = row_mem1[group_index];
      end
    end else if (row_index == 0) begin
      cur_top = I_mask;
      cur_mid = I_mask;
      cur_bot = I_mask;
    end else if (row_index == 1) begin
      cur_top = mem0_group;
      cur_mid = mem0_group;
      cur_bot = I_mask;
    end else if ((row_index & 1'b1) == 1'b1) begin
      // Odd input row: row r-2 is row_mem1, row r-1 is row_mem0.
      cur_top = mem1_group;
      cur_mid = mem0_group;
      cur_bot = I_mask;
    end else begin
      // Even input row: row r-2 is row_mem0, row r-1 is row_mem1.
      cur_top = mem0_group;
      cur_mid = mem1_group;
      cur_bot = I_mask;
    end
  end

  // Apply one 3x3 operation to four horizontally adjacent output pixels.
  // tl/tc/tr are top-row groups, ml/mc/mr middle-row groups, and bl/bc/br
  // bottom-row groups.  The edge flags select replicated horizontal borders.
  function [3:0] morph_group;
    input [3:0] tl, tc, tr;
    input [3:0] ml, mc, mr;
    input [3:0] bl, bc, br;
    input       left_edge;
    input       right_edge;
    integer i;
    reg top_l, top_c, top_r;
    reg mid_l, mid_c, mid_r;
    reg bot_l, bot_c, bot_r;
    begin
      for (i = 0; i < 4; i = i + 1) begin
        top_c = tc[i];
        mid_c = mc[i];
        bot_c = bc[i];

        if (i == 0)
          top_l = left_edge ? tc[0] : tl[3];
        else
          top_l = tc[i-1];
        if (i == 3)
          top_r = right_edge ? tc[3] : tr[0];
        else
          top_r = tc[i+1];

        if (i == 0)
          mid_l = left_edge ? mc[0] : ml[3];
        else
          mid_l = mc[i-1];
        if (i == 3)
          mid_r = right_edge ? mc[3] : mr[0];
        else
          mid_r = mc[i+1];

        if (i == 0)
          bot_l = left_edge ? bc[0] : bl[3];
        else
          bot_l = bc[i-1];
        if (i == 3)
          bot_r = right_edge ? bc[3] : br[0];
        else
          bot_r = bc[i+1];

        if (OPERATION == 0)
          morph_group[i] = top_l & top_c & top_r &
                           mid_l & mid_c & mid_r &
                           bot_l & bot_c & bot_r;
        else
          morph_group[i] = top_l | top_c | top_r |
                           mid_l | mid_c | mid_r |
                           bot_l | bot_c | bot_r;
      end
    end
  endfunction

  wire process_group = active && !flush_pending &&
                        (virtual_row || I_tvalid);
  wire [3:0] next_mask = morph_group(
      left_top, prev_top, cur_top,
      left_mid, prev_mid, cur_mid,
      left_bot, prev_bot, cur_bot,
      (group_index == 1), 1'b0);
  wire [3:0] last_mask = morph_group(
      left_top, prev_top, prev_top,
      left_mid, prev_mid, prev_mid,
      left_bot, prev_bot, prev_bot,
      (GROUPS == 1), 1'b1);

  // When the source has no blank cycle between rows, the last group of the
  // previous row is emitted while group zero of the next row is captured.
  wire [3:0] next_row_top = ((row_index + 1) == 1) ? row_mem0[0] :
                             (((row_index + 1) & 1'b1) ? row_mem1[0] : row_mem0[0]);
  wire [3:0] next_row_mid = ((row_index + 1) == 1) ? row_mem0[0] :
                             (((row_index + 1) & 1'b1) ? row_mem0[0] : row_mem1[0]);
  wire [3:0] next_row_bot = I_mask;

  integer k;
  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      active          <= 1'b0;
      virtual_row     <= 1'b0;
      flush_pending   <= 1'b0;
      row_index       <= 12'd0;
      group_index     <= {GROUP_BITS{1'b0}};
      last_group_index<= {GROUP_BITS{1'b0}};
      seen_last       <= 1'b0;
      left_top        <= 4'd0;
      left_mid        <= 4'd0;
      left_bot        <= 4'd0;
      prev_top        <= 4'd0;
      prev_mid        <= 4'd0;
      prev_bot        <= 4'd0;
      O_tvalid        <= 1'b0;
      O_tlast         <= 1'b0;
      O_tuser         <= 1'b0;
      O_mask          <= 4'd0;
      O_frame_end     <= 1'b0;
      O_invalid       <= 1'b0;
      for (k = 0; k < GROUPS; k = k + 1) begin
        row_mem0[k] <= 4'd0;
        row_mem1[k] <= 4'd0;
      end
    end else begin
      O_tvalid    <= 1'b0;
      O_tlast     <= 1'b0;
      O_tuser     <= 1'b0;
      O_frame_end <= 1'b0;
      O_invalid   <= 1'b0;

      // A new SOF is accepted only while the previous frame is fully drained.
      // A SOF before the drain is a real contract violation, not a silent reset.
      if (I_tuser && active) begin
        O_invalid <= 1'b1;
      end

      if (!active) begin
        if (I_tuser) begin
          active        <= 1'b1;
          virtual_row   <= 1'b0;
          flush_pending <= 1'b0;
          row_index     <= 12'd0;
          group_index   <= {GROUP_BITS{1'b0}};
          seen_last     <= 1'b0;

          // Support SOF accompanying the first group.  Row zero produces no
          // output until row one arrives, but it is captured immediately.
          if (I_tvalid) begin
            row_mem0[0] <= I_mask;
            left_top    <= I_mask;
            left_mid    <= I_mask;
            left_bot    <= I_mask;
            prev_top    <= I_mask;
            prev_mid    <= I_mask;
            prev_bot    <= I_mask;
            if (GROUPS == 1)
              flush_pending <= 1'b1;
            else
              group_index <= {{(GROUP_BITS-1){1'b0}},1'b1};
          end
        end
      end else if (flush_pending) begin
        // The rightmost group is emitted with its right edge replicated.
        // Row zero is only a capture row; row one and later produce output.
        if (row_index != 0) begin
          O_tvalid <= 1'b1;
          O_tlast  <= 1'b1;
          O_mask   <= last_mask;
          O_tuser  <= ((row_index == 1) && (GROUPS == 1)) ||
                      (virtual_row && (IMG_HEIGHT == 1) && (GROUPS == 1));
          if (virtual_row)
            O_frame_end <= 1'b1;
        end

        // Consume next-row group zero in this same cycle whenever the input
        // stream is continuous.  This preserves one accepted group per clock
        // except for the internally generated bottom-row drain.
        if (!virtual_row && (row_index < IMG_HEIGHT-1) &&
            I_tvalid && !I_tuser) begin
          if (((row_index + 1) & 1'b1) == 1'b0)
            row_mem0[0] <= I_mask;
          else
            row_mem1[0] <= I_mask;
          if (I_tlast && (GROUPS != 1))
            O_invalid <= 1'b1;
          left_top <= next_row_top;
          left_mid <= next_row_mid;
          left_bot <= next_row_bot;
          prev_top <= next_row_top;
          prev_mid <= next_row_mid;
          prev_bot <= next_row_bot;
          row_index <= row_index + 12'd1;
          if (GROUPS == 1) begin
            group_index <= {GROUP_BITS{1'b0}};
            flush_pending <= 1'b1;
          end else begin
            group_index <= {{(GROUP_BITS-1){1'b0}},1'b1};
            flush_pending <= 1'b0;
          end
        end else begin
          flush_pending <= 1'b0;
          group_index   <= {GROUP_BITS{1'b0}};
          left_top      <= 4'd0;
          left_mid      <= 4'd0;
          left_bot      <= 4'd0;
          prev_top      <= 4'd0;
          prev_mid      <= 4'd0;
          prev_bot      <= 4'd0;

          if (virtual_row) begin
            active      <= 1'b0;
            virtual_row <= 1'b0;
          end else if (row_index == IMG_HEIGHT-1) begin
            // Feed one internally generated replicated bottom row.
            virtual_row <= 1'b1;
            row_index   <= IMG_HEIGHT;
          end else begin
            row_index <= row_index + 12'd1;
          end
        end
      end else if (process_group) begin
        if (!virtual_row) begin
          if (row_index < IMG_HEIGHT) begin
            if ((row_index & 1'b1) == 1'b0)
              row_mem0[group_index] <= I_mask;
            else
              row_mem1[group_index] <= I_mask;
          end
          if (I_tlast && (group_index != GROUPS-1))
            O_invalid <= 1'b1;
          if (!I_tlast && (group_index == GROUPS-1))
            O_invalid <= 1'b1;
          if (I_tlast)
            seen_last <= 1'b1;
        end

        if (group_index == 0) begin
          left_top <= cur_top;
          left_mid <= cur_mid;
          left_bot <= cur_bot;
          prev_top <= cur_top;
          prev_mid <= cur_mid;
          prev_bot <= cur_bot;
          if (GROUPS == 1)
            flush_pending <= 1'b1;
          else
            group_index <= {{(GROUP_BITS-1){1'b0}},1'b1};
        end else begin
          if (row_index != 0) begin
            O_tvalid <= 1'b1;
            O_mask   <= next_mask;
            O_tuser  <= (row_index == 1) && (group_index == 1);
          end
          left_top  <= prev_top;
          left_mid  <= prev_mid;
          left_bot  <= prev_bot;
          prev_top  <= cur_top;
          prev_mid  <= cur_mid;
          prev_bot  <= cur_bot;

          if (group_index == GROUPS-1)
            flush_pending <= 1'b1;
          else
            group_index <= group_index + {{(GROUP_BITS-1){1'b0}},1'b1};
        end
      end
    end
  end

endmodule


module morph_open_96 #(
  parameter integer IMG_WIDTH  = 1280,
  parameter integer IMG_HEIGHT = 720
)(
  input  wire       I_clk,
  input  wire       I_rst_n,
  input  wire       I_tvalid,
  input  wire       I_tlast,
  input  wire       I_tuser,
  input  wire [3:0] I_mask,
  output wire       O_tvalid,
  output wire       O_tlast,
  output wire       O_tuser,
  output wire [3:0] O_mask,
  output wire       O_frame_end,
  output wire       O_invalid
);
  wire erode_valid, erode_last, erode_user, erode_frame_end, erode_invalid;
  wire dilate_invalid;
  wire [3:0] erode_mask;

  morph_filter_96 #(
    .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .OPERATION(0)
  ) u_erode (
    .I_clk(I_clk), .I_rst_n(I_rst_n),
    .I_tvalid(I_tvalid), .I_tlast(I_tlast), .I_tuser(I_tuser), .I_mask(I_mask),
    .O_tvalid(erode_valid), .O_tlast(erode_last), .O_tuser(erode_user),
    .O_mask(erode_mask), .O_frame_end(erode_frame_end), .O_invalid(erode_invalid)
  );

  morph_filter_96 #(
    .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT), .OPERATION(1)
  ) u_dilate (
    .I_clk(I_clk), .I_rst_n(I_rst_n),
    .I_tvalid(erode_valid), .I_tlast(erode_last), .I_tuser(erode_user),
    .I_mask(erode_mask),
    .O_tvalid(O_tvalid), .O_tlast(O_tlast), .O_tuser(O_tuser), .O_mask(O_mask),
    .O_frame_end(O_frame_end), .O_invalid(dilate_invalid)
  );

  // Preserve an error raised by the first pass until the detector's frame
  // accumulator observes it.  The pulse is intentionally not hidden by the
  // second pass's valid cadence.
  assign O_invalid = erode_invalid | dilate_invalid;
endmodule
