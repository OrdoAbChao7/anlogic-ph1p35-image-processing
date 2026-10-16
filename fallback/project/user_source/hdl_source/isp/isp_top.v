module isp_top (
input axi4s_video_aclk,
input I_rst_n ,
input I_tlast ,
input I_tuser ,
input [39:0] I_tdata ,
input I_tvalid ,
input [9:0] I_tdest ,
input O_tready ,
output [127:0] O_tdata ,
output O_tlast ,
output O_tuser ,
output O_tvalid ,
output I_tready,
input sel_view,            // SW1：原图 <-> 纯边缘图

// ===== 新增：颜色检测结果输出(给hdmi_mixer画框) =====
output [10:0] det_xmin, det_ymin, det_xmax, det_ymax,
output [19:0] det_area,
output        det_valid
);

wire m_aixs_tvalid;
wire [127:0] m_aixs_tdata;
wire m_aixs_tuser;
wire m_aixs_tlast;
wire m_aixs_tready;

wire [ 95:0] m_aixs_tdata_96;

wire awb_O_tlast;
wire awb_O_tuser;
wire [ 95:0] awb_O_tdata;
wire awb_O_tvalid;
wire awb_O_tready;

wire edge_O_tlast;
wire edge_O_tuser;
wire [ 95:0] edge_O_tdata;
wire edge_O_tvalid;
wire edge_I_tready;

// ===== 新增：颜色检测信号 =====
wire [10:0] cd_xmin, cd_ymin, cd_xmax, cd_ymax;
wire [19:0] cd_area;
wire        cd_valid;

// Register the AWB saturation outputs before Sobel and align raw mode
// with the one-cycle Sobel branch. Control follows exactly the same registers.
reg [95:0] awb_data_d1,awb_data_d2;
reg [2:0] awb_ctrl_d1,awb_ctrl_d2;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
 if(!I_rst_n)begin awb_data_d1<=0;awb_data_d2<=0;awb_ctrl_d1<=0;awb_ctrl_d2<=0;end
 else begin
  awb_data_d1<=awb_O_tdata;awb_data_d2<=awb_data_d1;
  awb_ctrl_d1<={awb_O_tvalid,awb_O_tuser,awb_O_tlast};awb_ctrl_d2<=awb_ctrl_d1;
 end
end

//========乒乓开关同步 + 帧锁存========
reg [1:0] sel_sync;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
if(!I_rst_n) begin
    sel_sync <= 2'b00;
end else begin
    sel_sync <= {sel_sync[0], sel_view};
end
end
wire sel_sync_out = sel_sync[1];

reg sel_frame;
always @(posedge axi4s_video_aclk or negedge I_rst_n) begin
if(!I_rst_n) begin
    sel_frame <= 1'b0;
end else if(awb_ctrl_d1[1]) begin
    sel_frame <= sel_sync_out;
end
end

//========AXI4S MUX(原图 / 边缘)========
wire mux_O_tlast;
wire mux_O_tuser;
wire [95:0] mux_O_tdata;
wire mux_O_tvalid;
wire mux_O_tready;

assign mux_O_tlast  = sel_frame ? edge_O_tlast  : awb_ctrl_d2[0];
assign mux_O_tuser  = sel_frame ? edge_O_tuser  : awb_ctrl_d2[1];
assign mux_O_tdata  = sel_frame ? edge_O_tdata  : awb_data_d2;
assign mux_O_tvalid = sel_frame ? edge_O_tvalid : awb_ctrl_d2[2];
assign mux_O_tready = O_tready;

// ★修复：edge 常开，避免切回原图时流水线堵死、画面冻结
assign edge_I_tready = mux_O_tready;

wire awb_O_tuser_128;
wire awb_O_tvalid_128;
wire [127:0] awb_O_tdata_128;

assign O_tdata  = awb_O_tdata_128;
// O_tlast is generated from the packed 128-bit output word count.
assign O_tuser  = awb_O_tuser_128 ;
assign O_tvalid = awb_O_tvalid_128 ;


demosaic #(
.IMG_HEIGHT (720),
.IMG_WIDTH (1280),
.data_complete_delay (50 ),
.BAYER_MODE ("BGGR")
)
u_demosaic
(
.I_clk (axi4s_video_aclk) ,
.I_rst_n (I_rst_n) ,
.axi4s_video_tdata (I_tdata) ,
.axi4s_video_tdest (I_tdest) ,
.axi4s_video_tlast (I_tlast) ,
.axi4s_video_tvalid (I_tvalid) ,
.axi4s_video_tuser (I_tuser) ,
.axi4s_video_tready (I_tready) ,
.O_tlast (m_aixs_tlast) ,
.O_tuser (m_aixs_tuser) ,
.O_tdata (m_aixs_tdata) ,
.O_tvalid (m_aixs_tvalid) ,
.O_tready (m_aixs_tready)
);

data128_96 u_data128_96 (
.I_tdata(m_aixs_tdata),
.O_tdata(m_aixs_tdata_96)
);

awb #(
.IMG_HEIGHT(720),
.IMG_WIDTH (1280)
) u_awb (
.I_clk (axi4s_video_aclk),
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

edge_detect_96 #(
.IMG_WIDTH (1280),
.IMG_HEIGHT(720),
.EDGE_TH (11'd80)
) u_edge_detect_96 (
.I_clk (axi4s_video_aclk),
.I_rst_n (I_rst_n),
.I_tlast (awb_ctrl_d1[0]),
.I_tuser (awb_ctrl_d1[1]),
.I_tdata (awb_data_d1),
.I_tvalid(awb_ctrl_d1[2]),
.I_tready(edge_I_tready),
.O_tlast (edge_O_tlast),
.O_tuser (edge_O_tuser),
.O_tdata (edge_O_tdata),
.O_tvalid(edge_O_tvalid)
);

wire [95:0] box_O_tdata;
wire box_O_tlast,box_O_tuser,box_O_tvalid;
industrial_overlay_96 #(.IMG_WIDTH(1280),.IMG_HEIGHT(720)) u_industrial_overlay(
 .clk(axi4s_video_aclk),.rst_n(I_rst_n),
 .raw_valid(awb_ctrl_d1[2]),.raw_sof(awb_ctrl_d1[1]),.raw_last(awb_ctrl_d1[0]),.raw_data(awb_data_d1),
 .video_valid(mux_O_tvalid),.video_sof(mux_O_tuser),.video_last(mux_O_tlast),.video_data(mux_O_tdata),
 .out_valid(box_O_tvalid),.out_sof(box_O_tuser),.out_last(box_O_tlast),.out_data(box_O_tdata),
 .xmin(cd_xmin),.ymin(cd_ymin),.xmax(cd_xmax),.ymax(cd_ymax),.area(cd_area),.target_valid(cd_valid));
assign det_xmin=cd_xmin;assign det_ymin=cd_ymin;assign det_xmax=cd_xmax;assign det_ymax=cd_ymax;
assign det_area=cd_area;assign det_valid=cd_valid;

data_96bit_to_128bit u_data_96bit_to_128bit(
.I_clk ( axi4s_video_aclk ),
.I_rst_n ( I_rst_n ),

.I_96b_frame_start ( box_O_tuser ),
.I_96b_valid ( box_O_tvalid ),
.I_96b_data ( box_O_tdata ),

.O_128b_frame_start ( awb_O_tuser_128 ),
.O_128b_valid ( awb_O_tvalid_128 ),
.O_128b_data ( awb_O_tdata_128 ),
.O_128b_line_end ( O_tlast )
);

endmodule
