`timescale 1ns / 1ps

module tb_color_detect_96;

  reg        clk;
  reg        rst_n;
  reg        tvalid;
  reg        tlast;
  reg        tuser;
  reg [95:0] tdata;

  wire [10:0] xmin, ymin, xmax, ymax;
  wire [18:0] area;
  wire        valid_frame;

  color_detect_96 #(
    .IMG_WIDTH(1280),
    .IMG_HEIGHT(720)
  ) u_detect (
    .I_clk(clk),
    .I_rst_n(rst_n),
    .I_tvalid(tvalid),
    .I_tlast(tlast),
    .I_tuser(tuser),
    .I_tdata(tdata),
    .xmin(xmin),
    .ymin(ymin),
    .xmax(xmax),
    .ymax(ymax),
    .area(area),
    .valid_frame(valid_frame)
  );

  always #5 clk = ~clk;

  initial begin
    clk = 0;
    rst_n = 0;
    tvalid = 0;
    tlast = 0;
    tuser = 0;
    tdata = 96'd0;

    #30 rst_n = 1;

    // Start of Frame
    @(posedge clk);
    tuser <= 1;
    tvalid <= 0;
    @(posedge clk);
    tuser <= 0;

    // Feed a calibrated target color (e.g. industrial reddish part R=100, G=0, B=0: cb=111, cr=178)
    tdata <= {24'h640000, 24'h640000, 24'h640000, 24'h640000};
    tvalid <= 1;

    @(posedge clk);
    tvalid <= 0;

    #2;
    $display("DEBUG: R0=%d, G0=%d, B0=%d", u_detect.R0, u_detect.G0, u_detect.B0);
    $display("DEBUG: cb0=%d, cb0[17:10]=%d, cr0=%d, cr0[17:10]=%d, t0=%b", u_detect.cb0, u_detect.cb0[17:10], u_detect.cr0, u_detect.cr0[17:10], u_detect.t0);
    $display("Industrial Color Detect Test: Area = %d, xmin = %d, xmax = %d, ymin = %d, ymax = %d", area, xmin, xmax, ymin, ymax);
    if (area == 19'd4 && xmin == 11'd0 && xmax == 11'd3) begin
      $display("INDUSTRIAL INSPECTION SIMULATION PASS: Target Recognized and BBox Extracted!");
    end else begin
      $display("INDUSTRIAL INSPECTION SIMULATION FAILED: Unexpected BBox or Area!");
      $fatal(1);
    end

    #50 $finish;
  end

endmodule
