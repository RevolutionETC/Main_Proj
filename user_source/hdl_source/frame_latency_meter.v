 
 
module frame_latency_meter(
 input wire I_clk,I_rst_n,input wire I_sample,input wire I_valid,
 input wire [15:0] I_capture_sequence,input wire [15:0] I_display_sequence,
 output reg O_valid,output reg [7:0] O_frame_latency
);
 wire [15:0] sequence_delta=I_capture_sequence-I_display_sequence;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin O_valid<=0;O_frame_latency<=0;end
 else if(I_sample)begin
  O_valid<=I_valid;
  if(!I_valid)O_frame_latency<=0;
  else if(sequence_delta>16'd255)O_frame_latency<=8'hff;
  else O_frame_latency<=sequence_delta[7:0];
 end
endmodule
