`timescale 1ns / 1ps

// Small-geometry contract test for the real VTC -> HDMI mixer timing path.
// The production top uses 1280x720 / 1650x750; the reduced geometry keeps this
// test fast while exercising the same counters, USER/LAST generation and mixer
// pipeline.  A green test proves signal relationships, not board behavior.
module tb_video_timing_contract;

  localparam integer H_ACTIVE = 8;
  localparam integer H_FRAME  = 12;
  localparam integer H_SYNC_START = 9;
  localparam integer H_SYNC_END   = 11;
  localparam integer V_ACTIVE = 4;
  localparam integer V_FRAME  = 7;
  localparam integer V_SYNC_START = 5;
  localparam integer V_SYNC_END   = 6;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  wire vtc_vs;
  wire vtc_hs;
  wire vtc_de;
  wire vtc_user;
  wire vtc_last;

  wire mix_vs;
  wire mix_hs;
  wire mix_de;
  wire mix_rd_en;
  wire [23:0] mix_data;

  reg [23:0] rd_data = 24'h123456;

  integer warmup_cycles = 0;
  integer frame_count = 0;
  integer frame_active_pixels = 0;
  integer frame_lines = 0;
  integer previous_frame_active_pixels;
  integer previous_frame_lines;
  reg have_frame = 1'b0;

  reg de_d1 = 1'b0;
  reg de_d2 = 1'b0;
  reg de_d3 = 1'b0;
  reg hs_d1 = 1'b0;
  reg hs_d2 = 1'b0;
  reg hs_d3 = 1'b0;
  reg vs_d1 = 1'b0;
  reg vs_d2 = 1'b0;
  reg vs_d3 = 1'b0;

  always #5 clk = ~clk;

  uivtc #(
    .H_ActiveSize(H_ACTIVE),
    .H_FrameSize(H_FRAME),
    .H_SyncStart(H_SYNC_START),
    .H_SyncEnd(H_SYNC_END),
    .V_ActiveSize(V_ACTIVE),
    .V_FrameSize(V_FRAME),
    .V_SyncStart(V_SYNC_START),
    .V_SyncEnd(V_SYNC_END)
  ) dut_vtc (
    .I_vtc_rstn(rst_n),
    .I_vtc_clk(clk),
    .O_vtc_vs(vtc_vs),
    .O_vtc_hs(vtc_hs),
    .O_vtc_de_valid(vtc_de),
    .O_vtc_user(vtc_user),
    .O_vtc_last(vtc_last)
  );

  hdmi_mixer #(
    .H_OFFSET(0),
    .V_OFFSET(0),
    .IMG_WIDTH(H_ACTIVE),
    .IMG_HEIGHT(V_ACTIVE),
    .DEBUG_MODE(0)
  ) dut_mixer (
    .I_clk(clk),
    .I_rst_n(rst_n),
    .I_video_vsync(vtc_vs),
    .I_video_hsync(vtc_hs),
    .I_video_de(vtc_de),
    .I_video_user(vtc_user),
    .I_video_last(vtc_last),
    .I_debug_status(4'd0),
    .O_video_rd_en(mix_rd_en),
    .I_video_rd_data(rd_data),
    .O_hdmi_vsync(mix_vs),
    .O_hdmi_hsync(mix_hs),
    .O_hdmi_de(mix_de),
    .O_hdmi_data(mix_data)
  );

  always @(posedge clk) begin
    #1;
    if (rst_n) begin
      warmup_cycles = warmup_cycles + 1;

      if (warmup_cycles > 8) begin
        // The VTC outputs are registered before the mixer samples them. The
        // externally observed mixer sidebands therefore appear three clocks
        // after the observed VTC sidebands (two mixer registers plus that
        // synchronous producer boundary).
        if (mix_de !== de_d3)
          $fatal(1, "DE delay mismatch: got=%b expected=%b", mix_de, de_d3);
        if (mix_hs !== hs_d3)
          $fatal(1, "HSYNC delay mismatch: got=%b expected=%b", mix_hs, hs_d3);
        if (mix_vs !== vs_d3)
          $fatal(1, "VSYNC delay mismatch: got=%b expected=%b", mix_vs, vs_d3);

        // The mixer read window is the active image window, not blanking.
        if (mix_rd_en !== vtc_de)
          $fatal(1, "DDR read-window mismatch: rd_en=%b vtc_de=%b user=%b last=%b x=%0d y=%0d",
                 mix_rd_en, vtc_de, vtc_user, vtc_last, dut_mixer.S_x, dut_mixer.S_y);
        if (mix_de && mix_data !== rd_data)
          $fatal(1, "RGB data delay mismatch: got=%h expected=%h", mix_data, rd_data);

        if (vtc_user) begin
          if (!vtc_de)
            $fatal(1, "frame USER must accompany an active pixel");
          if (have_frame) begin
            if (frame_active_pixels != H_ACTIVE * V_ACTIVE)
              $fatal(1, "frame active-pixel count=%0d expected=%0d",
                     frame_active_pixels, H_ACTIVE * V_ACTIVE);
            if (frame_lines != V_ACTIVE)
              $fatal(1, "frame line count=%0d expected=%0d", frame_lines, V_ACTIVE);
          end
          have_frame = 1'b1;
          frame_count = frame_count + 1;
          frame_active_pixels = 0;
          frame_lines = 0;
        end

        if (vtc_last) begin
          if (!vtc_de)
            $fatal(1, "line LAST must accompany an active pixel");
          frame_lines = frame_lines + 1;
        end
        if (vtc_de)
          frame_active_pixels = frame_active_pixels + 1;
      end
    end

    de_d3 = de_d2;
    hs_d3 = hs_d2;
    vs_d3 = vs_d2;
    de_d2 = de_d1;
    de_d1 = vtc_de;
    hs_d2 = hs_d1;
    hs_d1 = vtc_hs;
    vs_d2 = vs_d1;
    vs_d1 = vtc_vs;
  end

  initial begin
    repeat (8) @(posedge clk);
    rst_n = 1'b1;
    wait (frame_count == 4);
    wait (frame_active_pixels == H_ACTIVE * V_ACTIVE);
    if (frame_active_pixels != H_ACTIVE * V_ACTIVE)
      $fatal(1, "final frame active-pixel count=%0d expected=%0d",
             frame_active_pixels, H_ACTIVE * V_ACTIVE);
    if (frame_lines != V_ACTIVE)
      $fatal(1, "final frame line count=%0d expected=%0d", frame_lines, V_ACTIVE);
    $display("PASS VTC/HDMI mixer timing contract: 4 frames, %0dx%0d active, three-clock observed sideband delay",
             H_ACTIVE, V_ACTIVE);
    $finish;
  end

  initial begin
    #20000;
    $fatal(1, "timeout waiting for four complete frames");
  end

endmodule
