// Isolated arithmetic feasibility probe. No video integration.
// Signed INT8 x9 dot + signed INT32 bias, exact 33-bit sum,
// arithmetic >>> 8 (floor), saturation [-128,127]. Four enabled edges.
// rst synchronous active-high flushes all valid/data; ce=0 holds pipeline.
module int8_core(input clk,rst,ce,in_valid,input [71:0] a,b,
 input signed [31:0] bias,output reg out_valid,output reg signed [7:0] q);
reg signed [15:0] p[0:8];
reg signed [18:0] sum;
reg signed [31:0] bias0,bias1;
reg signed [32:0] biased;
reg v0,v1,v2;
integer i;
wire signed [32:0] scaled = biased >>> 8;
always @(posedge clk) begin
 if(rst) begin
  for(i=0;i<9;i=i+1) p[i]<=16'sd0;
  sum<=19'sd0; bias0<=32'sd0; bias1<=32'sd0; biased<=33'sd0;
  v0<=0;v1<=0;v2<=0;out_valid<=0;q<=0;
 end else if(ce) begin
  for(i=0;i<9;i=i+1) p[i]<=$signed(a[i*8+:8])*$signed(b[i*8+:8]);
  sum<= $signed({{3{p[0][15]}},p[0]})+$signed({{3{p[1][15]}},p[1]})+$signed({{3{p[2][15]}},p[2]})+
        $signed({{3{p[3][15]}},p[3]})+$signed({{3{p[4][15]}},p[4]})+$signed({{3{p[5][15]}},p[5]})+
        $signed({{3{p[6][15]}},p[6]})+$signed({{3{p[7][15]}},p[7]})+$signed({{3{p[8][15]}},p[8]});
  bias0<=bias;bias1<=bias0;
  biased <= $signed({{14{sum[18]}},sum})+$signed({bias1[31],bias1});
  if(scaled>33'sd127) q<=8'sd127;
  else if(scaled< -33'sd128) q<= -8'sd128;
  else q<=scaled[7:0];
  v0<=in_valid;v1<=v0;v2<=v1;out_valid<=v2;
 end
end
endmodule
// Scan-style loading limits probe IO count; it is not an accelerator scheduler.
module core_probe(input clk,rst,ce,in_valid,load,input [7:0] din,
 output out_valid,output signed [7:0] q);
reg [175:0] operands;
always @(posedge clk) if(rst) operands<=176'd0;else if(load) operands<={operands[167:0],din};
int8_core u(clk,rst,ce,in_valid,operands[71:0],operands[143:72],operands[175:144],out_valid,q);
endmodule
module ram_probe(input clk,we,input [9:0] wa,ra,input [31:0] din,output reg [31:0] q);
reg [31:0] mem[0:1023];
always @(posedge clk) begin
 if(we) mem[wa]<=din;
 q<=mem[ra];
end
endmodule
