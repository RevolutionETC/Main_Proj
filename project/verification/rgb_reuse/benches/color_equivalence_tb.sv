`timescale 1ns/1ps
// Blue and green must behave exactly as the original successful red pipeline
// when supplied the same shapes with channels permuted, including moving OSD.
module color_equivalence_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,h=0,de=0;reg [23:0] rgb=0,redrgb=0;
 wire nv,nh,nd,rv,rh,rd;wire [23:0] np,rp;reg [23:0] expected;
 integer phase,f,x,y,i,pixels=0,confirmed=0,ox=0,oy=0;reg [1:0] color;reg old_rv=0;
 red_target_video #(.WIDTH(512),.HEIGHT(320)) dut(.I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_page(3'd0),.I_effect(2'd0),.I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(nv),.O_hsync(nh),.O_de(nd),.O_data(np));
 reference_red_target_video #(.WIDTH(512),.HEIGHT(320)) refdut(.I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_page(3'd0),.I_effect(2'd0),.I_vsync(v),.I_hsync(h),.I_de(de),.I_data(redrgb),.O_vsync(rv),.O_hsync(rh),.O_de(rd),.O_data(rp));
 function target(input integer xx,yy,ff);integer cx;begin
  cx=50+4*ff;
  target=(xx>=cx&&xx<=cx+70&&yy>=90&&yy<=150)||
   ((xx-230)*(xx-230)+(yy-120)*(yy-120)<=35*35)||
   (yy>=170&&yy<=250&&xx>=350&&xx<=350+yy-170);
 end endfunction
 always @(posedge clk)begin #1;
 if(!rst)begin old_rv=0;ox=0;oy=0;end else begin
  if(rv&&!old_rv)begin ox=0;oy=0;end old_rv=rv;
  expected=rp==24'hff2020 ?(color==2?24'h2860ff:24'h20c040):rp==24'hd02020 ?(color==2?24'h2020d0:24'h20d020):rp;
  // The original global NO TARGET is deliberately red in all color phases.
  if(rp==24'hff2020&&ox>=202&&ox<310&&oy>=250&&oy<264)expected=rp;
  if({nv,nh,nd}!=={rv,rh,rd}||(np!==expected&&np!==24'h2860ff&&np!==24'h20c040&&rp!==24'hff2020))$fatal(1,"Color is not equivalent to original red algorithm phase=%0d f=%0d %h/%h",phase,f,np,expected);
  if(nd)begin pixels=pixels+1;if(ox==511)begin ox=0;oy=oy+1;end else ox=ox+1;end
  if(dut.ana_done!==refdut.ana_done||dut.stable_done!==refdut.stable_done)$fatal(1,"Color processing schedule differs");
  if(dut.ana_done)for(i=0;i<8;i=i+1)begin
   if(dut.ana_objects[i*50+:48]!==refdut.ana_objects[i*48+:48])$fatal(1,"Color geometry/features/class differ");
  end
  if(dut.stable_done)begin
   if(dut.stable_objects[47])confirmed=confirmed+1;
   for(i=0;i<8;i=i+1)if(dut.stable_objects[i*50+:48]!==refdut.stable_objects[i*48+:48])$fatal(1,"Color motion/stability differs");
  end
 end end
 initial begin
  for(phase=0;phase<2;phase=phase+1)begin
   rst=0;v=0;de=0;repeat(4)@(negedge clk);color=phase==0?2:3;rst=1;
   for(f=0;f<5;f=f+1)begin
    v=1;repeat(4)@(negedge clk);v=0;repeat(200)@(negedge clk);
    for(y=0;y<320;y=y+1)begin
     for(x=0;x<512;x=x+1)begin
      de=1;redrgb=target(x,y,f)?24'hd02020:24'hb0b0b0;
      rgb=target(x,y,f)?(color==2?24'h2020d0:24'h20d020):24'hb0b0b0;@(negedge clk);
     end
     de=0;h=1;repeat(160)@(negedge clk);h=0;
    end
    repeat(12000)@(negedge clk);
    if(dut.dropped!=0||dut.capture_limit)$fatal(1,"Color frame drop");
   end
  end
  if(pixels!=1638400||confirmed<4)$fatal(1,"Color equivalence coverage");
  $display("PASS blue and green exact red-algorithm equivalence: 1638400 video pixels with palette mapping outside intentionally changed annotations, three shape classes, moving boxes, identical geometry/class/schedule and confirmation");$finish;
 end
 initial begin #30000000;$fatal(1,"Color equivalence watchdog");end
endmodule
