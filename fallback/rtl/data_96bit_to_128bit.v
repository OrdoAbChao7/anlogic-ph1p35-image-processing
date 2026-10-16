module data_96bit_to_128bit #(
 parameter IMG_WIDTH=1280
)(
 input wire I_clk,I_rst_n,I_96b_frame_start,I_96b_valid,
 input wire [95:0] I_96b_data,
 output reg O_128b_frame_start,O_128b_valid,
 output reg [127:0] O_128b_data,
 output reg O_128b_line_end
);
 reg [95:0] saved;
 reg [1:0] phase;
 reg [10:0] word_x;
 wire [1:0] p=I_96b_frame_start?2'd0:phase;
 always @(posedge I_clk or negedge I_rst_n) begin
  if(!I_rst_n)begin
    saved<=0;phase<=0;word_x<=0;
    O_128b_frame_start<=0;O_128b_valid<=0;O_128b_data<=0;O_128b_line_end<=0;
  end else begin
    O_128b_frame_start<=I_96b_frame_start;
    O_128b_valid<=0;O_128b_line_end<=0;
    if(I_96b_frame_start)begin phase<=0;word_x<=0;end
    if(I_96b_valid)begin
      saved<=I_96b_data;phase<=p+2'd1;
      case(p)
       2'd1:begin O_128b_valid<=1;O_128b_data<={saved,I_96b_data[95:64]};end
       2'd2:begin O_128b_valid<=1;O_128b_data<={saved[63:0],I_96b_data[95:32]};end
       2'd3:begin O_128b_valid<=1;O_128b_data<={saved[31:0],I_96b_data};end
       default:O_128b_data<=0;
      endcase
      if(p!=0)begin
        if(word_x==IMG_WIDTH*3/16-1)begin word_x<=0;O_128b_line_end<=1;end
        else word_x<=word_x+11'd1;
      end
    end
  end
 end
endmodule
