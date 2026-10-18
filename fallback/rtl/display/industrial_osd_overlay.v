`timescale 1ns / 1ps
// ============================================================================
// HDMI-domain OSD for the fixed red-part inspection demo.
//
// The overlay consumes the same frame-stable result bus as the bounding box.
// It embeds the Anlogic logo ROM and a small synthesizable 5x7 character set.
// Frame count is shown in hexadecimal to avoid a divider on the pixel path;
// width/height are shown as three hexadecimal digits (pixel units).
// ============================================================================

module industrial_osd_overlay #(
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
  reg [31:0] frame_counter;

  wire [14:0] logo_addr = ((y << 7) + (y << 5)) + x;
  wire [24:0] logo_pixel;
  wire in_logo = I_de && (x < LOGO_W) && (y < LOGO_H);
  anlogic_logo_rom u_logo_rom(.I_addr(logo_addr), .O_pixel(logo_pixel));

  function [7:0] hex_ascii;
    input [3:0] value;
    begin
      if (value < 10) hex_ascii = 8'h30 + value;
      else hex_ascii = 8'h41 + value - 10;
    end
  endfunction

  function [7:0] text_char;
    input integer line;
    input integer pos;
    input [1:0] mode;
    input [31:0] frame;
    input [10:0] width;
    input [10:0] height;
    input detected;
    input pass;
    input ng;
    input invalid;
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
            6:text_char=hex_ascii(frame[31:28]); 7:text_char=hex_ascii(frame[27:24]);
            8:text_char=hex_ascii(frame[23:20]); 9:text_char=hex_ascii(frame[19:16]);
            10:text_char=hex_ascii(frame[15:12]); 11:text_char=hex_ascii(frame[11:8]);
            12:text_char=hex_ascii(frame[7:4]); 13:text_char=hex_ascii(frame[3:0]);
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
            6:text_char=hex_ascii(width[10:8]); 7:text_char=hex_ascii(width[7:4]);
            8:text_char=hex_ascii(width[3:0]); 10:text_char="H"; 11:text_char=":";
            12:text_char=hex_ascii(height[10:8]); 13:text_char=hex_ascii(height[7:4]);
            14:text_char=hex_ascii(height[3:0]);
            default:text_char=" ";
          endcase
        end
        4: begin
          case (pos)
            0:text_char="S"; 1:text_char="T"; 2:text_char="A"; 3:text_char="T"; 4:text_char="U"; 5:text_char="S"; 6:text_char=":";
            7: if(invalid) text_char="I"; else if(pass) text_char="P"; else if(ng) text_char="N"; else text_char="N";
            8: if(invalid) text_char="N"; else if(pass) text_char="A"; else if(ng) text_char="G"; else text_char="O";
            9: if(invalid) text_char="V"; else if(pass) text_char="S"; else if(ng) text_char=" "; else text_char="_";
            10:if(invalid) text_char="A"; else if(pass) text_char="S"; else if(ng) text_char=" "; else text_char="O";
            11:if(invalid) text_char="L"; else if(pass) text_char=" "; else if(ng) text_char=" "; else text_char="B";
            12:if(invalid) text_char="I"; else if(pass) text_char=" "; else if(ng) text_char=" "; else text_char="J";
            13:if(invalid) text_char="D"; else if(pass) text_char=" "; else if(ng) text_char=" "; else text_char="E";
            14:if(invalid) text_char=" "; else if(pass) text_char=" "; else if(ng) text_char=" "; else text_char="C";
            15:if(invalid) text_char=" "; else if(pass) text_char=" "; else if(ng) text_char=" "; else text_char="T";
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
          default: glyph_row = 5'd0;
        endcase
      end
  endfunction

  integer text_line;
  integer text_pos;
  integer text_row;
  integer text_col;
  reg [7:0] current_char;
  reg [4:0] current_row;
  reg        text_on;
  reg [23:0] text_color;

  always @* begin
    text_line = -1;
    text_pos = 0;
    text_row = 0;
    text_col = 0;
    current_char = 8'h20;
    current_row = 5'd0;
    text_on = 1'b0;
    text_color = 24'hffffff;
    if (I_de && (x >= 12'd180) && (x < 12'd436) &&
        (((y >= 12'd8) && (y < 12'd24)) ||
         ((y >= 12'd32) && (y < 12'd48)) ||
         ((y >= 12'd56) && (y < 12'd72)) ||
         ((y >= 12'd80) && (y < 12'd96)) ||
         ((y >= 12'd104) && (y < 12'd120)))) begin
      if (y < 24) text_line=0;
      else if (y < 48) text_line=1;
      else if (y < 72) text_line=2;
      else if (y < 96) text_line=3;
      else text_line=4;
      text_pos = (x - 180) >> 3;
      text_row = (y - (8 + text_line*24)) >> 1;
      text_col = ((x - 180) & 7) >> 1;
      current_char = text_char(text_line,text_pos,I_mode,frame_counter,I_width,I_height,
                               I_detected,I_pass,I_ng,I_invalid);
      current_row = glyph_row(current_char, text_row[2:0]);
      text_on = current_row[4-text_col];
      if (I_invalid) text_color=24'hef4444;
      else if (I_pass) text_color=24'h10b981;
      else if (I_ng) text_color=24'hef4444;
      else text_color=24'hf59e0b;
    end
  end

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      x <= 0; y <= 0; vsync_d <= 0; frame_counter <= 0;
      O_vsync <= 0; O_hsync <= 0; O_de <= 0; O_rgb <= 0;
    end else begin
      O_vsync <= I_vsync;
      O_hsync <= I_hsync;
      O_de <= I_de;
      if (!I_de)
        O_rgb <= 24'd0;
      else if (in_logo && logo_pixel[24])
        O_rgb <= logo_pixel[23:0];
      else if (text_on)
        O_rgb <= text_color;
      else
        O_rgb <= I_rgb;

      vsync_d <= I_vsync;
      if (I_vsync && !vsync_d)
        frame_counter <= frame_counter + 32'd1;

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
endmodule
