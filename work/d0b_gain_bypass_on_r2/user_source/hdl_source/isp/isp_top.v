module isp_top (
    input 			axi4s_video_aclk,
    input 			I_rst_n			,
    input 			I_tlast			,
    input 			I_tuser			,
    input [39:0] 	I_tdata			,
    input 			I_tvalid		,
    input [9:0] 	I_tdest			,
    input 			O_tready		,
    input [15:0] I_awb_gain_r_q8_8,
    input [15:0] I_awb_gain_g_q8_8,
    input [15:0] I_awb_gain_b_q8_8,
    output [127:0] 	O_tdata			,
    output 			O_tlast			,
    output 			O_tuser			,
    output 			O_tvalid		,
    output 			I_tready		,

    // Industrial Inspection Subsystem Outputs
    output wire [10:0]  O_ind_xmin,
    output wire [10:0]  O_ind_xmax,
    output wire [10:0]  O_ind_ymin,
    output wire [10:0]  O_ind_ymax,
    output wire [10:0]  O_ind_width,
    output wire [10:0]  O_ind_height,
    output wire         O_ind_detected,
    output wire         O_ind_pass,
    output wire         O_ind_ng,
    output wire         O_ind_no_obj,
    output wire         O_ind_invalid,
    output wire         O_led_pass,
    output wire         O_led_ng,
    output wire         O_led_det,
    output wire         O_ind_result_toggle,
    output wire [19:0]  O_ind_area,
    // Post-AWB four-pixel stream exposed for source-domain V2 feature taps.
    // The formal wrapper consumes this bus for motion sampling and frame
    // statistics; it is the same stream used by the detector below.
    output wire [95:0]  O_ind_awb_tdata,
    output wire         O_ind_awb_tlast,
    output wire         O_ind_awb_tuser,
    output wire         O_ind_awb_tvalid
);

// Frozen v1 inspection ROI. Coordinates are half-open [x0,x1) x [y0,y1).
// Until the camera/fixture is available for calibration, the approved
// contract uses the complete 1280x720 raster as a fixed ROI. Keep the named
// endpoints at the integration boundary so later calibration cannot silently
// change detector semantics or OSD coordinates.
localparam integer INDUSTRIAL_ROI_X0 = 0;
localparam integer INDUSTRIAL_ROI_Y0 = 0;
localparam integer INDUSTRIAL_ROI_X1 = 1280;
localparam integer INDUSTRIAL_ROI_Y1 = 720;
localparam integer INDUSTRIAL_ROI_X      = INDUSTRIAL_ROI_X0;
localparam integer INDUSTRIAL_ROI_Y      = INDUSTRIAL_ROI_Y0;
localparam integer INDUSTRIAL_ROI_WIDTH  = INDUSTRIAL_ROI_X1 - INDUSTRIAL_ROI_X0;
localparam integer INDUSTRIAL_ROI_HEIGHT = INDUSTRIAL_ROI_Y1 - INDUSTRIAL_ROI_Y0;

wire         m_aixs_tvalid;  //synthesis keep
  wire [127:0] m_aixs_tdata;  //synthesis keep
  wire         m_aixs_tuser;  //synthesis keep
  wire         m_aixs_tlast;  //synthesis keep
  wire         m_aixs_tready;  //synthesis keep

  wire [ 95:0] m_aixs_tdata_96;  //synthesis keep


  wire         awb_O_tlast;  //synthesis keep
  wire         awb_O_tuser;  //synthesis keep
  wire [ 95:0] awb_O_tdata;  //synthesis keep
  wire         awb_O_tvalid;  //synthesis keep
  wire         awb_O_tready;  //synthesis keep
  wire         awb_gain_O_tready;
  wire [95:0]  awb_gain_O_tdata;
  wire         awb_gain_O_tlast;
  wire         awb_gain_O_tuser;
  wire         awb_gain_O_tvalid;

  wire         awb_O_tuser_128;  //synthesis keep
  wire         awb_O_tvalid_128;  //synthesis keep
  wire [127:0] awb_O_tdata_128;  //synthesis keep

  // D0b: awb_O_tready is driven directly by O_tready (see bypass block).
  assign O_tdata  = awb_O_tdata_128;
  assign O_tlast  = awb_O_tlast    ;
  assign O_tuser  = awb_O_tuser_128    ;
  assign O_tvalid = awb_O_tvalid_128   ;

  //assign m_aixs_tready = O_tready;
  //assign O_tdata  = m_aixs_tdata;
  //assign O_tlast  = m_aixs_tlast    ;
  //assign O_tuser  = m_aixs_tuser    ;
  //assign O_tvalid = m_aixs_tvalid   ;


