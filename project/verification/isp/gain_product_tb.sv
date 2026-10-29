`timescale 1ns/1ps
module gain_product_tb;
 reg [7:0] pixel;reg [9:0] gain;wire [17:0] full;wire [16:0] narrow;
 unsigned_gain_product #(.GAIN_BITS(10)) enhancement(.pixel(pixel),.gain(gain),.product(full));
 unsigned_gain_product #(.GAIN_BITS(9)) retro(.pixel(pixel),.gain(gain[8:0]),.product(narrow));
 integer a,b;
 initial begin
  for(a=0;a<256;a=a+1)for(b=0;b<1024;b=b+1)begin
   pixel=a;gain=b;#1;
   if(full!==a*b||narrow!==a*(b%512))$fatal(1,"Gain product %0d %0d",a,b);
  end
  $display("PASS exact gain arithmetic: 262144 enhancement + 262144 retro unsigned products, including gain bit 9");$finish;
 end
endmodule
