`timescale 1ns/1ps
module tb_morph_open_96;
  localparam integer W=8;
  localparam integer H=4;
  localparam integer G=2;
  reg clk=0, rst_n=0;
  reg tvalid=0, tlast=0, tuser=0;
  reg [3:0] mask=0;
  wire ovalid, olast, ouser, oframe, oinvalid;
  wire [3:0] omask;
  integer out_count;
  integer frame_done;
  integer frame_number;
  reg [3:0] captured [0:H*G-1];
  integer i, r, g;

  always #5 clk=~clk;

  morph_open_96 #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) dut (
    .I_clk(clk), .I_rst_n(rst_n),
    .I_tvalid(tvalid), .I_tlast(tlast), .I_tuser(tuser), .I_mask(mask),
    .O_tvalid(ovalid), .O_tlast(olast), .O_tuser(ouser), .O_mask(omask),
    .O_frame_end(oframe), .O_invalid(oinvalid)
  );

  always @(posedge clk) begin
    if (ovalid) begin
      if (ouser) out_count = 0;
      captured[out_count] = omask;
      out_count = out_count + 1;
      $display("OUT frame=%0d count=%0d last=%b end=%b mask=%b", frame_number, out_count, olast, oframe, omask);
    end
    if (oframe) begin
      frame_done = 1;
      if (oinvalid) $fatal(1, "unexpected morphology invalid");
    end
  end

  task send_frame;
    input integer mode;
    begin
      frame_done = 0;
      out_count = 0;
      frame_number = frame_number + 1;
      @(negedge clk); tuser=1; tvalid=0; tlast=0; mask=0;
      @(negedge clk); tuser=0;
      for (r=0; r<H; r=r+1) begin
        for (g=0; g<G; g=g+1) begin
          if (mode==0) mask=4'b1111;
          else begin
            mask=4'b0000;
            if ((r==1) && (g==0)) mask=4'b0010;
          end
          @(negedge clk);
          tvalid=1; tlast=(g==G-1);
        end
      end
      @(negedge clk); tvalid=0; tlast=0; mask=0;
      wait(frame_done);
      #1;
      if (out_count != H*G)
        $fatal(1, "output count mismatch: %0d", out_count);
      for (i=0; i<H*G; i=i+1) begin
        if (mode==0 && captured[i] !== 4'b1111)
          $fatal(1, "all-one opening mismatch at %0d: %b", i, captured[i]);
        if (mode==1 && captured[i] !== 4'b0000)
          $fatal(1, "noise opening mismatch at %0d: %b", i, captured[i]);
      end
      $display("PASS morphology frame mode=%0d", mode);
    end
  endtask

  initial begin
    frame_number=0; out_count=0; frame_done=0;
    #20; rst_n=1;
    send_frame(0);
    send_frame(1);
    $display("PASS morph_open_96 continuous-row and frame-drain regression");
    #20; $finish;
  end
endmodule