 
 
 
module wb_tint_96(
 input wire I_clk,I_rst_n,I_enable,
 input wire signed [4:0] I_ab,I_gm,
 input wire [95:0] I_data,input wire I_valid,I_user,I_last,
 output reg [95:0] O_data,output reg O_valid,O_user,O_last
);
 function [4:0] factor(input signed [5:0] offset);
 integer n;begin n=offset;if(n>9)n=9;if(n< -9)n=-9;factor=n;end
 endfunction
  
  
 function [13:0] product(input [7:0] pixel,input signed [4:0] offset);
 reg [5:0] gain;
 begin
  gain=6'd32+{{1{offset[4]}},offset};
  product=pixel*gain;
 end endfunction
 function [7:0] clip(input [13:0] p);
 reg [14:0] q;begin q={1'b0,p}+15'd16;clip=q>8176?8'd255:q[12:5];end
 endfunction
 wire signed [4:0] want_r=I_enable?factor({I_ab[4],I_ab}):5'd0;
 wire signed [4:0] want_b=I_enable?factor(-$signed({I_ab[4],I_ab})):5'd0;
 wire signed [4:0] want_g=I_enable?factor({I_gm[4],I_gm}):5'd0;
 reg signed [4:0] gr,gg,gb;
 wire signed [4:0] er=I_user?want_r:gr,eg=I_user?want_g:gg,eb=I_user?want_b:gb;
 reg [13:0] pr[0:3],pg[0:3],pb[0:3];reg v,u,l;integer p;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  gr<=0;gg<=0;gb<=0;v<=0;u<=0;l<=0;O_data<=0;O_valid<=0;O_user<=0;O_last<=0;
  for(p=0;p<4;p=p+1)begin pr[p]<=0;pg[p]<=0;pb[p]<=0;end
 end else begin
  if(I_user)begin gr<=want_r;gg<=want_g;gb<=want_b;end
  v<=I_valid;u<=I_user;l<=I_last;O_valid<=v;O_user<=u;O_last<=l;
  for(p=0;p<4;p=p+1)begin
   pr[p]<=product(I_data[p*24+16+:8],er);pg[p]<=product(I_data[p*24+8+:8],eg);pb[p]<=product(I_data[p*24+:8],eb);
   O_data[p*24+:24]<=v?{clip(pr[p]),clip(pg[p]),clip(pb[p])}:24'd0;
  end
 end
endmodule
