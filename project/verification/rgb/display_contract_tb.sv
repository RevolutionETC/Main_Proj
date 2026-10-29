`timescale 1ns/1ps
// A valid class alone must not suppress status if no color can be rendered.
// This reproduces a silent-blank condition of the previous display contract;
// it does not assume that every observed board fault has this single cause.
module display_contract_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,start=0,fs=0,wb=1,rb=0;
 reg [399:0] old_objects=0;wire [383:0] geometry;wire [15:0] colors;
 wire [2:0] status;wire old_done,new_done,old_busy,new_busy,valid;wire [1:0] old_ink,new_ink;
 reg [10:0] x=0,y=0;integer i,n;
 genvar k;generate for(k=0;k<8;k=k+1)begin
  assign geometry[k*48+:48]=old_objects[k*50+:48];assign colors[k*2+:2]=old_objects[k*50+48+:2];
 end endgenerate
 previous_color_mask old_display(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(1'b0),.I_write_bank(wb),.I_objects(old_objects),.I_limit(1'b0),.O_busy(old_busy),.O_done(old_done),.I_read_bank(rb),.I_x(x),.I_y(y),.O_color(old_ink));
 target_mask new_display(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(1'b0),.I_enable(1'b1),.I_frame_start(fs),.I_objects(geometry),.I_colors(colors),.I_limit(1'b0),.I_capture_limit(1'b0),.O_busy(new_busy),.O_done(new_done),.O_valid(valid),.O_status(status),.O_count(),.I_x(x),.I_y(y),.O_color(new_ink));
 task batch;begin
  start=1;@(negedge clk);start=0;n=0;
  while(!old_done&&n<50000)begin n=n+1;@(negedge clk);end
  if(!old_done||!new_busy)$fatal(1,"Display contract fixture did not complete");
  rb=wb;fs=1;@(negedge clk);fs=0;repeat(2)@(negedge clk);
 end endtask
 task sample(input integer xx,yy,old_expected,new_expected);begin
  x=xx;y=yy;repeat(2)@(negedge clk);
  if(old_ink!==old_expected[1:0]||new_ink!==new_expected[1:0])$fatal(1,"Display contract %0d,%0d old=%b new=%b",xx,yy,old_ink,new_ink);
 end endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;
  old_objects[0+:50]={2'd0,1'b1,2'd2,11'd100,11'd249,11'd120,11'd239,1'b0};batch();
  sample(100,160,0,0);sample(458,530,0,0);sample(466,530,0,0);if(status!=3)$fatal(1,"NO TARGET footer metadata missing");
  wb=0;old_objects[48+:2]=2;batch();sample(100,160,2,2);sample(128,102,2,2);sample(458,530,0,0);
  $display("PASS previous-display fault replay: valid shape plus unusable color silently removed both box and NO TARGET; new overlay exports NO TARGET for the footer without floating text, while valid blue boxes/text still render correctly");$finish;
 end
 initial begin #1000000;$fatal(1,"Display contract watchdog");end
endmodule
