`timescale 1ns/1ps

// Frame-domain single-target sort event controller.
// It counts a verdict once per target_enter lifecycle and emits one request
// when the target crosses the configured x-coordinate.
module sort_event_controller #(
  parameter integer TRIGGER_X    = 100,
  parameter integer CENTER_WIDTH = 11,
  parameter integer COUNT_WIDTH  = 16
)(
  input  wire                    I_clk,
  input  wire                    I_rst_n,
  input  wire                    I_frame_valid,
  input  wire                    I_track_valid,
  input  wire                    I_target_enter,
  input  wire                    I_target_exit,
  input  wire                    I_tracking_lost,
  input  wire                    I_verdict_valid,
  input  wire                    I_verdict_pass,
  input  wire                    I_verdict_invalid,
  input  wire [CENTER_WIDTH-1:0] I_center_x,
  output reg                    O_enter_event,
  output reg                    O_pass_event,
  output reg                    O_ng_event,
  output reg                    O_sort_request,
  output reg                    O_control_fault,
  output reg                    O_active,
  output reg                    O_classified,
  output reg                    O_triggered,
  output reg [COUNT_WIDTH-1:0]  O_pass_count,
  output reg [COUNT_WIDTH-1:0]  O_ng_count
);

  reg [CENTER_WIDTH-1:0] previous_x;
  reg                    previous_x_valid;

  wire classification_now = I_frame_valid && O_active && I_verdict_valid &&
                             !I_verdict_invalid && !O_classified;
  wire qualified_now = I_frame_valid && O_active && I_track_valid &&
                       !I_verdict_invalid && (O_classified || classification_now);
  wire crossed_now = (I_center_x >= TRIGGER_X) &&
                     (!previous_x_valid || (previous_x < TRIGGER_X) ||
                      classification_now);
  wire sort_now = qualified_now && !O_triggered && crossed_now;

  always @(posedge I_clk or negedge I_rst_n) begin
    if (!I_rst_n) begin
      O_enter_event   <= 1'b0;
      O_pass_event    <= 1'b0;
      O_ng_event      <= 1'b0;
      O_sort_request  <= 1'b0;
      O_control_fault <= 1'b0;
      O_active        <= 1'b0;
      O_classified    <= 1'b0;
      O_triggered     <= 1'b0;
      O_pass_count    <= {COUNT_WIDTH{1'b0}};
      O_ng_count      <= {COUNT_WIDTH{1'b0}};
      previous_x      <= {CENTER_WIDTH{1'b0}};
      previous_x_valid <= 1'b0;
    end else begin
      O_enter_event   <= 1'b0;
      O_pass_event    <= 1'b0;
      O_ng_event      <= 1'b0;
      O_sort_request  <= 1'b0;
      O_control_fault <= 1'b0;

      if (I_frame_valid) begin
        if (I_target_enter) begin
          O_active         <= 1'b1;
          O_classified     <= 1'b0;
          O_triggered      <= 1'b0;
          previous_x_valid <= 1'b0;
          O_enter_event    <= 1'b1;
        end

        if (I_tracking_lost) begin
          O_active         <= 1'b0;
          O_classified     <= 1'b0;
          O_triggered      <= 1'b0;
          previous_x_valid <= 1'b0;
          O_control_fault  <= 1'b1;
        end else if (I_target_exit) begin
          O_active         <= 1'b0;
          O_classified     <= 1'b0;
          O_triggered      <= 1'b0;
          previous_x_valid <= 1'b0;
        end else begin
          if (I_verdict_invalid)
            O_control_fault <= 1'b1;

          if (classification_now) begin
            O_classified <= 1'b1;
            if (I_verdict_pass) begin
              O_pass_count <= O_pass_count + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
              O_pass_event <= 1'b1;
            end else begin
              O_ng_count <= O_ng_count + {{(COUNT_WIDTH-1){1'b0}}, 1'b1};
              O_ng_event <= 1'b1;
            end
          end

          if (sort_now) begin
            O_triggered    <= 1'b1;
            O_sort_request <= 1'b1;
          end

          if (O_active && I_track_valid) begin
            previous_x       <= I_center_x;
            previous_x_valid <= 1'b1;
          end
        end
      end
    end
  end
endmodule
