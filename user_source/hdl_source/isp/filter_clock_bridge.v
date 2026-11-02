 
 
module filter_clock_bridge #(parameter AW=10)(
 input wire src_clk,dst_clk,rst_n,input wire [95:0] rgb,
 input wire valid,sof,last,previous_bad,input wire [2:0] mode,
 output wire [95:0] out_rgb,output wire out_valid,out_sof,out_last,
 output wire [2:0] out_mode,output wire out_previous_bad,output wire overflow
);
 reg sof_d,overflow_src;reg [2:0] frame_mode;
 wire fs=sof&&!sof_d;
 wire push=valid||fs;
 wire full,empty;wire [102:0] head;
 wire [2:0] event_mode=fs?mode:frame_mode;
 always @(posedge src_clk or negedge rst_n)
  if(!rst_n)begin sof_d<=0;frame_mode<=0;overflow_src<=0;end
  else begin sof_d<=sof;if(fs)frame_mode<=mode;
   if(push&&full)overflow_src<=1;end
 frame_stream_fifo #(.WIDTH(103),.AW(AW)) u_fifo(
  .rst_n(rst_n),.wclk(src_clk),.we(push&&!full),
  .di({previous_bad,event_mode,last,fs,valid,rgb}),.full(full),
  .rclk(dst_clk),.re(!empty),.dout(head),.empty(empty),.used());
 assign out_rgb=head[95:0];assign out_valid=!empty&&head[96];
 assign out_sof=!empty&&head[97];assign out_last=!empty&&head[98];
 assign out_mode=head[101:99];assign out_previous_bad=head[102];
 (* async_reg="true" *) reg [1:0] error_sync;
 always @(posedge dst_clk or negedge rst_n)
  if(!rst_n)error_sync<=0;else error_sync<={error_sync[0],overflow_src};
 assign overflow=error_sync[1];
endmodule
