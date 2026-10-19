`timescale 1ns/1ps
// Debounced, frame-boundary display-mode controller.
// Buttons are active low. I_key_edge_n is the single-click mode-cycle key:
// ORIGINAL -> SOBEL -> CARTOON -> ORIGINAL. The visible mode changes only
// on I_frame_start. I_key_cartoon_n remains reserved for the later OSD page.
module mode_controller #(
    parameter integer DEBOUNCE_CYCLES = 1000000
)(
    input  wire       I_clk,
    input  wire       I_rst_n,
    input  wire       I_key_edge_n,
    input  wire       I_key_cartoon_n,
    input  wire       I_frame_start,
    output reg  [1:0] O_mode,
    output wire       O_edge_req,
    output wire       O_cartoon_req
);

    localparam [1:0] MODE_ORIGINAL = 2'd0;
    localparam [1:0] MODE_SOBEL    = 2'd1;
    localparam [1:0] MODE_CARTOON  = 2'd2;

    reg [1:0] edge_sync;
    reg [1:0] cartoon_sync;
    reg       edge_pressed;
    reg       cartoon_pressed;
    reg [31:0] edge_count;
    reg [31:0] cartoon_count;
    reg [1:0] pending_mode;

    wire edge_sample   = ~edge_sync[1];
    wire cartoon_sample = ~cartoon_sync[1];

    function [1:0] next_mode;
        input [1:0] mode;
        begin
            case (mode)
                MODE_ORIGINAL: next_mode = MODE_SOBEL;
                MODE_SOBEL:    next_mode = MODE_CARTOON;
                default:       next_mode = MODE_ORIGINAL;
            endcase
        end
    endfunction

    assign O_edge_req   = (O_mode == MODE_SOBEL);
    assign O_cartoon_req = (O_mode == MODE_CARTOON);

    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            edge_sync      <= 2'b11;
            cartoon_sync   <= 2'b11;
            edge_pressed   <= 1'b0;
            cartoon_pressed<= 1'b0;
            edge_count     <= 32'd0;
            cartoon_count  <= 32'd0;
            pending_mode   <= MODE_ORIGINAL;
            O_mode         <= MODE_ORIGINAL;
        end else begin
            edge_sync    <= {edge_sync[0], I_key_edge_n};
            cartoon_sync <= {cartoon_sync[0], I_key_cartoon_n};

            if (edge_sample == edge_pressed) begin
                edge_count <= 32'd0;
            end else if (DEBOUNCE_CYCLES <= 1 || edge_count >= DEBOUNCE_CYCLES-1) begin
                edge_pressed <= edge_sample;
                edge_count   <= 32'd0;
                if (edge_sample)
                    pending_mode <= next_mode(pending_mode);
            end else begin
                edge_count <= edge_count + 32'd1;
            end

            if (cartoon_sample == cartoon_pressed) begin
                cartoon_count <= 32'd0;
            end else if (DEBOUNCE_CYCLES <= 1 || cartoon_count >= DEBOUNCE_CYCLES-1) begin
                cartoon_pressed <= cartoon_sample;
                cartoon_count   <= 32'd0;
            end else begin
                cartoon_count <= cartoon_count + 32'd1;
            end

            if (I_frame_start)
                O_mode <= pending_mode;
        end
    end
endmodule
