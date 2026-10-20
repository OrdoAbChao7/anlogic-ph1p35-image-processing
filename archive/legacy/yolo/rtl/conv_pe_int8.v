// INT8 MAC Processing Element (PE) for Micro-CNN / YOLO Acceleration on Anlogic PH1P35
// Features:
// - Pipelined 8-bit signed multiplication & 32-bit accumulation
// - Saturating ReLU activation
// - Requantization scaling with programmable shift
// - Synthesis-friendly for Anlogic DSP blocks

module conv_pe_int8 #(
  parameter DATA_WIDTH = 8,
  parameter ACC_WIDTH  = 32
)(
  input  wire                   clk,
  input  wire                   rst_n,
  input  wire                   clr_acc,     // 清除累加器(新卷积步起始)
  input  wire                   valid_in,    // 输入乘加有效
  input  wire signed [DATA_WIDTH-1:0] act_in,      // 激活值输入 (INT8)
  input  wire signed [DATA_WIDTH-1:0] w_in,        // 权重输入 (INT8)
  input  wire signed [ACC_WIDTH-1:0]  bias_in,     // 偏置值输入 (INT32)
  input  wire [3:0]             shift_val,   // 量化右移位数
  output reg                    valid_out,   // 结果输出有效
  output reg  signed [DATA_WIDTH-1:0] act_out      // 激活值输出 (INT8, ReLU饱和截断)
);

  // Stage 1: DSP Multiplication (8-bit signed * 8-bit signed = 16-bit signed)
  reg signed [15:0] mult_reg;
  reg               valid_d1;
  reg               clr_d1;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mult_reg <= 16'sd0;
      valid_d1 <= 1'b0;
      clr_d1   <= 1'b0;
    end else begin
      valid_d1 <= valid_in;
      clr_d1   <= clr_acc;
      if (valid_in) begin
        mult_reg <= act_in * w_in;
      end else begin
        mult_reg <= 16'sd0;
      end
    end
  end

  // Stage 2: 32-bit Accumulator
  reg signed [ACC_WIDTH-1:0] acc_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      acc_reg <= 32'sd0;
    end else if (clr_d1) begin
      acc_reg <= bias_in + {{16{mult_reg[15]}}, mult_reg};
    end else if (valid_d1) begin
      acc_reg <= acc_reg + {{16{mult_reg[15]}}, mult_reg};
    end
  end

  // Stage 3: ReLU + Requantization Scaling
  wire signed [ACC_WIDTH-1:0] relu_val = (acc_reg > 32'sd0) ? acc_reg : 32'sd0;
  wire signed [ACC_WIDTH-1:0] scaled_val = relu_val >>> shift_val;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      act_out   <= 8'sd0;
      valid_out <= 1'b0;
    end else begin
      valid_out <= clr_d1; // 当触发新一轮计算时，上一轮最终累加结果锁存输出
      if (scaled_val > 32'sd127) begin
        act_out <= 8'sd127; // 正向饱和
      end else begin
        act_out <= scaled_val[DATA_WIDTH-1:0];
      end
    end
  end

endmodule
