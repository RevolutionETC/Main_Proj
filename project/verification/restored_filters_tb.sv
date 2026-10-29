`timescale 1ns/1ps
// Independent pixel formulas: no access to DUT internals.
module restored_filters_tb;
 localparam W=25,H=17,HT=41,D=HT+10;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,vs=0,hs=0,de=0;reg [23:0] rgb=0;reg [2:0] mode=0;
 wire ov,oh,od;wire [23:0] out;
 display_filter #(.WIDTH(W),.HEIGHT(H),.HTOTAL(HT)) dut(
  .clk(clk),.rst_n(rst),.mode_i(mode),.vs_i(vs),.hs_i(hs),.de_i(de),.rgb_i(rgb),
  .vs_o(ov),.hs_o(oh),.de_o(od),.rgb_o(out));
 integer pattern=0,active_mode=0;
 function [23:0] image(input integer x,y);
  reg [7:0] r,g,b;integer z;begin
   if(pattern<64)begin r=16+64*(pattern/16);g=16+64*((pattern/4)%4);b=16+64*(pattern%4);end
   else case(pattern)
    64:begin r=32+x;g=64+x;b=96+x;end
    65:begin r=32+y;g=64+y;b=96+y;end
    66:begin r=((x+y)%2)?81:65;g=r;b=r;end
    67:begin z=(x*97+y*43+x*y*19)%31;r=20+z;g=r;b=r;end
    68:begin r=(x*67+y*97)%256;g=(x*37+y*83+19)%256;b=(x*53+y*71+31)%256;end
    69:begin r=(x*7+y*11)%32;g=(x*13+y*3)%32;b=(x*17+y*5)%32;end
    70:begin r=x<W/2?0:255;g=y<H/2?255:0;b=x==y?255:0;end
    default:begin r=(x*11+y*3)%256;g=(x*3+y*17)%256;b=(x*7+y*19)%256;end
   endcase
   image={r,g,b};
  end
 endfunction
 function integer cx(input integer a);begin cx=a<0?0:a>=W?W-1:a;end endfunction
 function integer cy(input integer a);begin cy=a<0?0:a>=H?H-1:a;end endfunction
 function integer luminance(input [23:0] a);
  integer co,t,cg;begin co=a[23:16]-a[7:0];t=a[7:0]+(co>>>1);cg=a[15:8]-t;luminance=(t+(cg>>>1))&255;end
 endfunction
 function integer magnitude(input integer x,y);
  integer gx,gy,v[0:8],i,j;begin
   for(j=0;j<3;j=j+1)for(i=0;i<3;i=i+1)v[j*3+i]=luminance(image(cx(x+i-1),cy(y+j-1)));
   gx=v[2]+2*v[5]+v[8]-v[0]-2*v[3]-v[6];gy=v[6]+2*v[7]+v[8]-v[0]-2*v[1]-v[2];
   if(gx<0)gx=-gx;if(gy<0)gy=-gy;magnitude=gx+gy;
  end
 endfunction
 function [23:0] expected(input integer x,y,m);
  reg [23:0] a;reg [7:0] gray;begin
   a=image(x,y);gray=(77*a[23:16]+150*a[15:8]+29*a[7:0]+128)>>8;
   case(m)
    1:expected={3{gray}};
    2:expected=magnitude(x,y)>=80?24'h101820:{{4{a[23:22]}},{4{a[15:14]}},{4{a[7:6]}}};
    3:expected=~a;
    default:expected=a;
   endcase
  end
 endfunction
 reg [2:0] history[0:2500];integer t=0,out_pixels=0,checked=0,frames=0,xx,yy,mag;
 integer dark_pixels=0,palette_pixels=0,near78=0,near80=0,near82=0,atomic_checks=0;
 reg [63:0] palette_seen=0;reg [23:0] want;
 always @(posedge clk)if(rst)begin
  history[t]={vs,hs,de};#1;
  if(t>=D)begin
   if({ov,oh,od}!==history[t-D])$fatal(1,"restored sync mismatch pattern%0d mode%0d t%0d",pattern,active_mode,t);
   if(od)begin
    xx=out_pixels%W;yy=out_pixels/W;want=expected(xx,yy,active_mode);
    if(out!==want)$fatal(1,"restored pixel pattern%0d mode%0d xy%0d,%0d got%h exp%h",pattern,active_mode,xx,yy,out,want);
    if(mode!=active_mode)atomic_checks=atomic_checks+1;
    if(active_mode==2)begin
     mag=magnitude(xx,yy);
     if(mag>=80)dark_pixels=dark_pixels+1;else palette_pixels=palette_pixels+1;
     if(mag==78)near78=near78+1;if(mag==80)near80=near80+1;if(mag==82)near82=near82+1;
     if(pattern<64)palette_seen[pattern]=1;
    end
    out_pixels=out_pixels+1;checked=checked+1;
   end else if(out!==0)$fatal(1,"nonzero blank output");
  end
  t=t+1;
 end
 task tick(input integer v,h,d,input [23:0] a);begin @(negedge clk);vs=v;hs=h;de=d;rgb=a;end endtask
 integer m,x,y;
 initial begin
  for(pattern=0;pattern<72;pattern=pattern+1)for(m=1;m<=3;m=m+1)begin
   rst=0;repeat(4)@(negedge clk);rst=1;mode=m;active_mode=m;t=0;out_pixels=0;
   tick(1,0,0,0);tick(0,0,0,0);repeat(HT*3)tick(0,0,0,0);
   for(y=0;y<H;y=y+1)begin
    for(x=0;x<W;x=x+1)begin
     // A mid-frame request must not alter this frame's output.
     if(y==H/2&&x==W/2)mode=m==3?1:m+1;
     tick(0,0,1,image(x,y));
    end
    for(x=W;x<HT;x=x+1)tick(0,x==W,0,0);
   end
   repeat(HT*4)tick(0,0,0,0);
   if(out_pixels!=W*H)$fatal(1,"restored output count %0d",out_pixels);frames=frames+1;
  end
  if(palette_seen!==64'hffffffffffffffff||dark_pixels==0||palette_pixels==0||near78==0||near80==0||near82==0||atomic_checks==0)
   $fatal(1,"coverage palette%h dark%0d palette%0d thresholds%0d/%0d/%0d atomic%0d",palette_seen,dark_pixels,palette_pixels,near78,near80,near82,atomic_checks);
  $display("PASS restored filter oracles: %0d frames/%0d pixels, all 64 cartoon colours, flat/low-gradient/noise/borders, threshold 78/80/82=%0d/%0d/%0d, %0d midframe-request pixels",frames,checked,near78,near80,near82,atomic_checks);$finish;
 end
 initial begin #50000000;$fatal(1,"restored timeout");end
endmodule
