`timescale 1ns/1ps

module tb_dimension_calibrator;
  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg result_valid = 1'b0;
  reg calibration_valid = 1'b1;
  reg [10:0] xmin=0, xmax=0, ymin=0, ymax=0;
  reg [19:0] area=0;
  reg [31:0] scale_x=32'd32768, scale_y=32'd16384;
  reg [31:0] nominal_w=32'd3932160, nominal_h=32'd1310720;
  reg [31:0] tolerance_w=32'd131072, tolerance_h=32'd131072;
  reg [8:0] occupancy_min=9'd200;
  reg [15:0] aspect_min=16'd320, aspect_max=16'd448;
  wire valid, invalid, dimension_valid, shape_valid;
  wire [31:0] width_mm, height_mm;
  wire [8:0] occupancy;
  wire [15:0] aspect;

  always #5 clk = ~clk;

  dimension_calibrator dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_result_valid(result_valid),
    .I_calibration_valid(calibration_valid), .I_xmin(xmin), .I_xmax(xmax),
    .I_ymin(ymin), .I_ymax(ymax), .I_area(area),
    .I_scale_x_q16_16(scale_x), .I_scale_y_q16_16(scale_y),
    .I_nominal_width_q16_16(nominal_w), .I_nominal_height_q16_16(nominal_h),
    .I_tolerance_width_q16_16(tolerance_w), .I_tolerance_height_q16_16(tolerance_h),
    .I_occupancy_min_q8(occupancy_min), .I_aspect_min_q8(aspect_min),
    .I_aspect_max_q8(aspect_max), .O_valid(valid), .O_invalid(invalid),
    .O_dimension_valid(dimension_valid), .O_shape_valid(shape_valid),
    .O_width_mm_q16_16(width_mm), .O_height_mm_q16_16(height_mm),
    .O_occupancy_q8(occupancy), .O_aspect_q8(aspect)
  );

  task clear_inputs;
    begin result_valid=1'b0; end
  endtask

  task send_bbox;
    input integer ax, bx, ay, by, ap;
    begin
      @(negedge clk); clear_inputs;
      xmin=ax; xmax=bx; ymin=ay; ymax=by; area=ap; result_valid=1'b1;
      @(posedge clk); #1; clear_inputs;
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n=1'b1;

    send_bbox(10,129,20,99,9600);
    if (!valid || invalid || !dimension_valid || !shape_valid ||
        width_mm!==32'd3932160 || height_mm!==32'd1310720 ||
        occupancy!==9'd256 || aspect!==16'd384)
      $fatal(1, "normal calibration failed w=%0d h=%0d occ=%0d asp=%0d",
        width_mm, height_mm, occupancy, aspect);

    send_bbox(10,129,20,99,7000);
    if (!valid || !dimension_valid || shape_valid || occupancy>=9'd200)
      $fatal(1, "occupancy rejection failed occ=%0d", occupancy);

    send_bbox(0,139,0,79,11200);
    if (!valid || dimension_valid || shape_valid || aspect!==16'd448)
      $fatal(1, "dimension/aspect rejection failed");

    calibration_valid=1'b0;
    send_bbox(10,129,20,99,9600);
    if (valid || !invalid)
      $fatal(1, "uncalibrated input was accepted");
    calibration_valid=1'b1;

    send_bbox(20,10,0,79,1);
    if (valid || !invalid)
      $fatal(1, "reverse bbox was accepted");

    rst_n=1'b0;
    #1;
    if (valid || invalid || width_mm!==0 || height_mm!==0)
      $fatal(1, "reset output contract failed");
    $display("TB_DIMENSION_CALIBRATOR_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in dimension calibrator testbench");
  end
endmodule
