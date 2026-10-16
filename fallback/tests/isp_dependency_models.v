// Test-only ISP upstream dependencies. These exercise routing/control;
// real AWB tags are checked separately with its RAM dependency model.
module demosaic #(parameter IMG_HEIGHT=720,IMG_WIDTH=1280,data_complete_delay=50,BAYER_MODE="BGGR")(
 input I_clk,I_rst_n,input [39:0] axi4s_video_tdata,input [9:0] axi4s_video_tdest,
 input axi4s_video_tlast,axi4s_video_tvalid,axi4s_video_tuser,
 output axi4s_video_tready,output reg O_tlast,O_tuser,O_tvalid,output reg [127:0] O_tdata,input O_tready);
assign axi4s_video_tready=O_tready;
always @(posedge I_clk or negedge I_rst_n)if(!I_rst_n)begin O_tlast<=0;O_tuser<=0;O_tvalid<=0;O_tdata<=0;end
else begin O_tlast<=axi4s_video_tlast;O_tuser<=axi4s_video_tuser;O_tvalid<=axi4s_video_tvalid;O_tdata<={4{{8'd0,axi4s_video_tdata[23:0]}}};end
endmodule
module awb #(parameter IMG_HEIGHT=720,IMG_WIDTH=1280)(
 input I_clk,I_rst_n,I_tlast,I_tuser,input [95:0] I_tdata,input I_tvalid,output I_tready,
 output reg O_tlast,O_tuser,output reg [95:0] O_tdata,output reg O_tvalid,input O_tready);
assign I_tready=O_tready;
always @(posedge I_clk or negedge I_rst_n)if(!I_rst_n)begin O_tlast<=0;O_tuser<=0;O_tvalid<=0;O_tdata<=0;end
else begin O_tlast<=I_tlast;O_tuser<=I_tuser;O_tvalid<=I_tvalid;O_tdata<=I_tdata;end
endmodule
