 
 
 
module camera_frame_check #(parameter LINE_WORDS=400, LINES=720)(
 input wire I_clk,I_rst_n,I_sof,I_eof,I_valid,I_line_end,I_lane_error,
 output reg O_previous_bad,output reg O_frame_toggle,
 output reg [31:0] O_bad_frames
);
 reg active,bad;reg [10:0] words,lines;
 wire [11:0] word_total={1'b0,words}+I_valid;
 wire [11:0] final_lines={1'b0,lines}+I_line_end;
 wire lane_fault=I_lane_error&&I_valid;
 wire line_fault=I_line_end&&(word_total!=LINE_WORDS||lines>=LINES);
 wire final_bad=bad||lane_fault||line_fault||(final_lines!=LINES)||
                (!I_line_end&&word_total!=0);
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin active<=0;bad<=0;words<=0;lines<=0;
  O_previous_bad<=1;O_frame_toggle<=0;O_bad_frames<=0;
 end else if(I_sof)begin
   
  if(active)begin O_previous_bad<=1;O_bad_frames<=O_bad_frames+1'b1;end
  active<=1;bad<=lane_fault;words<=I_valid?1:0;lines<=0;
  O_frame_toggle<=~O_frame_toggle;
 end else if(active)begin
  if(lane_fault||line_fault||word_total>LINE_WORDS)bad<=1;
  if(I_line_end)begin
   words<=0;if(lines<2047)lines<=lines+1'b1;else bad<=1;
  end else if(I_valid)begin
   if(words<2047)words<=words+1'b1;else bad<=1;
  end
  if(I_eof)begin
   active<=0;O_previous_bad<=final_bad;
   if(final_bad)O_bad_frames<=O_bad_frames+1'b1;
  end
 end
endmodule
