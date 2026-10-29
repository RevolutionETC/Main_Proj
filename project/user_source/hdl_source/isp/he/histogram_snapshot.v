// A complete 64-bin snapshot crosses clocks through double-buffered ERAM.
// Source never overwrites a published bank before a display-frame ACK.
module histogram_snapshot(
 input wire I_wclk,I_rclk,I_rst_n,
 input wire I_we,I_publish,input wire [5:0] I_addr,input wire [7:0] I_height,
 output wire O_ready,input wire I_frame_start,input wire [5:0] I_read_addr,
 output reg [7:0] O_height,output reg O_valid
);
 (* ram_style="block" *) reg [7:0] heights[0:127];
 reg request,acknowledge,active_bank;
 (* async_reg="true" *) reg [1:0] ack_sync;
 (* async_reg="true" *) reg [2:0] req_sync;
 assign O_ready=request==ack_sync[1];
 wire next_bank=(I_frame_start&&req_sync[2]!=active_bank)?req_sync[2]:active_bank;
 always @(posedge I_wclk)if(I_we&&O_ready)heights[{!request,I_addr}]<=I_height;
 always @(posedge I_rclk)O_height<=heights[{next_bank,I_read_addr}];
 always @(posedge I_wclk or negedge I_rst_n)
 if(!I_rst_n)begin request<=0;ack_sync<=0;end
 else begin ack_sync<={ack_sync[0],acknowledge};if(I_publish&&O_ready)request<=!request;end
 always @(posedge I_rclk or negedge I_rst_n)
 if(!I_rst_n)begin acknowledge<=0;active_bank<=0;req_sync<=0;O_valid<=0;end
 else begin
  req_sync<={req_sync[1:0],request};
  if(I_frame_start&&req_sync[2]!=active_bank)begin
   active_bank<=req_sync[2];acknowledge<=req_sync[2];O_valid<=1;
  end
 end
endmodule
