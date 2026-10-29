`timescale 1ns/1ps
// Frozen qualified D implementation has only its two module names changed.
module restored_filter_equivalence_tb;
 localparam W=25,H=17,HT=41;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,vs=0,hs=0,de=0;reg [23:0] rgb=0;reg [2:0] mode=0;
 wire av,ah,ad,bv,bh,bd;wire [23:0] a,b;
 display_filter #(.WIDTH(W),.HEIGHT(H),.HTOTAL(HT)) dut(
  .clk(clk),.rst_n(rst),.mode_i(mode),.vs_i(vs),.hs_i(hs),.de_i(de),.rgb_i(rgb),.vs_o(av),.hs_o(ah),.de_o(ad),.rgb_o(a));
 restored_filter_reference #(.WIDTH(W),.HEIGHT(H),.HTOTAL(HT)) refd(
  .clk(clk),.rst_n(rst),.mode_i(mode),.vs_i(vs),.hs_i(hs),.de_i(de),.rgb_i(rgb),.vs_o(bv),.hs_o(bh),.de_o(bd),.rgb_o(b));
 integer cycle=0,pixels=0,frame=0;
 always @(posedge clk)if(rst)begin #1;
  if({av,ah,ad,a}!={bv,bh,bd,b})$fatal(1,"existing mode equivalence frame%0d cycle%0d mode%0d got%h ref%h",frame,cycle,mode,a,b);
  if(ad)pixels=pixels+1;cycle=cycle+1;
 end
 function [23:0] image(input integer x,y,f);
  reg [7:0] r,g,b;begin r=(x*17+y*83+f*19)%256;g=(x*53+y*61+f*31)%256;b=(x*97+y*7+f*13)%256;image={r,g,b};end
 endfunction
 task tick(input integer v,h,d,input [23:0] c);begin @(negedge clk);vs=v;hs=h;de=d;rgb=c;end endtask
 integer m,x,y,n;
 initial begin
  for(m=0;m<8;m=m+1)if(m==0||m>=4)begin
   rst=0;repeat(4)@(negedge clk);rst=1;mode=m;
   for(n=0;n<3;n=n+1)begin
    tick(1,0,0,0);tick(0,0,0,0);repeat(HT*3)tick(0,0,0,0);
    for(y=0;y<H;y=y+1)begin
     for(x=0;x<W;x=x+1)tick(0,0,1,image(x,y,frame));
     for(x=W;x<HT;x=x+1)tick(0,x==W,0,0);
    end
    repeat(HT*4)tick(0,0,0,0);frame=frame+1;
   end
  end
  if(pixels!=15*W*H)$fatal(1,"equivalence count %0d",pixels);
  $display("PASS original five modes bit-identical to frozen qualified D: %0d frames/%0d pixels, back-to-back frames and reset",frame,pixels);$finish;
 end
 initial begin #5000000;$fatal(1,"equivalence timeout");end
endmodule
