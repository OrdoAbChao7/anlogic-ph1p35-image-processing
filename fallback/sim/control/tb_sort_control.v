`timescale 1ns/1ps

module tb_sort_control;
  localparam integer CENTER_WIDTH = 8;
  localparam integer COUNT_WIDTH = 8;

  reg clk = 1'b0;
  reg rst_n = 1'b0;
  reg frame_valid = 1'b0;
  reg track_valid = 1'b0;
  reg target_enter = 1'b0;
  reg target_exit = 1'b0;
  reg tracking_lost = 1'b0;
  reg verdict_valid = 1'b0;
  reg verdict_pass = 1'b0;
  reg verdict_invalid = 1'b0;
  reg [CENTER_WIDTH-1:0] center_x = 0;
  reg arm = 1'b0;
  reg clear_fault = 1'b0;
  reg manual_request = 1'b0;

  wire enter_event, pass_event, ng_event, sort_request, control_fault;
  wire active, classified, triggered;
  wire [COUNT_WIDTH-1:0] pass_count, ng_count;
  wire safe_enable, request_allowed, safe_hold, fault_latched;
  wire pulse, busy, accepted, rejected, timeout;

  always #5 clk = ~clk;

  sort_event_controller #(
    .TRIGGER_X(10), .CENTER_WIDTH(CENTER_WIDTH), .COUNT_WIDTH(COUNT_WIDTH)
  ) controller (
    .I_clk(clk), .I_rst_n(rst_n), .I_frame_valid(frame_valid),
    .I_track_valid(track_valid), .I_target_enter(target_enter),
    .I_target_exit(target_exit), .I_tracking_lost(tracking_lost),
    .I_verdict_valid(verdict_valid), .I_verdict_pass(verdict_pass),
    .I_verdict_invalid(verdict_invalid), .I_center_x(center_x),
    .O_enter_event(enter_event), .O_pass_event(pass_event),
    .O_ng_event(ng_event), .O_sort_request(sort_request),
    .O_control_fault(control_fault), .O_active(active),
    .O_classified(classified), .O_triggered(triggered),
    .O_pass_count(pass_count), .O_ng_count(ng_count)
  );

  sort_safety_interlock safety (
    .I_clk(clk), .I_rst_n(rst_n), .I_arm(arm), .I_invalid(verdict_invalid),
    .I_tracking_lost(tracking_lost), .I_external_fault(1'b0),
    .I_clear_fault(clear_fault), .O_safe_enable(safe_enable),
    .O_request_allowed(request_allowed), .O_safe_hold(safe_hold),
    .O_fault_latched(fault_latched)
  );

  sort_pulse_generator #(.PULSE_CYCLES(3)) pulse_generator (
    .I_clk(clk), .I_rst_n(rst_n),
    .I_request(sort_request | manual_request),
    .I_enable(request_allowed), .O_pulse(pulse), .O_busy(busy),
    .O_accepted(accepted), .O_rejected(rejected), .O_timeout(timeout)
  );

  task clear_inputs;
    begin
      frame_valid = 1'b0; track_valid = 1'b0; target_enter = 1'b0;
      target_exit = 1'b0; tracking_lost = 1'b0; verdict_valid = 1'b0;
      verdict_pass = 1'b0; verdict_invalid = 1'b0; clear_fault = 1'b0;
      manual_request = 1'b0;
    end
  endtask

  task frame_step;
    input integer do_enter;
    input integer do_exit;
    input integer do_lost;
    input integer do_verdict_valid;
    input integer do_verdict_pass;
    input integer do_invalid;
    input integer x;
    begin
      @(negedge clk); clear_inputs;
      frame_valid = 1'b1; track_valid = 1'b1;
      target_enter = do_enter; target_exit = do_exit; tracking_lost = do_lost;
      verdict_valid = do_verdict_valid; verdict_pass = do_verdict_pass;
      verdict_invalid = do_invalid; center_x = x;
      @(posedge clk); #1; clear_inputs;
    end
  endtask

  task idle_step;
    begin @(negedge clk); clear_inputs; @(posedge clk); #1; end
  endtask

  initial begin
    // Reset is an enforced safe hold, even if no external arm is present.
    #1;
    if (!safe_hold || safe_enable || pulse)
      $fatal(1, "reset safety state failed");
    repeat (2) @(posedge clk);
    rst_n = 1'b1;
    arm = 1'b1;
    idle_step;
    if (!request_allowed || fault_latched)
      $fatal(1, "armed safety state failed");

    frame_step(1, 0, 0, 0, 0, 0, 0);
    if (!enter_event || !active)
      $fatal(1, "target enter failed");
    frame_step(0, 0, 0, 1, 1, 0, 0);
    if (!pass_event || pass_count !== 1 || !classified)
      $fatal(1, "PASS classification failed");
    frame_step(0, 0, 0, 0, 0, 0, 12);
    if (!sort_request || !triggered)
      $fatal(1, "sort request pulse/state failed");
    idle_step;
    if (!accepted || !pulse || !busy)
      $fatal(1, "sort request was not accepted");

    // The accepted pulse is three cycles wide; a request while busy is rejected.
    @(negedge clk); clear_inputs; manual_request = 1'b1;
    @(posedge clk); #1; clear_inputs;
    if (!pulse || !rejected || !timeout)
      $fatal(1, "busy request rejection failed");
    idle_step;
    if (!pulse || busy)
      $fatal(1, "pulse width final cycle failed");
    idle_step;
    if (pulse || busy)
      $fatal(1, "pulse width did not terminate");

    frame_step(0, 0, 1, 0, 0, 0, 12);
    if (!control_fault || !fault_latched || !safe_hold)
      $fatal(1, "tracking lost safety fault failed");
    frame_step(0, 0, 0, 0, 0, 0, 12);
    if (sort_request || pulse)
      $fatal(1, "stale target executed after tracking loss");
    frame_step(0, 0, 0, 0, 0, 0, 0);
    @(negedge clk); clear_inputs; clear_fault = 1'b1;
    @(posedge clk); #1; clear_inputs;
    if (fault_latched || !request_allowed)
      $fatal(1, "fault clear failed");

    frame_step(1, 0, 0, 0, 0, 0, 0);
    frame_step(0, 0, 0, 1, 0, 1, 12);
    if (!control_fault || pass_count !== 1 || ng_count !== 0 || sort_request ||
        !fault_latched || pulse)
      $fatal(1, "INVALID action was not blocked");
    @(negedge clk); clear_inputs; clear_fault = 1'b1;
    @(posedge clk); #1; clear_inputs;
    frame_step(0, 0, 0, 1, 0, 0, 12);
    if (!ng_event || ng_count !== 1 || !sort_request)
      $fatal(1, "NG reclassification failed");

    rst_n = 1'b0;
    #1;
    if (pulse || safe_enable || !safe_hold)
      $fatal(1, "reset did not force output safe");
    $display("TB_SORT_CONTROL_PASS");
    $finish;
  end

  initial begin
    #100000;
    $fatal(1, "timeout in sort control testbench");
  end
endmodule
