`timescale 1ns/1ps

module tb_tracking_overlay;
  localparam integer DEPTH = 4;
  localparam integer CW = 11;
  localparam [23:0] TRACK_COLOR = 24'h22d3ee;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg de = 1'b0, hs = 1'b0, vs = 1'b0;
  reg [23:0] rgb = 24'h112233;
  reg [10:0] x = 0, y = 0;
  reg track_valid = 1'b1;
  reg [DEPTH-1:0] valid_mask = 4'b0011;
  reg [DEPTH*CW-1:0] x_flat = 0;
  reg [DEPTH*CW-1:0] y_flat = 0;
  wire ode, ohs, ovs;
  wire [23:0] orgb;

  always #5 clk = ~clk;

  tracking_overlay #(
    .IMG_WIDTH(32), .IMG_HEIGHT(16), .HISTORY_DEPTH(DEPTH),
    .COORD_WIDTH(CW), .POINT_RADIUS(1), .TRACK_COLOR(TRACK_COLOR)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_de(de), .I_hsync(hs), .I_vsync(vs),
    .I_rgb(rgb), .I_x(x), .I_y(y), .I_track_valid(track_valid),
    .I_valid_mask(valid_mask), .I_x_flat(x_flat), .I_y_flat(y_flat),
    .O_de(ode), .O_hsync(ohs), .O_vsync(ovs), .O_rgb(orgb)
  );

  task sample_pixel;
    input integer px;
    input integer py;
    input [23:0] expected;
    begin
      @(negedge clk);
      x = px; y = py; de = 1'b1; hs = 1'b0; vs = 1'b0; rgb = 24'h112233;
      @(posedge clk);
      #1;
      if (!ode || orgb !== expected)
        $fatal(1, "overlay pixel mismatch at %0d,%0d de=%b rgb=%h expected=%h",
          px, py, ode, orgb, expected);
    end
  endtask

  initial begin
    x_flat[0*CW +: CW] = 11'd3;
    y_flat[0*CW +: CW] = 11'd4;
    x_flat[1*CW +: CW] = 11'd10;
    y_flat[1*CW +: CW] = 11'd8;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    sample_pixel(3, 4, TRACK_COLOR);
    sample_pixel(4, 5, TRACK_COLOR);
    sample_pixel(20, 10, 24'h112233);

    @(negedge clk);
    x = 10; y = 8; de = 1'b1; hs = 1'b1; vs = 1'b1;
    @(posedge clk);
    #1;
    if (!ode || !ohs || !ovs || orgb !== TRACK_COLOR)
      $fatal(1, "second point or sync delay mismatch de=%b hs=%b vs=%b rgb=%h",
        ode, ohs, ovs, orgb);

    @(negedge clk);
    track_valid = 1'b0; x = 3; y = 4; de = 1'b1; hs = 1'b0; vs = 1'b0;
    @(posedge clk);
    #1;
    if (!ode || orgb !== 24'h112233)
      $fatal(1, "hidden track was drawn rgb=%h", orgb);

    @(negedge clk);
    de = 1'b0; hs = 1'b0; vs = 1'b0;
    @(posedge clk);
    #1;
    if (ode || orgb !== 24'd0)
      $fatal(1, "blanking contract mismatch de=%b rgb=%h", ode, orgb);

    $display("TB_TRACKING_OVERLAY_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in tracking overlay testbench");
  end
endmodule
