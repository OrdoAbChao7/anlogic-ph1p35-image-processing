

module design_top_wrapper (
    input wire        I_sys_clk,

    output wire       O_cam_scl,
    inout  wire       IO_cam_sda,
    output wire       O_cam_24m,
    output wire       O_cam_rst,

    output wire       O_led1,
    output wire       O_led2,
    output wire       O_led3,

    input wire [1:0]  I_button,

    output wire       O_tmds_ch0_p,
    output wire       O_tmds_ch1_p,
    output wire       O_tmds_ch2_p,
    output wire       O_tmds_clk_p,

    inout wire        IO_rx_clk_pad_n,
    inout wire        IO_rx_clk_pad_p,
    inout wire[3:0]   IO_rx_data_pad_n,
    inout wire[3:0]   IO_rx_data_pad_p,

    output wire[12:0] ddr_addr,
    output wire[ 1:0] ddr_ba,
    output wire[ 0:0] ddr_cke,
    output wire[ 0:0] ddr_odt,
    output wire[ 0:0] ddr_cs_n,
    output wire       ddr_ras_n,
    output wire       ddr_cas_n,
    output wire       ddr_we_n,
    output wire[ 0:0] ddr_ck_p,
    output wire[ 0:0] ddr_ck_n,
    inout wire[1:0]   ddr_dm,
    inout wire[15:0]  ddr_dq,
    inout wire[1:0]   ddr_dqs_p,
    inout wire[1:0]   ddr_dqs_n
);


    // HX1P35A HDL manual: KEY1=D5 and KEY2=A9, both active-low.
    // These inputs are pulled up by the board-level pin constraints.
    wire I_mode_edge_n = I_button[0];
    wire I_mode_cartoon_n = I_button[1];
    (* keep = "true" *) wire O_led_pass;
    (* keep = "true" *) wire O_led_ng;
    (* keep = "true" *) wire O_led_det;


    wire        	S_100m_clk;
    wire        	S_24m_clk;
    wire        	S_aux_50m_clk;
	wire        	S_10m_clk;

	wire        	S_pll_lock;
    wire        	S_rst_n;
	reg  [17:0] 	S_cam_power_cnt;
	reg         	S_cam_pwdnb;
	reg         	S_cam_i2c_ready;
	(* keep = "true" *) wire [15:0] S_cam_sensor_id;
	(* keep = "true" *) wire        S_cam_sensor_id_ok;
	(* keep = "true" *) wire        S_cam_i2c_error;
	localparam integer CAM_PWDNB_LOW_CYCLES = 23810;  // >= 1 ms at 23.809524 MHz
	localparam integer CAM_I2C_START_CYCLES = 142857; // release + >= 5 ms

	wire [15:0] 	S_ae;
    wire [15:0] 	S_ag;
    wire 			S_cam_cfg_done;
    wire 			S_ae_cfg_done;
    wire 			S_ae_req;

	wire        	S_csi_rx_clk;
    wire        	S_hs_rx_valid;
    wire[15:0]  	S_hs_rx_data;
	wire[1:0]   	S_lane_error;

	wire        	S_csi_frame_start;
	wire        	S_csi_frame_end;
	wire        	S_csi_valid;
	wire[31:0]  	S_csi_data;
	(* keep = "true" *) wire [15:0] S_csi_data_length;

	wire        	S_raw10_frame_start;
	wire        	S_raw10_frame_end;
	wire        	S_raw10_valid;
	wire [39:0] 	S_raw10_data;

	wire 			S_axis_tlast;
	wire 			S_axis_tuser;
	wire [39:0]		S_axis_tdata;
	wire 			S_axis_tvalid;

	wire [39:0]		S_raw_tdata ;
	wire			S_raw_tlast ;
	wire 			S_raw_tvalid;
	wire 			S_raw_tuser ;

	wire			S_ISP_O_tready;
	// video_in exposes no backpressure output; its async FIFO is the always-ready
	// sink for the ISP stream, so make the AXI-stream contract explicit.
	assign			S_ISP_O_tready = 1'b1;
	wire [127:0]	S_ISP_O_tdata ;
	wire 			S_ISP_O_tlast ;
	wire 			S_ISP_O_tuser ;
	wire 			S_ISP_O_tvalid;


    wire        S_ddr_clk;
    wire        S_hdmi_pixel_clk;
    wire        S_hdmi_serial_clk;
    wire        S_hdmi_rst_n;
    wire        S_video_out_rst_n;


    wire        S_vi_128b_frame_start;
    wire        S_vi_128b_valid;
    wire[127:0] S_vi_128b_data;

    wire        S_video_out_rd_busy;
    wire        S_video_in_wr_busy;
    wire[1:0]   S_video_out_rp;

    wire        S_ddr_user_wr_en;
    wire        S_ddr_user_rd_en;
    wire[24:0]  S_ddr_user_addr;
    wire[127:0] S_ddr_user_wr_data;
    wire        S_ddr_user_ready;
    wire        S_ddr_user_rd_valid;
    wire[127:0] S_ddr_user_rd_data;

    wire        S_vi_ddr_wr_en;
    wire[24:0]  S_vi_ddr_wr_addr;
    wire[127:0] S_vi_ddr_wr_data;
    wire        S_vi_ddr_wr_ready;

    wire        S_vo_ddr_rd_en;
    wire[24:0]  S_vo_ddr_rd_addr;
    wire        S_vo_ddr_rd_ready;
    wire        S_vo_dbg_fifo_rst;
    wire        S_vo_dbg_ddr_rd_valid;
    wire        S_vo_dbg_fifo_rd_en;
    wire        S_vo_dbg_fifo_empty;

    wire        S_init_calib_complete;
    wire[24:0]  S_mc_app_addr;
    wire[2:0]   S_mc_app_cmd;
    wire        S_mc_app_en;
    wire[127:0] S_mc_app_wdf_data;
    wire        S_mc_app_wdf_end;
    wire[15:0]  S_mc_app_wdf_mask;
    wire        S_mc_app_wdf_wren;
    wire[127:0] S_mc_app_rd_data;
    wire        S_mc_app_rd_data_end;
    wire        S_mc_app_rd_data_valid;
    wire        S_mc_app_rdy;
    wire        S_mc_app_wdf_rdy;
    wire        S_mc_dbg_fifo_afull;
    wire        S_mc_dbg_app_rdy;
    wire        S_mc_dbg_wdf_rdy;
    wire        S_mc_dbg_cmd_pop;

    wire        S_hdmi_vsync;
    wire        S_hdmi_hsync;
    wire        S_hdmi_de;
    wire        S_hdmi_user;
    wire        S_hdmi_last;
    wire        S_video_out_vsync;
    wire        S_hdmi_window_rd_en;
    wire        S_hdmi_out_vsync;
    wire        S_hdmi_out_hsync;
    wire        S_hdmi_out_de;
    wire[23:0]  S_hdmi_out_data;

    wire[23:0]  S_video_rd_data;
    reg         S_dbg_raw_seen;
    reg         S_dbg_isp_seen;
    reg         S_dbg_ddr_wr_seen;
    reg         S_dbg_ddr_rd_seen;
    reg         S_dbg_cam_cfg_seen;
    reg         S_dbg_hs_seen;
    reg         S_dbg_csi_seen;
    reg         S_dbg_raw10_seen;
    reg         S_dbg_isp_fs_seen;
    reg         S_dbg_isp_valid_seen;
    reg         S_dbg_ddr_req_seen;
    reg         S_dbg_ddr_ready_seen;
    reg [1:0]   S_dbg_raw_seen_sync;
    reg [1:0]   S_dbg_isp_seen_sync;
    reg [1:0]   S_dbg_ddr_wr_seen_sync;
    reg [1:0]   S_dbg_ddr_rd_seen_sync;
    reg [1:0]   S_dbg_cam_cfg_seen_sync;
    reg [1:0]   S_dbg_hs_seen_sync;
    reg [1:0]   S_dbg_csi_seen_sync;
    reg [1:0]   S_dbg_raw10_seen_sync;
    reg [1:0]   S_dbg_isp_fs_seen_sync;
    reg [1:0]   S_dbg_isp_valid_seen_sync;
    reg [1:0]   S_dbg_ddr_req_seen_sync;
    reg [1:0]   S_dbg_ddr_ready_seen_sync;
    reg         S_dbg_video_nonzero_seen;
    reg         S_dbg_rd_req_seen;
    reg         S_dbg_rd_valid_seen;
    reg         S_dbg_rd_nonzero_seen;
    reg [1:0]   S_dbg_rd_req_seen_sync;
    reg [1:0]   S_dbg_rd_valid_seen_sync;
    reg [1:0]   S_dbg_rd_nonzero_seen_sync;
    reg         S_dbg_mc_init_seen;
    reg         S_dbg_mc_app_rdy_seen;
    reg         S_dbg_mc_wdf_rdy_seen;
    reg         S_dbg_mc_cmd_pop_seen;
    reg [1:0]   S_dbg_mc_init_seen_sync;
    reg [1:0]   S_dbg_mc_app_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_wdf_rdy_seen_sync;
    reg [1:0]   S_dbg_mc_cmd_pop_seen_sync;
    wire[3:0]   S_hdmi_debug_status;
    wire        S_lane_error_any;
    wire        S_csi_packet_start;
    reg         S_csi_length_active_d;
    reg [10:0]  S_mipi_line_count;
    reg         S_mipi_length_error;
    reg         S_mipi_lane_error;
    reg         S_mipi_frame_seen;
    reg         S_mipi_frame_done;
    reg         S_mipi_last_length_error;
    reg         S_mipi_last_line_error;
    reg         S_mipi_last_lane_error;
    wire[3:0]   S_mipi_diag_status_async;
    reg [3:0]   S_mipi_diag_status_sync1;
    reg [3:0]   S_mipi_diag_status_sync2;


    assign S_video_out_vsync = ~S_hdmi_vsync;


    assign S_rst_n 		= S_pll_lock;
    assign S_hdmi_rst_n = S_pll_lock;

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw_seen <= 1'b0;
        else if(S_raw10_frame_start | S_axis_tvalid)
            S_dbg_raw_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_seen <= 1'b0;
        else if(S_ISP_O_tuser | S_ISP_O_tvalid)
            S_dbg_isp_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_wr_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_wr_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_rd_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_ddr_rd_seen <= 1'b1;
    end

    always @(posedge S_24m_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_cam_cfg_seen <= 1'b0;
        else if(S_cam_cfg_done)
            S_dbg_cam_cfg_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_hs_seen <= 1'b0;
        else if(S_hs_rx_valid)
            S_dbg_hs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_csi_seen <= 1'b0;
        else if(S_csi_frame_start | S_csi_valid)
            S_dbg_csi_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_raw10_seen <= 1'b0;
        else if(S_raw10_frame_start | S_raw10_valid)
            S_dbg_raw10_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_fs_seen <= 1'b0;
        else if(S_ISP_O_tuser)
            S_dbg_isp_fs_seen <= 1'b1;
    end

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_isp_valid_seen <= 1'b0;
        else if(S_ISP_O_tvalid)
            S_dbg_isp_valid_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_req_seen <= 1'b0;
        else if(S_vi_ddr_wr_en)
            S_dbg_ddr_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_ddr_ready_seen <= 1'b0;
        else if(S_ddr_user_ready)
            S_dbg_ddr_ready_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_req_seen <= 1'b0;
        else if(S_vo_ddr_rd_en)
            S_dbg_rd_req_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_valid_seen <= 1'b0;
        else if(S_ddr_user_rd_valid)
            S_dbg_rd_valid_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_video_out_rst_n) begin
        if(!S_video_out_rst_n)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_video_out_vsync)
            S_dbg_rd_nonzero_seen <= 1'b0;
        else if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
            S_dbg_rd_nonzero_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_init_seen <= 1'b0;
        else if(S_init_calib_complete)
            S_dbg_mc_init_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_app_rdy_seen <= 1'b0;
        else if(S_mc_dbg_app_rdy)
            S_dbg_mc_app_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_wdf_rdy_seen <= 1'b0;
        else if(S_mc_dbg_wdf_rdy)
            S_dbg_mc_wdf_rdy_seen <= 1'b1;
    end

    always @(posedge S_ddr_clk or negedge S_rst_n) begin
        if(!S_rst_n)
            S_dbg_mc_cmd_pop_seen <= 1'b0;
        else if(S_mc_dbg_cmd_pop)
            S_dbg_mc_cmd_pop_seen <= 1'b1;
    end

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_dbg_cam_cfg_seen_sync <= 2'b00;
            S_dbg_hs_seen_sync      <= 2'b00;
            S_dbg_csi_seen_sync     <= 2'b00;
            S_dbg_raw10_seen_sync   <= 2'b00;
            S_dbg_raw_seen_sync    <= 2'b00;
            S_dbg_isp_seen_sync    <= 2'b00;
            S_dbg_ddr_wr_seen_sync <= 2'b00;
            S_dbg_ddr_rd_seen_sync <= 2'b00;
            S_dbg_isp_fs_seen_sync  <= 2'b00;
            S_dbg_isp_valid_seen_sync <= 2'b00;
            S_dbg_ddr_req_seen_sync <= 2'b00;
            S_dbg_ddr_ready_seen_sync <= 2'b00;
            S_dbg_video_nonzero_seen <= 1'b0;
            S_dbg_rd_req_seen_sync <= 2'b00;
            S_dbg_rd_valid_seen_sync <= 2'b00;
            S_dbg_rd_nonzero_seen_sync <= 2'b00;
            S_dbg_mc_init_seen_sync <= 2'b00;
            S_dbg_mc_app_rdy_seen_sync <= 2'b00;
            S_dbg_mc_wdf_rdy_seen_sync <= 2'b00;
            S_dbg_mc_cmd_pop_seen_sync <= 2'b00;
        end
        else begin
            S_dbg_cam_cfg_seen_sync <= {S_dbg_cam_cfg_seen_sync[0], S_dbg_cam_cfg_seen};
            S_dbg_hs_seen_sync      <= {S_dbg_hs_seen_sync[0],      S_dbg_hs_seen};
            S_dbg_csi_seen_sync     <= {S_dbg_csi_seen_sync[0],     S_dbg_csi_seen};
            S_dbg_raw10_seen_sync   <= {S_dbg_raw10_seen_sync[0],   S_dbg_raw10_seen};
            S_dbg_raw_seen_sync    <= {S_dbg_raw_seen_sync[0],    S_dbg_raw_seen};
            S_dbg_isp_seen_sync    <= {S_dbg_isp_seen_sync[0],    S_dbg_isp_seen};
            S_dbg_ddr_wr_seen_sync <= {S_dbg_ddr_wr_seen_sync[0], S_dbg_ddr_wr_seen};
            S_dbg_ddr_rd_seen_sync <= {S_dbg_ddr_rd_seen_sync[0], S_dbg_ddr_rd_seen};
            S_dbg_isp_fs_seen_sync  <= {S_dbg_isp_fs_seen_sync[0],  S_dbg_isp_fs_seen};
            S_dbg_isp_valid_seen_sync <= {S_dbg_isp_valid_seen_sync[0], S_dbg_isp_valid_seen};
            S_dbg_ddr_req_seen_sync <= {S_dbg_ddr_req_seen_sync[0], S_dbg_ddr_req_seen};
            S_dbg_ddr_ready_seen_sync <= {S_dbg_ddr_ready_seen_sync[0], S_dbg_ddr_ready_seen};
            S_dbg_rd_req_seen_sync <= {S_dbg_rd_req_seen_sync[0], S_dbg_rd_req_seen};
            S_dbg_rd_valid_seen_sync <= {S_dbg_rd_valid_seen_sync[0], S_dbg_rd_valid_seen};
            S_dbg_rd_nonzero_seen_sync <= {S_dbg_rd_nonzero_seen_sync[0], S_dbg_rd_nonzero_seen};
            S_dbg_mc_init_seen_sync <= {S_dbg_mc_init_seen_sync[0], S_dbg_mc_init_seen};
            S_dbg_mc_app_rdy_seen_sync <= {S_dbg_mc_app_rdy_seen_sync[0], S_dbg_mc_app_rdy_seen};
            S_dbg_mc_wdf_rdy_seen_sync <= {S_dbg_mc_wdf_rdy_seen_sync[0], S_dbg_mc_wdf_rdy_seen};
            S_dbg_mc_cmd_pop_seen_sync <= {S_dbg_mc_cmd_pop_seen_sync[0], S_dbg_mc_cmd_pop_seen};
            if(S_hdmi_window_rd_en && (S_video_rd_data != 24'd0))
                S_dbg_video_nonzero_seen <= 1'b1;
        end
    end

    assign S_lane_error_any = |S_lane_error;

    // A RAW10 line contains 1280 * 10 / 8 = 1600 bytes.  The CSI parser
    // reports the number of 16-bit lane words, therefore the expected value
    // is 1600 / 2 = 800 = 16'h0320.  Count one long packet whenever that
    // decoded length changes from zero to non-zero.
    assign S_csi_packet_start = (S_csi_data_length != 16'd0) &&
                                !S_csi_length_active_d;

    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if(!S_rst_n) begin
            S_csi_length_active_d      <= 1'b0;
            S_mipi_line_count          <= 11'd0;
            S_mipi_length_error        <= 1'b0;
            S_mipi_lane_error          <= 1'b0;
            S_mipi_frame_seen          <= 1'b0;
            S_mipi_frame_done          <= 1'b0;
            S_mipi_last_length_error   <= 1'b0;
            S_mipi_last_line_error     <= 1'b0;
            S_mipi_last_lane_error     <= 1'b0;
        end
        else begin
            S_csi_length_active_d <= (S_csi_data_length != 16'd0);

            if(S_csi_frame_start) begin
                S_mipi_line_count   <= 11'd0;
                S_mipi_length_error <= 1'b0;
                S_mipi_lane_error   <= 1'b0;
                S_mipi_frame_seen   <= 1'b1;
            end
            else begin
                if(S_csi_packet_start) begin
                    S_mipi_line_count <= S_mipi_line_count + 11'd1;
                    if(S_csi_data_length != 16'h0320)
                        S_mipi_length_error <= 1'b1;
                end

                if(S_lane_error_any)
                    S_mipi_lane_error <= 1'b1;
            end

            // Publish only a completed frame, so the HDMI-domain diagnostic
            // sees a stable result rather than counters changing every line.
            if(S_csi_frame_end) begin
                S_mipi_frame_done        <= 1'b1;
                S_mipi_last_length_error <= S_mipi_length_error;
                S_mipi_last_line_error   <= (S_mipi_line_count != 11'd720);
                S_mipi_last_lane_error   <= S_mipi_lane_error |
                                            S_lane_error_any;
            end
        end
    end

    // Diagnostic result codes consumed by hdmi_mixer DEBUG_MODE=4:
    // 0=config incomplete, 1=no HS traffic, 2=no completed CSI frame,
    // 3=lane error, 4=wrong RAW10 line length, 5=wrong lines/frame,
    // 6=the observed MIPI frame structure is correct, 7=I2C error.
    // I2C error has the highest priority because O_cfg_done only indicates
    // that the write sequencer reached its end; it does not prove that every
    // sensor register write was acknowledged successfully.
    assign S_mipi_diag_status_async =
        S_cam_i2c_error              ? 4'd7 :
        !S_cam_cfg_done              ? 4'd0 :
        !S_dbg_hs_seen               ? 4'd1 :
        !(S_mipi_frame_seen &&
          S_mipi_frame_done)         ? 4'd2 :
        S_mipi_last_lane_error       ? 4'd3 :
        S_mipi_last_length_error     ? 4'd4 :
        S_mipi_last_line_error       ? 4'd5 : 4'd6;

    always @(posedge S_hdmi_pixel_clk or negedge S_hdmi_rst_n) begin
        if(!S_hdmi_rst_n) begin
            S_mipi_diag_status_sync1 <= 4'd0;
            S_mipi_diag_status_sync2 <= 4'd0;
        end
        else begin
            S_mipi_diag_status_sync1 <= S_mipi_diag_status_async;
            S_mipi_diag_status_sync2 <= S_mipi_diag_status_sync1;
        end
    end

    assign S_vo_dbg_fifo_rst = 1'b0;
    assign S_vo_dbg_ddr_rd_valid = 1'b0;
    assign S_vo_dbg_fifo_rd_en = 1'b0;
    assign S_vo_dbg_fifo_empty = 1'b0;
    assign S_mc_dbg_fifo_afull = 1'b0;
    assign S_mc_dbg_app_rdy = 1'b0;
    assign S_mc_dbg_wdf_rdy = 1'b0;
    assign S_mc_dbg_cmd_pop = 1'b0;

    assign S_hdmi_debug_status = S_mipi_diag_status_sync2;

	// J9 pin 37 is connected to the module's PWDNB/XSHUTDN input.
	// Hold the sensor in power-down after PLL lock, then allow its internal
	// power-up sequence to finish before the first I2C transaction.
	always @(posedge S_24m_clk or negedge S_pll_lock) begin
		if (!S_pll_lock) begin
			S_cam_power_cnt <= 18'd0;
			S_cam_pwdnb <= 1'b0;
			S_cam_i2c_ready <= 1'b0;
		end else begin
			if (S_cam_power_cnt < CAM_I2C_START_CYCLES)
				S_cam_power_cnt <= S_cam_power_cnt + 1'b1;
			if (S_cam_power_cnt >= CAM_PWDNB_LOW_CYCLES)
				S_cam_pwdnb <= 1'b1;
			if (S_cam_power_cnt >= CAM_I2C_START_CYCLES - 1)
				S_cam_i2c_ready <= 1'b1;
		end
	end

	assign O_cam_rst 	= S_cam_pwdnb;
    assign O_cam_24m 	= S_24m_clk;




    PLL u_PLL(
        .refclk      ( I_sys_clk         ),
        // The HX1P35A manual does not expose a dedicated user-reset pin.
        // Hold the PLL reset inactive and use its lock signal as the
        // internally generated reset release for every clock domain.
        .reset    	 ( 1'b0              ),

        .clk0_out    ( S_100m_clk        ),
        .clk1_out    ( S_24m_clk         ),

        .clk4_out    ( S_hdmi_pixel_clk  ),
        .clk5_out    ( S_hdmi_serial_clk ),

        .lock        ( S_pll_lock        )

    );





  ae_set u_ae_set (
      .I_clk(S_24m_clk),
      .I_rst(~S_rst_n),
      .I_btn({I_button,2'b11}),
      .I_cam_cfg_done(S_cam_cfg_done),
      .I_ae_cfg_done(S_ae_cfg_done),
      .O_ae_req(S_ae_req),
      .O_ae(S_ae),
      .O_ag(S_ag)
  );

    uicfgcs520 #(
      .CLK_DIV(23809524 / 100000 - 1)
  ) u_uicfgcs520 (
      .I_clk(S_24m_clk),  //系统时钟输入
      .I_rst_n(S_cam_i2c_ready), // SC520CS power-up delay completed
      .I_ae_req(S_ae_req),
      .I_ae(S_ae),
      .I_ag(S_ag),
      .O_cam_scl(O_cam_scl),  //I2C总线，SCL时钟
      .IO_cam_sda(IO_cam_sda),  //I2C总线，SDA数据
      .O_cfg_done(S_cam_cfg_done),  //摄像头寄存器初始化完成
      .O_ae_cfg_done(S_ae_cfg_done),  //AE配置完成
      .O_sensor_id(S_cam_sensor_id),
      .O_sensor_id_ok(S_cam_sensor_id_ok),
      .O_iic_error(S_cam_i2c_error)
  );

    mipi_dphy_rx_ph1p_mipiio_wrapper#(
        .DPHY_RX_LOCATION      ( "DPHY0" ),
        .HS_EQUALIZER          ( "3dB"   ),// 828 Mbps/Lane接收均衡
        .HS_VGA_GAIN           ( "8dB" ),//"-3dB","-1.5dB","0dB","1.5dB","3dB","4.5dB","6dB","7.5dB"
        .LANE_NUM              ( 2       ),
        .BYTE_NUM              ( 1       )
    )u_mipi_dphy_rx_ph1p_mipiio_wrapper(
        .I_lp_clk              ( S_100m_clk       ),
        .I_rst                 ( ~S_rst_n         ),

        .I_clk_lane_in_delay   ( 6'd0             ),
        .I_data_lane0_in_delay ( 6'd0             ),
        .I_data_lane1_in_delay ( 6'd0             ),
        .I_data_lane2_in_delay ( 6'd0             ),
        .I_data_lane3_in_delay ( 6'd0             ),

        // LANE_NUM=2: keep the inversion vector width equal to the PHY port.
        .I_lane_invert         ( 2'b00            ),

        .O_hs_rx_clk           ( S_csi_rx_clk     ),
        .O_hs_rx_valid         ( S_hs_rx_valid    ),
        .O_hs_rx_data          ( S_hs_rx_data     ),

        .O_lp_rx_lane0_p       (  ),
        .O_lp_rx_lane0_n       (  ),

        .I_lp_tx_en            ( 1'b0             ),
        .I_lp_tx_lane0_p       ( 1'b1             ),
        .I_lp_tx_lane0_n       ( 1'b1             ),

        .O_lane_match_error    (                  ),
        .O_lane_error          ( S_lane_error     ),

        .IO_rx_clk_pad_n       ( IO_rx_clk_pad_n  ),
        .IO_rx_clk_pad_p       ( IO_rx_clk_pad_p  ),
        .IO_rx_data_pad_n      ( IO_rx_data_pad_n ),
        .IO_rx_data_pad_p      ( IO_rx_data_pad_p )
    );


 //  cwc cwc_inst
 //(
 //    .probe0(S_hs_rx_valid),
 //    .probe1(S_hs_rx_data),
 //    .probe2(S_lane_error),
 //    .clk(S_csi_rx_clk)
 //);

 //csi 解码为RAW数据
csi_unpacket_2lane u_csi_unpacket(
.I_clk                 ( S_csi_rx_clk       ),
.I_rst_n               ( S_rst_n        	),
.I_hs_valid            ( S_hs_rx_valid     ),
.I_hs_data             ( S_hs_rx_data      ),

.O_csi_frame_start     ( S_csi_frame_start ),
.O_csi_frame_end       ( S_csi_frame_end   ),
.O_csi_valid           ( S_csi_valid       ),
.O_csi_data            ( S_csi_data        ),
.O_data_length         ( S_csi_data_length )
);


//解码为RAW8
raw10_unpacket_2lane u_raw10_unpacket (
.I_clk  (S_csi_rx_clk),
.I_rst_n(S_rst_n),

.I_csi_frame_start(S_csi_frame_start),
.I_csi_frame_end  (S_csi_frame_end),
.I_csi_valid      (S_csi_valid),
.I_csi_data       (S_csi_data),

.O_raw10_frame_start(S_raw10_frame_start),
.O_raw10_frame_end  (S_raw10_frame_end),
.O_raw10_valid      (S_raw10_valid),
.O_raw10_data       (S_raw10_data)
  );


//将数据转为stream流
uial2axis #(
.IMG_WIDTH(1280),
.IMG_HEIGHT(720),
.INPUT_DATA_WIDTH(40)
)
u_uial2axis (
.I_native_clk(S_csi_rx_clk),
.I_rst_n     (S_rst_n),
.I_data      (S_raw10_data       ),
.I_data_valid(S_raw10_valid      ),
.I_data_start(S_raw10_frame_start),
.I_data_end  (S_raw10_frame_end  ),
.axis_tvalid (S_axis_tvalid),
.axis_tdata  (S_axis_tdata ),
.axis_tuser  (S_axis_tuser ),
.axis_tlast  (S_axis_tlast )
);


// SC520CS原厂HD模式已经直接输出1280x720 RAW10，无需FPGA窗口裁剪。
assign S_raw_tdata  = S_axis_tdata;
assign S_raw_tlast  = S_axis_tlast;
assign S_raw_tvalid = S_axis_tvalid;
assign S_raw_tuser  = S_axis_tuser;


//cwc1 cwc1_Inst
//  (
//      .probe0(S_axis_tuser),
//      .probe1(S_axis_tvalid),
//      .probe2(S_axis_tlast),
//      .probe3(S_axis_tdata),
//      .probe4(S_ISP_O_tuser),
//      .probe5(S_ISP_O_tvalid),
//      .probe6(S_ISP_O_tlast),
//      .probe7(S_ISP_O_tdata),
//      .probe8 (S_raw_tdata ),
//      .probe9 (S_raw_tlast ),
//      .probe10(S_raw_tvalid),
//      .probe11(S_raw_tuser ),
//      .clk(S_csi_rx_clk)
//  );


    wire [10:0] ind_xmin, ind_xmax, ind_ymin, ind_ymax;
    wire [10:0] ind_meas_w, ind_meas_h;
    wire        ind_detected, ind_pass, ind_ng, ind_no_obj, ind_invalid;
    wire        ind_led_pass, ind_led_ng, ind_led_det;
    wire        ind_result_toggle;
    reg  [15:0] ind_v2_frame_id;
    reg         ind_v2_toggle_d;
    wire [11:0] ind_cx_sum = {1'b0, ind_xmin} + {1'b0, ind_xmax};
    wire [11:0] ind_cy_sum = {1'b0, ind_ymin} + {1'b0, ind_ymax};
    wire [10:0] ind_v2_cx = ind_cx_sum >> 1;
    wire [10:0] ind_v2_cy = ind_cy_sum >> 1;

    // Source-domain frame ID for the result toggle. This counter is only a
    // protocol tag; it is not a measured camera frame-rate or latency value.
    always @(posedge S_csi_rx_clk or negedge S_rst_n) begin
        if (!S_rst_n) begin
            ind_v2_frame_id <= 16'd0;
            ind_v2_toggle_d <= 1'b0;
        end else begin
            if (ind_result_toggle != ind_v2_toggle_d)
                ind_v2_frame_id <= ind_v2_frame_id + 16'd1;
            ind_v2_toggle_d <= ind_result_toggle;
        end
    end

    // ISP算法顶层模块 (集成工业目标定位与缺陷检测)
    isp_top u_isp_top (
        .axi4s_video_aclk ( S_csi_rx_clk         ),
        .I_rst_n          ( S_rst_n              ),
        .I_tlast          ( S_raw_tlast          ),
        .I_tuser          ( S_raw_tuser          ),
        .I_tdata          ( S_raw_tdata          ),
        .I_tvalid         ( S_raw_tvalid         ),
        .I_tdest          (                      ),
        .O_tready         ( S_ISP_O_tready       ),
        .O_tdata          ( S_ISP_O_tdata        ),
        .O_tlast          ( S_ISP_O_tlast        ),
        .O_tuser          ( S_ISP_O_tuser        ),
        .O_tvalid         ( S_ISP_O_tvalid       ),
        .I_tready         (                      ),
        .O_ind_xmin       ( ind_xmin             ),
        .O_ind_xmax       ( ind_xmax             ),
        .O_ind_ymin       ( ind_ymin             ),
        .O_ind_ymax       ( ind_ymax             ),
        .O_ind_width      ( ind_meas_w           ),
        .O_ind_height     ( ind_meas_h           ),
        .O_ind_detected   ( ind_detected         ),
        .O_ind_pass       ( ind_pass             ),
        .O_ind_ng         ( ind_ng               ),
        .O_ind_no_obj     ( ind_no_obj           ),
        .O_ind_invalid    ( ind_invalid          ),
        .O_led_pass       ( ind_led_pass         ),
        .O_led_ng         ( ind_led_ng           ),
        .O_led_det         ( ind_led_det          ),
        .O_ind_result_toggle ( ind_result_toggle )
        );

    // LEDs consume the same HDMI-domain atomic result as the OSD and BBox.
    // INVALID deliberately lights both result indicators, while the detected
    // indicator remains low because the measurement is not trustworthy.
    assign O_led_pass = (sync_hdmi_pass || sync_hdmi_invalid);
    assign O_led_ng   = (sync_hdmi_ng   || sync_hdmi_invalid);
    assign O_led_det  = sync_hdmi_detected;
    // HX1P35A independent LEDs are high-active: LED1=D10, LED2=E10,
    // LED3=C6.  Keep the logical status encoding unchanged and expose it
    // through the physical board outputs.
    assign O_led1 = O_led_pass;
    assign O_led2 = O_led_ng;
    assign O_led3 = O_led_det;


    video_in u_video_in(
        .I_rst_n              (  S_rst_n             ),

        .I_camera_clk         ( S_csi_rx_clk          ),
        .I_camera_frame_start ( S_ISP_O_tuser  ),
        .I_camera_valid       ( S_ISP_O_tvalid ),
        .I_camera_data        ( S_ISP_O_tdata  ),
        .I_mipi_rx_error      ( 1'b0			      ),

        .I_ddr_clk            ( S_ddr_clk             ),
		.I_display_pause      ( 1'b0                  ),
        .I_video_out_rd_busy  ( S_video_out_rd_busy   ),
        .O_video_in_wr_busy   ( S_video_in_wr_busy    ),
        .O_video_out_rp       ( S_video_out_rp        ),

        .O_ddr_user_wr_en     ( S_vi_ddr_wr_en        ),
        .O_ddr_user_addr      ( S_vi_ddr_wr_addr      ),
        .O_ddr_user_wr_data   ( S_vi_ddr_wr_data      ),
        .I_ddr_user_ready     ( S_ddr_user_ready      )
    );



    assign S_ddr_user_wr_en    = S_vi_ddr_wr_en;

    assign S_ddr_user_rd_en    = S_vo_ddr_rd_en;

    assign S_ddr_user_addr     = S_vi_ddr_wr_en ? S_vi_ddr_wr_addr :
                                 S_vo_ddr_rd_en ? S_vo_ddr_rd_addr : 'd0;

    assign S_ddr_user_wr_data  = S_vi_ddr_wr_data;


    assign S_video_out_rst_n = S_hdmi_rst_n;

    video_out u_video_out(
        .I_rst_n             ( S_video_out_rst_n    ),
        .I_ddr_clk           ( S_ddr_clk            ),

        .O_video_out_rd_busy ( S_video_out_rd_busy  ),
        .I_video_in_wr_busy  ( S_video_in_wr_busy   ),
        .I_video_out_rp      ( S_video_out_rp       ),

        .O_ddr_user_rd_en    ( S_vo_ddr_rd_en       ),
        .O_ddr_user_addr     ( S_vo_ddr_rd_addr     ),
        .I_ddr_user_ready    ( S_ddr_user_ready     ),
        .I_ddr_user_rd_valid ( S_ddr_user_rd_valid  ),
        .I_ddr_user_rd_data  ( S_ddr_user_rd_data   ),

        .I_dsi_clk           ( S_hdmi_pixel_clk     ),
        .I_video_vsync       ( S_video_out_vsync    ),
        .I_video_rd_en       ( S_hdmi_window_rd_en  ),
        .O_vdieo_data        ( S_video_rd_data      )
    );



    mc_to_user_interface u_mc_to_user_interface(
        .I_clk                   ( S_ddr_clk               ),
        .I_rst_n                 ( S_rst_n                 ),

        .I_ddr_user_wr_en        ( S_ddr_user_wr_en        ),
        .I_ddr_user_rd_en        ( S_ddr_user_rd_en        ),
        .I_ddr_user_addr         ( S_ddr_user_addr         ),
        .I_ddr_user_wr_data      ( S_ddr_user_wr_data      ),
        .O_ddr_user_ready        ( S_ddr_user_ready        ),
        .O_ddr_user_rd_valid     ( S_ddr_user_rd_valid     ),
        .O_ddr_user_rd_data      ( S_ddr_user_rd_data      ),

        .O_mc_app_en             ( S_mc_app_en             ),
        .O_mc_app_addr           ( S_mc_app_addr           ),
        .O_mc_app_cmd            ( S_mc_app_cmd            ),
        .I_mc_app_rdy            ( S_mc_app_rdy            ),
        .O_mc_app_wdf_wren       ( S_mc_app_wdf_wren       ),
        .O_mc_app_wdf_data       ( S_mc_app_wdf_data       ),
        .O_mc_app_wdf_end        ( S_mc_app_wdf_end        ),
        .O_mc_app_wdf_mask       ( S_mc_app_wdf_mask       ),
        .I_mc_app_wdf_rdy        ( S_mc_app_wdf_rdy        ),
        .I_mc_app_rd_data        ( S_mc_app_rd_data        ),
        .I_mc_app_rd_data_end    ( S_mc_app_rd_data_end    ),
        .I_mc_app_rd_data_valid  ( S_mc_app_rd_data_valid  )
    );



    ph1p35_324_ddr_wrapper u_ph1p35_324_ddr_wrapper(
        .I_sys_clk              ( I_sys_clk              ),
        .I_sys_rst_n            ( S_rst_n                ),

        .O_ddr_clk              ( S_ddr_clk              ),
        .O_init_calib_complete  ( S_init_calib_complete  ),
        .I_mc_app_addr          ( S_mc_app_addr          ),
        .I_mc_app_cmd           ( S_mc_app_cmd           ),
        .I_mc_app_en            ( S_mc_app_en            ),
        .I_mc_app_wdf_data      ( S_mc_app_wdf_data      ),
        .I_mc_app_wdf_end       ( S_mc_app_wdf_end       ),
        .I_mc_app_wdf_mask      ( S_mc_app_wdf_mask      ),
        .I_mc_app_wdf_wren      ( S_mc_app_wdf_wren      ),
        .O_mc_app_rd_data       ( S_mc_app_rd_data       ),
        .O_mc_app_rd_data_end   ( S_mc_app_rd_data_end   ),
        .O_mc_app_rd_data_valid ( S_mc_app_rd_data_valid ),
        .O_mc_app_rdy           ( S_mc_app_rdy           ),
        .O_mc_app_wdf_rdy       ( S_mc_app_wdf_rdy       ),

        .ddr_addr               ( ddr_addr               ),
        .ddr_ba                 ( ddr_ba                 ),
        .ddr_cke                ( ddr_cke                ),
        .ddr_odt                ( ddr_odt                ),
        .ddr_cs_n               ( ddr_cs_n               ),
        .ddr_ras_n              ( ddr_ras_n              ),
        .ddr_cas_n              ( ddr_cas_n              ),
        .ddr_we_n               ( ddr_we_n               ),
        .ddr_ck_p               ( ddr_ck_p               ),
        .ddr_ck_n               ( ddr_ck_n               ),
        .ddr_dm                 ( ddr_dm                 ),
        .ddr_dq                 ( ddr_dq                 ),
        .ddr_dqs_p              ( ddr_dqs_p              ),
        .ddr_dqs_n              ( ddr_dqs_n              )
    );


    // Generate the real 720p timing used by the DDR video reader and all
    // downstream pixel-processing stages.  These signals must not be left
    // floating: video_out uses the VSYNC edge to schedule frame reads, while
    // the mode, bbox, and OSD stages consume the mixer timing sidebands.
    uivtc #(
        .H_ActiveSize ( 1280 ),
        .H_FrameSize  ( 1650 ),
        .H_SyncStart  ( 1390 ),
        .H_SyncEnd    ( 1430 ),
        .V_ActiveSize ( 720  ),
        .V_FrameSize  ( 750  ),
        .V_SyncStart  ( 725  ),
        .V_SyncEnd    ( 730  )
    ) u_hdmi_vtc (
        .I_vtc_rstn     ( S_hdmi_rst_n     ),
        .I_vtc_clk      ( S_hdmi_pixel_clk ),
        .O_vtc_vs       ( S_hdmi_vsync     ),
        .O_vtc_hs       ( S_hdmi_hsync     ),
        .O_vtc_de_valid ( S_hdmi_de        ),
        .O_vtc_user     ( S_hdmi_user      ),
        .O_vtc_last     ( S_hdmi_last      )
    );

    // Convert the DDR reader's pixel stream into the same timed RGB stream
    // consumed by the three display modes.  The OSD remains the final pixel
    // stage below, so this mixer only owns base-video timing and read enable.
    hdmi_mixer #(
        .H_OFFSET  ( 0    ),
        .V_OFFSET  ( 0    ),
        .IMG_WIDTH ( 1280 ),
        .IMG_HEIGHT( 720  ),
        .DEBUG_MODE( 0    )
    ) u_hdmi_mixer (
        .I_clk           ( S_hdmi_pixel_clk   ),
        .I_rst_n         ( S_hdmi_rst_n       ),
        .I_video_vsync   ( S_hdmi_vsync       ),
        .I_video_hsync   ( S_hdmi_hsync       ),
        .I_video_de      ( S_hdmi_de          ),
        .I_video_user    ( S_hdmi_user        ),
        .I_video_last    ( S_hdmi_last        ),
        .I_debug_status  ( S_hdmi_debug_status),
        .O_video_rd_en   ( S_hdmi_window_rd_en),
        .I_video_rd_data ( S_video_rd_data    ),
        .O_hdmi_vsync    ( S_hdmi_out_vsync   ),
        .O_hdmi_hsync    ( S_hdmi_out_hsync   ),
        .O_hdmi_de       ( S_hdmi_out_de      ),
        .O_hdmi_data     ( S_hdmi_out_data    )
    );




    // --- video_cartoon pipeline wires ---
    // HDMI-domain mode controller: debounced active-low keys are committed at frame start.
    wire [1:0]  S_display_mode;
    wire        S_edge_req;
    wire        S_cartoon_req;
    wire        S_cartoon_out_vsync;
    wire        S_cartoon_out_hsync;
    wire        S_cartoon_out_de;
    wire [23:0] S_cartoon_out_data;
    wire [1:0]  S_cartoon_mode;

    mode_controller #(
        .DEBOUNCE_CYCLES ( 1000000 )
    ) u_mode_controller (
        .I_clk          ( S_hdmi_pixel_clk ),
        .I_rst_n        ( S_hdmi_rst_n     ),
        .I_key_edge_n   ( I_mode_edge_n    ),
        .I_key_cartoon_n( I_mode_cartoon_n ),
        .I_frame_start  ( S_hdmi_out_vsync ),
        .O_mode         ( S_display_mode   ),
        .O_edge_req     ( S_edge_req       ),
        .O_cartoon_req  ( S_cartoon_req    )
    );

    // --- Cartoon / Edge / Raw mode filter ---
    video_cartoon #(
        .WIDTH          ( 1280 ),
        .HEIGHT         ( 720  ),
        .EDGE_THRESHOLD ( 12'd240 )
    ) u_video_cartoon (
        .clk            ( S_hdmi_pixel_clk     ),
        .rst_n          ( S_hdmi_rst_n         ),
        .i_vs           ( S_hdmi_out_vsync     ),
        .i_hs           ( S_hdmi_out_hsync     ),
        .i_de           ( S_hdmi_out_de        ),
        .i_rgb          ( S_hdmi_out_data      ),
        .i_edge_req     ( S_edge_req           ),
        .i_toon_req     ( S_cartoon_req        ),
        .i_overlay      ( 1'b0                 ),
        .i_overlay_rgb  ( 24'd0                ),
        .o_vs           ( S_cartoon_out_vsync  ),
        .o_hs           ( S_cartoon_out_hsync  ),
        .o_de           ( S_cartoon_out_de     ),
        .o_rgb          ( S_cartoon_out_data   ),
        .o_mode         ( S_cartoon_mode       )
    );

    wire [10:0] sync_hdmi_xmin, sync_hdmi_xmax, sync_hdmi_ymin, sync_hdmi_ymax;
    wire [10:0] sync_hdmi_width, sync_hdmi_height;
    wire        sync_hdmi_detected, sync_hdmi_pass, sync_hdmi_ng;
    wire        sync_hdmi_invalid;
    wire        v2_hdmi_result_valid;
    wire [15:0] v2_hdmi_frame_id;
    wire [10:0] v2_hdmi_xmin, v2_hdmi_xmax, v2_hdmi_ymin, v2_hdmi_ymax;
    wire [10:0] v2_hdmi_cx, v2_hdmi_cy;
    wire        v2_hdmi_detected, v2_hdmi_pass, v2_hdmi_ng, v2_hdmi_invalid;
    wire        v2_hdmi_shape_valid;
    wire        v2_hdmi_motion;
    wire [23:0] v2_hdmi_motion_count;
    wire [15:0] v2_hdmi_pass_count, v2_hdmi_ng_count;
    wire        v2_hdmi_sort_pulse, v2_hdmi_safe_enable;

    industrial_v2_result_cdc u_industrial_v2_result_cdc (
        .I_src_clk             ( S_csi_rx_clk       ),
        .I_dst_clk             ( S_hdmi_pixel_clk   ),
        .I_rst_n               ( S_hdmi_rst_n       ),
        .I_src_toggle          ( ind_result_toggle  ),
        .I_src_frame_id        ( ind_v2_frame_id    ),
        .I_src_xmin            ( ind_xmin            ),
        .I_src_xmax            ( ind_xmax            ),
        .I_src_ymin            ( ind_ymin            ),
        .I_src_ymax            ( ind_ymax            ),
        .I_src_cx              ( ind_v2_cx           ),
        .I_src_cy              ( ind_v2_cy           ),
        .I_src_width_mm_q16_16 ( 32'd0              ),
        .I_src_height_mm_q16_16( 32'd0              ),
        .I_src_detected        ( ind_detected        ),
        .I_src_pass            ( ind_pass             ),
        .I_src_ng              ( ind_ng               ),
        .I_src_invalid         ( ind_invalid          ),
        .I_src_dimension_valid ( 1'b0                ),
        .I_src_shape_valid     ( 1'b0                ),
        .I_src_motion          ( 1'b0                ),
        .I_src_motion_count    ( 24'd0               ),
        .I_src_pass_count      ( 16'd0               ),
        .I_src_ng_count        ( 16'd0               ),
        .I_src_sort_pulse      ( 1'b0                ),
        .I_src_safe_enable     ( 1'b0                ),
        .O_dst_valid           ( v2_hdmi_result_valid),
        .O_dst_frame_id        ( v2_hdmi_frame_id    ),
        .O_dst_xmin            ( v2_hdmi_xmin        ),
        .O_dst_xmax            ( v2_hdmi_xmax        ),
        .O_dst_ymin            ( v2_hdmi_ymin        ),
        .O_dst_ymax            ( v2_hdmi_ymax        ),
        .O_dst_cx              ( v2_hdmi_cx          ),
        .O_dst_cy              ( v2_hdmi_cy          ),
        .O_dst_width_mm_q16_16(                      ),
        .O_dst_height_mm_q16_16(                     ),
        .O_dst_detected        ( v2_hdmi_detected    ),
        .O_dst_pass            ( v2_hdmi_pass        ),
        .O_dst_ng              ( v2_hdmi_ng          ),
        .O_dst_invalid         ( v2_hdmi_invalid     ),
        .O_dst_dimension_valid (                     ),
        .O_dst_shape_valid     ( v2_hdmi_shape_valid ),
        .O_dst_motion          ( v2_hdmi_motion      ),
        .O_dst_motion_count    ( v2_hdmi_motion_count),
        .O_dst_pass_count      ( v2_hdmi_pass_count  ),
        .O_dst_ng_count        ( v2_hdmi_ng_count    ),
        .O_dst_sort_pulse      ( v2_hdmi_sort_pulse  ),
        .O_dst_safe_enable     ( v2_hdmi_safe_enable ),
        .O_dst_overflow        (                     )
    );

    // The result CDC holds a newly published source-domain result pending
    // until the HDMI frame boundary.  BBox, OSD and status therefore consume
    // one atomic result for the entire displayed frame.
    inspection_result_cdc u_inspection_result_cdc (
        .I_src_clk      ( S_csi_rx_clk       ),
        .I_dst_clk      ( S_hdmi_pixel_clk   ),
        .I_rst_n        ( S_hdmi_rst_n       ),
        .I_frame_start  ( S_hdmi_out_vsync   ),
        .I_src_toggle   ( ind_result_toggle  ),
        .I_src_xmin     ( ind_xmin            ),
        .I_src_xmax     ( ind_xmax            ),
        .I_src_ymin     ( ind_ymin            ),
        .I_src_ymax     ( ind_ymax            ),
        .I_src_width    ( ind_meas_w          ),
        .I_src_height   ( ind_meas_h          ),
        .I_src_detected ( ind_detected        ),
        .I_src_pass     ( ind_pass             ),
        .I_src_ng       ( ind_ng               ),
        .I_src_no_obj   ( ind_no_obj           ),
        .I_src_invalid  ( ind_invalid          ),
        .O_xmin         ( sync_hdmi_xmin       ),
        .O_xmax         ( sync_hdmi_xmax       ),
        .O_ymin         ( sync_hdmi_ymin       ),
        .O_ymax         ( sync_hdmi_ymax       ),
        .O_width        ( sync_hdmi_width      ),
        .O_height       ( sync_hdmi_height     ),
        .O_detected     ( sync_hdmi_detected   ),
        .O_pass         ( sync_hdmi_pass       ),
        .O_ng           ( sync_hdmi_ng         ),
        .O_no_obj       (                       ),
        .O_invalid      ( sync_hdmi_invalid    )
    );

    // --- Industrial Inspection Bounding Box Overlay ---
    wire        S_bbox_out_vsync;
    wire        S_bbox_out_hsync;
    wire        S_bbox_out_de;
    wire [23:0] S_bbox_out_data;
    wire        S_tracking_out_vsync;
    wire        S_tracking_out_hsync;
    wire        S_tracking_out_de;
    wire [23:0] S_tracking_out_data;
    wire        S_tracking_valid;

    industrial_v2_display_tracking u_industrial_v2_display_tracking (
        .I_clk          ( S_hdmi_pixel_clk       ),
        .I_rst_n        ( S_hdmi_rst_n           ),
        .I_frame_valid  ( v2_hdmi_result_valid   ),
        .I_frame_id     ( v2_hdmi_frame_id       ),
        .I_detected     ( v2_hdmi_detected       ),
        .I_invalid      ( v2_hdmi_invalid        ),
        .I_cx           ( v2_hdmi_cx              ),
        .I_cy           ( v2_hdmi_cy              ),
        .I_de           ( S_cartoon_out_de       ),
        .I_hsync        ( S_cartoon_out_hsync    ),
        .I_vsync        ( S_cartoon_out_vsync    ),
        .I_rgb          ( S_cartoon_out_data     ),
        .O_de           ( S_tracking_out_de      ),
        .O_hsync        ( S_tracking_out_hsync   ),
        .O_vsync        ( S_tracking_out_vsync   ),
        .O_rgb          ( S_tracking_out_data    ),
        .O_track_valid  ( S_tracking_valid      ),
        .O_track_enter  (                     ),
        .O_track_exit   (                     ),
        .O_tracking_state(                    ),
        .O_track_cx     (                     ),
        .O_track_cy     (                     )
    );

    bbox_draw_overlay #(
        .IMG_WIDTH          ( 1280 ),
        .IMG_HEIGHT         ( 720  ),
        .LINE_THICKNESS     ( 2    ),
        .USE_INTERNAL_COORD ( 1    ),
        .COLOR_PASS         ( 24'h10b981 ), // Green (PASS)
        .COLOR_NG           ( 24'hef4444 )  // Red (NG)
    ) u_bbox_draw_overlay (
        .I_clk        ( S_hdmi_pixel_clk     ),
        .I_rst_n      ( S_hdmi_rst_n         ),
        .I_de         ( S_tracking_out_de    ),
        .I_hsync      ( S_tracking_out_hsync ),
        .I_vsync      ( S_tracking_out_vsync ),
        .I_rgb        ( S_tracking_out_data  ),
        .I_x          ( 11'd0                ),
        .I_y          ( 11'd0                ),
        .I_detected   ( sync_hdmi_detected   ),
        .I_xmin       ( sync_hdmi_xmin       ),
        .I_xmax       ( sync_hdmi_xmax       ),
        .I_ymin       ( sync_hdmi_ymin       ),
        .I_ymax       ( sync_hdmi_ymax       ),
        .I_pass       ( sync_hdmi_pass       ),
        .I_ng         ( sync_hdmi_ng         ),
        .O_de         ( S_bbox_out_de        ),
        .O_hsync      ( S_bbox_out_hsync     ),
        .O_vsync      ( S_bbox_out_vsync     ),
        .O_rgb        ( S_bbox_out_data      )
    );


    // OSD is the final pixel stage, so its timing sidebands follow the same
    // one-cycle delay as the displayed pixels.
    wire        S_osd_out_vsync;
    wire        S_osd_out_hsync;
    wire        S_osd_out_de;
    wire [23:0] S_osd_out_data;

    industrial_osd_overlay #(
        .IMG_WIDTH  ( 1280 ),
        .IMG_HEIGHT ( 720  )
    ) u_industrial_osd (
        .I_clk       ( S_hdmi_pixel_clk   ),
        .I_rst_n     ( S_hdmi_rst_n       ),
        .I_vsync     ( S_bbox_out_vsync   ),
        .I_hsync     ( S_bbox_out_hsync   ),
        .I_de        ( S_bbox_out_de      ),
        .I_rgb       ( S_bbox_out_data    ),
        .I_mode      ( S_display_mode     ),
        .I_detected  ( sync_hdmi_detected ),
        .I_pass      ( sync_hdmi_pass     ),
        .I_ng        ( sync_hdmi_ng       ),
        .I_invalid   ( sync_hdmi_invalid  ),
        .I_width     ( sync_hdmi_width    ),
        .I_height    ( sync_hdmi_height   ),
        .O_vsync     ( S_osd_out_vsync    ),
        .O_hsync     ( S_osd_out_hsync    ),
        .O_de        ( S_osd_out_de        ),
        .O_rgb       ( S_osd_out_data      )
    );

    hdmi_tx u_hdmi_tx(
        .I_pixel_clk        ( S_hdmi_pixel_clk  ),
        .I_serial_clk       ( S_hdmi_serial_clk ),
        .I_rst              ( ~S_hdmi_rst_n     ),
        .I_key_in           ( 1'b0              ),
        .I_edid_read_trig   ( 1'b0              ),
        .O_edid_read_valid  (                   ),
        .O_edid_read_data   (                   ),
        .I_video_rgb_enable ( 1'b1              ),
        .I_video_in_vs      ( S_osd_out_vsync  ),
        .I_video_in_de      ( S_osd_out_de     ),
        .I_video_in_user    ( 1'b0              ),
        .I_video_in_valid   ( 1'b0              ),
        .I_video_in_last    ( 1'b0              ),
        .O_video_in_ready   (                   ),
        .I_video_in_data    ( S_osd_out_data   ),
        .I_audio_valid      ( 1'b0              ),
        .I_audio_left_data  ( 24'd0             ),
        .I_audio_right_data ( 24'd0             ),
        .I_i2s_BCLK         ( 1'b0              ),
        .I_i2s_LRCK         ( 1'b0              ),
        .I_i2s_DOUT         ( 1'b0              ),
        .O_ddc_scl          (                   ),
        .O_hdmi_clk_p       (                   ),
        .O_hdmi_tx_p        (                   ),
        .O_tmds_ch0_p       ( O_tmds_ch0_p      ),
        .O_tmds_ch1_p       ( O_tmds_ch1_p      ),
        .O_tmds_ch2_p       ( O_tmds_ch2_p      ),
        .O_tmds_clk_p       ( O_tmds_clk_p      )
    );


endmodule
