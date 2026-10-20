`timescale 1ns/1ps

module tb_industrial_osd_telemetry;
  reg clk = 1'b0;
  always #5 clk = ~clk;

  reg rst_n = 1'b0;
  reg vsync = 1'b0;
  reg hsync = 1'b0;
  reg de = 1'b0;
  reg [23:0] rgb = 24'h010203;
  reg [1:0] mode = 2'd0;
  reg detected = 1'b1, pass_value = 1'b1, ng = 1'b0, invalid = 1'b0;
  reg [10:0] width_px = 11'd2047, height_px = 11'd2047;
  reg proc_valid = 1'b1;
  reg [31:0] proc_cycles = 32'h89ABCDEF;
  reg motion_valid = 1'b1, motion = 1'b1;
  reg [23:0] motion_count = 24'hFFFFFF;
  reg [15:0] pass_count = 16'hFFFF, ng_count = 16'hFFFF;
  reg sort_pulse = 1'b1, safe_enable = 1'b0;
  reg dimension_valid = 1'b1, shape_valid = 1'b1, scale_provisional = 1'b1;
  reg [31:0] width_mm = 32'd3932160, height_mm = 32'd1310720;

  wire out_vsync, out_hsync, out_de;
  wire [23:0] out_rgb;

  industrial_osd_overlay #(
    .IMG_WIDTH(640), .IMG_HEIGHT(360), .LOGO_W(0), .LOGO_H(0)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vsync), .I_hsync(hsync), .I_de(de),
    .I_rgb(rgb), .I_mode(mode), .I_detected(detected), .I_pass(pass_value),
    .I_ng(ng), .I_invalid(invalid), .I_width(width_px), .I_height(height_px),
    .I_proc_valid(proc_valid), .I_proc_cycles(proc_cycles),
    .I_motion_valid(motion_valid), .I_motion(motion), .I_motion_count(motion_count),
    .I_pass_count(pass_count), .I_ng_count(ng_count),
    .I_sort_pulse(sort_pulse), .I_safe_enable(safe_enable),
    .I_dimension_valid(dimension_valid), .I_shape_valid(shape_valid),
    .I_scale_provisional(scale_provisional), .I_width_mm_q16_16(width_mm),
    .I_height_mm_q16_16(height_mm),
    .O_vsync(out_vsync), .O_hsync(out_hsync), .O_de(out_de), .O_rgb(out_rgb)
  );

  task pulse_frame_boundary;
    begin
      @(negedge clk); vsync = 1'b1;
      @(posedge clk); #1;
      @(negedge clk); vsync = 1'b0;
      @(posedge clk); #1;
    end
  endtask

  task check_pixel;
    input integer px;
    input integer py;
    input [23:0] expected_rgb;
    input [7:0] expected_char;
    input [8*32-1:0] label;
    begin
      @(negedge clk);
      de = 1'b1;
      dut.x = px;
      dut.y = py;
      #1;
      if (dut.current_char !== expected_char)
        $fatal(1, "%0s char mismatch at (%0d,%0d): got %0s expected %0s",
               label, px, py, dut.current_char, expected_char);
      @(posedge clk); #1;
      if (out_rgb !== expected_rgb)
        $fatal(1, "%0s pixel mismatch at (%0d,%0d): got %h expected %h",
               label, px, py, out_rgb, expected_rgb);
      if (out_de !== de || out_hsync !== hsync || out_vsync !== vsync)
        $fatal(1, "%0s timing sideband lost one-cycle alignment", label);
    end
  endtask

  initial begin
    repeat (3) @(negedge clk);
    rst_n = 1'b1;
    pulse_frame_boundary();

    // Mutating the inputs mid-frame must not change the displayed snapshot.
    proc_valid = 1'b0;
    proc_cycles = 32'hFFFFFFFF;
    check_pixel(180, 8, 24'h10B981, "M", "mode row");
    check_pixel(180, 8 + 1*24, 24'h10B981, "F", "frame row");
    check_pixel(180, 8 + 2*24, 24'h10B981, "R", "target row");
    check_pixel(180 + 7*8, 8 + 4*24, 24'h10B981, "P", "verdict row");
    check_pixel(180 + 9*8 + 2, 8 + 5*24, 24'h10B981, "8", "matched PROC");
    check_pixel(180, 8 + 6*24, 24'h10B981, "V", "VIDEO N/A");
    check_pixel(180 + 15*8, 8 + 7*24, 24'h10B981, "F", "maximum motion count");
    check_pixel(180 + 5*8, 8 + 8*24, 24'h10B981, "F", "maximum PASS/NG counts");
    check_pixel(180 + 5*8 + 4, 8 + 9*24, 24'h10B981, "1", "sort pulse row");
    check_pixel(180 + 12*8 + 2, 8 + 9*24, 24'h10B981, "0", "safe-default row");
    check_pixel(180 + 10*8, 8 + 3*24, 24'h10B981, "P", "pixel unit");
    check_pixel(180 + 6*8 + 2, 8 + 3*24, 24'h10B981, "2", "2047 pixel width");
    check_pixel(180 + 11*8 + 2, 8 + 10*24, 24'h10B981, "0", "provisional mm width");
    check_pixel(180 + 16*8, 8 + 11*24, 24'h10B981, "V", "shape row");

    // A new frame atomically publishes invalid PROC/dimension data.
    dimension_valid = 1'b0;
    shape_valid = 1'b0;
    width_mm = 32'hFFFFFFFF;
    height_mm = 32'hFFFFFFFF;
    pulse_frame_boundary();
    check_pixel(180 + 9*8, 8 + 5*24, 24'h10B981, "N", "invalid PROC N/A");
    check_pixel(180 + 10*8 + 6, 8 + 5*24, 24'h10B981, "/", "invalid PROC slash");
    check_pixel(180 + 9*8, 8 + 10*24, 24'h10B981, "D", "invalid dimensions N/A");
    check_pixel(180 + 11*8, 8 + 10*24, 24'h10B981, "M", "no stale dimension value");
    check_pixel(180 + 16*8, 8 + 11*24, 24'h10B981, "N", "invalid shape N/A");

    // The bounded five-digit candidate conversion also retains its maximum.
    dimension_valid = 1'b1;
    shape_valid = 1'b1;
    width_mm = 32'hFFFFFFFF;
    height_mm = 32'hFFFFFFFF;
    pulse_frame_boundary();
    check_pixel(180 + 11*8 + 4, 8 + 10*24, 24'h10B981, "6", "maximum mm ten-thousands digit");
    check_pixel(180 + 15*8 + 2, 8 + 10*24, 24'h10B981, "5", "maximum mm ones digit");
    check_pixel(180 + 2*8 + 4, 8 + 11*24, 24'h10B981, "6", "maximum height mm digit");

    $display("TB_INDUSTRIAL_OSD_TELEMETRY_PASS");
    $finish;
  end
endmodule
