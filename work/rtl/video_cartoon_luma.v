// Variant: quantize luminance, preserve channel differences until saturation.
// RGB888, one pixel/clock, no backpressure. VS is active high.
// Six register stages: RAM read, window/row sums, gradients/blur,
// abs/quantize, edge decision, output. All sidebands have equal delay.
// Causal 3x3 window ends at the current pixel; top/left replicate.
module video_cartoon #(
    parameter integer WIDTH = 1280,
    parameter integer HEIGHT = 720,
    parameter [11:0] EDGE_THRESHOLD = 12'd160
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

    // Alternating row banks: the write bank contains row y-2. Read-first
    // synchronous ports permit block-RAM inference without resetting RAM.
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

    function [7:0] gray;
        input [23:0] p;
        begin gray={2'b0,p[23:18]}+{1'b0,p[15:9]}+{2'b0,p[7:2]}; end
    endfunction
    function [9:0] weighted;
        input [7:0] v0,v1,v2;
        begin weighted={2'b0,v0}+{1'b0,v1,1'b0}+{2'b0,v2}; end
    endfunction
    function [7:0] quantize;
        input [7:0] v;
        begin quantize={v[7:5],v[7:5],v[7:6]}; end
    endfunction

    function [7:0] clip_channel;
        input signed [9:0] value;
        begin
            if(value < 0) clip_channel=8'd0;
            else if(value > 10'sd255) clip_channel=8'd255;
            else clip_channel=value[7:0];
        end
    endfunction
    function [23:0] quantize_luma;
        input [23:0] pixel;
        reg [9:0] sum;
        reg [7:0] lum, qlum;
        reg signed [9:0] delta, red, green, blue;
        begin
            sum={2'b0,pixel[23:16]}+{1'b0,pixel[15:8],1'b0}+{2'b0,pixel[7:0]};
            lum=sum[9:2];
            qlum=quantize(lum);
            delta=$signed({2'b0,qlum})-$signed({2'b0,lum});
            red=$signed({2'b0,pixel[23:16]})+delta;
            green=$signed({2'b0,pixel[15:8]})+delta;
            blue=$signed({2'b0,pixel[7:0]})+delta;
            quantize_luma={clip_channel(red),clip_channel(green),clip_channel(blue)};
        end
    endfunction

    reg [9:0] left1,right1,upper1,lower1;
    reg [9:0] blur_top1[0:2],blur_mid1[0:2],blur_bot1[0:2];
    reg signed [10:0] gx2,gy2;
    reg [11:0] blur2[0:2];
    reg [10:0] ax3,ay3;
    reg [23:0] quant3,quant4;
    reg edge4;
    integer ch;
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            left1<=0; right1<=0; upper1<=0; lower1<=0;
            gx2<=0; gy2<=0; ax3<=0; ay3<=0;
            quant3<=0; quant4<=0; edge4<=0; o_rgb<=0;
            for(ch=0;ch<3;ch=ch+1) begin
                blur_top1[ch]<=0; blur_mid1[ch]<=0; blur_bot1[ch]<=0; blur2[ch]<=0;
            end
        end else begin
            // Stage 1. Maximum weighted sum is 4*255=1020 (10 bits).
            left1<=weighted(gray(a),gray(d),gray(g));
            right1<=weighted(gray(c),gray(f),gray(i));
            upper1<=weighted(gray(a),gray(b),gray(c));
            lower1<=weighted(gray(g),gray(h),gray(i));
            for(ch=0;ch<3;ch=ch+1) begin
                blur_top1[ch]<=weighted(a[ch*8+:8],b[ch*8+:8],c[ch*8+:8]);
                blur_mid1[ch]<=weighted(d[ch*8+:8],e[ch*8+:8],f[ch*8+:8]);
                blur_bot1[ch]<=weighted(g[ch*8+:8],h[ch*8+:8],i[ch*8+:8]);
                // Stage 2: 16*255=4080, no truncation until /16.
                blur2[ch]<={2'b0,blur_top1[ch]}+{1'b0,blur_mid1[ch],1'b0}+{2'b0,blur_bot1[ch]};
                // Stage 3.
                // Color quantization is applied jointly below.
            end
            quant3<=quantize_luma({blur2[2][11:4],blur2[1][11:4],blur2[0][11:4]});
            gx2<=$signed({1'b0,right1})-$signed({1'b0,left1});
            gy2<=$signed({1'b0,lower1})-$signed({1'b0,upper1});
            ax3<=gx2[10] ? (~gx2+11'd1) : gx2;
            ay3<=gy2[10] ? (~gy2+11'd1) : gy2;
            // Stage 4.
            edge4<=({1'b0,ax3}+{1'b0,ay3})>=EDGE_THRESHOLD;
            quant4<=quant3;
            // Stage 5. OSD is restored after processing, never filtered.
            if(!de_pipe[4]) o_rgb<=24'd0;
            else if(overlay_pipe[4]) o_rgb<=color_pipe[4];
            else case(mode_pipe[4])
                EDGE: o_rgb<=edge4 ? 24'hffffff : 24'h000000;
                TOON: o_rgb<=edge4 ? 24'h000000 : quant4;
                default: o_rgb<=raw_pipe[4];
            endcase
        end
    end
endmodule
