`timescale 1ns/1ps

module tb_reset_release_sync;
  reg src_clk = 1'b0;
  reg dst_clk = 1'b0;
  reg async_rst_n = 1'b1;
  wire src_rst_n;
  wire dst_rst_n;

  always #5 src_clk = ~src_clk;
  always #7 dst_clk = ~dst_clk;

  reset_release_sync src_sync (
    .I_clk(src_clk), .I_async_rst_n(async_rst_n), .O_rst_n(src_rst_n)
  );
  reset_release_sync dst_sync (
    .I_clk(dst_clk), .I_async_rst_n(async_rst_n), .O_rst_n(dst_rst_n)
  );

  initial begin
    #1;
    async_rst_n = 1'b0;
    #1;
    if (src_rst_n !== 1'b0 || dst_rst_n !== 1'b0)
      $fatal(1, "reset must assert asynchronously in both domains");

    async_rst_n = 1'b1;
    fork
      begin
        @(posedge src_clk); #1;
        if (src_rst_n !== 1'b0)
          $fatal(1, "source reset released before two source-clock edges");
        @(posedge src_clk); #1;
        if (src_rst_n !== 1'b1)
          $fatal(1, "source reset did not release on its second clock edge");
      end
      begin
        @(posedge dst_clk); #1;
        if (dst_rst_n !== 1'b0)
          $fatal(1, "destination reset released before two destination-clock edges");
        @(posedge dst_clk); #1;
        if (dst_rst_n !== 1'b1)
          $fatal(1, "destination reset did not release on its second clock edge");
      end
    join

    #1 async_rst_n = 1'b0;
    #1;
    if (src_rst_n !== 1'b0 || dst_rst_n !== 1'b0)
      $fatal(1, "reset assertion must not wait for either local clock");
    $display("TB_RESET_RELEASE_SYNC_PASS");
    $finish;
  end
endmodule
