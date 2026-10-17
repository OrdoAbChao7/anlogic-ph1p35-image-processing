`timescale 1ns/1ps
// RGB888, one pixel/clock, no backpressure.
// Candidate s4: per-channel 8-level quantization, four-neighbour local fill,
// and Sobel contour fusion. VS is active high; all image borders replicate.
module video_cartoon #(
    parameter integer WIDTH = 1280,
    parameter integer HEIGHT = 720,
    parameter [11:0] EDGE_THRESHOLD = 12'd240
)(
    input wire clk, rst_n,
    input wire i_vs, i_hs, i_de,
    input wire [23:0] i_rgb,
    input wire i_edge_req, i_toon_req,
    input wire i_overlay,
    input wire [23:0] i_overlay_rgb,
    output wire o_vs, o_hs, o_de,
    output reg [23:0] o_rgb,
    output wire [1:0] o_mode
);
    localparam [1:0] RAW=2'd0, EDGE=2'd1, TOON=2'd2;

    reg [1:0] edge_sync, toon_sync;
    reg [1:0] active_mode;
    reg [11:0] x, y, x0, y0;
    reg parity, parity0;
    wire [1:0] requested = toon_sync[1] ? TOON : (edge_sync[1] ? EDGE : RAW);
    wire [1:0] selected = (i_de && x==0 && y==0) ? requested : active_mode;

    // Alternating row banks: each bank stores the row two positions behind
    // the current row. Synchronous read-first RAM inference is retained.
    (* ram_style = "block" *) reg [23:0] bank0[0:WIDTH-1];
    (* ram_style = "block" *) reg [23:0] bank1[0:WIDTH-1];
    reg [23:0] q0, q1;
    always @(posedge clk) begin
        if(i_de && !i_vs && rst_n) begin
            q0 <= bank0[x];
            if(!parity) bank0[x] <= i_rgb;
        end
    end
    always @(posedge clk) begin
        if(i_de && !i_vs && rst_n) begin
            q1 <= bank1[x];
            if(parity) bank1[x] <= i_rgb;
        end
    end

    reg [5:0] vs_pipe, hs_pipe, de_pipe;
    reg [4:0] overlay_pipe;
    reg [23:0] raw_pipe[0:4], color_pipe[0:4];
    reg [1:0] mode_pipe[0:5];
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            edge_sync<=0; toon_sync<=0; active_mode<=RAW;
            x<=0; y<=0; x0<=0; y0<=0; parity<=0; parity0<=0;
            vs_pipe<=0; hs_pipe<=0; de_pipe<=0; overlay_pipe<=0;
            for(k=0;k<5;k=k+1) begin raw_pipe[k]<=0; color_pipe[k]<=0; end
            for(k=0;k<6;k=k+1) mode_pipe[k]<=RAW;
        end else begin
            edge_sync<={edge_sync[0],i_edge_req};
            toon_sync<={toon_sync[0],i_toon_req};
            if(i_de && x==0 && y==0) active_mode<=requested;
            if(i_vs) begin x<=0; y<=0; parity<=0; end
            else if(i_de) begin
                if(x==WIDTH-1) begin
                    x<=0;
                    if(y==HEIGHT-1) begin y<=0; parity<=0; end
                    else begin y<=y+12'd1; parity<=~parity; end
                end else x<=x+12'd1;
            end
            x0<=x; y0<=y; parity0<=parity;
            vs_pipe<={vs_pipe[4:0],i_vs};
            hs_pipe<={hs_pipe[4:0],i_hs};
            de_pipe<={de_pipe[4:0],i_de};
            overlay_pipe<={overlay_pipe[3:0],i_overlay};
            raw_pipe[0]<=i_rgb; color_pipe[0]<=i_overlay_rgb;
            mode_pipe[0]<=selected;
            for(k=1;k<5;k=k+1) begin
                raw_pipe[k]<=raw_pipe[k-1]; color_pipe[k]<=color_pipe[k-1];
            end
            for(k=1;k<6;k=k+1) mode_pipe[k]<=mode_pipe[k-1];
        end
    end
    assign o_vs=vs_pipe[5];
    assign o_hs=hs_pipe[5];
    assign o_de=de_pipe[5];
    assign o_mode=mode_pipe[5];

    wire [23:0] middle = (y0==0) ? raw_pipe[0] : (parity0 ? q0 : q1);
    wire [23:0] top = (y0<2) ? middle : (parity0 ? q1 : q0);
    wire [23:0] bottom = raw_pipe[0];
    reg [23:0] top_l1,top_l2,mid_l1,mid_l2,bot_l1,bot_l2;
    wire [23:0] a=(x0==0)?top:top_l2, b=(x0==0)?top:top_l1, c=top;
    wire [23:0] d=(x0==0)?middle:mid_l2, e=(x0==0)?middle:mid_l1, f=middle;
    wire [23:0] g=(x0==0)?bottom:bot_l2, h=(x0==0)?bottom:bot_l1, i=bottom;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            top_l1<=0; top_l2<=0; mid_l1<=0; mid_l2<=0; bot_l1<=0; bot_l2<=0;
        end else if(de_pipe[0]) begin
            top_l2<=(x0==0)?top:top_l1; top_l1<=top;
            mid_l2<=(x0==0)?middle:mid_l1; mid_l1<=middle;
            bot_l2<=(x0==0)?bottom:bot_l1; bot_l1<=bottom;
        end
    end

    function [23:0] quantize_pixel;
        input [23:0] p;
        reg [2:0] r,g,b;
        begin
            r=p[23:21]; g=p[15:13]; b=p[7:5];
            quantize_pixel={
                {r,r,r[2:1]},
                {g,g,g[2:1]},
                {b,b,b[2:1]}
            };
        end
    endfunction

    function [9:0] luma_q;
        input [23:0] p;
        begin
            luma_q={2'b0,p[23:18]}+{1'b0,p[15:9]}+{2'b0,p[7:2]};
        end
    endfunction

    function [9:0] weighted;
        input [9:0] v0,v1,v2;
        begin weighted=(v0)+(v1<<1)+(v2); end
    endfunction

    wire [23:0] qa=quantize_pixel(a), qb=quantize_pixel(b), qc=quantize_pixel(c);
    wire [23:0] qd=quantize_pixel(d), qe=quantize_pixel(e), qf=quantize_pixel(f);
    wire [23:0] qg=quantize_pixel(g), qh=quantize_pixel(h), qi=quantize_pixel(i);
    wire [23:0] fill_color = (qb==qh && qh==qd && qd==qf) ? qb : qe;

    reg [9:0] left1,right1,upper1,lower1;
    reg signed [10:0] gx2,gy2;
    reg [10:0] ax3,ay3;
    reg edge4;
    reg [23:0] fill1,fill2,fill3,fill4;
    integer ch;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            left1<=0; right1<=0; upper1<=0; lower1<=0;
            gx2<=0; gy2<=0; ax3<=0; ay3<=0; edge4<=0;
            fill1<=0; fill2<=0; fill3<=0; fill4<=0; o_rgb<=0;
        end else begin
            // Stage 1: quantized-window Sobel sums and local region fill.
            left1<=weighted(luma_q(qa),luma_q(qd),luma_q(qg));
            right1<=weighted(luma_q(qc),luma_q(qf),luma_q(qi));
            upper1<=weighted(luma_q(qa),luma_q(qb),luma_q(qc));
            lower1<=weighted(luma_q(qg),luma_q(qh),luma_q(qi));
            fill1<=fill_color;
            // Stage 2: signed gradient.
            gx2<=$signed({1'b0,right1})-$signed({1'b0,left1});
            gy2<=$signed({1'b0,lower1})-$signed({1'b0,upper1});
            fill2<=fill1;
            // Stage 3: absolute values.
            ax3<=gx2[10] ? (~gx2+11'd1) : gx2;
            ay3<=gy2[10] ? (~gy2+11'd1) : gy2;
            fill3<=fill2;
            // Stage 4: contour decision.
            edge4<=({1'b0,ax3}+{1'b0,ay3})>=EDGE_THRESHOLD;
            fill4<=fill3;
            // Stage 5: OSD is restored after processing.
            if(!de_pipe[4]) o_rgb<=24'd0;
            else if(overlay_pipe[4]) o_rgb<=color_pipe[4];
            else case(mode_pipe[4])
                EDGE: o_rgb<=edge4 ? 24'hffffff : 24'h000000;
                TOON: o_rgb<=edge4 ? 24'h000000 : fill4;
                default: o_rgb<=raw_pipe[4];
            endcase
        end
    end
endmodule
