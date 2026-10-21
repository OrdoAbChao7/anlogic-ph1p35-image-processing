`timescale 1ns/1ps

// Safety boundary for internal sort requests. No GPIO polarity or pin is
// assumed here; the only output is an internal permission signal.
module sort_safety_interlock (
  input  wire I_clk,
  input  wire I_rst_n,
  input  wire I_arm,
  input  wire I_invalid,
  input  wire I_tracking_lost,
  input  wire I_external_fault,
  input  wire I_clear_fault,
  output wire O_safe_enable,
  output wire O_request_allowed,
  output wire O_safe_hold,
  output reg  O_fault_latched
);

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      O_fault_latched <= 1'b0;
    end else begin
      if (I_clear_fault && !I_invalid && !I_tracking_lost && !I_external_fault)
        O_fault_latched <= 1'b0;
      if (I_invalid || I_tracking_lost || I_external_fault)
        O_fault_latched <= 1'b1;
    end
  end

  assign O_safe_enable = I_rst_n && I_arm && !O_fault_latched &&
                         !I_invalid && !I_tracking_lost && !I_external_fault;
  assign O_request_allowed = O_safe_enable;
  assign O_safe_hold = !O_safe_enable;
endmodule
