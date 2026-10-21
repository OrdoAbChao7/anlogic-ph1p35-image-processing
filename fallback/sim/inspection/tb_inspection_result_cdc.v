`timescale 1ns/1ps

// The result bus is bundled-data CDC: the source holds all fields stable and
// flips I_src_toggle only after publishing a complete frame result.  The
// destination must not expose the new bus until a destination video frame
// boundary arrives.
module tb_inspection_result_cdc;
  reg src_clk = 1'b0;
  reg dst_clk = 1'b0;
  reg rst_n = 1'b0;
  reg frame_start = 1'b0;
  reg src_toggle = 1'b0;
  reg [10:0] src_xmin = 0, src_xmax = 0, src_ymin = 0, src_ymax = 0;
  reg [10:0] src_width = 0, src_height = 0;
  reg src_detected = 0, src_pass = 0, src_ng = 0, src_no_obj = 0, src_invalid = 1;

  wire [10:0] out_xmin, out_xmax, out_ymin, out_ymax, out_width, out_height;
  wire out_detected, out_pass, out_ng, out_no_obj, out_invalid;

  always #5 src_clk = ~src_clk;
  always #7 dst_clk = ~dst_clk;

  inspection_result_cdc dut (
    .I_src_clk(src_clk),
    .I_dst_clk(dst_clk),
    .I_rst_n(rst_n),
    .I_frame_start(frame_start),
    .I_src_toggle(src_toggle),
    .I_src_xmin(src_xmin), .I_src_xmax(src_xmax),
    .I_src_ymin(src_ymin), .I_src_ymax(src_ymax),
    .I_src_width(src_width), .I_src_height(src_height),
    .I_src_detected(src_detected), .I_src_pass(src_pass),
    .I_src_ng(src_ng), .I_src_no_obj(src_no_obj), .I_src_invalid(src_invalid),
    .O_xmin(out_xmin), .O_xmax(out_xmax),
    .O_ymin(out_ymin), .O_ymax(out_ymax),
    .O_width(out_width), .O_height(out_height),
    .O_detected(out_detected), .O_pass(out_pass),
    .O_ng(out_ng), .O_no_obj(out_no_obj), .O_invalid(out_invalid)
  );

  task expect_invalid_reset;
    begin
      if (!out_invalid || out_detected || out_pass || out_ng || out_no_obj)
        $fatal(1, "reset result is not INVALID-only");
    end
  endtask

  task publish_pass;
    begin
      @(negedge src_clk);
      src_xmin = 11'd100; src_xmax = 11'd219;
      src_ymin = 11'd200; src_ymax = 11'd279;
      src_width = 11'd120; src_height = 11'd80;
      src_detected = 1'b1; src_pass = 1'b1;
      src_ng = 1'b0; src_no_obj = 1'b0; src_invalid = 1'b0;
      src_toggle = ~src_toggle;
    end
  endtask

  task publish_ng;
    begin
      @(negedge src_clk);
      src_xmin = 11'd300; src_xmax = 11'd459;
      src_ymin = 11'd220; src_ymax = 11'd299;
      src_width = 11'd160; src_height = 11'd80;
      src_detected = 1'b1; src_pass = 1'b0;
      src_ng = 1'b1; src_no_obj = 1'b0; src_invalid = 1'b0;
      src_toggle = ~src_toggle;
    end
  endtask

  task commit_frame;
    begin
      @(negedge dst_clk);
      frame_start = 1'b1;
      @(negedge dst_clk);
      frame_start = 1'b0;
    end
  endtask

  initial begin
    repeat (3) @(negedge dst_clk);
    rst_n = 1'b1;
    repeat (2) @(negedge dst_clk);
    expect_invalid_reset();

    publish_pass();
    repeat (5) @(negedge dst_clk);
    if (out_invalid !== 1'b1 || out_pass !== 1'b0 || out_width !== 0)
      $fatal(1, "result changed before destination frame boundary");
    commit_frame();
    if (out_invalid !== 1'b0 || out_pass !== 1'b1 || out_width !== 120 ||
        out_height !== 80 || out_xmin !== 100 || out_xmax !== 219)
      $fatal(1, "PASS result was not committed atomically at frame boundary");

    publish_ng();
    repeat (5) @(negedge dst_clk);
    if (out_pass !== 1'b1 || out_ng !== 1'b0 || out_width !== 120)
      $fatal(1, "new result leaked into the current destination frame");
    commit_frame();
    if (out_invalid !== 1'b0 || out_pass !== 1'b0 || out_ng !== 1'b1 ||
        out_width !== 160 || out_height !== 80 || out_xmin !== 300 || out_xmax !== 459)
      $fatal(1, "NG result was not committed atomically at frame boundary");

    $display("TB_INSPECTION_RESULT_CDC_PASS");
    $finish;
  end

  initial begin
    #5000;
    $fatal(1, "timeout");
  end
endmodule
