`timescale 1ns/1ps
// Compare the actual successful red RTL against the rebuild, cycle by cycle.
// Deliberate weak blue/green background speckles expose the former broad gate.
module red_equivalence_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,h=0,de=0,en=1;reg [23:0] rgb=0;reg [1:0] effect=0;
 wire nv,nh,nd,rv,rh,rd;wire [23:0] np,rp;
 red_target_video dut(.I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_page(3'd0),.I_effect(effect),.I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(nv),.O_hsync(nh),.O_de(nd),.O_data(np));
 reference_red_target_video refdut(.I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_page(3'd0),.I_effect(effect),.I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(rv),.O_hsync(rh),.O_de(rd),.O_data(rp));
 // Same capture capacity, fed the previous version's broad color gates.
 wire [9:0] r={2'd0,rgb[23:16]},g={2'd0,rgb[15:8]},b={2'd0,rgb[7:0]};
 wire wb=b>=48&&b>=g+10&&b>=r+16&&16*b>=17*g&&8*b>=9*r;
 wire wg=g>=48&&g>=r+12&&g>=b+10&&8*g>=9*r&&16*g>=17*b;
 reg [1:0] wide_color=0;
 always @(posedge clk)wide_color<=dut.red?1:(wb||wg)?2:0;
 wire wide_limit;wire [31:0] wide_drops;wire [39:0] wide_data;
 reference_color_components #(.MAX_LINE_RUNS(32)) former_capture(.I_clk(clk),.I_rst_n(rst),.I_frame_start(dut.fs1),.I_enable(dut.en1),.I_de(dut.d1),.I_x(dut.x1),.I_y(dut.y1),.I_color(wide_color),.I_analyzer_busy(1'b0),.O_start(),.O_bank(),.O_runs(),.O_limit(wide_limit),.O_dropped(wide_drops),.I_read_bank(1'b0),.I_read_addr(12'd0),.O_read_data(wide_data),.I_label(7'd0),.O_root());
 integer f,x,y,i,pixels=0,batches=0,stable_batches=0;reg [47:0] rec;
 function [23:0] pixel(input integer xx,yy,ff);integer cx;begin
  cx=100+4*ff;pixel=24'hb0b0b0;
  // 64 isolated runs per selected line: these are weak casts, not targets.
  if(yy%7==0&&xx%16<3)pixel=(xx/16)%2==0?24'h5c707e:24'h708274;
  if((xx>=cx&&xx<=cx+145&&yy>=120&&yy<=230)||
     ((xx-700)*(xx-700)+(yy-220)*(yy-220)<=52*52)||
     (yy>=140&&yy<=285&&(xx-450)*145<=(yy-140)*70&&(450-xx)*145<=(yy-140)*70))pixel=24'hd02020;
  if(ff>=8)pixel=24'hb0b0b0;
 end endfunction
 always @(posedge clk)begin #1;if(rst)begin
  if({nv,nh,nd}!=={rv,rh,rd}||(np!==rp&&np!==24'hff2020&&rp!==24'hff2020))$fatal(1,"Red video differs from successful baseline f=%0d pixel=%0d: %h/%h",f,pixels,np,rp);
  if(nd)pixels=pixels+1;
  if(dut.capture_start!==refdut.capture_start||dut.ana_done!==refdut.ana_done||dut.stable_done!==refdut.stable_done)$fatal(1,"Red capture/classification schedule changed");
  if(dut.ana_done)begin
   batches=batches+1;if(dut.ana_count!==refdut.ana_count)$fatal(1,"Red component count changed");
   for(i=0;i<8;i=i+1)if(dut.ana_objects[i*50+:48]!==refdut.ana_objects[i*48+:48])$fatal(1,"Red measured descriptor changed");
  end
  if(dut.stable_done)begin
   stable_batches=stable_batches+1;
   for(i=0;i<8;i=i+1)if(dut.stable_objects[i*50+:48]!==refdut.stable_objects[i*48+:48])$fatal(1,"Red stable class/box differs");
  end
 end end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<11;f=f+1)begin
   if(f==5)effect=1;if(f==7)effect=2;
   v=1;repeat(4)@(negedge clk);v=0;repeat(200)@(negedge clk);
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin de=1;rgb=pixel(x,y,f);@(negedge clk);end
    de=0;h=1;repeat(160)@(negedge clk);h=0;
   end
   repeat(12000)@(negedge clk);
   if(dut.capture_limit||dut.dropped!=0)$fatal(1,"Weak cast interfered with successful red detection");
   if(f>=2&&f<8)begin
    if(dut.ana_count!=3)$fatal(1,"Missing stable red objects");
    for(i=0;i<3;i=i+1)begin rec=dut.stable_objects[i*50+:48];if(!rec[47])$fatal(1,"Red flicker with weak blue/green background");end
   end
  end
  if(pixels!=11*614400||batches<9||stable_batches<9||wide_drops==0)$fatal(1,"Equivalence/old-gate noise scenario not exercised");
  en=0;v=1;repeat(10)@(negedge clk);
  $display("PASS red baseline equivalence: 6758400 video pixels, unchanged non-annotation pixels and exact descriptor/schedule/class/motion equality; coordinate/status annotations intentionally differ, original/edge/enhance, weak blue/green speckles rejected; former broad-gate capture drops=%0d",wide_drops);$finish;
 end
 initial begin #150000000;$fatal(1,"Equivalence watchdog");end
endmodule
