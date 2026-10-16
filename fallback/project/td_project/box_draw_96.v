module box_draw_96 #(
  parameter IMG_WIDTH=1280,parameter IMG_HEIGHT=720
)(
 input wire clk,rst_n,I_tvalid,I_tlast,I_tuser,
 input wire [95:0] I_tdata,
 input wire [10:0] bxmin,bymin,bxmax,bymax,
 input wire b_valid,
 output reg O_tvalid,O_tlast,O_tuser,
 output reg [95:0] O_tdata
);
 reg [10:0] x_pos,y_pos;
 reg [10:0] rxmin,rymin,rxmax,rymax;reg r_valid;
 wire [10:0] sx=I_tuser?11'd0:x_pos;
 wire [10:0] sy=I_tuser?11'd0:y_pos;
 wire [10:0] x0=I_tuser?bxmin:rxmin,y0=I_tuser?bymin:rymin;
 wire [10:0] x1=I_tuser?bxmax:rxmax,y1=I_tuser?bymax:rymax;
 wire target_valid=I_tuser?b_valid:r_valid;
 function on_border;
 input [10:0] x,y,a,b,c,d;input valid;
 begin on_border=valid&&(a<=c)&&(b<=d)&&
 (x>=a&&x<=c&&y>=b&&y<=d)&&(x==a||x==c||y==b||y==d);end
 endfunction
 integer i;
 always @(posedge clk or negedge rst_n) begin
   if(!rst_n) begin
     x_pos<=0;y_pos<=0;rxmin<=0;rymin<=0;rxmax<=0;rymax<=0;r_valid<=0;
     O_tvalid<=0;O_tlast<=0;O_tuser<=0;O_tdata<=0;
   end else begin
     O_tvalid<=I_tvalid;O_tlast<=I_tlast;O_tuser<=I_tuser;
     O_tdata<=I_tdata;
     if(I_tuser) begin
       rxmin<=bxmin;rymin<=bymin;rxmax<=bxmax;rymax<=bymax;r_valid<=b_valid;
       x_pos<=0;y_pos<=0;
     end
     if(I_tvalid) begin
       for(i=0;i<4;i=i+1)
         if(on_border(sx+i,sy,x0,y0,x1,y1,target_valid))
           O_tdata[95-i*24 -:24]<=24'hffff00;
       if(sx==IMG_WIDTH-4) begin
         x_pos<=0;y_pos<=(sy==IMG_HEIGHT-1)?11'd0:sy+11'd1;
       end else begin x_pos<=sx+11'd4;y_pos<=sy;end
     end
   end
 end
endmodule
