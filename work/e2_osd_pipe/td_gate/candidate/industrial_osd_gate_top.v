`timescale 1ns/1ps
// E2 Gate A/B harness — self-contained OSD top so the pad count stays small.
// The only difference between the two arms is the DUT module name.
module industrial_osd_gate_top (
  input  wire        I_clk,
  input  wire        I_rst_n,
  output wire        O_vsync,
  output wire        O_hsync,
  output wire        O_de,
  output wire [23:0] O_rgb
);
  localparam integer H_ACTIVE = 1280;
  localparam integer H_TOTAL  = 1650;
  localparam integer V_ACTIVE = 720;
  localparam integer V_TOTAL  = 750;

  reg [11:0] hc, vc;
  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      hc <= 12'd0; vc <= 12'd0;
    end else if (hc == H_TOTAL-1) begin
      hc <= 12'd0;
      vc <= (vc == V_TOTAL-1) ? 12'd0 : vc + 12'd1;
    end else begin
      hc <= hc + 12'd1;
    end
  end

  wire        vsync_w = (vc >= V_ACTIVE);
  wire        hsync_w = (hc >= H_ACTIVE);
  wire        de_w    = (hc < H_ACTIVE) && (vc < V_ACTIVE);
  wire [23:0] rgb_w   = {hc[7:0], vc[7:0], (hc[7:0] ^ vc[7:0])};

  reg [3:0] frame_no;
  reg       vsync_d;
  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      frame_no <= 4'd0; vsync_d <= 1'b0;
    end else begin
      vsync_d <= vsync_w;
      if (vsync_w && !vsync_d) frame_no <= frame_no + 4'd1;
    end
  end

  reg [1:0]  mode_r;
  reg        det_r, pass_r, ng_r, inv_r;
  reg [10:0] w_r, h_r;
  reg        pv_r;
  reg [31:0] pc_r;
  reg        mv_r, mo_r;
  reg [23:0] mc_r;
  reg [15:0] pcount_r, ncount_r;
  reg        sp_r, se_r, dv_r, sv_r, sc_r;
  reg [31:0] wmm_r, hmm_r;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      mode_r <= 2'd0; det_r <= 1'b0; pass_r <= 1'b0; ng_r <= 1'b0; inv_r <= 1'b0;
      w_r <= 11'd120; h_r <= 11'd80; pv_r <= 1'b0; pc_r <= 32'd0;
      mv_r <= 1'b0; mo_r <= 1'b0; mc_r <= 24'd0;
      pcount_r <= 16'd0; ncount_r <= 16'd0;
      sp_r <= 1'b0; se_r <= 1'b0; dv_r <= 1'b0; sv_r <= 1'b0; sc_r <= 1'b0;
      wmm_r <= 32'd0; hmm_r <= 32'd0;
    end else begin
      mode_r  <= frame_no[1:0];
      det_r   <= frame_no[0];
      pass_r  <= (frame_no[1:0] == 2'd0);
      ng_r    <= (frame_no[1:0] == 2'd1);
      inv_r   <= (frame_no[2:0] == 3'd3);
      w_r     <= 11'd120 + {7'd0, frame_no} * 11'd7;
      h_r     <= 11'd80  + {7'd0, frame_no} * 11'd3;
      pv_r    <= frame_no[2];
      pc_r    <= 32'h1000 + {28'd0, frame_no} * 32'd13;
      mv_r    <= frame_no[1];
      mo_r    <= frame_no[3];
      mc_r    <= {20'd0, frame_no} * 24'd5;
      pcount_r <= 16'd100 + {12'd0, frame_no};
      ncount_r <= 16'd7   + {12'd0, frame_no};
      sp_r    <= frame_no[2];
      se_r    <= ~frame_no[3];
      dv_r    <= frame_no[0];
      sv_r    <= ~frame_no[0];
      sc_r    <= frame_no[1];
      wmm_r   <= {16'd60, 16'd0};
      hmm_r   <= {16'd20, 16'd0};
    end
  end

  industrial_osd_overlay #(
    .IMG_WIDTH(H_ACTIVE), .IMG_HEIGHT(V_ACTIVE), .LOGO_W(160), .LOGO_H(160)
  ) dut (
    .I_clk(I_clk), .I_rst_n(I_rst_n),
    .I_vsync(vsync_w), .I_hsync(hsync_w), .I_de(de_w), .I_rgb(rgb_w),
    .I_mode(mode_r), .I_detected(det_r), .I_pass(pass_r), .I_ng(ng_r),
    .I_invalid(inv_r), .I_width(w_r), .I_height(h_r),
    .I_proc_valid(pv_r), .I_proc_cycles(pc_r),
    .I_motion_valid(mv_r), .I_motion(mo_r), .I_motion_count(mc_r),
    .I_pass_count(pcount_r), .I_ng_count(ncount_r),
    .I_sort_pulse(sp_r), .I_safe_enable(se_r),
    .I_dimension_valid(dv_r), .I_shape_valid(sv_r),
    .I_scale_provisional(sc_r),
    .I_width_mm_q16_16(wmm_r), .I_height_mm_q16_16(hmm_r),
    .O_vsync(O_vsync), .O_hsync(O_hsync), .O_de(O_de), .O_rgb(O_rgb)
  );
endmodule
