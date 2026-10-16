// Test-only dependency models: synchronous RAM, and a disabled gain-update
// divider. This test checks AWB raster tags, not the vendor divider arithmetic.
module divider(input clk,rst,start,input [31:0] denominator,input [47:0] numerator,output [47:0] quotient,output done);
assign quotient=48'h10000;assign done=1'b0;
endmodule
module blk_mem_gen_awb_delay_signal(input clka,wea,input [10:0] addra,input [95:0] dia,input clkb,input [10:0] addrb,output reg [95:0] dob);
reg [95:0] mem[0:1023];
always @(posedge clka)if(wea)mem[addra]<=dia;
always @(posedge clkb)dob<=mem[addrb];
endmodule
