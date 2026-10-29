// Regression-only copy of the previous delivered bug. Never compiled into FPGA.
// Previous completed CSI frame verdict, held through the following ISP SOF.
module previous_frame_check #(parameter LINE_WORDS=400, LINES=720)(
 input wire I_clk,I_rst_n,I_sof,I_eof,I_valid,I_lane_error,
 output reg O_previous_bad,output reg O_frame_toggle,
 output reg [31:0] O_bad_frames
);
 reg active,vd,bad;reg [10:0] words,lines;
 wire line_end=vd&&!I_valid;
 wire [11:0] final_lines={1'b0,lines}+line_end;
 wire final_bad=bad||I_lane_error||I_valid||(final_lines!=LINES)||
                (line_end&&words!=LINE_WORDS);
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin active<=0;vd<=0;bad<=0;words<=0;lines<=0;
 O_previous_bad<=1;O_frame_toggle<=0;O_bad_frames<=0;end
 else begin
  vd<=I_valid;
  if(I_sof)begin
   if(active)begin O_previous_bad<=1;O_bad_frames<=O_bad_frames+1'b1;end
   active<=1;bad<=I_lane_error;words<=I_valid?1:0;lines<=0;
   O_frame_toggle<=~O_frame_toggle;
  end else if(active)begin
   if(I_lane_error)bad<=1;
   if(I_valid)begin
    if(words<2047)words<=words+1'b1;
    if(words>=LINE_WORDS)bad<=1;
   end else begin
    words<=0;
    if(line_end)begin
     if(lines<2047)lines<=lines+1'b1;
     if(words!=LINE_WORDS||lines>=LINES)bad<=1;
    end
   end
   if(I_eof)begin
    active<=0;O_previous_bad<=final_bad;
    if(final_bad)O_bad_frames<=O_bad_frames+1'b1;
   end
  end
 end
endmodule
