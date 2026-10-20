// Experimental width correction for adamgallas/fpga_accelerator_yolov3tiny
// commit 6ba312bd220e67a987d3417bacd030db30b15770, Apache-2.0.
// Isolated arithmetic experiment; not a PH1P35 synthesis result.
module cal_addtree_int16_x9_wide (
    input clk,
    input signed [15:0] a1, a2, a3, a4, a5, a6, a7, a8, a9,
    output reg signed [18:0] dout
);
    reg signed [18:0] b1, b2, b3;
    always @(posedge clk) begin
        b1 <= {{3{a1[15]}},a1} + {{3{a2[15]}},a2} + {{3{a3[15]}},a3};
        b2 <= {{3{a4[15]}},a4} + {{3{a5[15]}},a5} + {{3{a6[15]}},a6};
        b3 <= {{3{a7[15]}},a7} + {{3{a8[15]}},a8} + {{3{a9[15]}},a9};
        dout <= b1 + b2 + b3;
    end
endmodule
