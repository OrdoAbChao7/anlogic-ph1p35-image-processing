`timescale 1ns/1ps

// Isolated R1 candidate: sparse motion samples remain provisional until the
// complete raw raster has ended. O_frame_invalid stays asserted from the
// first stream-contract error through O_frame_end so the motion transaction
// cannot commit a frame whose unselected tail was malformed.
module motion_grid_adapter_96 #(
  parameter integer INPUT_WIDTH  = 1280,
  parameter integer INPUT_HEIGHT = 720,
  parameter integer GRID_WIDTH   = 160,
  parameter integer GRID_HEIGHT  = 120,
  parameter integer X_STEP       = 8,
  parameter integer Y_STEP       = 6,
  parameter integer FRAME_ID_WIDTH = 16
)(
  input  wire                         I_clk,
  input  wire                         I_rst_n,
  input  wire                         I_tuser,
  input  wire                         I_tlast,
  input  wire                         I_tvalid,
  input  wire [FRAME_ID_WIDTH-1:0]    I_frame_id,
  input  wire [95:0]                  I_tdata,
  output reg                          O_frame_start,
  output reg                          O_frame_end,
  output reg                          O_sample_valid,
  output reg  [FRAME_ID_WIDTH-1:0]    O_frame_id,
  output reg  [((GRID_WIDTH <= 1) ? 1 : $clog2(GRID_WIDTH))-1:0] O_sample_x,
  output reg  [((GRID_HEIGHT <= 1) ? 1 : $clog2(GRID_HEIGHT))-1:0] O_sample_y,
  output reg  [7:0]                   O_y_value,
  output reg                          O_invalid,
  output reg                          O_frame_invalid
);

  localparam integer PIXELS_PER_GROUP = 4;
  localparam integer GROUPS_PER_LINE  = INPUT_WIDTH / PIXELS_PER_GROUP;
  localparam integer GROUP_STEP       = X_STEP / PIXELS_PER_GROUP;
  localparam integer GROUP_X_WIDTH    = (GROUPS_PER_LINE <= 1) ? 1 : $clog2(GROUPS_PER_LINE);
  localparam integer ROW_WIDTH        = (INPUT_HEIGHT <= 1) ? 1 : $clog2(INPUT_HEIGHT);
  localparam integer GRID_X_WIDTH     = (GRID_WIDTH <= 1) ? 1 : $clog2(GRID_WIDTH);
  localparam integer GRID_Y_WIDTH     = (GRID_HEIGHT <= 1) ? 1 : $clog2(GRID_HEIGHT);
  localparam integer TOTAL_BEATS      = GROUPS_PER_LINE * INPUT_HEIGHT;
  localparam integer BEAT_COUNT_WIDTH = (TOTAL_BEATS <= 1) ? 1 : $clog2(TOTAL_BEATS + 1);

  reg [GROUP_X_WIDTH-1:0] current_group_x;
  reg [ROW_WIDTH-1:0]     current_row_y;
  reg [GROUP_X_WIDTH-1:0] hold_group_x;
  reg [ROW_WIDTH-1:0]     hold_row_y;
  reg [FRAME_ID_WIDTH-1:0] hold_frame_id;
  reg [95:0]              hold_data;
  reg                     hold_valid;
  reg                     hold_frame_last;
  reg                     frame_active;
  reg [BEAT_COUNT_WIDTH-1:0] frame_beat_count;

  wire hold_selected = hold_valid &&
                        ((GROUP_STEP > 0) && ((hold_group_x % GROUP_STEP) == 0)) &&
                        ((Y_STEP > 0) && ((hold_row_y % Y_STEP) == 0));
  wire hold_is_raw_frame_last = hold_valid &&
                        (hold_group_x == GROUPS_PER_LINE-1) &&
                        (hold_row_y == INPUT_HEIGHT-1);
  wire expected_tlast = (current_group_x == GROUPS_PER_LINE-1);

  function [7:0] rgb_to_luma;
    input [95:0] data;
    reg [7:0] r;
    reg [7:0] g;
    reg [7:0] b;
    reg [17:0] weighted;
    begin
      r = data[95:88];
      g = data[87:80];
      b = data[79:72];
      weighted = (r * 8'd77) + (g * 8'd150) + (b * 8'd29);
      rgb_to_luma = weighted[17:8];
    end
  endfunction

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      current_group_x <= {GROUP_X_WIDTH{1'b0}};
      current_row_y   <= {ROW_WIDTH{1'b0}};
      hold_group_x    <= {GROUP_X_WIDTH{1'b0}};
      hold_row_y      <= {ROW_WIDTH{1'b0}};
      hold_frame_id   <= {FRAME_ID_WIDTH{1'b0}};
      hold_data       <= 96'd0;
      hold_valid      <= 1'b0;
      hold_frame_last <= 1'b0;
      frame_active    <= 1'b0;
      frame_beat_count <= {BEAT_COUNT_WIDTH{1'b0}};
      O_frame_start   <= 1'b0;
      O_frame_end     <= 1'b0;
      O_sample_valid  <= 1'b0;
      O_frame_id      <= {FRAME_ID_WIDTH{1'b0}};
      O_sample_x      <= {GRID_X_WIDTH{1'b0}};
      O_sample_y      <= {GRID_Y_WIDTH{1'b0}};
      O_y_value       <= 8'd0;
      O_invalid       <= 1'b0;
      O_frame_invalid <= 1'b0;
    end else begin
      O_frame_start  <= 1'b0;
      O_frame_end    <= 1'b0;
      O_sample_valid <= 1'b0;
      O_invalid      <= 1'b0;

      if (O_frame_end)
        O_frame_invalid <= 1'b0;

      if (I_tuser) begin
        if (frame_active)
          O_invalid <= 1'b1;
        current_group_x <= (I_tvalid && !I_tlast) ? 1 : 0;
        current_row_y   <= (I_tvalid && I_tlast && INPUT_HEIGHT > 1) ? 1 : 0;
        hold_group_x    <= {GROUP_X_WIDTH{1'b0}};
        hold_row_y      <= {ROW_WIDTH{1'b0}};
        hold_frame_id   <= I_frame_id;
        hold_data       <= I_tdata;
        hold_valid      <= I_tvalid;
        hold_frame_last <= I_tvalid && (TOTAL_BEATS == 1);
        frame_active    <= 1'b1;
        frame_beat_count <= I_tvalid ? 1 : 0;
        O_frame_start   <= 1'b1;
        O_frame_id      <= I_frame_id;
        O_frame_invalid <= 1'b0;

        if (I_tvalid && (I_tlast != (GROUPS_PER_LINE == 1))) begin
          O_invalid       <= 1'b1;
          O_frame_invalid <= 1'b1;
        end
      end else begin
        if (hold_selected) begin
          O_sample_valid <= 1'b1;
          O_frame_id     <= hold_frame_id;
          O_sample_x     <= hold_group_x / GROUP_STEP;
          O_sample_y     <= hold_row_y / Y_STEP;
          O_y_value      <= rgb_to_luma(hold_data);
        end

        if (I_tvalid) begin
          if (!frame_active) begin
            O_invalid       <= 1'b1;
            O_frame_invalid <= 1'b1;
          end else begin
            if ((I_tlast != expected_tlast) || (I_frame_id != hold_frame_id)) begin
              O_invalid       <= 1'b1;
              O_frame_invalid <= 1'b1;
            end
            if (frame_beat_count < TOTAL_BEATS) begin
              hold_group_x    <= current_group_x;
              hold_row_y      <= current_row_y;
              hold_frame_id   <= I_frame_id;
              hold_data       <= I_tdata;
              hold_valid      <= 1'b1;
              hold_frame_last <= (frame_beat_count == TOTAL_BEATS-1);
              frame_beat_count <= frame_beat_count + 1'b1;
              if (I_tlast) begin
                current_group_x <= {GROUP_X_WIDTH{1'b0}};
                if (current_row_y == INPUT_HEIGHT-1)
                  current_row_y <= {ROW_WIDTH{1'b0}};
                else
                  current_row_y <= current_row_y + 1'b1;
              end else if (current_group_x == GROUPS_PER_LINE-1) begin
                current_group_x <= {GROUP_X_WIDTH{1'b0}};
                O_invalid       <= 1'b1;
                O_frame_invalid <= 1'b1;
              end else begin
                current_group_x <= current_group_x + 1'b1;
              end
            end else begin
              O_invalid       <= 1'b1;
              O_frame_invalid <= 1'b1;
            end
          end
        end else begin
          hold_valid <= 1'b0;
        end

        if (frame_active && hold_valid && hold_frame_last) begin
          O_frame_end  <= 1'b1;
          frame_active <= 1'b0;
        end
      end
    end
  end
endmodule