demosaic #(
    .IMG_HEIGHT          (720 ),  // 图像高度
    .IMG_WIDTH           (1280),  // 图像宽度
    .data_complete_delay (50  ),
    .BAYER_MODE          ("BGGR")
)
u_demosaic
(
    .I_clk   			(axi4s_video_aclk)	,   // 时钟信号
    .I_rst_n 			(I_rst_n)	,   // 复位信号，低有效
    .axi4s_video_tdata 	(I_tdata)	,  // AXI4-Stream视频数据
    .axi4s_video_tdest 	(I_tdest)	,
    .axi4s_video_tlast 	(I_tlast)	,  // 行结束信号
    .axi4s_video_tvalid	(I_tvalid)	,  // 数据有效信号
    .axi4s_video_tuser 	(I_tuser)	,  // 帧开始信号
    .axi4s_video_tready	(I_tready)	,  // 从模块准备好接受数据
    .O_tlast  			(m_aixs_tlast)	,  // 输出行结束信号
    .O_tuser  			(m_aixs_tuser)	,  // 输出帧开始信号
    .O_tdata  			(m_aixs_tdata)	,  // 输出数据
    .O_tvalid 			(m_aixs_tvalid)	,  // 输出数据有效信号
    .O_tready   		(m_aixs_tready)	   // 输出数据准备好信号
);

data128_96 u_data128_96 (
    .I_tdata(m_aixs_tdata),
    .O_tdata(m_aixs_tdata_96)
);

awb #(
    .IMG_HEIGHT(720 ),
    .IMG_WIDTH (1280)
) u_awb (
    .I_clk   (axi4s_video_aclk),
    .I_rst_n (I_rst_n),
    .I_tlast (m_aixs_tlast),
    .I_tuser (m_aixs_tuser),
    .I_tdata (m_aixs_tdata_96),
    .I_tvalid(m_aixs_tvalid),
    .I_tready(m_aixs_tready),
    .O_tlast (awb_O_tlast ),
    .O_tuser (awb_O_tuser ),
    .O_tdata (awb_O_tdata ),
    .O_tvalid(awb_O_tvalid),
    .O_tready(awb_O_tready)
);

