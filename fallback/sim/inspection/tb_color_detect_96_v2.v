`timescale 1ns/1ps
module tb_color_detect_96_v2;
  localparam integer W=1280;
  localparam integer H=720;
  localparam integer G=320;
  reg clk=0, rst_n=0;
  reg tvalid=0, tlast=0, tuser=0;
  reg [95:0] tdata=0;
  wire [10:0] xmin,xmax,ymin,ymax,cx,cy;
  wire [19:0] area;
  wire detected, invalid, frame_sync;
  integer r,g,i,frame_count;

  always #1 clk=~clk;

  color_detect_96_v2 #(
    .IMG_WIDTH(W), .IMG_HEIGHT(H), .MIN_AREA(100),
    .CB_MIN(85), .CB_MAX(125), .CR_MIN(135), .CR_MAX(200)
  ) dut (
    .I_clk(clk), .I_rst_n(rst_n),
    .I_tvalid(tvalid), .I_tlast(tlast), .I_tuser(tuser), .I_tdata(tdata),
    .O_xmin(xmin), .O_xmax(xmax), .O_ymin(ymin), .O_ymax(ymax),
    .O_cx(cx), .O_cy(cy), .O_area(area), .O_detected(detected),
    .O_invalid(invalid), .O_frame_sync(frame_sync)
  );

  always @(posedge clk)
    if (frame_sync) frame_count = frame_count + 1;

  task send_full_red_frame;
    begin
      @(negedge clk); tuser=1; tvalid=0; tlast=0; tdata=0;
      @(negedge clk); tuser=0;
      for (r=0; r<H; r=r+1) begin
        for (g=0; g<G; g=g+1) begin
          @(negedge clk);
          tvalid=1;
          tlast=(g==G-1);
          tdata={4{24'h961e1e}};
        end
      end
      @(negedge clk); tvalid=0; tlast=0; tdata=0;
    end
  endtask

  initial begin
    frame_count=0;
    #10; rst_n=1;
    send_full_red_frame();
    repeat(2*G+32) @(posedge clk);
    if (frame_count != 1) $fatal(1, "frame publication missing count=%0d",frame_count);
    if (invalid !== 1'b0 || detected !== 1'b1) $fatal(1, "full frame status invalid=%b detected=%b",invalid,detected);
    if (area !== 20'd921600) $fatal(1, "full frame area=%0d expected=921600",area);
    if (xmin !== 0 || ymin !== 0 || xmax !== 1279 || ymax !== 719)
      $fatal(1, "full frame bbox=%0d,%0d,%0d,%0d",xmin,ymin,xmax,ymax);
    $display("PASS color_detect_96_v2 full-frame area=921600 bbox=0,0,1279,719");
    #10; $finish;
  end
endmodule