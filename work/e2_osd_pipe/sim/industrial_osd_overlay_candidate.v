`timescale 1ns / 1ps
// ============================================================================
// HDMI-domain OSD for the fixed red-part inspection demo.
//
// The overlay consumes the same frame-stable result bus as the bounding box.
// It embeds the Anlogic logo ROM and a small synthesizable 5x7 character set.
// Frame count, width and height are shown as decimal digits. The conversion is
// snapshotted on the frame boundary so the pixel path only selects characters.
// ============================================================================

module industrial_osd_overlay_candidate #(
  parameter integer IMG_WIDTH = 1280,
  parameter integer IMG_HEIGHT = 720,
  parameter integer LOGO_W = 160,
  parameter integer LOGO_H = 160
)(
  input  wire        I_clk,
  input  wire        I_rst_n,
  input  wire        I_vsync,
  input  wire        I_hsync,
  input  wire        I_de,
  input  wire [23:0] I_rgb,
  input  wire [1:0]  I_mode,
  input  wire        I_detected,
  input  wire        I_pass,
  input  wire        I_ng,
  input  wire        I_invalid,
  input  wire [10:0] I_width,
  input  wire [10:0] I_height,
  input  wire        I_proc_valid,
  input  wire [31:0] I_proc_cycles,
  input  wire        I_motion_valid,
  input  wire        I_motion,
  input  wire [23:0] I_motion_count,
  input  wire [15:0] I_pass_count,
  input  wire [15:0] I_ng_count,
  input  wire        I_sort_pulse,
  input  wire        I_safe_enable,
  input  wire        I_dimension_valid,
  input  wire        I_shape_valid,
  input  wire        I_scale_provisional,
  input  wire [31:0] I_width_mm_q16_16,
  input  wire [31:0] I_height_mm_q16_16,
  output reg         O_vsync,
  output reg         O_hsync,
  output reg         O_de,
  output reg  [23:0] O_rgb
);

  localparam [1:0] MODE_ORIGINAL = 2'd0;
  localparam [1:0] MODE_SOBEL    = 2'd1;
  localparam [1:0] MODE_CARTOON  = 2'd2;

  reg [11:0] x;
  reg [11:0] y;
  reg        vsync_d;
  reg [39:0] frame_digits;
  reg [15:0] width_digits;
  reg [15:0] height_digits;
  reg detected_snapshot, pass_snapshot, ng_snapshot, invalid_snapshot;
  reg proc_valid_snapshot;
  reg [31:0] proc_cycles_snapshot;
  reg motion_valid_snapshot, motion_snapshot;
  reg [23:0] motion_count_snapshot;
  reg [15:0] pass_count_snapshot, ng_count_snapshot;
  reg sort_pulse_snapshot, safe_enable_snapshot;
  reg dimension_valid_snapshot, shape_valid_snapshot, scale_provisional_snapshot;
  reg [19:0] width_mm_digits, height_mm_digits;

  wire [14:0] logo_addr = ((y << 7) + (y << 5)) + x;
  wire [24:0] logo_pixel;
  wire in_logo = I_de && (x < LOGO_W) && (y < LOGO_H);

  function [7:0] hex_ascii;
    input [3:0] value;
    begin
      if (value < 10) hex_ascii = 8'h30 + value;
      else hex_ascii = 8'h41 + value - 10;
    end
  endfunction

  // Increment the already-decimal frame value one nibble at a time.  This
  // keeps the frame-boundary update synthesizable without inferring a bank of
  // 32-bit division/modulo operators on the HDMI clock domain.
  function [39:0] bcd_increment;
    input [39:0] value;
    reg [39:0] result;
    reg        carry;
    begin
      result = value;
      carry = 1'b1;
      if (carry) begin if (result[3:0]   == 4'd9) begin result[3:0]   = 4'd0; end else begin result[3:0]   = result[3:0]   + 4'd1; carry = 1'b0; end end
      if (carry) begin if (result[7:4]   == 4'd9) begin result[7:4]   = 4'd0; end else begin result[7:4]   = result[7:4]   + 4'd1; carry = 1'b0; end end
      if (carry) begin if (result[11:8]  == 4'd9) begin result[11:8]  = 4'd0; end else begin result[11:8]  = result[11:8]  + 4'd1; carry = 1'b0; end end
      if (carry) begin if (result[15:12] == 4'd9) begin result[15:12] = 4'd0; end else begin result[15:12] = result[15:12] + 4'd1; carry = 1'b0; end end
      if (carry) begin if (result[19:16] == 4'd9) begin result[19:16] = 4'd0; end else begin result[19:16] = result[19:16] + 4'd1; carry = 1'b0; end end
      if (carry) begin if (result[23:20] == 4'd9) begin result[23:20] = 4'd0; end else begin result[23:20] = result[23:20] + 4'd1; carry = 1'b0; end end
      if (carry) begin if (result[27:24] == 4'd9) begin result[27:24] = 4'd0; end else begin result[27:24] = result[27:24] + 4'd1; carry = 1'b0; end end
      if (carry) begin if (result[31:28] == 4'd9) begin result[31:28] = 4'd0; end else begin result[31:28] = result[31:28] + 4'd1; carry = 1'b0; end end
      if (carry) begin if (result[35:32] == 4'd9) begin result[35:32] = 4'd0; end else begin result[35:32] = result[35:32] + 4'd1; carry = 1'b0; end end
      if (carry) begin if (result[39:36] == 4'd9) begin result[39:36] = 4'd0; end else begin result[39:36] = result[39:36] + 4'd1; end end
      bcd_increment = result;
    end
  endfunction

  // Convert the bounded 11-bit pixel dimensions to four BCD digits at the
  // frame boundary. Values through the full 0..2047 input range are retained.
  function [15:0] dimension_to_bcd;
    input [10:0] value;
    reg [10:0] remainder;
    reg [3:0] thousands;
    reg [3:0] hundreds;
    reg [3:0] tens;
    reg [3:0] ones;
    begin
      remainder = value;
      thousands = 4'd0;
      hundreds = 4'd0;
      tens = 4'd0;
      ones = 4'd0;
      if (remainder >= 11'd2000) begin thousands = 4'd2; remainder = remainder - 11'd2000; end
      else if (remainder >= 11'd1000) begin thousands = 4'd1; remainder = remainder - 11'd1000; end
      if (remainder >= 11'd900) begin hundreds = 4'd9; remainder = remainder - 11'd900; end
      else if (remainder >= 11'd800) begin hundreds = 4'd8; remainder = remainder - 11'd800; end
      else if (remainder >= 11'd700) begin hundreds = 4'd7; remainder = remainder - 11'd700; end
      else if (remainder >= 11'd600) begin hundreds = 4'd6; remainder = remainder - 11'd600; end
      else if (remainder >= 11'd500) begin hundreds = 4'd5; remainder = remainder - 11'd500; end
      else if (remainder >= 11'd400) begin hundreds = 4'd4; remainder = remainder - 11'd400; end
      else if (remainder >= 11'd300) begin hundreds = 4'd3; remainder = remainder - 11'd300; end
      else if (remainder >= 11'd200) begin hundreds = 4'd2; remainder = remainder - 11'd200; end
      else if (remainder >= 11'd100) begin hundreds = 4'd1; remainder = remainder - 11'd100; end
      if (remainder >= 11'd90) begin tens = 4'd9; remainder = remainder - 11'd90; end
      else if (remainder >= 11'd80) begin tens = 4'd8; remainder = remainder - 11'd80; end
      else if (remainder >= 11'd70) begin tens = 4'd7; remainder = remainder - 11'd70; end
      else if (remainder >= 11'd60) begin tens = 4'd6; remainder = remainder - 11'd60; end
      else if (remainder >= 11'd50) begin tens = 4'd5; remainder = remainder - 11'd50; end
      else if (remainder >= 11'd40) begin tens = 4'd4; remainder = remainder - 11'd40; end
      else if (remainder >= 11'd30) begin tens = 4'd3; remainder = remainder - 11'd30; end
      else if (remainder >= 11'd20) begin tens = 4'd2; remainder = remainder - 11'd20; end
      else if (remainder >= 11'd10) begin tens = 4'd1; remainder = remainder - 11'd10; end
      ones = remainder[3:0];
      dimension_to_bcd = {thousands, hundreds, tens, ones};
    end
  endfunction

  // Convert the integer-mm portion of a Q16.16 candidate dimension to five
  // decimal digits. This is only evaluated on a frame boundary.
  function [19:0] mm_integer_to_bcd;
    input [15:0] value;
    reg [15:0] remainder;
    reg [3:0] ten_thousands, thousands, hundreds, tens, ones;
    begin
      remainder = value;
      ten_thousands = 4'd0;
      thousands = 4'd0;
      hundreds = 4'd0;
      tens = 4'd0;
      ones = 4'd0;
      if (remainder >= 16'd60000) begin ten_thousands = 4'd6; remainder = remainder - 16'd60000; end
      else if (remainder >= 16'd50000) begin ten_thousands = 4'd5; remainder = remainder - 16'd50000; end
      else if (remainder >= 16'd40000) begin ten_thousands = 4'd4; remainder = remainder - 16'd40000; end
      else if (remainder >= 16'd30000) begin ten_thousands = 4'd3; remainder = remainder - 16'd30000; end
      else if (remainder >= 16'd20000) begin ten_thousands = 4'd2; remainder = remainder - 16'd20000; end
      else if (remainder >= 16'd10000) begin ten_thousands = 4'd1; remainder = remainder - 16'd10000; end
      if (remainder >= 16'd9000) begin thousands = 4'd9; remainder = remainder - 16'd9000; end
      else if (remainder >= 16'd8000) begin thousands = 4'd8; remainder = remainder - 16'd8000; end
      else if (remainder >= 16'd7000) begin thousands = 4'd7; remainder = remainder - 16'd7000; end
      else if (remainder >= 16'd6000) begin thousands = 4'd6; remainder = remainder - 16'd6000; end
      else if (remainder >= 16'd5000) begin thousands = 4'd5; remainder = remainder - 16'd5000; end
      else if (remainder >= 16'd4000) begin thousands = 4'd4; remainder = remainder - 16'd4000; end
      else if (remainder >= 16'd3000) begin thousands = 4'd3; remainder = remainder - 16'd3000; end
      else if (remainder >= 16'd2000) begin thousands = 4'd2; remainder = remainder - 16'd2000; end
      else if (remainder >= 16'd1000) begin thousands = 4'd1; remainder = remainder - 16'd1000; end
      if (remainder >= 16'd900) begin hundreds = 4'd9; remainder = remainder - 16'd900; end
      else if (remainder >= 16'd800) begin hundreds = 4'd8; remainder = remainder - 16'd800; end
      else if (remainder >= 16'd700) begin hundreds = 4'd7; remainder = remainder - 16'd700; end
      else if (remainder >= 16'd600) begin hundreds = 4'd6; remainder = remainder - 16'd600; end
      else if (remainder >= 16'd500) begin hundreds = 4'd5; remainder = remainder - 16'd500; end
      else if (remainder >= 16'd400) begin hundreds = 4'd4; remainder = remainder - 16'd400; end
      else if (remainder >= 16'd300) begin hundreds = 4'd3; remainder = remainder - 16'd300; end
      else if (remainder >= 16'd200) begin hundreds = 4'd2; remainder = remainder - 16'd200; end
      else if (remainder >= 16'd100) begin hundreds = 4'd1; remainder = remainder - 16'd100; end
      if (remainder >= 16'd90) begin tens = 4'd9; remainder = remainder - 16'd90; end
      else if (remainder >= 16'd80) begin tens = 4'd8; remainder = remainder - 16'd80; end
      else if (remainder >= 16'd70) begin tens = 4'd7; remainder = remainder - 16'd70; end
      else if (remainder >= 16'd60) begin tens = 4'd6; remainder = remainder - 16'd60; end
      else if (remainder >= 16'd50) begin tens = 4'd5; remainder = remainder - 16'd50; end
      else if (remainder >= 16'd40) begin tens = 4'd4; remainder = remainder - 16'd40; end
      else if (remainder >= 16'd30) begin tens = 4'd3; remainder = remainder - 16'd30; end
      else if (remainder >= 16'd20) begin tens = 4'd2; remainder = remainder - 16'd20; end
      else if (remainder >= 16'd10) begin tens = 4'd1; remainder = remainder - 16'd10; end
      ones = remainder[3:0];
      mm_integer_to_bcd = {ten_thousands, thousands, hundreds, tens, ones};
    end
  endfunction

  function [7:0] text_char;
    input integer line;
    input integer pos;
    input [1:0] mode;
    input [39:0] frame_digits_in;
    input [15:0] width_digits_in;
    input [15:0] height_digits_in;
    input detected;
    input pass;
    input ng;
    input invalid;
    input proc_valid;
    input [31:0] proc_cycles;
    input motion_valid;
    input motion;
    input [23:0] motion_count;
    input [15:0] pass_count;
    input [15:0] ng_count;
    input sort_pulse;
    input safe_enable;
    input dimension_valid;
    input shape_valid;
    input scale_provisional;
    input [19:0] width_mm_digits_in;
    input [19:0] height_mm_digits_in;
    begin
      text_char = 8'h20;
      case (line)
        0: begin
          case (pos)
            0:text_char="M"; 1:text_char="O"; 2:text_char="D"; 3:text_char="E"; 4:text_char=":";
            5: if(mode==MODE_ORIGINAL) text_char="O"; else if(mode==MODE_SOBEL) text_char="S"; else text_char="C";
            6: if(mode==MODE_ORIGINAL) text_char="R"; else if(mode==MODE_SOBEL) text_char="O"; else text_char="A";
            7: if(mode==MODE_ORIGINAL) text_char="I"; else if(mode==MODE_SOBEL) text_char="B"; else text_char="R";
            8: if(mode==MODE_ORIGINAL) text_char="G"; else if(mode==MODE_SOBEL) text_char="E"; else text_char="T";
            9: if(mode==MODE_ORIGINAL) text_char="I"; else if(mode==MODE_SOBEL) text_char="L"; else text_char="O";
            10:if(mode==MODE_ORIGINAL) text_char="N"; else if(mode==MODE_SOBEL) text_char=" "; else text_char="O";
            11:if(mode==MODE_ORIGINAL) text_char="A"; else if(mode==MODE_SOBEL) text_char=" "; else text_char="N";
            12:if(mode==MODE_ORIGINAL) text_char="L"; else text_char=" ";
            default:text_char=" ";
          endcase
        end
        1: begin
          case (pos)
            0:text_char="F"; 1:text_char="R"; 2:text_char="A"; 3:text_char="M"; 4:text_char="E"; 5:text_char=":";
            6:text_char=hex_ascii(frame_digits_in[39:36]); 7:text_char=hex_ascii(frame_digits_in[35:32]);
            8:text_char=hex_ascii(frame_digits_in[31:28]); 9:text_char=hex_ascii(frame_digits_in[27:24]);
            10:text_char=hex_ascii(frame_digits_in[23:20]); 11:text_char=hex_ascii(frame_digits_in[19:16]);
            12:text_char=hex_ascii(frame_digits_in[15:12]); 13:text_char=hex_ascii(frame_digits_in[11:8]);
            14:text_char=hex_ascii(frame_digits_in[7:4]); 15:text_char=hex_ascii(frame_digits_in[3:0]);
            default:text_char=" ";
          endcase
        end
        2: begin
          case (pos)
            0:text_char="R"; 1:text_char="E"; 2:text_char="D"; 3:text_char="_";
            4:text_char="P"; 5:text_char="A"; 6:text_char="R"; 7:text_char="T";
            default:text_char=" ";
          endcase
        end
        3: begin
          case (pos)
            0:text_char="N"; 1:text_char=":"; 2:text_char=detected ? "1" : "0";
            4:text_char="W"; 5:text_char=":";
            6:text_char=hex_ascii(width_digits_in[15:12]); 7:text_char=hex_ascii(width_digits_in[11:8]);
            8:text_char=hex_ascii(width_digits_in[7:4]); 9:text_char=hex_ascii(width_digits_in[3:0]);
            10:text_char="P"; 11:text_char="X"; 13:text_char="H"; 14:text_char=":";
            15:text_char=hex_ascii(height_digits_in[15:12]); 16:text_char=hex_ascii(height_digits_in[11:8]);
            17:text_char=hex_ascii(height_digits_in[7:4]); 18:text_char=hex_ascii(height_digits_in[3:0]);
            19:text_char="P"; 20:text_char="X";
            default:text_char=" ";
          endcase
        end
        4: begin
          case (pos)
            0:text_char="S"; 1:text_char="T"; 2:text_char="A"; 3:text_char="T"; 4:text_char="U"; 5:text_char="S"; 6:text_char=":";
            7: if(invalid) text_char="I"; else if(pass) text_char="P"; else if(ng) text_char="N"; else text_char="N";
            8: if(invalid) text_char="N"; else if(pass) text_char="A"; else if(ng) text_char="G"; else text_char="O";
            9: if(invalid) text_char="V"; else if(pass) text_char="S"; else if(ng) text_char=" "; else text_char="_";
            10:if(invalid) text_char="A"; else if(pass) text_char="S"; else if(!ng) text_char="O";
            11:if(invalid) text_char="L"; else if(!pass && !ng) text_char="B";
            12:if(invalid) text_char="I"; else if(!pass && !ng) text_char="J";
            13:if(invalid) text_char="D"; else if(!pass && !ng) text_char="E";
            14:if(!invalid && !pass && !ng) text_char="C";
            15:if(!invalid && !pass && !ng) text_char="T";
            default:text_char=" ";
          endcase
        end
        5: begin
          case (pos)
            0:text_char="P"; 1:text_char="R"; 2:text_char="O"; 3:text_char="C";
            4:text_char=":"; 5:text_char="C"; 6:text_char="Y"; 7:text_char="C"; 8:text_char=" ";
            9: if(proc_valid) text_char=hex_ascii(proc_cycles[31:28]); else text_char="N";
            10:if(proc_valid) text_char=hex_ascii(proc_cycles[27:24]); else text_char="/";
            11:if(proc_valid) text_char=hex_ascii(proc_cycles[23:20]); else text_char="A";
            12:if(proc_valid) text_char=hex_ascii(proc_cycles[19:16]);
            13:if(proc_valid) text_char=hex_ascii(proc_cycles[15:12]);
            14:if(proc_valid) text_char=hex_ascii(proc_cycles[11:8]);
            15:if(proc_valid) text_char=hex_ascii(proc_cycles[7:4]);
            16:if(proc_valid) text_char=hex_ascii(proc_cycles[3:0]);
            default:text_char=" ";
          endcase
        end
        6: begin
          case (pos)
            0:text_char="V"; 1:text_char="I"; 2:text_char="D"; 3:text_char="E"; 4:text_char="O";
            5:text_char=":"; 6:text_char="N"; 7:text_char="/"; 8:text_char="A"; 9:text_char=" ";
            10:text_char="E"; 11:text_char="2"; 12:text_char="E"; 13:text_char=":";
            14:text_char="N"; 15:text_char="/"; 16:text_char="A";
            default:text_char=" ";
          endcase
        end
        7: begin
          if (!motion_valid) begin
            case (pos)
              0:text_char="M"; 1:text_char="O"; 2:text_char="T"; 3:text_char="I"; 4:text_char="O"; 5:text_char="N";
              6:text_char=":"; 7:text_char="N"; 8:text_char="/"; 9:text_char="A"; 10:text_char=" ";
              11:text_char="C"; 12:text_char="O"; 13:text_char="U"; 14:text_char="N"; 15:text_char="T";
              16:text_char=":"; 17:text_char="N"; 18:text_char="/"; 19:text_char="A";
              default:text_char=" ";
            endcase
          end else begin
            case (pos)
              0:text_char="M"; 1:text_char="O"; 2:text_char="T"; 3:text_char="I"; 4:text_char="O"; 5:text_char="N";
              6:text_char=":"; 7:text_char=motion ? "1" : "0"; 9:text_char="C"; 10:text_char="O";
              11:text_char="U"; 12:text_char="N"; 13:text_char="T"; 14:text_char=":";
              15:text_char=hex_ascii(motion_count[23:20]); 16:text_char=hex_ascii(motion_count[19:16]);
              17:text_char=hex_ascii(motion_count[15:12]); 18:text_char=hex_ascii(motion_count[11:8]);
              19:text_char=hex_ascii(motion_count[7:4]); 20:text_char=hex_ascii(motion_count[3:0]);
              default:text_char=" ";
            endcase
          end
        end
        8: begin
          case (pos)
            0:text_char="P"; 1:text_char="A"; 2:text_char="S"; 3:text_char="S"; 4:text_char=":";
            5:text_char=hex_ascii(pass_count[15:12]); 6:text_char=hex_ascii(pass_count[11:8]);
            7:text_char=hex_ascii(pass_count[7:4]); 8:text_char=hex_ascii(pass_count[3:0]); 9:text_char=" ";
            10:text_char="N"; 11:text_char="G"; 12:text_char=":";
            13:text_char=hex_ascii(ng_count[15:12]); 14:text_char=hex_ascii(ng_count[11:8]);
            15:text_char=hex_ascii(ng_count[7:4]); 16:text_char=hex_ascii(ng_count[3:0]);
            default:text_char=" ";
          endcase
        end
        9: begin
          case (pos)
            0:text_char="S"; 1:text_char="O"; 2:text_char="R"; 3:text_char="T"; 4:text_char=":";
            5:text_char=sort_pulse ? "1" : "0"; 6:text_char=" ";
            7:text_char="S"; 8:text_char="A"; 9:text_char="F"; 10:text_char="E"; 11:text_char=":";
            12:text_char=safe_enable ? "1" : "0";
            default:text_char=" ";
          endcase
        end
        10: begin
          if (scale_provisional) begin
            case (pos)
              0:text_char="C"; 1:text_char="A"; 2:text_char="L"; 3:text_char=":";
              4:text_char="P"; 5:text_char="R"; 6:text_char="O"; 7:text_char="V"; 8:text_char=" ";
              9:if(dimension_valid) text_char="W"; else text_char="D";
              10:if(dimension_valid) text_char=":"; else text_char="I";
              11:if(dimension_valid) text_char=hex_ascii(width_mm_digits_in[19:16]); else text_char="M";
              12:if(dimension_valid) text_char=hex_ascii(width_mm_digits_in[15:12]); else text_char=":";
              13:if(dimension_valid) text_char=hex_ascii(width_mm_digits_in[11:8]); else text_char="N";
              14:if(dimension_valid) text_char=hex_ascii(width_mm_digits_in[7:4]); else text_char="/";
              15:if(dimension_valid) text_char=hex_ascii(width_mm_digits_in[3:0]); else text_char="A";
              16:if(dimension_valid) text_char="M";
              17:if(dimension_valid) text_char="M";
              default:text_char=" ";
            endcase
          end else begin
            case (pos)
              0:text_char="C"; 1:text_char="A"; 2:text_char="L"; 3:text_char=":";
              4:text_char="C"; 5:text_char="H"; 6:text_char="E"; 7:text_char="C"; 8:text_char="K"; 9:text_char=" ";
              10:if(dimension_valid) text_char="W"; else text_char="D";
              11:if(dimension_valid) text_char=":"; else text_char="I";
              12:if(dimension_valid) text_char=hex_ascii(width_mm_digits_in[19:16]); else text_char="M";
              13:if(dimension_valid) text_char=hex_ascii(width_mm_digits_in[15:12]); else text_char=":";
              14:if(dimension_valid) text_char=hex_ascii(width_mm_digits_in[11:8]); else text_char="N";
              15:if(dimension_valid) text_char=hex_ascii(width_mm_digits_in[7:4]); else text_char="/";
              16:if(dimension_valid) text_char=hex_ascii(width_mm_digits_in[3:0]); else text_char="A";
              17:if(dimension_valid) text_char="M";
              18:if(dimension_valid) text_char="M";
              default:text_char=" ";
            endcase
          end
        end
        11: begin
          case (pos)
            0:text_char="H"; 1:text_char=":";
            2:if(dimension_valid) text_char=hex_ascii(height_mm_digits_in[19:16]); else text_char="N";
            3:if(dimension_valid) text_char=hex_ascii(height_mm_digits_in[15:12]); else text_char="/";
            4:if(dimension_valid) text_char=hex_ascii(height_mm_digits_in[11:8]); else text_char="A";
            5:if(dimension_valid) text_char=hex_ascii(height_mm_digits_in[7:4]);
            6:if(dimension_valid) text_char=hex_ascii(height_mm_digits_in[3:0]);
            7:if(dimension_valid) text_char="M";
            8:if(dimension_valid) text_char="M";
            9:text_char=" "; 10:text_char="S"; 11:text_char="H"; 12:text_char="A"; 13:text_char="P";
            14:text_char="E"; 15:text_char=":";
            16:if(shape_valid) text_char="V"; else text_char="N";
            17:if(shape_valid) text_char="A"; else text_char="/";
            18:if(shape_valid) text_char="L"; else text_char="A";
            19:if(shape_valid) text_char="I";
            20:if(shape_valid) text_char="D";
            default:text_char=" ";
          endcase
        end
        default:text_char=" ";
      endcase
    end
  endfunction

  function [4:0] glyph_row;
      input [7:0] c;
      input [2:0] row;
      begin
        glyph_row = 5'd0;
        case (c)
          "A": begin
            case (row)
              3'd0: glyph_row = 5'b01110;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b11111;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b10001;
              default: glyph_row = 5'd0;
            endcase
          end
          "B": begin
            case (row)
              3'd0: glyph_row = 5'b11110;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b11110;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b11110;
              default: glyph_row = 5'd0;
            endcase
          end
          "C": begin
            case (row)
              3'd0: glyph_row = 5'b01111;
              3'd1: glyph_row = 5'b10000;
              3'd2: glyph_row = 5'b10000;
              3'd3: glyph_row = 5'b10000;
              3'd4: glyph_row = 5'b10000;
              3'd5: glyph_row = 5'b10000;
              3'd6: glyph_row = 5'b01111;
              default: glyph_row = 5'd0;
            endcase
          end
          "D": begin
            case (row)
              3'd0: glyph_row = 5'b11110;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b10001;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b11110;
              default: glyph_row = 5'd0;
            endcase
          end
          "E": begin
            case (row)
              3'd0: glyph_row = 5'b11111;
              3'd1: glyph_row = 5'b10000;
              3'd2: glyph_row = 5'b10000;
              3'd3: glyph_row = 5'b11110;
              3'd4: glyph_row = 5'b10000;
              3'd5: glyph_row = 5'b10000;
              3'd6: glyph_row = 5'b11111;
              default: glyph_row = 5'd0;
            endcase
          end
          "F": begin
            case (row)
              3'd0: glyph_row = 5'b11111;
              3'd1: glyph_row = 5'b10000;
              3'd2: glyph_row = 5'b10000;
              3'd3: glyph_row = 5'b11110;
              3'd4: glyph_row = 5'b10000;
              3'd5: glyph_row = 5'b10000;
              3'd6: glyph_row = 5'b10000;
              default: glyph_row = 5'd0;
            endcase
          end
          "G": begin
            case (row)
              3'd0: glyph_row = 5'b01111;
              3'd1: glyph_row = 5'b10000;
              3'd2: glyph_row = 5'b10000;
              3'd3: glyph_row = 5'b10111;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b01111;
              default: glyph_row = 5'd0;
            endcase
          end
          "H": begin
            case (row)
              3'd0: glyph_row = 5'b10001;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b11111;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b10001;
              default: glyph_row = 5'd0;
            endcase
          end
          "I": begin
            case (row)
              3'd0: glyph_row = 5'b11111;
              3'd1: glyph_row = 5'b00100;
              3'd2: glyph_row = 5'b00100;
              3'd3: glyph_row = 5'b00100;
              3'd4: glyph_row = 5'b00100;
              3'd5: glyph_row = 5'b00100;
              3'd6: glyph_row = 5'b11111;
              default: glyph_row = 5'd0;
            endcase
          end
          "J": begin
            case (row)
              3'd0: glyph_row = 5'b00111;
              3'd1: glyph_row = 5'b00010;
              3'd2: glyph_row = 5'b00010;
              3'd3: glyph_row = 5'b00010;
              3'd4: glyph_row = 5'b00010;
              3'd5: glyph_row = 5'b10010;
              3'd6: glyph_row = 5'b01100;
              default: glyph_row = 5'd0;
            endcase
          end
          "K": begin
            case (row)
              3'd0: glyph_row = 5'b10001;
              3'd1: glyph_row = 5'b10010;
              3'd2: glyph_row = 5'b10100;
              3'd3: glyph_row = 5'b11000;
              3'd4: glyph_row = 5'b10100;
              3'd5: glyph_row = 5'b10010;
              3'd6: glyph_row = 5'b10001;
              default: glyph_row = 5'd0;
            endcase
          end
          "L": begin
            case (row)
              3'd0: glyph_row = 5'b10000;
              3'd1: glyph_row = 5'b10000;
              3'd2: glyph_row = 5'b10000;
              3'd3: glyph_row = 5'b10000;
              3'd4: glyph_row = 5'b10000;
              3'd5: glyph_row = 5'b10000;
              3'd6: glyph_row = 5'b11111;
              default: glyph_row = 5'd0;
            endcase
          end
          "M": begin
            case (row)
              3'd0: glyph_row = 5'b10001;
              3'd1: glyph_row = 5'b11011;
              3'd2: glyph_row = 5'b10101;
              3'd3: glyph_row = 5'b10101;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b10001;
              default: glyph_row = 5'd0;
            endcase
          end
          "N": begin
            case (row)
              3'd0: glyph_row = 5'b10001;
              3'd1: glyph_row = 5'b11001;
              3'd2: glyph_row = 5'b10101;
              3'd3: glyph_row = 5'b10011;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b10001;
              default: glyph_row = 5'd0;
            endcase
          end
          "O": begin
            case (row)
              3'd0: glyph_row = 5'b01110;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b10001;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b01110;
              default: glyph_row = 5'd0;
            endcase
          end
          "P": begin
            case (row)
              3'd0: glyph_row = 5'b11110;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b11110;
              3'd4: glyph_row = 5'b10000;
              3'd5: glyph_row = 5'b10000;
              3'd6: glyph_row = 5'b10000;
              default: glyph_row = 5'd0;
            endcase
          end
          "R": begin
            case (row)
              3'd0: glyph_row = 5'b11110;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b11110;
              3'd4: glyph_row = 5'b10100;
              3'd5: glyph_row = 5'b10010;
              3'd6: glyph_row = 5'b10001;
              default: glyph_row = 5'd0;
            endcase
          end
          "S": begin
            case (row)
              3'd0: glyph_row = 5'b01111;
              3'd1: glyph_row = 5'b10000;
              3'd2: glyph_row = 5'b10000;
              3'd3: glyph_row = 5'b01110;
              3'd4: glyph_row = 5'b00001;
              3'd5: glyph_row = 5'b00001;
              3'd6: glyph_row = 5'b11110;
              default: glyph_row = 5'd0;
            endcase
          end
          "T": begin
            case (row)
              3'd0: glyph_row = 5'b11111;
              3'd1: glyph_row = 5'b00100;
              3'd2: glyph_row = 5'b00100;
              3'd3: glyph_row = 5'b00100;
              3'd4: glyph_row = 5'b00100;
              3'd5: glyph_row = 5'b00100;
              3'd6: glyph_row = 5'b00100;
              default: glyph_row = 5'd0;
            endcase
          end
          "U": begin
            case (row)
              3'd0: glyph_row = 5'b10001;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b10001;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b01110;
              default: glyph_row = 5'd0;
            endcase
          end
          "V": begin
            case (row)
              3'd0: glyph_row = 5'b10001;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b10001;
              3'd4: glyph_row = 5'b01010;
              3'd5: glyph_row = 5'b01010;
              3'd6: glyph_row = 5'b00100;
              default: glyph_row = 5'd0;
            endcase
          end
          "W": begin
            case (row)
              3'd0: glyph_row = 5'b10001;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b10101;
              3'd4: glyph_row = 5'b10101;
              3'd5: glyph_row = 5'b10101;
              3'd6: glyph_row = 5'b01010;
              default: glyph_row = 5'd0;
            endcase
          end
          "X": begin
            case (row)
              3'd0: glyph_row = 5'b10001;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b01010;
              3'd3: glyph_row = 5'b00100;
              3'd4: glyph_row = 5'b01010;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b10001;
              default: glyph_row = 5'd0;
            endcase
          end
          "Y": begin
            case (row)
              3'd0: glyph_row = 5'b10001;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b01010;
              3'd3: glyph_row = 5'b00100;
              3'd4: glyph_row = 5'b00100;
              3'd5: glyph_row = 5'b00100;
              3'd6: glyph_row = 5'b00100;
              default: glyph_row = 5'd0;
            endcase
          end
          "0": begin
            case (row)
              3'd0: glyph_row = 5'b01110;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10011;
              3'd3: glyph_row = 5'b10101;
              3'd4: glyph_row = 5'b11001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b01110;
              default: glyph_row = 5'd0;
            endcase
          end
          "1": begin
            case (row)
              3'd0: glyph_row = 5'b00100;
              3'd1: glyph_row = 5'b01100;
              3'd2: glyph_row = 5'b00100;
              3'd3: glyph_row = 5'b00100;
              3'd4: glyph_row = 5'b00100;
              3'd5: glyph_row = 5'b00100;
              3'd6: glyph_row = 5'b01110;
              default: glyph_row = 5'd0;
            endcase
          end
          "2": begin
            case (row)
              3'd0: glyph_row = 5'b01110;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b00001;
              3'd3: glyph_row = 5'b00010;
              3'd4: glyph_row = 5'b00100;
              3'd5: glyph_row = 5'b01000;
              3'd6: glyph_row = 5'b11111;
              default: glyph_row = 5'd0;
            endcase
          end
          "3": begin
            case (row)
              3'd0: glyph_row = 5'b11110;
              3'd1: glyph_row = 5'b00001;
              3'd2: glyph_row = 5'b00001;
              3'd3: glyph_row = 5'b01110;
              3'd4: glyph_row = 5'b00001;
              3'd5: glyph_row = 5'b00001;
              3'd6: glyph_row = 5'b11110;
              default: glyph_row = 5'd0;
            endcase
          end
          "4": begin
            case (row)
              3'd0: glyph_row = 5'b00010;
              3'd1: glyph_row = 5'b00110;
              3'd2: glyph_row = 5'b01010;
              3'd3: glyph_row = 5'b10010;
              3'd4: glyph_row = 5'b11111;
              3'd5: glyph_row = 5'b00010;
              3'd6: glyph_row = 5'b00010;
              default: glyph_row = 5'd0;
            endcase
          end
          "5": begin
            case (row)
              3'd0: glyph_row = 5'b11111;
              3'd1: glyph_row = 5'b10000;
              3'd2: glyph_row = 5'b10000;
              3'd3: glyph_row = 5'b11110;
              3'd4: glyph_row = 5'b00001;
              3'd5: glyph_row = 5'b00001;
              3'd6: glyph_row = 5'b11110;
              default: glyph_row = 5'd0;
            endcase
          end
          "6": begin
            case (row)
              3'd0: glyph_row = 5'b00110;
              3'd1: glyph_row = 5'b01000;
              3'd2: glyph_row = 5'b10000;
              3'd3: glyph_row = 5'b11110;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b01110;
              default: glyph_row = 5'd0;
            endcase
          end
          "7": begin
            case (row)
              3'd0: glyph_row = 5'b11111;
              3'd1: glyph_row = 5'b00001;
              3'd2: glyph_row = 5'b00010;
              3'd3: glyph_row = 5'b00100;
              3'd4: glyph_row = 5'b01000;
              3'd5: glyph_row = 5'b01000;
              3'd6: glyph_row = 5'b01000;
              default: glyph_row = 5'd0;
            endcase
          end
          "8": begin
            case (row)
              3'd0: glyph_row = 5'b01110;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b01110;
              3'd4: glyph_row = 5'b10001;
              3'd5: glyph_row = 5'b10001;
              3'd6: glyph_row = 5'b01110;
              default: glyph_row = 5'd0;
            endcase
          end
          "9": begin
            case (row)
              3'd0: glyph_row = 5'b01110;
              3'd1: glyph_row = 5'b10001;
              3'd2: glyph_row = 5'b10001;
              3'd3: glyph_row = 5'b01111;
              3'd4: glyph_row = 5'b00001;
              3'd5: glyph_row = 5'b00010;
              3'd6: glyph_row = 5'b11100;
              default: glyph_row = 5'd0;
            endcase
          end
          ":": begin
            case (row)
              3'd0: glyph_row = 5'b00000;
              3'd1: glyph_row = 5'b00100;
              3'd2: glyph_row = 5'b00100;
              3'd3: glyph_row = 5'b00000;
              3'd4: glyph_row = 5'b00100;
              3'd5: glyph_row = 5'b00100;
              3'd6: glyph_row = 5'b00000;
              default: glyph_row = 5'd0;
            endcase
          end
          "_": begin
            case (row)
              3'd0: glyph_row = 5'b00000;
              3'd1: glyph_row = 5'b00000;
              3'd2: glyph_row = 5'b00000;
              3'd3: glyph_row = 5'b00000;
              3'd4: glyph_row = 5'b00000;
              3'd5: glyph_row = 5'b00000;
              3'd6: glyph_row = 5'b11111;
              default: glyph_row = 5'd0;
            endcase
          end
          "/": begin
            case (row)
              3'd0: glyph_row = 5'b00010;
              3'd1: glyph_row = 5'b00010;
              3'd2: glyph_row = 5'b00100;
              3'd3: glyph_row = 5'b00100;
              3'd4: glyph_row = 5'b01000;
              3'd5: glyph_row = 5'b01000;
              3'd6: glyph_row = 5'b10000;
              default: glyph_row = 5'd0;
            endcase
          end
          default: glyph_row = 5'd0;
        endcase
      end
  endfunction

  // ==========================================================================
  // Three-stage overlay pipeline (E2 timing-closure change).
  //
  //   stage 0  coordinate decode      x,y -> text cell + logo address
  //   stage 1  registered cell/addr,  video delayed by 1
  //   stage 2  registered char/logo   video delayed by 2
  //   stage 3  registered RGB select (the only output register)
  //
  // I_rgb / I_de / I_hsync / I_vsync are delayed by the same three cycles, so
  // the emitted pixel for every (x,y) is unchanged; only the constant pipeline
  // latency differs, and DE/HS/VS keep their exact relationship to RGB.
  // ==========================================================================

  integer text_line_c;
  integer text_pos_c;
  integer text_row_c;
  integer text_col_c;
  reg     text_active_c;

  always @* begin
    text_active_c = 1'b0;
    text_line_c   = -1;
    text_pos_c    = 0;
    text_row_c    = 0;
    text_col_c    = 0;
    if (I_de && (x >= 12'd180) && (x < 12'd436) &&
        (((y >= 12'd8) && (y < 12'd24)) ||
         ((y >= 12'd32) && (y < 12'd48)) ||
         ((y >= 12'd56) && (y < 12'd72)) ||
         ((y >= 12'd80) && (y < 12'd96)) ||
         ((y >= 12'd104) && (y < 12'd120)) ||
         ((y >= 12'd128) && (y < 12'd144)) ||
         ((y >= 12'd152) && (y < 12'd168)) ||
         ((y >= 12'd176) && (y < 12'd192)) ||
         ((y >= 12'd200) && (y < 12'd216)) ||
         ((y >= 12'd224) && (y < 12'd240)) ||
         ((y >= 12'd248) && (y < 12'd264)) ||
         ((y >= 12'd272) && (y < 12'd288)))) begin
      text_active_c = 1'b1;
      if (y < 24) text_line_c=0;
      else if (y < 48) text_line_c=1;
      else if (y < 72) text_line_c=2;
      else if (y < 96) text_line_c=3;
      else if (y < 120) text_line_c=4;
      else if (y < 144) text_line_c=5;
      else if (y < 168) text_line_c=6;
      else if (y < 192) text_line_c=7;
      else if (y < 216) text_line_c=8;
      else if (y < 240) text_line_c=9;
      else if (y < 264) text_line_c=10;
      else text_line_c=11;
      text_pos_c = (x - 180) >> 3;
      text_row_c = (y - (8 + text_line_c*24)) >> 1;
      text_col_c = ((x - 180) & 7) >> 1;
    end
  end

  // ---- stage 1 -------------------------------------------------------------
  reg        in_logo_s1;
  reg [14:0] logo_addr_s1;
  reg        text_active_s1;
  reg [3:0]  text_line_s1;
  reg [4:0]  text_pos_s1;
  reg [2:0]  text_row_s1;
  reg [2:0]  text_col_s1;
  reg [1:0]  mode_s1;
  reg [23:0] rgb_s1;
  reg        de_s1, hs_s1, vs_s1;

  // ---- stage 2 -------------------------------------------------------------
  wire [24:0] logo_pixel_w;
  wire [7:0]  current_char_w;
  reg  [24:0] logo_pixel_s2;
  reg  [7:0]  current_char_s2;
  reg         in_logo_s2;
  reg         text_active_s2;
  reg  [2:0]  text_row_s2;
  reg  [2:0]  text_col_s2;
  reg  [23:0] rgb_s2;
  reg         de_s2, hs_s2, vs_s2;

  anlogic_logo_rom u_logo_rom(.I_addr(logo_addr_s1), .O_pixel(logo_pixel_w));

  assign current_char_w = text_char(text_line_s1, text_pos_s1, mode_s1,
                                    frame_digits, width_digits, height_digits,
                                    detected_snapshot, pass_snapshot, ng_snapshot,
                                    invalid_snapshot,
                                    proc_valid_snapshot, proc_cycles_snapshot,
                                    motion_valid_snapshot, motion_snapshot,
                                    motion_count_snapshot,
                                    pass_count_snapshot, ng_count_snapshot,
                                    sort_pulse_snapshot,
                                    safe_enable_snapshot, dimension_valid_snapshot,
                                    shape_valid_snapshot,
                                    scale_provisional_snapshot, width_mm_digits,
                                    height_mm_digits);

  // ---- stage 3 combination -------------------------------------------------
  wire [4:0]  glyph_row_w   = glyph_row(current_char_s2, text_row_s2);
  wire        text_on_s2    = text_active_s2 && glyph_row_w[4 - text_col_s2];
  wire [23:0] text_color_s2 = invalid_snapshot ? 24'hef4444 :
                              pass_snapshot    ? 24'h10b981 :
                              ng_snapshot      ? 24'hef4444 : 24'hf59e0b;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      x <= 0; y <= 0; vsync_d <= 0;
      frame_digits <= 0; width_digits <= 0; height_digits <= 0;
      detected_snapshot <= 1'b0; pass_snapshot <= 1'b0;
      ng_snapshot <= 1'b0; invalid_snapshot <= 1'b0;
      proc_valid_snapshot <= 1'b0; proc_cycles_snapshot <= 32'd0;
      motion_valid_snapshot <= 1'b0; motion_snapshot <= 1'b0;
      motion_count_snapshot <= 24'd0;
      pass_count_snapshot <= 16'd0; ng_count_snapshot <= 16'd0;
      sort_pulse_snapshot <= 1'b0; safe_enable_snapshot <= 1'b0;
      dimension_valid_snapshot <= 1'b0; shape_valid_snapshot <= 1'b0;
      scale_provisional_snapshot <= 1'b1;
      width_mm_digits <= 20'd0; height_mm_digits <= 20'd0;

      in_logo_s1 <= 1'b0; logo_addr_s1 <= 15'd0; text_active_s1 <= 1'b0;
      text_line_s1 <= 4'd0; text_pos_s1 <= 5'd0; text_row_s1 <= 3'd0;
      text_col_s1 <= 3'd0; mode_s1 <= 2'd0;
      rgb_s1 <= 24'd0; de_s1 <= 1'b0; hs_s1 <= 1'b0; vs_s1 <= 1'b0;

      logo_pixel_s2 <= 25'd0; current_char_s2 <= 8'h20;
      in_logo_s2 <= 1'b0; text_active_s2 <= 1'b0;
      text_row_s2 <= 3'd0; text_col_s2 <= 3'd0;
      rgb_s2 <= 24'd0; de_s2 <= 1'b0; hs_s2 <= 1'b0; vs_s2 <= 1'b0;
    end else begin
      // ---- pipeline stage 1 ------------------------------------------------
      in_logo_s1     <= in_logo;
      logo_addr_s1   <= logo_addr;
      text_active_s1 <= text_active_c;
      text_line_s1   <= text_line_c;
      text_pos_s1    <= text_pos_c;
      text_row_s1    <= text_row_c;
      text_col_s1    <= text_col_c;
      mode_s1        <= I_mode;
      rgb_s1         <= I_rgb;
      de_s1          <= I_de;
      hs_s1          <= I_hsync;
      vs_s1          <= I_vsync;

      // ---- pipeline stage 2 ------------------------------------------------
      logo_pixel_s2   <= logo_pixel_w;
      current_char_s2 <= current_char_w;
      in_logo_s2      <= in_logo_s1;
      text_active_s2  <= text_active_s1;
      text_row_s2     <= text_row_s1;
      text_col_s2     <= text_col_s1;
      rgb_s2          <= rgb_s1;
      de_s2           <= de_s1;
      hs_s2           <= hs_s1;
      vs_s2           <= vs_s1;

      // ---- frame-boundary snapshot state (unchanged) -----------------------
      vsync_d <= I_vsync;
      if (I_vsync && !vsync_d) begin
        frame_digits <= bcd_increment(frame_digits);
        width_digits <= dimension_to_bcd(I_width);
        height_digits <= dimension_to_bcd(I_height);
        detected_snapshot <= I_detected;
        pass_snapshot <= I_pass;
        ng_snapshot <= I_ng;
        invalid_snapshot <= I_invalid;
        proc_valid_snapshot <= I_proc_valid;
        proc_cycles_snapshot <= I_proc_cycles;
        motion_valid_snapshot <= I_motion_valid;
        motion_snapshot <= I_motion;
        motion_count_snapshot <= I_motion_count;
        pass_count_snapshot <= I_pass_count;
        ng_count_snapshot <= I_ng_count;
        sort_pulse_snapshot <= I_sort_pulse;
        safe_enable_snapshot <= I_safe_enable;
        dimension_valid_snapshot <= I_dimension_valid;
        shape_valid_snapshot <= I_shape_valid;
        scale_provisional_snapshot <= I_scale_provisional;
        width_mm_digits <= mm_integer_to_bcd(I_width_mm_q16_16[31:16]);
        height_mm_digits <= mm_integer_to_bcd(I_height_mm_q16_16[31:16]);
      end

      if (I_vsync) begin
        x <= 0; y <= 0;
      end else if (I_de) begin
        if (x == IMG_WIDTH-1) begin
          x <= 0;
          y <= (y == IMG_HEIGHT-1) ? 0 : y + 1'b1;
        end else x <= x + 1'b1;
      end
    end
  end

  // ---- stage 3 output register ---------------------------------------------
  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      O_vsync <= 1'b0; O_hsync <= 1'b0; O_de <= 1'b0; O_rgb <= 24'd0;
    end else begin
      O_vsync <= vs_s2;
      O_hsync <= hs_s2;
      O_de    <= de_s2;
      if (!de_s2)
        O_rgb <= 24'd0;
      else if (in_logo_s2 && logo_pixel_s2[24])
        O_rgb <= logo_pixel_s2[23:0];
      else if (text_on_s2)
        O_rgb <= text_color_s2;
      else
        O_rgb <= rgb_s2;
    end
  end

endmodule
