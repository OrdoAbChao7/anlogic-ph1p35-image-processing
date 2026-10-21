`timescale 1ns/1ps

module tb_trajectory_history;
  localparam integer DEPTH = 4;
  localparam integer CW = 11;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg push = 1'b0;
  reg new_track = 1'b0;
  reg [CW-1:0] cx = 0;
  reg [CW-1:0] cy = 0;
  wire [DEPTH*CW-1:0] x_flat;
  wire [DEPTH*CW-1:0] y_flat;
  wire [DEPTH-1:0] valid_mask;
  wire [2:0] count;

  always #5 clk = ~clk;

  trajectory_history #(.HISTORY_DEPTH(DEPTH), .COORD_WIDTH(CW)) dut (
    .I_clk(clk), .I_rst_n(rst_n), .I_push(push), .I_new_track(new_track),
    .I_cx(cx), .I_cy(cy), .O_x_flat(x_flat), .O_y_flat(y_flat),
    .O_valid_mask(valid_mask), .O_count(count)
  );

  task write_point;
    input integer in_cx;
    input integer in_cy;
    input first_point;
    begin
      @(negedge clk);
      cx = in_cx;
      cy = in_cy;
      new_track = first_point;
      push = 1'b1;
      @(posedge clk);
      #1;
      push = 1'b0;
      new_track = 1'b0;
    end
  endtask

  task expect_point;
    input integer index;
    input integer expected_x;
    input integer expected_y;
    begin
      if (!valid_mask[index] || x_flat[index*CW +: CW] !== expected_x ||
          y_flat[index*CW +: CW] !== expected_y)
        $fatal(1, "history point mismatch index=%0d valid=%b x=%0d/%0d y=%0d/%0d",
          index, valid_mask[index], x_flat[index*CW +: CW], expected_x,
          y_flat[index*CW +: CW], expected_y);
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    rst_n = 1'b1;

    write_point(10, 20, 1'b1);
    if (valid_mask !== 4'b0001 || count !== 1)
      $fatal(1, "new track clear mismatch mask=%b count=%0d", valid_mask, count);
    expect_point(0, 10, 20);

    write_point(11, 21, 1'b0);
    write_point(12, 22, 1'b0);
    write_point(13, 23, 1'b0);
    if (valid_mask !== 4'b1111 || count !== 4)
      $fatal(1, "history fill mismatch mask=%b count=%0d", valid_mask, count);
    expect_point(0, 13, 23);
    expect_point(1, 12, 22);
    expect_point(2, 11, 21);
    expect_point(3, 10, 20);

    write_point(14, 24, 1'b0);
    if (count !== 4)
      $fatal(1, "history count did not saturate count=%0d", count);
    expect_point(0, 14, 24);
    expect_point(1, 13, 23);
    expect_point(2, 12, 22);
    expect_point(3, 11, 21);

    write_point(100, 200, 1'b1);
    if (valid_mask !== 4'b0001 || count !== 1)
      $fatal(1, "new target did not clear old history mask=%b count=%0d", valid_mask, count);
    expect_point(0, 100, 200);

    @(negedge clk);
    cx = 300; cy = 300; push = 1'b0; new_track = 1'b0;
    @(posedge clk);
    #1;
    if (valid_mask !== 4'b0001 || count !== 1)
      $fatal(1, "ignored push changed history mask=%b count=%0d", valid_mask, count);
    expect_point(0, 100, 200);

    rst_n = 1'b0;
    repeat (2) @(posedge clk);
    if (valid_mask !== 4'b0000 || count !== 0)
      $fatal(1, "reset did not clear history");

    $display("TB_TRAJECTORY_HISTORY_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in trajectory history testbench");
  end
endmodule
