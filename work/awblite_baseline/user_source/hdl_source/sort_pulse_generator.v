`timescale 1ns/1ps

// Fixed-width internal actuator pulse. The first pulse cycle coincides with
// an accepted request; subsequent cycles are emitted while O_busy is high.
module sort_pulse_generator #(
  parameter integer PULSE_CYCLES = 3,
  parameter integer COUNTER_WIDTH = (PULSE_CYCLES <= 1) ? 1 : $clog2(PULSE_CYCLES + 1)
)(
  input  wire                    I_clk,
  input  wire                    I_rst_n,
  input  wire                    I_request,
  input  wire                    I_enable,
  output reg                    O_pulse,
  output reg                    O_busy,
  output reg                    O_accepted,
  output reg                    O_rejected,
  output reg                    O_timeout
);

  reg [COUNTER_WIDTH-1:0] remaining;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      O_pulse    <= 1'b0;
      O_busy     <= 1'b0;
      O_accepted <= 1'b0;
      O_rejected <= 1'b0;
      O_timeout  <= 1'b0;
      remaining  <= {COUNTER_WIDTH{1'b0}};
    end else begin
      O_pulse    <= 1'b0;
      O_accepted <= 1'b0;
      O_rejected <= 1'b0;
      O_timeout  <= 1'b0;

      if (O_busy) begin
        if (!I_enable) begin
          O_busy    <= 1'b0;
          remaining <= {COUNTER_WIDTH{1'b0}};
          O_timeout <= 1'b1;
        end else begin
          O_pulse <= 1'b1;
          if (I_request) begin
            O_rejected <= 1'b1;
            O_timeout  <= 1'b1;
          end
          if (remaining <= 1) begin
            O_busy    <= 1'b0;
            remaining <= {COUNTER_WIDTH{1'b0}};
          end else begin
            remaining <= remaining - {{(COUNTER_WIDTH-1){1'b0}}, 1'b1};
          end
        end
      end else if (I_request) begin
        if (I_enable) begin
          O_accepted <= 1'b1;
          O_pulse    <= 1'b1;
          if (PULSE_CYCLES > 1) begin
            O_busy    <= 1'b1;
            remaining <= PULSE_CYCLES - 1;
          end else begin
            O_busy    <= 1'b0;
            remaining <= {COUNTER_WIDTH{1'b0}};
          end
        end else begin
          O_rejected <= 1'b1;
          O_timeout  <= 1'b1;
        end
      end
    end
  end
endmodule
