`timescale 1ns/1ps
module tb_color_detect_96_v2_boundaries;
  localparam integer W=8;
  localparam integer H=4;
  localparam integer G=2;
  reg clk=0, rst_n=0, tvalid=0, tlast=0, tuser=0;
  reg [95:0] tdata=0;
  wire [10:0] xmin,xmax,ymin,ymax,cx,cy;
  wire [19:0] area;
  wire detected, invalid, frame_sync;
  integer r,g,frame_seen;

  always #1 clk=~clk;

  color_detect_96_v2 #(.IMG_WIDTH(W),.IMG_HEIGHT(H),.MIN_AREA(1)) dut (
    .I_clk(clk),.I_rst_n(rst_n),.I_tvalid(tvalid),.I_tlast(tlast),
    .I_tuser(tuser),.I_tdata(tdata),.O_xmin(xmin),.O_xmax(xmax),
    .O_ymin(ymin),.O_ymax(ymax),.O_cx(cx),.O_cy(cy),.O_area(area),
    .O_detected(detected),.O_invalid(invalid),.O_frame_sync(frame_sync)
  );
  always @(posedge clk) if(frame_sync) frame_seen=frame_seen+1;

  task send_constant;
    input [23:0] pixel;
    input integer expected;
    begin
      @(negedge clk); tuser=1; tvalid=0; tlast=0;
      @(negedge clk); tuser=0;
      for (r=0;r<H;r=r+1) for (g=0;g<G;g=g+1) begin
        @(negedge clk); tvalid=1; tlast=(g==G-1); tdata={4{pixel}};
      end
      @(negedge clk); tvalid=0; tlast=0; tdata=0;
      repeat(2*G+16) @(posedge clk);
      if(invalid!==0 || detected!==expected[0] || area!==(expected?20'd32:20'd0))
        $fatal(1,"pixel=%h expected=%0d got invalid=%b detected=%b area=%0d",pixel,expected,invalid,detected,area);
    end
  endtask

  initial begin
    frame_seen=0;
    #10; rst_n=1;
    send_constant(24'h961e1e,1); // Cb=107, Cr=188: inside
    send_constant(24'h565300,0); // Cb=85 endpoint
    send_constant(24'h100000,0); // Cb=125 endpoint, Cr=136
    send_constant(24'h100100,0); // Cr=135 endpoint, Cb=124
    send_constant(24'h900000,0); // Cr=200 endpoint, Cb=103
    if(frame_seen != 5) $fatal(1,"frame publication count=%0d",frame_seen);
    $display("PASS strict Q10 Cb/Cr open-interval boundary vectors");
    #10; $finish;
  end
endmodule