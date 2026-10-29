// Bit-exact replacement of rgb_brighten_96 using six dual-read ERAM ROMs.
// One registered stage; all frame/quality metadata travels with the pixels.
module rgb_brighten_eram_96 #(parameter ENABLE=1'b1)(
 input wire I_clk,I_rst_n,input wire [95:0] I_data,input wire I_valid,I_user,I_last,
 input wire [2:0] I_mode,input wire I_previous_bad,
 output wire [95:0] O_data,output reg O_valid,O_user,O_last,
 output reg [2:0] O_mode,output reg O_previous_bad
);
 function [7:0] lift(input integer value);
  begin lift=value<64?value+value/2:value<192?value+32:value+(255-value)/2;end
 endfunction
 genvar bank;
 generate if(ENABLE)begin:ENABLED
  for(bank=0;bank<6;bank=bank+1)begin:ROM
   (* ram_style="block" *) reg [7:0] curve[0:255];
   reg [7:0] a,b;integer k;
   initial for(k=0;k<256;k=k+1)curve[k]=lift(k);
   always @(posedge I_clk)begin
    a<=curve[I_data[bank*16+:8]];b<=curve[I_data[bank*16+8+:8]];
   end
   assign O_data[bank*16+:8]=a;assign O_data[bank*16+8+:8]=b;
  end
 end else begin:BYPASS
  reg [95:0] data;always @(posedge I_clk)data<=I_data;assign O_data=data;
 end endgenerate
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin O_valid<=0;O_user<=0;O_last<=0;O_mode<=0;O_previous_bad<=0;end
 else begin O_valid<=I_valid;O_user<=I_user;O_last<=I_last;O_mode<=I_mode;O_previous_bad<=I_previous_bad;end
endmodule
