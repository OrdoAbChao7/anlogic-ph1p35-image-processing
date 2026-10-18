`timescale 1ns/1ps
module tb_defect_classifier;
  reg clk=0,rst_n=0,frame_sync=0,detected=0,invalid=0;
  reg [10:0] xmin=0,xmax=0,ymin=0,ymax=0;
  reg [19:0] area=0;
  wire [10:0] width,height;
  wire pass,ng,no_obj,inv,led_pass,led_ng,led_det;
  wire [1:0] status;
  always #5 clk=~clk;
  defect_classifier dut(
    .I_clk(clk),.I_rst_n(rst_n),.I_frame_sync(frame_sync),
    .I_detected(detected),.I_invalid(invalid),
    .I_xmin(xmin),.I_xmax(xmax),.I_ymin(ymin),.I_ymax(ymax),.I_area(area),
    .O_width(width),.O_height(height),.O_pass(pass),.O_ng(ng),
    .O_no_obj(no_obj),.O_invalid(inv),.O_status(status),
    .O_led_pass(led_pass),.O_led_ng(led_ng),.O_led_det(led_det)
  );
  task publish;
    begin @(negedge clk); frame_sync=1; @(negedge clk); frame_sync=0; end
  endtask
  task check;
    input [1:0] exp;
    begin
      #1;
      if(status!==exp || (pass+ng+no_obj+inv)!==1 ||
         (led_det && no_obj) || (led_det && inv) ||
         (exp==2'b00 && {led_pass,led_ng,led_det}!==3'b000) ||
         (exp==2'b01 && {led_pass,led_ng,led_det}!==3'b101) ||
         (exp==2'b10 && {led_pass,led_ng,led_det}!==3'b011) ||
         (exp==2'b11 && {led_pass,led_ng,led_det}!==3'b110))
        $fatal(1,"status=%b pass=%b ng=%b no=%b inv=%b leds=%b%b%b",
               status,pass,ng,no_obj,inv,led_pass,led_ng,led_det);
    end
  endtask
  initial begin
    #12 rst_n=1;
    #1; check(2'b11); // reset state remains INVALID until a frame publishes
    detected=0; invalid=0; area=0; publish(); check(2'b00);
    detected=1; invalid=0; area=20'd9600; xmin=580; xmax=699; ymin=320; ymax=399;
    publish(); check(2'b01);
    xmin=580; xmax=744; ymin=320; ymax=399;
    publish(); check(2'b10);
    detected=1; invalid=1; publish(); check(2'b11);
    $display("PASS defect_classifier PASS/NG/NO_OBJECT/INVALID and LED exclusivity");
    #10 $finish;
  end
endmodule
