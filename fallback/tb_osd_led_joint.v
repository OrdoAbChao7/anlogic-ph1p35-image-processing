`timescale 1ns/1ps

module tb_osd_led_joint;
  localparam integer W = 320;
  localparam integer H = 120;

  reg clk = 0;
  always #5 clk = ~clk;

  reg rst_n = 0;
  reg frame_sync = 0;
  reg detected = 0;
  reg invalid = 0;
  reg [10:0] xmin = 0, xmax = 0, ymin = 0, ymax = 0;
  reg [19:0] area = 0;
  wire [10:0] width, height;
  wire pass, ng, no_obj, out_invalid;
  wire led_pass, led_ng, led_det;
  wire result_toggle;

  defect_classifier classifier (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_sync(frame_sync),
    .I_detected(detected), .I_invalid(invalid),
    .I_xmin(xmin), .I_xmax(xmax), .I_ymin(ymin), .I_ymax(ymax),
    .I_area(area), .O_width(width), .O_height(height),
    .O_pass(pass), .O_ng(ng), .O_no_obj(no_obj), .O_invalid(out_invalid),
    .O_status(), .O_led_pass(led_pass), .O_led_ng(led_ng),
    .O_led_det(led_det), .O_result_toggle(result_toggle)
  );

  reg vs = 0, hs = 0, de = 0;
  reg [23:0] rgb = 0;
  wire ovs, ohs, ode;
  wire [23:0] osd_rgb;
  industrial_osd_overlay #(.IMG_WIDTH(W), .IMG_HEIGHT(H), .LOGO_W(0), .LOGO_H(0)) osd (
    .I_clk(clk), .I_rst_n(rst_n), .I_vsync(vs), .I_hsync(hs), .I_de(de),
    .I_rgb(rgb), .I_mode(2'd2), .I_detected(detected), .I_pass(pass),
    .I_ng(ng), .I_invalid(out_invalid), .I_width(width), .I_height(height),
    .O_vsync(ovs), .O_hsync(ohs), .O_de(ode), .O_rgb(osd_rgb)
  );

  task tick;
    begin @(posedge clk); #1; end
  endtask

  task publish_no_object;
    begin
      frame_sync = 1;
      tick;
      frame_sync = 0;
      if (!no_obj || pass || ng || out_invalid || led_pass || led_ng || led_det)
        $fatal(1, "NO_OBJECT classifier/LED contract failed");
    end
  endtask

  task publish_pass;
    begin
      detected = 1;
      xmin = 0; xmax = 119; ymin = 0; ymax = 79; area = 20'd9600;
      frame_sync = 1;
      tick;
      frame_sync = 0;
      if (!pass || ng || no_obj || out_invalid || !led_pass || led_ng || !led_det)
        $fatal(1, "PASS classifier/LED contract failed");
    end
  endtask

  integer x, y;
  initial begin
    repeat (2) tick;
    rst_n = 1;
    publish_no_object();

    // One complete raster.  The test samples the final two characters of
    // NO_OBJECT on the status line, which previously were silently omitted.
    vs = 1; de = 0; tick; vs = 0; de = 1;
    for (y = 0; y < H; y = y + 1) begin
      for (x = 0; x < W; x = x + 1) begin
        rgb = 24'h000000;
        tick;
        if (y == 104 && (x == 294 || x == 302)) begin
          if (osd_rgb !== 24'hf59e0b)
            $fatal(1, "NO_OBJECT status glyph missing at x=%0d (got %h)", x, osd_rgb);
        end
      end
    end
    de = 0;
    publish_pass();

    $display("PASS OSD status tail and classifier LED joint contract");
    $finish;
  end
endmodule