// Apply the frame-controller's Q8.8 correction to the vendor AWB stream.
// The gain is captured at accepted frame start, so every pixel in one frame
// uses the same three gains without adding latency or changing sideband timing.
// D0b isolation build (on the timing-clean R2 tree): bypass the AWB gain
// stage that V2 inserted between the vendor AWB block and the 96->128 gearbox.
// This restores exactly the V1 video datapath (awb -> data_96bit_to_128bit)
// while leaving every other module, connection and constraint untouched.
  assign awb_O_tready      = O_tready;
  assign awb_gain_O_tdata  = awb_O_tdata;
  assign awb_gain_O_tlast  = awb_O_tlast;
  assign awb_gain_O_tuser  = awb_O_tuser;
  assign awb_gain_O_tvalid = awb_O_tvalid;

    data_96bit_to_128bit u_data_96bit_to_128bit(
        .I_clk              ( axi4s_video_aclk  ),
        .I_rst_n            ( I_rst_n           ),

        .I_96b_frame_start  ( awb_gain_O_tuser  ),
        .I_96b_valid        ( awb_gain_O_tvalid ),
        .I_96b_data         ( awb_gain_O_tdata  ),

        .O_128b_frame_start ( awb_O_tuser_128  	),
        .O_128b_valid       ( awb_O_tvalid_128 	),
        .O_128b_data        ( awb_O_tdata_128  	)
    );



    // =========================================================================
    // Industrial Inspection Subsystem: Color Detection & Defect Classification
    // =========================================================================
    wire [10:0] ind_xmin, ind_xmax, ind_ymin, ind_ymax, ind_cx, ind_cy;
    wire [19:0] ind_area;
    wire        ind_detected;
    wire        ind_invalid;
    wire        ind_frame_sync;

    color_detect_96_v2 #(
        .IMG_WIDTH  (1280),
        .IMG_HEIGHT (720),
        .CB_MIN     (85),
        .CB_MAX     (125),
        .CR_MIN     (135),
        .CR_MAX     (200),
        .MIN_AREA   (100),
        .ROI_X      (INDUSTRIAL_ROI_X),
        .ROI_Y      (INDUSTRIAL_ROI_Y),
        .ROI_WIDTH  (INDUSTRIAL_ROI_WIDTH),
        .ROI_HEIGHT (INDUSTRIAL_ROI_HEIGHT)
    ) u_color_detect_96_v2 (
        .I_clk        (axi4s_video_aclk),
        .I_rst_n      (I_rst_n),
        .I_tvalid     (awb_gain_O_tvalid),
        .I_tlast      (awb_gain_O_tlast),
        .I_tuser      (awb_gain_O_tuser),
        .I_tdata      (awb_gain_O_tdata),
        .O_xmin       (ind_xmin),
        .O_xmax       (ind_xmax),
        .O_ymin       (ind_ymin),
        .O_ymax       (ind_ymax),
        .O_cx         (ind_cx),
        .O_cy         (ind_cy),
        .O_area       (ind_area),
        .O_detected   (ind_detected),
        .O_invalid    (ind_invalid),
        .O_frame_sync (ind_frame_sync)
    );

    wire [10:0] ind_meas_w, ind_meas_h;
    wire        ind_pass, ind_ng, ind_no_obj;
    wire        ind_led_pass, ind_led_ng, ind_led_det, ind_classifier_invalid;
    wire        ind_result_toggle;

    defect_classifier #(
        .NOMINAL_WIDTH  (120),
        .WIDTH_TOL      (15),
        .NOMINAL_HEIGHT (80),
        .HEIGHT_TOL     (12)
    ) u_defect_classifier (
        .I_clk        (axi4s_video_aclk),
        .I_rst_n      (I_rst_n),
        .I_frame_sync (ind_frame_sync),
        .I_detected   (ind_detected),
        .I_invalid    (ind_invalid),
        .I_xmin       (ind_xmin),
        .I_xmax       (ind_xmax),
        .I_ymin       (ind_ymin),
        .I_ymax       (ind_ymax),
        .I_area       (ind_area),
        .O_width      (ind_meas_w),
        .O_height     (ind_meas_h),
        .O_pass       (ind_pass),
        .O_ng         (ind_ng),
        .O_no_obj     (ind_no_obj),
        .O_invalid    (ind_classifier_invalid),
        .O_led_pass   (ind_led_pass),
        .O_led_ng     (ind_led_ng),
        .O_led_det    (ind_led_det),
        .O_result_toggle(ind_result_toggle)
    );

    assign O_ind_xmin     = ind_xmin;
    assign O_ind_xmax     = ind_xmax;
    assign O_ind_ymin     = ind_ymin;
    assign O_ind_ymax     = ind_ymax;
    assign O_ind_width    = ind_meas_w;
    assign O_ind_height   = ind_meas_h;
    assign O_ind_detected = ind_detected;
    assign O_ind_pass     = ind_pass;
    assign O_ind_ng       = ind_ng;
    assign O_ind_no_obj   = ind_no_obj;
    assign O_ind_invalid  = ind_classifier_invalid;
    assign O_led_pass     = ind_led_pass;
    assign O_led_ng       = ind_led_ng;
    assign O_led_det      = ind_led_det;
    assign O_ind_result_toggle = ind_result_toggle;
    assign O_ind_area     = ind_area;
    assign O_ind_awb_tdata  = awb_gain_O_tdata;
    assign O_ind_awb_tlast  = awb_gain_O_tlast;
    assign O_ind_awb_tuser  = awb_gain_O_tuser;
    assign O_ind_awb_tvalid = awb_gain_O_tvalid;

