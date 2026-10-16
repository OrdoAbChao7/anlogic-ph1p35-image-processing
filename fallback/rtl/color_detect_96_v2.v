`timescale 1ns / 1ps
// ============================================================================
// Fixed red-part detector for the PH1P35 four-pixel RGB888 stream.
//
// Pipeline:
//   RGB888 x 4 -> Q10 Cb/Cr segmentation -> 3x3 opening -> frame statistics
//
// The published result is updated only at the end of the morphology-drained
// frame.  O_area is 20 bits so a full 1280x720 foreground (921600 pixels) is
// representable.  The default thresholds are the frozen Stage D contract:
//   85 < Cb < 125, 135 < Cr < 200, Q10 bias 131072.
// ============================================================================

module color_detect_96_v2 #(
  parameter integer IMG_WIDTH  = 1280,
  parameter integer IMG_HEIGHT = 720,
  parameter integer CB_MIN     = 85,
  parameter integer CB_MAX     = 125,
  parameter integer CR_MIN     = 135,
  parameter integer CR_MAX     = 200,
  parameter integer MIN_AREA   = 100,
  parameter integer ROI_X      = 0,
  parameter integer ROI_Y      = 0,
  parameter integer ROI_WIDTH  = 0,
  parameter integer ROI_HEIGHT = 0
)(
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_tvalid,
  input  wire        I_tlast,
  input  wire        I_tuser,
  input  wire [95:0] I_tdata,

  output reg  [10:0] O_xmin,
  output reg  [10:0] O_xmax,
  output reg  [10:0] O_ymin,
  output reg  [10:0] O_ymax,
  output reg  [10:0] O_cx,
  output reg  [10:0] O_cy,
  output reg  [19:0] O_area,
  output reg         O_detected,
  output reg         O_invalid,
  output reg         O_frame_sync
);

  localparam integer GROUPS = IMG_WIDTH / 4;
  localparam integer GROUP_BITS = (GROUPS <= 1) ? 1 : $clog2(GROUPS + 1);

  wire roi_is_full = (ROI_X == 0) && (ROI_Y == 0) &&
                     (ROI_WIDTH == 0) && (ROI_HEIGHT == 0);
  wire roi_geometry_valid = roi_is_full ||
      ((ROI_WIDTH > 0) && (ROI_HEIGHT > 0) &&
       (ROI_X >= 0) && (ROI_Y >= 0) &&
       (ROI_X + ROI_WIDTH <= IMG_WIDTH) &&
       (ROI_Y + ROI_HEIGHT <= IMG_HEIGHT));

  // Four RGB lanes, lane zero is the most significant 24-bit word.
  wire [7:0] r0 = I_tdata[95:88];
  wire [7:0] g0 = I_tdata[87:80];
  wire [7:0] b0 = I_tdata[79:72];
  wire [7:0] r1 = I_tdata[71:64];
  wire [7:0] g1 = I_tdata[63:56];
  wire [7:0] b1 = I_tdata[55:48];
  wire [7:0] r2 = I_tdata[47:40];
  wire [7:0] g2 = I_tdata[39:32];
  wire [7:0] b2 = I_tdata[31:24];
  wire [7:0] r3 = I_tdata[23:16];
  wire [7:0] g3 = I_tdata[15:8];
  wire [7:0] b3 = I_tdata[7:0];

  // Keep RGB unsigned and make the fixed-point width explicit.
  wire signed [19:0] cb0_raw = 20'sd512 * $signed({1'b0,b0}) -
                                 20'sd173 * $signed({1'b0,r0}) -
                                 20'sd339 * $signed({1'b0,g0}) + 20'sd131072;
  wire signed [19:0] cr0_raw = 20'sd512 * $signed({1'b0,r0}) -
                                 20'sd429 * $signed({1'b0,g0}) -
                                 20'sd83  * $signed({1'b0,b0}) + 20'sd131072;
  wire signed [19:0] cb1_raw = 20'sd512 * $signed({1'b0,b1}) -
                                 20'sd173 * $signed({1'b0,r1}) -
                                 20'sd339 * $signed({1'b0,g1}) + 20'sd131072;
  wire signed [19:0] cr1_raw = 20'sd512 * $signed({1'b0,r1}) -
                                 20'sd429 * $signed({1'b0,g1}) -
                                 20'sd83  * $signed({1'b0,b1}) + 20'sd131072;
  wire signed [19:0] cb2_raw = 20'sd512 * $signed({1'b0,b2}) -
                                 20'sd173 * $signed({1'b0,r2}) -
                                 20'sd339 * $signed({1'b0,g2}) + 20'sd131072;
  wire signed [19:0] cr2_raw = 20'sd512 * $signed({1'b0,r2}) -
                                 20'sd429 * $signed({1'b0,g2}) -
                                 20'sd83  * $signed({1'b0,b2}) + 20'sd131072;
  wire signed [19:0] cb3_raw = 20'sd512 * $signed({1'b0,b3}) -
                                 20'sd173 * $signed({1'b0,r3}) -
                                 20'sd339 * $signed({1'b0,g3}) + 20'sd131072;
  wire signed [19:0] cr3_raw = 20'sd512 * $signed({1'b0,r3}) -
                                 20'sd429 * $signed({1'b0,g3}) -
                                 20'sd83  * $signed({1'b0,b3}) + 20'sd131072;

  reg signed [19:0] cb0_r, cr0_r, cb1_r, cr1_r;
  reg signed [19:0] cb2_r, cr2_r, cb3_r, cr3_r;
  reg [11:0] col0_d1, col1_d1, col2_d1, col3_d1;
  reg [10:0] y_pos_d1;
  reg        tvalid_d1, tlast_d1, tuser_d1;

  function [7:0] q10_to_u8;
    input signed [19:0] value;
    reg signed [20:0] scaled;
    begin
      scaled = value >>> 10;
      if (scaled < 0)
        q10_to_u8 = 8'd0;
      else if (scaled > 255)
        q10_to_u8 = 8'd255;
      else
        q10_to_u8 = scaled[7:0];
    end
  endfunction

  wire [7:0] cb0_val = q10_to_u8(cb0_r);
  wire [7:0] cr0_val = q10_to_u8(cr0_r);
  wire [7:0] cb1_val = q10_to_u8(cb1_r);
  wire [7:0] cr1_val = q10_to_u8(cr1_r);
  wire [7:0] cb2_val = q10_to_u8(cb2_r);
  wire [7:0] cr2_val = q10_to_u8(cr2_r);
  wire [7:0] cb3_val = q10_to_u8(cb3_r);
  wire [7:0] cr3_val = q10_to_u8(cr3_r);

  reg [10:0] x_grp;
  reg [10:0] y_pos;
  wire [10:0] sample_x_grp = I_tuser ? 11'd0 : x_grp;

  wire roi0 = roi_is_full ||
              ((col0_d1 >= ROI_X) && (col0_d1 < ROI_X + ROI_WIDTH) &&
               (y_pos_d1 >= ROI_Y) && (y_pos_d1 < ROI_Y + ROI_HEIGHT));
  wire roi1 = roi_is_full ||
              ((col1_d1 >= ROI_X) && (col1_d1 < ROI_X + ROI_WIDTH) &&
               (y_pos_d1 >= ROI_Y) && (y_pos_d1 < ROI_Y + ROI_HEIGHT));
  wire roi2 = roi_is_full ||
              ((col2_d1 >= ROI_X) && (col2_d1 < ROI_X + ROI_WIDTH) &&
               (y_pos_d1 >= ROI_Y) && (y_pos_d1 < ROI_Y + ROI_HEIGHT));
  wire roi3 = roi_is_full ||
              ((col3_d1 >= ROI_X) && (col3_d1 < ROI_X + ROI_WIDTH) &&
               (y_pos_d1 >= ROI_Y) && (y_pos_d1 < ROI_Y + ROI_HEIGHT));

  // Strict open intervals are intentional and match the Stage D model.
  wire [3:0] segment_mask = {
    roi3 && (cb3_val > CB_MIN) && (cb3_val < CB_MAX) &&
           (cr3_val > CR_MIN) && (cr3_val < CR_MAX),
    roi2 && (cb2_val > CB_MIN) && (cb2_val < CB_MAX) &&
           (cr2_val > CR_MIN) && (cr2_val < CR_MAX),
    roi1 && (cb1_val > CB_MIN) && (cb1_val < CB_MAX) &&
           (cr1_val > CR_MIN) && (cr1_val < CR_MAX),
    roi0 && (cb0_val > CB_MIN) && (cb0_val < CB_MAX) &&
           (cr0_val > CR_MIN) && (cr0_val < CR_MAX)
  };

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      cb0_r <= 0; cr0_r <= 0; cb1_r <= 0; cr1_r <= 0;
      cb2_r <= 0; cr2_r <= 0; cb3_r <= 0; cr3_r <= 0;
      col0_d1 <= 0; col1_d1 <= 0; col2_d1 <= 0; col3_d1 <= 0;
      y_pos_d1 <= 0; tvalid_d1 <= 0; tlast_d1 <= 0; tuser_d1 <= 0;
    end else begin
      cb0_r <= cb0_raw; cr0_r <= cr0_raw;
      cb1_r <= cb1_raw; cr1_r <= cr1_raw;
      cb2_r <= cb2_raw; cr2_r <= cr2_raw;
      cb3_r <= cb3_raw; cr3_r <= cr3_raw;
      col0_d1 <= {sample_x_grp,2'b00};
      col1_d1 <= {sample_x_grp,2'b00} + 12'd1;
      col2_d1 <= {sample_x_grp,2'b00} + 12'd2;
      col3_d1 <= {sample_x_grp,2'b00} + 12'd3;
      y_pos_d1 <= I_tuser ? 11'd0 : y_pos;
      tvalid_d1 <= I_tvalid;
      tlast_d1 <= I_tlast;
      tuser_d1 <= I_tuser;
    end
  end

  // Fixed-raster coordinate tracker.  I_tuser may accompany the first group.
  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      x_grp <= 0;
      y_pos <= 0;
    end else if (I_tuser) begin
      if (I_tvalid) begin
        if (GROUPS == 1) begin
          x_grp <= 0;
          y_pos <= (IMG_HEIGHT == 1) ? 0 : 11'd1;
        end else begin
          x_grp <= 1;
          y_pos <= 0;
        end
      end else begin
        x_grp <= 0;
        y_pos <= 0;
      end
    end else if (I_tvalid) begin
      if (x_grp == GROUPS-1) begin
        x_grp <= 0;
        y_pos <= (y_pos == IMG_HEIGHT-1) ? 0 : y_pos + 11'd1;
      end else begin
        x_grp <= x_grp + 1'b1;
      end
    end
  end

  wire morph_valid, morph_last, morph_user, morph_frame_end, morph_invalid;
  wire [3:0] morph_mask;
  morph_open_96 #(
    .IMG_WIDTH(IMG_WIDTH), .IMG_HEIGHT(IMG_HEIGHT)
  ) u_morph_open (
    .I_clk(I_clk), .I_rst_n(I_rst_n),
    .I_tvalid(tvalid_d1), .I_tlast(tlast_d1), .I_tuser(tuser_d1),
    .I_mask((tvalid_d1 && roi_geometry_valid) ? segment_mask : 4'd0),
    .O_tvalid(morph_valid), .O_tlast(morph_last), .O_tuser(morph_user),
    .O_mask(morph_mask), .O_frame_end(morph_frame_end),
    .O_invalid(morph_invalid)
  );

  localparam integer OUT_GROUP_BITS = (GROUPS <= 1) ? 1 : $clog2(GROUPS + 1);
  reg [OUT_GROUP_BITS-1:0] out_group;
  reg [10:0] out_y;
  reg [19:0] acc_area;
  reg [10:0] acc_xmin, acc_xmax, acc_ymin, acc_ymax;
  reg        acc_invalid;
  reg [19:0] stat_area_next;
  reg [10:0] stat_xmin_next, stat_xmax_next, stat_ymin_next, stat_ymax_next;
  reg        stat_invalid_next;
  integer j;

  always @* begin
    stat_area_next = morph_user ? 20'd0 : acc_area;
    stat_xmin_next = morph_user ? IMG_WIDTH-1 : acc_xmin;
    stat_xmax_next = morph_user ? 0 : acc_xmax;
    stat_ymin_next = morph_user ? IMG_HEIGHT-1 : acc_ymin;
    stat_ymax_next = morph_user ? 0 : acc_ymax;
    stat_invalid_next = morph_user ? (!roi_geometry_valid) : acc_invalid;

    if (morph_invalid)
      stat_invalid_next = 1'b1;

    if (morph_valid) begin
      for (j = 0; j < 4; j = j + 1) begin
        if (morph_mask[j]) begin
          stat_area_next = stat_area_next + 20'd1;
          if ((out_group * 4 + j) < stat_xmin_next)
            stat_xmin_next = out_group * 4 + j;
          if ((out_group * 4 + j) > stat_xmax_next)
            stat_xmax_next = out_group * 4 + j;
          if (out_y < stat_ymin_next)
            stat_ymin_next = out_y;
          if (out_y > stat_ymax_next)
            stat_ymax_next = out_y;
        end
      end
    end
  end

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      out_group <= 0;
      out_y <= 0;
      acc_area <= 0;
      acc_xmin <= IMG_WIDTH-1;
      acc_xmax <= 0;
      acc_ymin <= IMG_HEIGHT-1;
      acc_ymax <= 0;
      acc_invalid <= !roi_geometry_valid;
      O_xmin <= 0; O_xmax <= 0; O_ymin <= 0; O_ymax <= 0;
      O_cx <= 0; O_cy <= 0; O_area <= 0;
      O_detected <= 0; O_invalid <= !roi_geometry_valid;
      O_frame_sync <= 0;
    end else begin
      O_frame_sync <= 1'b0;

      if (morph_invalid)
        acc_invalid <= 1'b1;

      if (morph_valid) begin
        acc_area <= stat_area_next;
        acc_xmin <= stat_xmin_next;
        acc_xmax <= stat_xmax_next;
        acc_ymin <= stat_ymin_next;
        acc_ymax <= stat_ymax_next;
        acc_invalid <= stat_invalid_next;

        if (morph_last) begin
          out_group <= 0;
          if (out_y == IMG_HEIGHT-1)
            out_y <= 0;
          else
            out_y <= out_y + 1'b1;
        end else begin
          out_group <= out_group + 1'b1;
        end

        if (morph_frame_end) begin
          O_frame_sync <= 1'b1;
          if (stat_invalid_next) begin
            O_invalid   <= 1'b1;
            O_detected  <= 1'b0;
            O_xmin <= 0; O_xmax <= 0; O_ymin <= 0; O_ymax <= 0;
            O_cx <= 0; O_cy <= 0; O_area <= 0;
          end else if (stat_area_next >= MIN_AREA) begin
            O_invalid   <= 1'b0;
            O_detected  <= 1'b1;
            O_xmin <= stat_xmin_next; O_xmax <= stat_xmax_next;
            O_ymin <= stat_ymin_next; O_ymax <= stat_ymax_next;
            O_cx <= ({1'b0,stat_xmin_next} + {1'b0,stat_xmax_next}) >> 1;
            O_cy <= ({1'b0,stat_ymin_next} + {1'b0,stat_ymax_next}) >> 1;
            O_area <= stat_area_next;
          end else begin
            O_invalid   <= 1'b0;
            O_detected  <= 1'b0;
            O_xmin <= 0; O_xmax <= 0; O_ymin <= 0; O_ymax <= 0;
            O_cx <= 0; O_cy <= 0; O_area <= stat_area_next;
          end
          acc_area <= 0;
          acc_xmin <= IMG_WIDTH-1;
          acc_xmax <= 0;
          acc_ymin <= IMG_HEIGHT-1;
          acc_ymax <= 0;
          acc_invalid <= !roi_geometry_valid;
        end
      end
    end
  end

endmodule