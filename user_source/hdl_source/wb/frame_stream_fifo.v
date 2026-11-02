 
module frame_stream_fifo #(parameter WIDTH=131, AW=9)(
 input wire rst_n,wclk,we,input wire [WIDTH-1:0] di,output reg full,
 input wire rclk,re,output reg [WIDTH-1:0] dout,output reg empty,
 output wire [AW:0] used
);
 (* ram_style="block" *) reg [WIDTH-1:0] mem[0:(1<<AW)-1];
 reg [AW:0] wp,wg,rp,rg;
 (* async_reg="true" *) reg [AW:0] rg1,rg2,wg1,wg2;
 wire [AW:0] wn=wp+(we&&!full),rn=rp+(re&&!empty);
 wire [AW:0] wgn=(wn>>1)^wn,rgn=(rn>>1)^rn;
 function [AW:0] binary(input [AW:0] gray);
 integer i;begin binary[AW]=gray[AW];for(i=AW-1;i>=0;i=i-1)binary[i]=binary[i+1]^gray[i];end
 endfunction
 assign used=binary(wg2)-rp;
 always @(posedge wclk)if(we&&!full)mem[wp[AW-1:0]]<=di;
 always @(posedge rclk)dout<=mem[rn[AW-1:0]];
 always @(posedge wclk or negedge rst_n)
 if(!rst_n)begin wp<=0;wg<=0;rg1<=0;rg2<=0;full<=0;end
 else begin rg1<=rg;rg2<=rg1;wp<=wn;wg<=wgn;full<=wgn=={~rg2[AW:AW-1],rg2[AW-2:0]};end
 always @(posedge rclk or negedge rst_n)
 if(!rst_n)begin rp<=0;rg<=0;wg1<=0;wg2<=0;empty<=1;end
 else begin wg1<=wg;wg2<=wg1;rp<=rn;rg<=rgn;empty<=rgn==wg2;end
endmodule