endmodule

// Four-pixel RGB888 Q8.8 gain stage. Gains are snapshotted on an accepted SOF;
// if the controller updates on that same edge, the frame uses the pre-edge
// gains and the update first applies at the next accepted SOF strictly after
// the update. This is deterministic and requires no minimum frame gap. The
// elastic pipeline preserves AXI backpressure and keeps sidebands aligned.
module axis_gain_rgb96 (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire [95:0] I_tdata,
    input  wire        I_tlast,
    input  wire        I_tuser,
    input  wire        I_tvalid,
    input  wire        I_tready,
    input  wire [9:0]  I_gain_r_q8_8,
    input  wire [9:0]  I_gain_g_q8_8,
    input  wire [9:0]  I_gain_b_q8_8,
    output wire        O_tready,
    output wire [95:0] O_tdata,
    output wire        O_tlast,
    output wire        O_tuser,
    output wire        O_tvalid
);
    reg [9:0] active_gain_r_q8_8;
    reg [9:0] active_gain_g_q8_8;
    reg [9:0] active_gain_b_q8_8;
    reg [95:0] raw_tdata;
    reg        raw_tlast;
    reg        raw_tuser;
    reg        raw_tvalid;
    reg [9:0]  raw_gain_r_q8_8;
    reg [9:0]  raw_gain_g_q8_8;
    reg [9:0]  raw_gain_b_q8_8;
    reg [17:0] product_r0;
    reg [17:0] product_g0;
    reg [17:0] product_b0;
    reg [17:0] product_r1;
    reg [17:0] product_g1;
    reg [17:0] product_b1;
    reg [17:0] product_r2;
    reg [17:0] product_g2;
    reg [17:0] product_b2;
    reg [17:0] product_r3;
    reg [17:0] product_g3;
    reg [17:0] product_b3;
    reg        product_tlast;
    reg        product_tuser;
    reg        product_tvalid;

    wire product_ready = !product_tvalid || I_tready;
    wire raw_ready = !raw_tvalid || product_ready;
    wire input_transfer = I_tvalid && raw_ready;
    wire raw_transfer = raw_tvalid && product_ready;

    function [17:0] multiply_channel;
        input [7:0] pixel;
        input [9:0] gain_q8_8;
        begin
            multiply_channel = {10'd0, pixel} * {8'd0, gain_q8_8};
        end
    endfunction

    function [7:0] scale_product;
        input [17:0] product;
        reg [18:0] rounded_q8;
        begin
            rounded_q8 = {1'b0, product} + 19'd128;
            rounded_q8 = rounded_q8 >> 8;
            scale_product = (|rounded_q8[18:8]) ? 8'hff : rounded_q8[7:0];
        end
    endfunction

    assign O_tready = raw_ready;
    assign O_tvalid = product_tvalid;
    assign O_tlast = product_tlast;
    assign O_tuser = product_tuser;
    assign O_tdata = {
        scale_product(product_r0), scale_product(product_g0), scale_product(product_b0),
        scale_product(product_r1), scale_product(product_g1), scale_product(product_b1),
        scale_product(product_r2), scale_product(product_g2), scale_product(product_b2),
        scale_product(product_r3), scale_product(product_g3), scale_product(product_b3)
    };

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            active_gain_r_q8_8 <= 10'd256;
            active_gain_g_q8_8 <= 10'd256;
            active_gain_b_q8_8 <= 10'd256;
            raw_tdata <= 96'd0;
            raw_tlast <= 1'b0;
            raw_tuser <= 1'b0;
            raw_tvalid <= 1'b0;
            raw_gain_r_q8_8 <= 10'd256;
            raw_gain_g_q8_8 <= 10'd256;
            raw_gain_b_q8_8 <= 10'd256;
            product_r0 <= 18'd0;
            product_g0 <= 18'd0;
            product_b0 <= 18'd0;
            product_r1 <= 18'd0;
            product_g1 <= 18'd0;
            product_b1 <= 18'd0;
            product_r2 <= 18'd0;
            product_g2 <= 18'd0;
            product_b2 <= 18'd0;
            product_r3 <= 18'd0;
            product_g3 <= 18'd0;
            product_b3 <= 18'd0;
            product_tlast <= 1'b0;
            product_tuser <= 1'b0;
            product_tvalid <= 1'b0;
        end else begin
            if (raw_ready) begin
                raw_tvalid <= I_tvalid;
                if (input_transfer) begin
                    raw_tdata <= I_tdata;
                    raw_tlast <= I_tlast;
                    raw_tuser <= I_tuser;
                    if (I_tuser) begin
                        active_gain_r_q8_8 <= I_gain_r_q8_8;
                        active_gain_g_q8_8 <= I_gain_g_q8_8;
                        active_gain_b_q8_8 <= I_gain_b_q8_8;
                        raw_gain_r_q8_8 <= I_gain_r_q8_8;
                        raw_gain_g_q8_8 <= I_gain_g_q8_8;
                        raw_gain_b_q8_8 <= I_gain_b_q8_8;
                    end else begin
                        raw_gain_r_q8_8 <= active_gain_r_q8_8;
                        raw_gain_g_q8_8 <= active_gain_g_q8_8;
                        raw_gain_b_q8_8 <= active_gain_b_q8_8;
                    end
                end
            end
            if (product_ready) begin
                product_tvalid <= raw_tvalid;
                if (raw_transfer) begin
                    product_r0 <= multiply_channel(raw_tdata[95:88], raw_gain_r_q8_8);
                    product_g0 <= multiply_channel(raw_tdata[87:80], raw_gain_g_q8_8);
                    product_b0 <= multiply_channel(raw_tdata[79:72], raw_gain_b_q8_8);
                    product_r1 <= multiply_channel(raw_tdata[71:64], raw_gain_r_q8_8);
                    product_g1 <= multiply_channel(raw_tdata[63:56], raw_gain_g_q8_8);
                    product_b1 <= multiply_channel(raw_tdata[55:48], raw_gain_b_q8_8);
                    product_r2 <= multiply_channel(raw_tdata[47:40], raw_gain_r_q8_8);
                    product_g2 <= multiply_channel(raw_tdata[39:32], raw_gain_g_q8_8);
                    product_b2 <= multiply_channel(raw_tdata[31:24], raw_gain_b_q8_8);
                    product_r3 <= multiply_channel(raw_tdata[23:16], raw_gain_r_q8_8);
                    product_g3 <= multiply_channel(raw_tdata[15:8], raw_gain_g_q8_8);
                    product_b3 <= multiply_channel(raw_tdata[7:0], raw_gain_b_q8_8);
                    product_tlast <= raw_tlast;
                    product_tuser <= raw_tuser;
                end
            end
        end
    end
endmodule


// Four-pixel RGB888 gamma stage.  The 16-segment curve approximates
// y = 255 * (x / 255)^0.7.  It lifts shadows and mid-tones while preserving
// black and white and adds one registered pipeline cycle.
module axis_gamma_rgb96 (
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_tlast,
    input  wire        I_tuser,
    input  wire [95:0] I_tdata,
    input  wire        I_tvalid,
    output reg         O_tlast,
    output reg         O_tuser,
    output reg  [95:0] O_tdata,
    output reg         O_tvalid
);

    function [7:0] gamma07;
        input [7:0] value;
        reg [7:0] base;
        reg [7:0] delta;
        reg [11:0] interpolation;
        begin
            case (value[7:4])
                4'h0: begin base = 8'd0;   delta = 8'd37; end
                4'h1: begin base = 8'd37;  delta = 8'd23; end
                4'h2: begin base = 8'd60;  delta = 8'd19; end
                4'h3: begin base = 8'd79;  delta = 8'd18; end
                4'h4: begin base = 8'd97;  delta = 8'd16; end
                4'h5: begin base = 8'd113; delta = 8'd16; end
                4'h6: begin base = 8'd129; delta = 8'd14; end
                4'h7: begin base = 8'd143; delta = 8'd14; end
                4'h8: begin base = 8'd157; delta = 8'd14; end
                4'h9: begin base = 8'd171; delta = 8'd13; end
                4'ha: begin base = 8'd184; delta = 8'd13; end
                4'hb: begin base = 8'd197; delta = 8'd12; end
                4'hc: begin base = 8'd209; delta = 8'd12; end
                4'hd: begin base = 8'd221; delta = 8'd12; end
                4'he: begin base = 8'd233; delta = 8'd11; end
                default: begin base = 8'd244; delta = 8'd11; end
            endcase

            interpolation = delta * value[3:0] + 8;
            if (value == 8'hff)
                gamma07 = 8'hff;
            else
                gamma07 = base + (interpolation >> 4);
        end
    endfunction

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            O_tlast  <= 1'b0;
            O_tuser  <= 1'b0;
            O_tdata  <= 96'd0;
            O_tvalid <= 1'b0;
        end else begin
            O_tlast  <= I_tlast;
            O_tuser  <= I_tuser;
            O_tvalid <= I_tvalid;
            if (I_tvalid) begin
                O_tdata <= {
                    gamma07(I_tdata[95:88]), gamma07(I_tdata[87:80]), gamma07(I_tdata[79:72]),
                    gamma07(I_tdata[71:64]), gamma07(I_tdata[63:56]), gamma07(I_tdata[55:48]),
                    gamma07(I_tdata[47:40]), gamma07(I_tdata[39:32]), gamma07(I_tdata[31:24]),
                    gamma07(I_tdata[23:16]), gamma07(I_tdata[15:8]),  gamma07(I_tdata[7:0])
                };
            end else begin
                O_tdata <= 96'd0;
            end
        end
    end

endmodule


// Centre crop for the ISP's four-pixel-wide RGB888 stream.  Frame start is
// intentionally forwarded at the original frame boundary so video_in can
// reset its asynchronous FIFO before the first selected row arrives.
module axis_crop_rgb96 #(
    parameter integer IN_WIDTH   = 1792,
    parameter integer IN_HEIGHT  = 1080,
    parameter integer OUT_WIDTH  = 1600,
    parameter integer OUT_HEIGHT = 900,
    parameter integer X_START    = 96,
    parameter integer Y_START    = 90
)(
    input  wire        I_clk,
    input  wire        I_rst_n,
    input  wire        I_tlast,
    input  wire        I_tuser,
    input  wire [95:0] I_tdata,
    input  wire        I_tvalid,
    output wire        O_tlast,
    output wire        O_tuser,
    output wire [95:0] O_tdata,
    output wire        O_tvalid
);

    localparam integer X_START_BEAT = X_START / 4;
    localparam integer OUT_BEATS    = OUT_WIDTH / 4;
    localparam integer X_END_BEAT   = X_START_BEAT + OUT_BEATS;

    reg [9:0]  S_hcnt;
    reg [10:0] S_vcnt;

    wire [9:0]  S_current_h = I_tuser ? 10'd0 : S_hcnt;
    wire [10:0] S_current_v = I_tuser ? 11'd0 : S_vcnt;
    wire S_inside = (S_current_h >= X_START_BEAT) &&
                    (S_current_h < X_END_BEAT) &&
                    (S_current_v >= Y_START) &&
                    (S_current_v < (Y_START + OUT_HEIGHT));

    assign O_tdata  = I_tdata;
    assign O_tvalid = I_tvalid && S_inside;
    assign O_tlast  = O_tvalid && (S_current_h == (X_END_BEAT - 1));
    assign O_tuser  = I_tuser;

    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            S_hcnt <= 10'd0;
            S_vcnt <= 11'd0;
        end
        else if(I_tuser) begin
            S_hcnt <= (I_tvalid && !I_tlast) ? 10'd1 : 10'd0;
            S_vcnt <= (I_tvalid && I_tlast) ? 11'd1 : 11'd0;
        end
        else if(I_tvalid) begin
            if(I_tlast) begin
                S_hcnt <= 10'd0;
                S_vcnt <= (S_vcnt == IN_HEIGHT - 1) ? 11'd0 : S_vcnt + 1'b1;
            end
            else begin
                S_hcnt <= S_hcnt + 1'b1;
            end
        end
    end

endmodule
