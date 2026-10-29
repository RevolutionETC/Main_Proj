`timescale 1ns/1ps
module red_video_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,en=1,v=0,h=0,de=0;reg [23:0] rgb=0;reg [1:0] effect=0;
 wire ov,oh,od;wire [23:0] out;
 red_target_video dut(.I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_page(3'd0),.I_effect(effect),.I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 reg [2:0] pv=0,ph=0,pd=0;reg old_ov=0;integer outframe=-1,ox=0,oy=0,fd=0,ink_count=0,frame_pixels=0;
 integer f,x,y,i,c,shapes,rects,circles,tris;reg [49:0] rec;
 function [23:0] pixel(input integer xx,yy,ff);integer center;begin
  center=100+8*ff;pixel=24'hb0b0b0;
  if((xx>=center&&xx<=center+145&&yy>=120&&yy<=230)||
   ((xx-700)*(xx-700)+(yy-220)*(yy-220)<=52*52)||
   (yy>=140&&yy<=285&&(xx-450)*145<=(yy-140)*70&&(450-xx)*145<=(yy-140)*70)||
   (xx>=100&&xx<=139&&yy>=340&&yy<=379)||(xx>=144&&xx<=183&&yy>=340&&yy<=379)||
   (xx>=840&&xx<=860&&yy>=350&&yy<=370))pixel=24'hd02020;
  if(xx>=880&&xx<=940&&yy>=150&&yy<=210)pixel=24'h2020d0;
  if(ff>=9)begin
   pixel=24'hb0b0b0;
   if(ff<14&&xx>=100&&xx<750&&yy>=100&&yy<450&&((xx-100)%250)<50&&((yy-100)%150)<50)pixel=24'hd02020;
  end
 end endfunction
 always @(posedge clk)begin
  pv={pv[1:0],v};ph={ph[1:0],h};pd={pd[1:0],de};#1;
  if(rst)begin
   if({ov,oh,od}!=={pv[2],ph[2],pd[2]})$fatal(1,"Three-cycle sync mismatch");
   if(ov&&!old_ov)begin outframe=outframe+1;ox=0;oy=0;frame_pixels=0;ink_count=0;
    if(outframe==5)begin fd=$fopen("red_shapes_preview.ppm","wb");$fwrite(fd,"P6\n1024 600\n255\n");end
   end
   old_ov=ov;
   if(od)begin
    if(^out===1'bx)$fatal(1,"Unknown display pixels");
    if(out==24'hff2020)ink_count=ink_count+1;
    if(outframe==5)$fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);
    if(ox==900&&oy==450)begin
     if(outframe<7&&out!==24'hb0b0b0)$fatal(1,"Original/effect frame tear");
     if(outframe==7&&out!==24'h000000)$fatal(1,"Edge flat background");
     if(outframe==8&&out!==24'hbcbcbc)$fatal(1,"Enhancement value %h",out);
    end
    if(outframe==5&&ox==140&&oy==180&&out!==24'hff2020)$fatal(1,"Moving box did not follow camera-equivalent translation: %h",out);
    frame_pixels=frame_pixels+1;if(ox==1023)begin ox=0;oy=oy+1;end else ox=ox+1;
    if(frame_pixels==614400&&outframe==5)begin if(ink_count<1000)$fatal(1,"Missing annotation ink");$fclose(fd);fd=0;end
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<17;f=f+1)begin
   if(f==8)effect=2;
   v=1;repeat(4)@(negedge clk);v=0;repeat(200)@(negedge clk);
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin de=1;rgb=pixel(x,y,f);@(negedge clk);end
    de=0;h=1;repeat(160)@(negedge clk);h=0;
    if(f==6&&y==300)effect=1;
   end
   repeat(12000)@(negedge clk);
   if(frame_pixels!=614400)$fatal(1,"Output pixel count");
   if(f>=2&&f<9)begin
    if(dut.ana_count!=6)$fatal(1,"Expected five red and one newly recognized blue region, got %0d",dut.ana_count);
    shapes=0;rects=0;circles=0;tris=0;
    for(i=0;i<8;i=i+1)begin rec=dut.stable_objects[i*50+:50];if(rec[47]&&rec[49:48]==1)begin
     shapes=shapes+1;case(rec[46:45])1:circles=circles+1;2:rects=rects+1;3:tris=tris+1;endcase
    end end
    if(shapes!=5||rects!=3||circles!=1||tris!=1)$fatal(1,"Multi-shape classes %0d/%0d/%0d",rects,circles,tris);
   end
   if(f>=11&&f<14&&(!dut.ana_limit||dut.ana_count!=8))$fatal(1,"Eight-target bound/limit indication");
   if(f==16&&(dut.ana_count!=0||dut.stable_objects!=0))$fatal(1,"Empty-frame ghost");
   if(dut.capture_limit||(f<10&&dut.ana_limit)||dut.dropped!=0)$fatal(1,"Unexpected limit/drop");
  end
  en=0;v=1;repeat(4)@(negedge clk);v=0;repeat(4)@(negedge clk);if(dut.front_valid)$fatal(1,"Disable stale mask");
  $display("PASS 17 full 1024x600 video frames: eight-target capacity/overflow, empty-frame cleanup, five separate red targets including a four-pixel gap, three shape classes, original red geometry/classes, newly accepted blue and tiny rejection, stable moving box, three-cycle video, atomic original/edge/enhancement selection and recognition disable");$finish;
 end
 initial begin #180000000;$fatal(1,"Video watchdog");end
endmodule
