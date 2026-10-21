module color_detect_96 #(
  parameter IMG_WIDTH  = 1280,
  parameter IMG_HEIGHT = 720
)(
  input  wire I_clk, I_rst_n,
  input  wire I_tvalid, I_tlast, I_tuser,
  input  wire [95:0] I_tdata,               // 4像素×24bit RGB
  output reg  [10:0] xmin,ymin,xmax,ymax,   // 包围盒
  output reg  [18:0] area,                  // 目标像素数
  output reg         valid_frame            // 每帧结果有效
);
  localparam GRP = IMG_WIDTH >> 2;          // 每行拍数=320
  reg [10:0] x_grp, y_pos;

  // ---- 拆4像素 RGB ----
  wire [7:0] R0=I_tdata[95:88],G0=I_tdata[87:80],B0=I_tdata[79:72];
  wire [7:0] R1=I_tdata[71:64],G1=I_tdata[63:56],B1=I_tdata[55:48];
  wire [7:0] R2=I_tdata[47:40],G2=I_tdata[39:32],B2=I_tdata[31:24];
  wire [7:0] R3=I_tdata[23:16],G3=I_tdata[15:8], B3=I_tdata[7:0];

  // ---- RGB→YCbCr (Q10定点, 系数×1024, 输出>>10得0~255) ----
  wire signed [17:0] cb0 = 512*$signed(B0)-173*$signed(R0)-339*$signed(G0)+128*1024;
  wire signed [17:0] cr0 = 512*$signed(R0)-429*$signed(G0)- 83*$signed(B0)+128*1024;
  wire signed [17:0] cb1 = 512*$signed(B1)-173*$signed(R1)-339*$signed(G1)+128*1024;
  wire signed [17:0] cr1 = 512*$signed(R1)-429*$signed(G1)- 83*$signed(B1)+128*1024;
  wire signed [17:0] cb2 = 512*$signed(B2)-173*$signed(R2)-339*$signed(G2)+128*1024;
  wire signed [17:0] cr2 = 512*$signed(R2)-429*$signed(G2)- 83*$signed(B2)+128*1024;
  wire signed [17:0] cb3 = 512*$signed(B3)-173*$signed(R3)-339*$signed(G3)+128*1024;
  wire signed [17:0] cr3 = 512*$signed(R3)-429*$signed(G3)- 83*$signed(B3)+128*1024;

  // ---- 红色阈值判定(4个像素都要) ----
  wire t0 = (cb0[17:10]>85 && cb0[17:10]<125) && (cr0[17:10]>135 && cr0[17:10]<200);
  wire t1 = (cb1[17:10]>85 && cb1[17:10]<125) && (cr1[17:10]>135 && cr1[17:10]<200);
  wire t2 = (cb2[17:10]>85 && cb2[17:10]<125) && (cr2[17:10]>135 && cr2[17:10]<200);
  wire t3 = (cb3[17:10]>85 && cb3[17:10]<125) && (cr3[17:10]>135 && cr3[17:10]<200);

  // ---- 4像素各自的全局列号 ----
  wire [11:0] col0 = {x_grp,2'b00};
  wire [11:0] col1 = {x_grp,2'b00}+1;
  wire [11:0] col2 = {x_grp,2'b00}+2;
  wire [11:0] col3 = {x_grp,2'b00}+3;

  // ---- 统计 + 行列计数 ----
  always @(posedge I_clk or negedge I_rst_n) begin
    if(!I_rst_n) begin
      xmin<=IMG_WIDTH-1; ymin<=IMG_HEIGHT-1; xmax<=0; ymax<=0;
      area<=0; valid_frame<=0; x_grp<=0; y_pos<=0;
    end else if(I_tuser) begin
      // 帧头：上一帧结果锁存输出，本帧清零重统计
      valid_frame<=1'b1;
      xmin<=IMG_WIDTH-1; ymin<=IMG_HEIGHT-1; xmax<=0; ymax<=0; area<=0;
      x_grp<=0; y_pos<=0;
    end else if(I_tvalid) begin
      // 统计4个像素：统一计算4像素增量与本周期边界，避免非阻塞赋值覆盖
      area <= area + (t0 ? 1'b1 : 1'b0) + (t1 ? 1'b1 : 1'b0) + (t2 ? 1'b1 : 1'b0) + (t3 ? 1'b1 : 1'b0);
      
      // 更新 X 边界
      if (t0 && col0 < xmin) xmin <= col0;
      else if (t1 && col1 < xmin) xmin <= col1;
      else if (t2 && col2 < xmin) xmin <= col2;
      else if (t3 && col3 < xmin) xmin <= col3;

      if (t3 && col3 > xmax) xmax <= col3;
      else if (t2 && col2 > xmax) xmax <= col2;
      else if (t1 && col1 > xmax) xmax <= col1;
      else if (t0 && col0 > xmax) xmax <= col0;

      // 更新 Y 边界
      if ((t0 || t1 || t2 || t3)) begin
        if (y_pos < ymin) ymin <= y_pos;
        if (y_pos > ymax) ymax <= y_pos;
      end

      // 行列计数
      if(x_grp==GRP-1) begin
        x_grp<=0;
        if(y_pos==IMG_HEIGHT-1) y_pos<=0; else y_pos<=y_pos+1;
      end else x_grp<=x_grp+1;
    end
  end
endmodule
