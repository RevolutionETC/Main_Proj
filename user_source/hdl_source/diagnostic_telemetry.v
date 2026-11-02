 
module diagnostic_telemetry(
 input wire I_ddr_clk,I_display_clk,I_rst_n,
 input wire I_age_valid,input wire [7:0] I_age,
 input wire [31:0] I_dropped_frames,I_read_overflow_frames,
 input wire [31:0] I_display_underflow_frames,
 output wire [8:0] O_latency,output wire [23:0] O_diagnostics,
 output wire [7:0] O_underflow
);
 reg [7:0] peak_age;
 wire [7:0] peak_next=I_age_valid&&I_age>peak_age?I_age:peak_age;
 always @(posedge I_ddr_clk or negedge I_rst_n)
 if(!I_rst_n)peak_age<=0;else peak_age<=peak_next;
 wire [7:0] dropped=(|I_dropped_frames[31:8])?8'hff:I_dropped_frames[7:0];
 wire [7:0] overflow=(|I_read_overflow_frames[31:8])?8'hff:I_read_overflow_frames[7:0];
 wire [32:0] coherent;
 config_mailbox #(.WIDTH(33),.RESET_VALUE(33'd0)) u_diagnostic_snapshot(
  .I_src_clk(I_ddr_clk),.I_dst_clk(I_display_clk),.I_rst_n(I_rst_n),
  .I_data({I_age_valid,I_age,peak_next,dropped,overflow}),.O_data(coherent));
 assign O_latency=coherent[32:24];
 assign O_diagnostics=coherent[23:0];
  
 assign O_underflow=(|I_display_underflow_frames[31:8])?8'hff:I_display_underflow_frames[7:0];
endmodule
