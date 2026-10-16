// Results computed from raw AWB stream; drawing uses the selected display stream.
module industrial_overlay_96 #(
 parameter IMG_WIDTH=1280,parameter IMG_HEIGHT=720
)(
 input wire clk,rst_n,
 input wire raw_valid,raw_sof,raw_last,
 input wire [95:0] raw_data,
 input wire video_valid,video_sof,video_last,
 input wire [95:0] video_data,
 output wire out_valid,out_sof,out_last,
 output wire [95:0] out_data,
 output wire [10:0] xmin,ymin,xmax,ymax,
 output wire [19:0] area,
 output wire target_valid
);
 color_detect_96 #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT)) detector(
 .I_clk(clk),.I_rst_n(rst_n),.I_tvalid(raw_valid),.I_tlast(raw_last),
 .I_tuser(raw_sof),.I_tdata(raw_data),.xmin(xmin),.ymin(ymin),
 .xmax(xmax),.ymax(ymax),.area(area),.valid_frame(target_valid));
 reg [95:0] d1,d2;reg [2:0] c1,c2;
 always @(posedge clk or negedge rst_n)begin
 if(!rst_n)begin d1<=0;d2<=0;c1<=0;c2<=0;end
 else begin d1<=video_data;d2<=d1;c1<={video_valid,video_sof,video_last};c2<=c1;end
 end
 box_draw_96 #(.IMG_WIDTH(IMG_WIDTH),.IMG_HEIGHT(IMG_HEIGHT)) overlay(
 .clk(clk),.rst_n(rst_n),.I_tvalid(c2[2]),.I_tlast(c2[0]),.I_tuser(c2[1]),.I_tdata(d2),
 .bxmin(xmin),.bymin(ymin),.bxmax(xmax),.bymax(ymax),.b_valid(target_valid),
 .O_tvalid(out_valid),.O_tlast(out_last),.O_tuser(out_sof),.O_tdata(out_data));
endmodule
