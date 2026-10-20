// Four RGB888 pixels per accepted valid cycle, lane0 in [95:72].
// Fixed raster: width must be a multiple of four, dimensions <= 2048.
// SOF may precede data or accompany its first group. No backpressure.
// Results publish only after a complete frame; valid_frame means target present.
module color_detect_96 #(
  parameter IMG_WIDTH=1280, parameter IMG_HEIGHT=720,
  parameter [7:0] CB_MIN=8'd85, parameter [7:0] CB_MAX=8'd125,
  parameter [7:0] CR_MIN=8'd135, parameter [7:0] CR_MAX=8'd200
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
    assign hit[g]=(cb[g][17:10]>CB_MIN)&&(cb[g][17:10]<CB_MAX)&&
                  (cr[g][17:10]>CR_MIN)&&(cr[g][17:10]<CR_MAX);
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
  wire any_hit=|hit;
  wire [1:0] first_lane=hit[0]?2'd0:hit[1]?2'd1:hit[2]?2'd2:2'd3;
  wire [1:0] last_lane=hit[3]?2'd3:hit[2]?2'd2:hit[1]?2'd1:2'd0;
  wire [10:0] lo_col={q_x[10:2],first_lane};
  wire [10:0] hi_col={q_x[10:2],last_lane};
  wire [1:0] count01={1'b0,hit[0]}+{1'b0,hit[1]};
  wire [1:0] count23={1'b0,hit[2]}+{1'b0,hit[3]};
  wire [2:0] hit_count={1'b0,count01}+{1'b0,count23};
  wire frame_found=(!q_sof&&(acc_area!=0))||(q_valid&&any_hit);
  always @* begin
    next_area=acc_area;next_xmin=acc_xmin;next_ymin=acc_ymin;
    next_xmax=acc_xmax;next_ymax=acc_ymax;
    if(q_sof) begin
      next_area=q_valid?{17'd0,hit_count}:20'd0;
      next_xmin=(q_valid&&any_hit)?lo_col:IMG_WIDTH-1;
      next_ymin=(q_valid&&any_hit)?q_y:IMG_HEIGHT-1;
      next_xmax=(q_valid&&any_hit)?hi_col:11'd0;
      next_ymax=(q_valid&&any_hit)?q_y:11'd0;
    end else if(q_valid&&any_hit) begin
      next_area=acc_area+{17'd0,hit_count};
      if(lo_col<acc_xmin)next_xmin=lo_col;
      if(hi_col>acc_xmax)next_xmax=hi_col;
      if(q_y<acc_ymin)next_ymin=q_y;
      if(q_y>acc_ymax)next_ymax=q_y;
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
        area<=next_area;valid_frame<=frame_found;
        xmin<=frame_found?next_xmin:11'd0;
        ymin<=frame_found?next_ymin:11'd0;
        xmax<=frame_found?next_xmax:11'd0;
        ymax<=frame_found?next_ymax:11'd0;
      end
    end
  end
endmodule
