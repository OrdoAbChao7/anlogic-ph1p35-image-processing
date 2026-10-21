`timescale 1ns/1ps

module tb_industrial_v2_result_cdc;
  reg src_clk = 1'b0;
  reg dst_clk = 1'b0;
  always #5 src_clk = ~src_clk;
  always #7 dst_clk = ~dst_clk;

  reg rst_n = 1'b0;
  reg src_toggle = 1'b0;
  reg [15:0] src_frame_id = 16'd0;
  reg [10:0] src_xmin = 11'd10, src_xmax = 11'd129;
  reg [10:0] src_ymin = 11'd20, src_ymax = 11'd99;
  reg [10:0] src_cx = 11'd69, src_cy = 11'd59;
  reg [31:0] src_width = 32'd3932160, src_height = 32'd1310720;
  reg src_detected = 1'b1, src_pass = 1'b1, src_ng = 1'b0, src_invalid = 1'b0;
  reg src_dimension_valid = 1'b1, src_shape_valid = 1'b1;
  reg src_motion_valid = 1'b1, src_motion = 1'b1;
  reg [23:0] src_motion_count = 24'd7;
  reg [15:0] src_pass_count = 16'd3, src_ng_count = 16'd1;
  reg src_sort_pulse = 1'b1, src_safe_enable = 1'b1;
  reg src_proc_valid = 1'b1;
  reg [31:0] src_proc_cycles = 32'h12345678;

  wire dst_valid;
  wire [15:0] dst_frame_id;
  wire [10:0] dst_xmin, dst_xmax, dst_ymin, dst_ymax, dst_cx, dst_cy;
  wire [31:0] dst_width, dst_height;
  wire dst_detected, dst_pass, dst_ng, dst_invalid;
  wire dst_dimension_valid, dst_shape_valid, dst_motion_valid, dst_motion;
  wire [23:0] dst_motion_count;
  wire [15:0] dst_pass_count, dst_ng_count;
  wire dst_sort_pulse, dst_safe_enable, dst_overflow;
  wire dst_proc_valid;
  wire [31:0] dst_proc_cycles;

  industrial_v2_result_cdc dut (
    .I_src_clk(src_clk), .I_dst_clk(dst_clk),
    .I_src_rst_n(rst_n), .I_dst_rst_n(rst_n),
    .I_src_toggle(src_toggle), .I_src_frame_id(src_frame_id),
    .I_src_xmin(src_xmin), .I_src_xmax(src_xmax),
    .I_src_ymin(src_ymin), .I_src_ymax(src_ymax),
    .I_src_cx(src_cx), .I_src_cy(src_cy),
    .I_src_width_mm_q16_16(src_width), .I_src_height_mm_q16_16(src_height),
    .I_src_detected(src_detected), .I_src_pass(src_pass), .I_src_ng(src_ng),
    .I_src_invalid(src_invalid), .I_src_dimension_valid(src_dimension_valid),
    .I_src_shape_valid(src_shape_valid), .I_src_motion_valid(src_motion_valid),
    .I_src_motion(src_motion),
    .I_src_motion_count(src_motion_count), .I_src_pass_count(src_pass_count),
    .I_src_ng_count(src_ng_count), .I_src_sort_pulse(src_sort_pulse),
    .I_src_safe_enable(src_safe_enable),
    .I_src_proc_valid(src_proc_valid), .I_src_proc_cycles(src_proc_cycles),
    .O_dst_proc_valid(dst_proc_valid), .O_dst_proc_cycles(dst_proc_cycles),
    .O_dst_valid(dst_valid),
    .O_dst_frame_id(dst_frame_id), .O_dst_xmin(dst_xmin), .O_dst_xmax(dst_xmax),
    .O_dst_ymin(dst_ymin), .O_dst_ymax(dst_ymax), .O_dst_cx(dst_cx),
    .O_dst_cy(dst_cy), .O_dst_width_mm_q16_16(dst_width),
    .O_dst_height_mm_q16_16(dst_height), .O_dst_detected(dst_detected),
    .O_dst_pass(dst_pass), .O_dst_ng(dst_ng), .O_dst_invalid(dst_invalid),
    .O_dst_dimension_valid(dst_dimension_valid), .O_dst_shape_valid(dst_shape_valid),
    .O_dst_motion_valid(dst_motion_valid), .O_dst_motion(dst_motion),
    .O_dst_motion_count(dst_motion_count),
    .O_dst_pass_count(dst_pass_count), .O_dst_ng_count(dst_ng_count),
    .O_dst_sort_pulse(dst_sort_pulse), .O_dst_safe_enable(dst_safe_enable),
    .O_dst_overflow(dst_overflow)
  );

  reg seen_one;
  reg seen_two;
  always @(posedge dst_clk) begin
    if (dst_valid) begin
      if (dst_frame_id == 16'd17) begin
        seen_one <= 1'b1;
        if (dst_cx != 11'd69 || dst_shape_valid != 1'b1 ||
            dst_dimension_valid != 1'b1 || dst_width != 32'd3932160 ||
            dst_height != 32'd1310720 ||
            dst_motion_count != 24'd7 || dst_pass_count != 16'd3 ||
            dst_sort_pulse != 1'b1 || dst_safe_enable != 1'b1 ||
            dst_motion_valid != 1'b1 ||
            dst_proc_valid != 1'b1 || dst_proc_cycles != 32'h12345678)
          $fatal(1, "CDC event one payload mismatch");
      end else if (dst_frame_id == 16'd18) begin
        seen_two <= 1'b1;
        if (dst_cx != 11'd100 || dst_pass != 1'b0 || dst_ng != 1'b1 ||
            dst_dimension_valid != 1'b0 || dst_shape_valid != 1'b0 ||
            dst_width != 32'hFFFFFFFF || dst_height != 32'hEEEEEEEE ||
            dst_motion_valid != 1'b0 || dst_motion != 1'b0 || dst_pass_count != 16'd4 ||
            dst_proc_valid != 1'b0 || dst_proc_cycles != 32'd0)
          $fatal(1, "CDC event two payload mismatch");
      end else begin
        $fatal(1, "unexpected CDC frame id %0d", dst_frame_id);
      end
    end
    if (dst_overflow)
      $fatal(1, "CDC overflow reported for separated events");
  end

  task send_event;
    input [15:0] id;
    input [10:0] center;
    input pass_value;
    input proc_valid_value;
    input [31:0] proc_cycles_value;
    begin
      @(negedge src_clk);
      src_frame_id = id;
      src_cx = center;
      src_pass = pass_value;
      src_ng = !pass_value;
      src_motion = pass_value;
      src_dimension_valid = pass_value;
      src_shape_valid = pass_value;
      src_width = pass_value ? 32'd3932160 : 32'hFFFFFFFF;
      src_height = pass_value ? 32'd1310720 : 32'hEEEEEEEE;
      src_motion_valid = pass_value;
      src_pass_count = (id == 16'd17) ? 16'd3 : 16'd4;
      src_sort_pulse = pass_value;
      src_proc_valid = proc_valid_value;
      src_proc_cycles = proc_cycles_value;
      src_toggle = ~src_toggle;
    end
  endtask

  initial begin
    seen_one = 1'b0;
    seen_two = 1'b0;
    repeat (4) @(negedge src_clk);
    rst_n = 1'b1;
    send_event(16'd17, 11'd69, 1'b1, 1'b1, 32'h12345678);
    repeat (10) @(posedge dst_clk);
    send_event(16'd18, 11'd100, 1'b0, 1'b0, 32'h87654321);
    repeat (12) @(posedge dst_clk);
    if (!seen_one || !seen_two)
      $fatal(1, "CDC events missing one=%b two=%b", seen_one, seen_two);
    $display("TB_INDUSTRIAL_V2_RESULT_CDC_PASS");
    $finish;
  end
endmodule
