// Pipeline wrappers isolate combinational output correction / ERAM output from IO.
// They change latency; no reset/valid protocol is claimed for these mapping probes.
module packed_registered(input clk,input signed [7:0] a,b,c,output reg signed [15:0] ac,bc);
reg signed [7:0] ar,br,cr;wire signed [15:0] x,y;
always @(posedge clk) begin ar<=a;br<=b;cr<=c;ac<=x;bc<=y;end
cal_mult_int8_x2 u(clk,ar,br,cr,x,y);
endmodule
module ram_registered(input clk,we,input [9:0] wa,ra,input [31:0] din,output reg [31:0] q);
reg wr;reg [9:0] war,rar;reg [31:0] dr;wire [31:0] qr;
always @(posedge clk) begin wr<=we;war<=wa;rar<=ra;dr<=din;q<=qr;end
ram_probe u(clk,wr,war,rar,dr,qr);
endmodule
