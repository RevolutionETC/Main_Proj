`timescale 1ns/1ps
// Reproduce the user's sequence without resets: single R/B/G, RB/RG/BG, RGB.
// Check actual output pixels every confirmed frame, not just detector flags.
module integrated_colors_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,h=0,de=0;reg [23:0] rgb=0;
 wire ov,oh,od;wire [23:0] out;
 red_target_video #(.USE_ISP_FILTERS(1),.HTOTAL(672),.WIDTH(512),.HEIGHT(320)) dut(.I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_page(3'd0),.I_image_mode(f==0?3'd0:f==1?3'd4:f==2?3'd5:f==3?3'd6:3'd7),.I_effect(2'd0),.I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 integer col[0:7],kind[0:7],left[0:7],top[0:7],num,mask;
 integer scene,f,x,y,i,c,k,xx,yy;
 integer ox=0,oy=0,pixels=0,ri=0,bi=0,gi=0,checked=0;
 reg old_v=0;reg [2:0] pv=0,ph=0,pd=0;
 function shape_hit(input integer px,py,slot);integer dx,dy;begin
  dx=px-left[slot]-28;dy=py-top[slot]-28;
  case(kind[slot])
   1:shape_hit=dx*dx+dy*dy<=28*28;
   2:shape_hit=px>=left[slot]&&px<=left[slot]+56&&py>=top[slot]&&py<=top[slot]+56;
   3:shape_hit=py>=top[slot]&&py<=top[slot]+56&&px>=left[slot]&&px<=left[slot]+py-top[slot];
   default:shape_hit=0;
  endcase
 end endfunction
 function [23:0] color_rgb(input integer palette,ff);begin
  // Blue/green include realistic moderate saturation rejected by old 1.5x gates.
  case(palette)
   1:color_rgb=24'hd02020;
   2:color_rgb=ff%2==0?24'h606080:24'h6e6e96;
   3:color_rgb=ff%2==0?24'h608060:24'h6e966e;
   default:color_rgb=24'hb0b0b0;
  endcase
 end endfunction
 always @(posedge clk)begin
  pv={pv[1:0],v};ph={ph[1:0],h};pd={pd[1:0],de};#1;
  if(rst)begin
   
   if(ov&&!old_v)begin ox=0;oy=0;pixels=0;ri=0;bi=0;gi=0;end old_v=ov;
   if(od)begin
    if(^out===1'bx)$fatal(1,"Unknown mixed-color pixels");
    if(out==24'hff2020)ri=ri+1;if(out==24'h2860ff)bi=bi+1;if(out==24'h20c040)gi=gi+1;
    if(f>=3)begin
     for(i=0;i<num;i=i+1)if(ox==left[i]&&oy==top[i]+28)begin
      if(out!==(col[i]==1?24'hff2020:col[i]==2?24'h2860ff:24'h20c040))$fatal(1,"Missing/wrong box scene=%0d frame=%0d object=%0d color=%0d rgb=%h",scene,f,i,col[i],out);
     end
     if(ox==202&&oy==250&&out==24'hff2020)$fatal(1,"NO TARGET remained with visible targets");
    end
    pixels=pixels+1;if(ox==511)begin ox=0;oy=oy+1;end else ox=ox+1;
   end
  end
 end
 initial begin
  num=0;repeat(5)@(negedge clk);rst=1;
  for(scene=0;scene<7;scene=scene+1)begin
   case(scene)0:mask=1;1:mask=2;2:mask=4;3:mask=3;4:mask=5;5:mask=6;6:mask=7;endcase
   num=0;
   for(c=1;c<=3;c=c+1)if(mask&(1<<(c-1)))for(k=1;k<=3;k=k+1)if(num<8)begin
    col[num]=c;kind[num]=k;left[num]=60+(num%3)*150;top[num]=60+(num/3)*90;num=num+1;
   end
   for(f=0;f<5;f=f+1)begin
    v=1;repeat(4)@(negedge clk);v=0;repeat(200)@(negedge clk);
    for(y=0;y<320;y=y+1)begin
     for(x=0;x<512;x=x+1)begin
      rgb=24'hb0b0b0;for(k=0;k<num;k=k+1)if(shape_hit(x,y,k))rgb=color_rgb(col[k],f);
      de=1;@(negedge clk);
     end
     de=0;h=1;repeat(160)@(negedge clk);h=0;
    end
    repeat(12000)@(negedge clk);
    if(pixels!=163840)$fatal(1,"Mixed-color frame length");
    if(f>=3)begin
     if((mask&1)?ri<300:ri!=0)$fatal(1,"Red annotation pixels scene=%0d n=%0d",scene,ri);
     if((mask&2)?bi<300:bi!=0)$fatal(1,"Blue annotation pixels scene=%0d n=%0d",scene,bi);
     if((mask&4)?gi<300:gi!=0)$fatal(1,"Green annotation pixels scene=%0d n=%0d",scene,gi);
     checked=checked+1;
    end
    if(dut.capture_limit||dut.dropped!=0)$fatal(1,"Mixed-color capture limit/drop");
   end
  end
  if(checked!=14)$fatal(1,"Missing color scenes");
  $display("PASS integrated filters + recognition: 35 continuous 512x320 frames, original/pixel/edge/retro/enhance: single R/B/G, all RB/RG/BG pairs and eight RGB targets; every confirmed frame has actual matching box pixels and color ink, no missing-color suppression or NO TARGET, all nine shape/color types and moderate blue/green saturation");$finish;
 end
 initial begin #90000000;$fatal(1,"Color-presence watchdog");end
endmodule
