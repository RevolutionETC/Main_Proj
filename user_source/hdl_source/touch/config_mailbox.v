 
module config_mailbox #(parameter WIDTH=9, parameter [WIDTH-1:0] RESET_VALUE=0)(
 input wire I_src_clk,I_dst_clk,I_rst_n,
 input wire [WIDTH-1:0] I_data,output reg [WIDTH-1:0] O_data
);
 reg [WIDTH-1:0] payload;
 reg request,acknowledge,req_delay;
 (* async_reg="true" *) reg [1:0] ack_sync,req_sync;
 always @(posedge I_src_clk or negedge I_rst_n)
 if(!I_rst_n)begin payload<=RESET_VALUE;request<=0;ack_sync<=0;end
 else begin
  ack_sync<={ack_sync[0],acknowledge};
  if(request==ack_sync[1] && I_data!=payload)begin payload<=I_data;request<=!request;end
 end
 always @(posedge I_dst_clk or negedge I_rst_n)
 if(!I_rst_n)begin req_sync<=0;req_delay<=0;acknowledge<=0;O_data<=RESET_VALUE;end
 else begin
  req_sync<={req_sync[0],request};req_delay<=req_sync[1];
  if(req_delay!=acknowledge)begin O_data<=payload;acknowledge<=req_delay;end
 end
endmodule
