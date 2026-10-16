// Four RGB888 pixels per accepted valid cycle, lane0 in [95:72].
// Fixed raster: width must be a multiple of four, dimensions <= 2048.
// SOF may precede data or accompany its first group. No backpressure.
// Results publish only after a complete frame; valid_frame means target present.
module color_detect_96 #(
  parameter IMG_WIDTH=1280, parameter IMG_HEIGHT=720
)(
  input wire I_clk,I_rst_n,I_tvalid,I_tlast,I_tuser,
  input wire [95:0] I_tdata,
  output reg [10:0] xmin,ymin,xmax,ymax,
  output reg [19:0] area,
  output reg valid_frame
);
  reg started;
  reg [10:0] in_x,in_y;
  wire [10:0] sample_x=I_tuser?11'd0:in_x;
  wire [10:0] sample_y=I_tuser?11'd0:in_y;
  wire accept=I_tvalid&&(started||I_tuser);
  // I_tlast is informational; raster coordinates use the fixed valid-group count.
  reg q_valid,q_sof,q_end;
  reg [10:0] q_x,q_y;
  reg [19:0] cb[0:3],cr[0:3];
  wire [3:0] hit;
  genvar g;
  generate for(g=0;g<4;g=g+1) begin: lanes
    wire signed [8:0] r=$signed({1'b0,I_tdata[95-g*24 -: 8]});
    wire signed [8:0] green=$signed({1'b0,I_tdata[87-g*24 -: 8]});
    wire signed [8:0] b=$signed({1'b0,I_tdata[79-g*24 -: 8]});
    always @(posedge I_clk or negedge I_rst_n) begin
      if(!I_rst_n) begin cb[g]<=20'd0;cr[g]<=20'd0;end
      else if(accept) begin
        cb[g]<=20'sd512*b-20'sd173*r-20'sd339*green+20'sd131072;
        cr[g]<=20'sd512*r-20'sd429*green-20'sd83*b+20'sd131072;
      end
    end
    assign hit[g]=(cb[g][17:10]>8'd85)&&(cb[g][17:10]<8'd125)&&
                  (cr[g][17:10]>8'd135)&&(cr[g][17:10]<8'd200);
  end endgenerate
  always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
      started<=1'b0;in_x<=0;in_y<=0;
      q_valid<=0;q_sof<=0;q_end<=0;q_x<=0;q_y<=0;
    end else begin
      q_valid<=accept;q_sof<=I_tuser;
      q_end<=accept&&(sample_x==IMG_WIDTH-4)&&(sample_y==IMG_HEIGHT-1);
      q_x<=sample_x;q_y<=sample_y;
      if(I_tuser) begin started<=1'b1;in_x<=0;in_y<=0;end
      if(accept) begin
        if(sample_x==IMG_WIDTH-4) begin
          in_x<=0;
          if(sample_y==IMG_HEIGHT-1) begin in_y<=0;started<=1'b0;end
          else in_y<=sample_y+11'd1;
        end else begin in_x<=sample_x+11'd4;in_y<=sample_y;end
      end
    end
  end
  reg [19:0] acc_area,next_area;
  reg [10:0] acc_xmin,acc_ymin,acc_xmax,acc_ymax;
  reg [10:0] next_xmin,next_ymin,next_xmax,next_ymax;
  reg [10:0] col;
  integer k;
  always @* begin
    next_area=q_sof?20'd0:acc_area;
    next_xmin=q_sof?IMG_WIDTH-1:acc_xmin;
    next_ymin=q_sof?IMG_HEIGHT-1:acc_ymin;
    next_xmax=q_sof?11'd0:acc_xmax;
    next_ymax=q_sof?11'd0:acc_ymax;
    col=0;
    if(q_valid) begin
      for(k=0;k<4;k=k+1) begin
        col=q_x+k;
        if(hit[k]) begin
          next_area=next_area+20'd1;
          if(col<next_xmin)next_xmin=col;
          if(col>next_xmax)next_xmax=col;
          if(q_y<next_ymin)next_ymin=q_y;
          if(q_y>next_ymax)next_ymax=q_y;
        end
      end
    end
  end
  always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
      acc_area<=0;acc_xmin<=IMG_WIDTH-1;acc_ymin<=IMG_HEIGHT-1;
      acc_xmax<=0;acc_ymax<=0;
      area<=0;xmin<=0;ymin<=0;xmax<=0;ymax<=0;valid_frame<=0;
    end else begin
      acc_area<=next_area;acc_xmin<=next_xmin;acc_ymin<=next_ymin;
      acc_xmax<=next_xmax;acc_ymax<=next_ymax;
      if(q_end) begin
        area<=next_area;valid_frame<=(next_area!=0);
        xmin<=(next_area!=0)?next_xmin:11'd0;
        ymin<=(next_area!=0)?next_ymin:11'd0;
        xmax<=(next_area!=0)?next_xmax:11'd0;
        ymax<=(next_area!=0)?next_ymax:11'd0;
      end
    end
  end
endmodule
