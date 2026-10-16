`timescale 1ns / 1ps
// ============================================================================
// Module: color_detect_96_v2
// Description: Enhanced 4-pixel parallel industrial color detection with
//              pipelined Cb/Cr stage for timing closure and jitter-free
//              double-buffered bounding box & center extraction.
// Reference:
//   - 05_vision_bbox_template (bounding_box.v) for frame-latched steady outputs
//   - 06_ph1p35_vision_baseline for clean timing closure
// ============================================================================

module color_detect_96_v2 #(
  parameter integer IMG_WIDTH  = 1280,
  parameter integer IMG_HEIGHT = 720,
  parameter integer CB_MIN     = 85,
  parameter integer CB_MAX     = 125,
  parameter integer CR_MIN     = 135,
  parameter integer CR_MAX     = 240,
  parameter integer MIN_AREA   = 100
)(
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_tvalid,
  input  wire        I_tlast,
  input  wire        I_tuser,
  input  wire [95:0] I_tdata,               // 4 pixels x 24-bit RGB (R[23:16], G[15:8], B[7:0])

  // Latched stable outputs (updated only on frame boundary, completely jitter-free for HDMI)
  output reg  [10:0] O_xmin,
  output reg  [10:0] O_xmax,
  output reg  [10:0] O_ymin,
  output reg  [10:0] O_ymax,
  output reg  [10:0] O_cx,                  // Bounding Box center X
  output reg  [10:0] O_cy,                  // Bounding Box center Y
  output reg  [18:0] O_area,                // Foreground pixel count
  output reg         O_detected,            // 1 = valid workpiece recognized (area >= MIN_AREA)
  output reg         O_frame_sync           // Pulses high for 1 cycle at latch instant
);

  localparam integer GRP = IMG_WIDTH >> 2;  // 320 clocks per line for 1280 pixels

  reg [10:0] x_grp;
  reg [10:0] y_pos;

  // Unpack 4-pixel RGB
  wire [7:0] R0 = I_tdata[95:88], G0 = I_tdata[87:80], B0 = I_tdata[79:72];
  wire [7:0] R1 = I_tdata[71:64], G1 = I_tdata[63:56], B1 = I_tdata[55:48];
  wire [7:0] R2 = I_tdata[47:40], G2 = I_tdata[39:32], B2 = I_tdata[31:24];
  wire [7:0] R3 = I_tdata[23:16], G3 = I_tdata[15:8],  B3 = I_tdata[7:0];

  // Q10 fixed-point RGB to YCbCr conversion
  // Intermediate calculation uses 20-bit signed integers to avoid overflow
  wire signed [19:0] cb0_raw = 512*$signed({1'b0, B0}) - 173*$signed({1'b0, R0}) - 339*$signed({1'b0, G0}) + 20'sd131072;
  wire signed [19:0] cr0_raw = 512*$signed({1'b0, R0}) - 429*$signed({1'b0, G0}) -  83*$signed({1'b0, B0}) + 20'sd131072;

  wire signed [19:0] cb1_raw = 512*$signed({1'b0, B1}) - 173*$signed({1'b0, R1}) - 339*$signed({1'b0, G1}) + 20'sd131072;
  wire signed [19:0] cr1_raw = 512*$signed({1'b0, R1}) - 429*$signed({1'b0, G1}) -  83*$signed({1'b0, B1}) + 20'sd131072;

  wire signed [19:0] cb2_raw = 512*$signed({1'b0, B2}) - 173*$signed({1'b0, R2}) - 339*$signed({1'b0, G2}) + 20'sd131072;
  wire signed [19:0] cr2_raw = 512*$signed({1'b0, R2}) - 429*$signed({1'b0, G2}) -  83*$signed({1'b0, B2}) + 20'sd131072;

  wire signed [19:0] cb3_raw = 512*$signed({1'b0, B3}) - 173*$signed({1'b0, R3}) - 339*$signed({1'b0, G3}) + 20'sd131072;
  wire signed [19:0] cr3_raw = 512*$signed({1'b0, R3}) - 429*$signed({1'b0, G3}) -  83*$signed({1'b0, B3}) + 20'sd131072;

  // Pipeline Stage 1 Registers (Break DSP -> Accumulator timing path)
  reg signed [19:0] cb0_r, cr0_r;
  reg signed [19:0] cb1_r, cr1_r;
  reg signed [19:0] cb2_r, cr2_r;
  reg signed [19:0] cb3_r, cr3_r;

  reg [11:0] col0_d1, col1_d1, col2_d1, col3_d1;
  reg [10:0] y_pos_d1;
  reg        tvalid_d1;
  reg        tuser_d1;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      cb0_r     <= 20'sd0;
      cr0_r     <= 20'sd0;
      cb1_r     <= 20'sd0;
      cr1_r     <= 20'sd0;
      cb2_r     <= 20'sd0;
      cr2_r     <= 20'sd0;
      cb3_r     <= 20'sd0;
      cr3_r     <= 20'sd0;
      col0_d1   <= 12'd0;
      col1_d1   <= 12'd0;
      col2_d1   <= 12'd0;
      col3_d1   <= 12'd0;
      y_pos_d1  <= 11'd0;
      tvalid_d1 <= 1'b0;
      tuser_d1  <= 1'b0;
    end else begin
      cb0_r     <= cb0_raw;
      cr0_r     <= cr0_raw;
      cb1_r     <= cb1_raw;
      cr1_r     <= cr1_raw;
      cb2_r     <= cb2_raw;
      cr2_r     <= cr2_raw;
      cb3_r     <= cb3_raw;
      cr3_r     <= cr3_raw;
      col0_d1   <= {x_grp, 2'b00};
      col1_d1   <= {x_grp, 2'b00} + 12'd1;
      col2_d1   <= {x_grp, 2'b00} + 12'd2;
      col3_d1   <= {x_grp, 2'b00} + 12'd3;
      y_pos_d1  <= y_pos;
      tvalid_d1 <= I_tvalid;
      tuser_d1  <= I_tuser;
    end
  end

  // Pipeline Stage 2: Saturated Cb/Cr extraction & Threshold comparison
  wire [7:0] cb0_val = cb0_r[19] ? 8'd0 : cb0_r[17:10];
  wire [7:0] cr0_val = cr0_r[19] ? 8'd0 : cr0_r[17:10];
  wire [7:0] cb1_val = cb1_r[19] ? 8'd0 : cb1_r[17:10];
  wire [7:0] cr1_val = cr1_r[19] ? 8'd0 : cr1_r[17:10];
  wire [7:0] cb2_val = cb2_r[19] ? 8'd0 : cb2_r[17:10];
  wire [7:0] cr2_val = cr2_r[19] ? 8'd0 : cr2_r[17:10];
  wire [7:0] cb3_val = cb3_r[19] ? 8'd0 : cb3_r[17:10];
  wire [7:0] cr3_val = cr3_r[19] ? 8'd0 : cr3_r[17:10];

  wire t0 = (cb0_val >= CB_MIN && cb0_val <= CB_MAX) && (cr0_val >= CR_MIN && cr0_val <= CR_MAX);
  wire t1 = (cb1_val >= CB_MIN && cb1_val <= CB_MAX) && (cr1_val >= CR_MIN && cr1_val <= CR_MAX);
  wire t2 = (cb2_val >= CB_MIN && cb2_val <= CB_MAX) && (cr2_val >= CR_MIN && cr2_val <= CR_MAX);
  wire t3 = (cb3_val >= CB_MIN && cb3_val <= CB_MAX) && (cr3_val >= CR_MIN && cr3_val <= CR_MAX);

  // Internal active accumulator registers
  reg [10:0] acc_xmin, acc_xmax, acc_ymin, acc_ymax;
  reg [18:0] acc_area;

  // Main streaming processing
  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      x_grp        <= 11'd0;
      y_pos        <= 11'd0;
      acc_xmin     <= IMG_WIDTH - 1;
      acc_xmax     <= 11'd0;
      acc_ymin     <= IMG_HEIGHT - 1;
      acc_ymax     <= 11'd0;
      acc_area     <= 19'd0;
      O_xmin       <= 11'd0;
      O_xmax       <= 11'd0;
      O_ymin       <= 11'd0;
      O_ymax       <= 11'd0;
      O_cx         <= 11'd0;
      O_cy         <= 11'd0;
      O_area       <= 19'd0;
      O_detected   <= 1'b0;
      O_frame_sync <= 1'b0;
    end else begin
      O_frame_sync <= 1'b0;

      // Coordinate progress (tracks input domain I_tuser / I_tvalid)
      if (I_tuser) begin
        x_grp <= 11'd0;
        y_pos <= 11'd0;
      end else if (I_tvalid) begin
        if (x_grp == GRP - 1) begin
          x_grp <= 11'd0;
          if (y_pos == IMG_HEIGHT - 1) y_pos <= 11'd0;
          else y_pos <= y_pos + 11'd1;
        end else begin
          x_grp <= x_grp + 11'd1;
        end
      end

      if (tuser_d1) begin
        // Frame Boundary: Latch accumulated result to outputs
        O_frame_sync <= 1'b1;
        if (acc_area >= MIN_AREA) begin
          O_xmin     <= acc_xmin;
          O_xmax     <= acc_xmax;
          O_ymin     <= acc_ymin;
          O_ymax     <= acc_ymax;
          O_cx       <= (acc_xmin + acc_xmax) >> 1;
          O_cy       <= (acc_ymin + acc_ymax) >> 1;
          O_area     <= acc_area;
          O_detected <= 1'b1;
        end else begin
          O_xmin     <= 11'd0;
          O_xmax     <= 11'd0;
          O_ymin     <= 11'd0;
          O_ymax     <= 11'd0;
          O_cx       <= 11'd0;
          O_cy       <= 11'd0;
          O_area     <= 19'd0;
          O_detected <= 1'b0;
        end

        // Reset accumulators for the upcoming frame
        acc_xmin <= IMG_WIDTH - 1;
        acc_xmax <= 11'd0;
        acc_ymin <= IMG_HEIGHT - 1;
        acc_ymax <= 11'd0;
        acc_area <= 19'd0;
      end else if (tvalid_d1) begin
        // 4-pixel lane accumulation
        acc_area <= acc_area + (t0 ? 19'd1 : 19'd0) + (t1 ? 19'd1 : 19'd0) +
                               (t2 ? 19'd1 : 19'd0) + (t3 ? 19'd1 : 19'd0);

        // Update X min
        if (t0 && col0_d1 < acc_xmin) acc_xmin <= col0_d1[10:0];
        else if (t1 && col1_d1 < acc_xmin) acc_xmin <= col1_d1[10:0];
        else if (t2 && col2_d1 < acc_xmin) acc_xmin <= col2_d1[10:0];
        else if (t3 && col3_d1 < acc_xmin) acc_xmin <= col3_d1[10:0];

        // Update X max
        if (t3 && col3_d1 > acc_xmax) acc_xmax <= col3_d1[10:0];
        else if (t2 && col2_d1 > acc_xmax) acc_xmax <= col2_d1[10:0];
        else if (t1 && col1_d1 > acc_xmax) acc_xmax <= col1_d1[10:0];
        else if (t0 && col0_d1 > acc_xmax) acc_xmax <= col0_d1[10:0];

        // Update Y bounds
        if (t0 || t1 || t2 || t3) begin
          if (y_pos_d1 < acc_ymin) acc_ymin <= y_pos_d1;
          if (y_pos_d1 > acc_ymax) acc_ymax <= y_pos_d1;
        end
      end
    end
  end

endmodule
