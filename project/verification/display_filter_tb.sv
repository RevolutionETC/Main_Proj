`timescale 1ns/1ps
module display_filter_tb;
 localparam W=24,H=16,HT=40,D=HT+10;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,vs=0,hs=0,de=0;reg [23:0] rgb=0;reg [2:0] mode=0;
 wire ov,oh,od;wire [23:0] out;
 display_filter #(.WIDTH(W),.HEIGHT(H),.HTOTAL(HT)) dut(
  .clk(clk),.rst_n(rst),.mode_i(mode),.vs_i(vs),.hs_i(hs),.de_i(de),.rgb_i(rgb),
  .vs_o(ov),.hs_o(oh),.de_o(od),.rgb_o(out));
 function [23:0] image(input integer x,y);
  reg [7:0] r,g,b;begin r=(x*17+y*5+3)%256;g=(x*7+y*23+19)%256;b=(x*31+y*11+47)%256;image={r,g,b};end
 endfunction
 function [25:0] yc(input [23:0] a);
  integer co,t,cg,y;begin co=a[23:16]-a[7:0];t=a[7:0]+(co>>>1);cg=a[15:8]-t;y=t+(cg>>>1);yc={y[7:0],co[8:0],cg[8:0]};end
 endfunction
 function integer clipx(input integer a);begin clipx=a<0?0:a>=W?W-1:a;end endfunction
 function integer clipy(input integer a);begin clipy=a<0?0:a>=H?H-1:a;end endfunction
 function [23:0] expected(input integer x,y,m);
  reg [23:0] a;reg [7:0] c;integer gx,gy,xx,yy,i,j,v[0:8];begin
   a=image(x,y);expected=a;
   if(m==1)begin c=(77*a[23:16]+150*a[15:8]+29*a[7:0]+128)>>8;expected={3{c}};end
   if(m==3)expected=~a;
   if(m==4)begin a=image((x/8)*8,(y/8)*8);c={a[23:21],a[15:13],a[7:6]};
    expected={{c[7:5],c[7:5],c[7:6]},{c[4:2],c[4:2],c[4:3]},{c[1:0],c[1:0],c[1:0],c[1:0]}};end
   if(m==2||m==5)begin
    for(j=0;j<3;j=j+1)for(i=0;i<3;i=i+1)begin a=image(clipx(x+i-1),clipy(y+j-1));c=yc(a)>>18;v[j*3+i]=c;end
    gx=v[2]+2*v[5]+v[8]-v[0]-2*v[3]-v[6];gy=v[6]+2*v[7]+v[8]-v[0]-2*v[1]-v[2];
    if(gx<0)gx=-gx;if(gy<0)gy=-gy;
    a=image(x,y);
    if(m==2)expected=(gx+gy>=80)?24'h101820:{{4{a[23:22]}},{4{a[15:14]}},{4{a[7:6]}}};
    else expected=(gx+gy>=80)?24'hffffff:24'd0;
   end
  end
 endfunction
 reg [2:0] sync_history[0:3000];reg [23:0] data_history[0:3000];
 integer t=0,checked=0,win_checked=0,out_pixels=0,m,x,y,z,xx,yy,i,j;reg [25:0] wanted;
 reg [23:0] enhance_expected[0:W*H-1],retro_expected[0:W*H-1];
 always @(posedge clk)begin
  if(rst)begin
   sync_history[t]={vs,hs,de};data_history[t]=rgb;#1;
   if(t>=D)begin
    if({ov,oh,od}!==sync_history[t-D])$fatal(1,"sync cycle=%0d got=%b exp=%b",t,{ov,oh,od},sync_history[t-D]);
    if(od)begin
     xx=out_pixels%W;yy=out_pixels/W;
     if(mode<=5)begin
      if(out!==expected(xx,yy,mode))$fatal(1,"mode %0d (%0d,%0d) got %h expected %h cycle %0d",mode,xx,yy,out,expected(xx,yy,mode),t);
     end else begin
      if(out!==(mode==6?retro_expected[out_pixels]:enhance_expected[out_pixels]))
       $fatal(1,"reference mode%0d (%0d,%0d) got%h exp%h",mode,xx,yy,out,mode==6?retro_expected[out_pixels]:enhance_expected[out_pixels]);
     end
     out_pixels=out_pixels+1;checked=checked+1;
    end
   end
   if(dut.wv)begin
    for(j=0;j<3;j=j+1)for(i=0;i<3;i=i+1)begin
     wanted=yc(image(clipx(dut.wx+i-1),clipy(dut.wy+j-1)));
     if(dut.win[(8-j*3-i)*26+:26]!==wanted)$fatal(1,"window (%0d,%0d) tap%0d,%0d got%h exp%h",dut.wx,dut.wy,i,j,dut.win[(8-j*3-i)*26+:26],wanted);
    end
    win_checked=win_checked+1;
   end
   t=t+1;
  end
 end
 task tick(input integer v,h,d,input [23:0] a);begin @(negedge clk);vs=v;hs=h;de=d;rgb=a;end endtask
 initial begin
  $readmemh("../fixtures/scalar_enhance.hex",enhance_expected);$readmemh("../fixtures/scalar_retro.hex",retro_expected);
  for(m=0;m<8;m=m+1)begin
   rst=0;repeat(4)@(negedge clk);rst=1;mode=m;t=0;out_pixels=0;
   tick(1,0,0,0);tick(0,0,0,0);repeat(HT*3)tick(0,0,0,0);
   for(y=0;y<H;y=y+1)begin
    for(x=0;x<W;x=x+1)tick(0,0,1,image(x,y));
    for(x=W;x<HT;x=x+1)tick(0,x==W,0,0);
   end
   repeat(HT*4)tick(0,0,0,0);
   if(out_pixels!=W*H)$fatal(1,"pixel count %0d",out_pixels);
  end
  $display("PASS display filters: %0d output pixels, %0d centered windows, exact all eight modes including grayscale/cartoon/negative, borders and timing",checked,win_checked);$finish;
 end
 initial begin #2000000;$fatal(1,"timeout");end
endmodule
