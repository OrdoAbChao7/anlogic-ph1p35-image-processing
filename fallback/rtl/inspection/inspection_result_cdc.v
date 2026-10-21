`timescale 1ns / 1ps

// Bundled-data CDC for the frame-published inspection result.
//
// The source domain holds the complete result bus stable and toggles
// I_src_toggle after a detector frame has drained.  The toggle is synchronized
// into the HDMI domain.  The bus is sampled only after that synchronization,
// held in a pending register, and committed to the display-facing outputs at
// I_frame_start.  This prevents a BBox, OSD or status field from changing in
// the middle of a displayed frame.
//
// I_src_clk is part of the interface contract and documents the source domain;
// the source-side bus is intentionally not re-registered here because the
// producer already guarantees it remains stable between toggle events.
module inspection_result_cdc (
    input  wire        I_src_clk,
    input  wire        I_dst_clk,
    input  wire        I_rst_n,
    input  wire        I_frame_start,
    input  wire        I_src_toggle,
    input  wire [10:0] I_src_xmin,
    input  wire [10:0] I_src_xmax,
    input  wire [10:0] I_src_ymin,
    input  wire [10:0] I_src_ymax,
    input  wire [10:0] I_src_width,
    input  wire [10:0] I_src_height,
    input  wire        I_src_detected,
    input  wire        I_src_pass,
    input  wire        I_src_ng,
    input  wire        I_src_no_obj,
    input  wire        I_src_invalid,
    output reg  [10:0] O_xmin,
    output reg  [10:0] O_xmax,
    output reg  [10:0] O_ymin,
    output reg  [10:0] O_ymax,
    output reg  [10:0] O_width,
    output reg  [10:0] O_height,
    output reg         O_detected,
    output reg         O_pass,
    output reg         O_ng,
    output reg         O_no_obj,
    output reg         O_invalid
);
    // I_src_clk is intentionally unused in the bundled-data implementation.
    wire unused_src_clk = I_src_clk;

    reg        toggle_meta;
    reg        toggle_sync;
    reg        toggle_seen;
    reg        pending_valid;
    reg [10:0] pending_xmin, pending_xmax, pending_ymin, pending_ymax;
    reg [10:0] pending_width, pending_height;
    reg        pending_detected, pending_pass, pending_ng;
    reg        pending_no_obj, pending_invalid;

    always @(posedge I_dst_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            toggle_meta     <= 1'b0;
            toggle_sync     <= 1'b0;
            toggle_seen     <= 1'b0;
            pending_valid   <= 1'b0;
            pending_xmin    <= 11'd0;
            pending_xmax    <= 11'd0;
            pending_ymin    <= 11'd0;
            pending_ymax    <= 11'd0;
            pending_width   <= 11'd0;
            pending_height  <= 11'd0;
            pending_detected<= 1'b0;
            pending_pass    <= 1'b0;
            pending_ng      <= 1'b0;
            pending_no_obj  <= 1'b0;
            pending_invalid <= 1'b1;
            O_xmin          <= 11'd0;
            O_xmax          <= 11'd0;
            O_ymin          <= 11'd0;
            O_ymax          <= 11'd0;
            O_width         <= 11'd0;
            O_height        <= 11'd0;
            O_detected      <= 1'b0;
            O_pass          <= 1'b0;
            O_ng            <= 1'b0;
            O_no_obj        <= 1'b0;
            O_invalid       <= 1'b1;
        end else begin
            toggle_meta <= I_src_toggle;
            toggle_sync <= toggle_meta;

            // The source bus is sampled only after the toggle has crossed two
            // destination clocks and is then held until the next frame start.
            if (toggle_sync != toggle_seen) begin
                toggle_seen      <= toggle_sync;
                pending_valid    <= 1'b1;
                pending_xmin     <= I_src_xmin;
                pending_xmax     <= I_src_xmax;
                pending_ymin     <= I_src_ymin;
                pending_ymax     <= I_src_ymax;
                pending_width    <= I_src_width;
                pending_height   <= I_src_height;
                pending_detected <= I_src_detected;
                pending_pass     <= I_src_pass;
                pending_ng       <= I_src_ng;
                pending_no_obj   <= I_src_no_obj;
                pending_invalid  <= I_src_invalid;
            end

            // Only this block changes the display-facing result, so all
            // fields become visible atomically at the same frame boundary.
            if (I_frame_start && pending_valid) begin
                pending_valid <= 1'b0;
                O_xmin       <= pending_xmin;
                O_xmax       <= pending_xmax;
                O_ymin       <= pending_ymin;
                O_ymax       <= pending_ymax;
                O_width      <= pending_width;
                O_height     <= pending_height;
                O_detected   <= pending_detected;
                O_pass       <= pending_pass;
                O_ng         <= pending_ng;
                O_no_obj     <= pending_no_obj;
                O_invalid    <= pending_invalid;
            end
        end
    end
endmodule
