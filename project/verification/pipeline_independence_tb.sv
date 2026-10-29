`timescale 1ns/1ps
// Parallel reference detector proves every recognition decision is independent
// of the selected display filter. Also inspect real coloured box pixels.
module pipeline_independence_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,h=0,de=0;reg [23:0] rgb=0;reg [2:0] mode=0;
 wire ov,oh,od;wire [23:0] out;
 red_target_video #(.USE_ISP_FILTERS(1),.WIDTH(256),.HEIGHT(160),.HTOTAL(420)) filtered(
  .I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_page(3'd0),.I_effect(2'd0),.I_image_mode(mode),
  .I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 red_target_video #(.WIDTH(256),.HEIGHT(160)) reference(
  .I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_page(3'd0),.I_effect(2'd0),.I_image_mode(3'd0),
  .I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(),.O_hsync(),.O_de(),.O_data());
 integer f,x,y,ox=0,oy=0,n=0,decisions=0,boxes=0;reg oldv=0;
 always @(posedge clk)begin #1;if(rst)begin
  if(filtered.ana_done!==reference.ana_done||filtered.ana_geometry!==reference.ana_geometry||filtered.ana_colors!==reference.ana_colors||filtered.stable_geometry!==reference.stable_geometry||filtered.stable_colors!==reference.stable_colors)
   $fatal(1,"filter changed raw RGB recognition");
  if(filtered.ana_done)decisions=decisions+1;
  if(ov&&!oldv)begin ox=0;oy=0;n=0;end oldv=ov;
  if(od)begin
   if(f>=3&&oy==95&&(ox==20||ox==100||ox==180))begin
    if(out!==(ox==20?24'hff2020:ox==100?24'h2860ff:24'h20c040))$fatal(1,"wrong filtered annotation mode%0d x%0d got%h",mode,ox,out);boxes=boxes+1;
   end
   n=n+1;if(ox==255)begin ox=0;oy=oy+1;end else ox=ox+1;
  end
 end end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(f=0;f<8;f=f+1)begin
   case(f%5)0:mode=0;1:mode=4;2:mode=5;3:mode=6;4:mode=7;endcase
   v=1;repeat(4)@(negedge clk);v=0;repeat(200)@(negedge clk);
   for(y=0;y<160;y=y+1)begin
    for(x=0;x<256;x=x+1)begin
     rgb=24'h606060;
     if(y>=60&&y<110)begin
      if(x>=20&&x<70)rgb=24'hd02020;
      if(x>=100&&x<150)rgb=24'h2050d0;
      if(x>=180&&x<230)rgb=24'h20d020;
     end
     de=1;@(negedge clk);
    end
    de=0;h=1;repeat(164)@(negedge clk);h=0;
   end
   repeat(20000)@(negedge clk);
   if(n!=40960||filtered.dropped!=0)$fatal(1,"frame length/drop");
  end
  if(decisions<5||boxes!=15)$fatal(1,"insufficient coverage");
  $display("PASS filter/recognition independence: 8 continuous RGB frames, cycle-exact classifier/tracker decisions against unfiltered reference, 15 actual coloured box probes across all five display choices");$finish;
 end
 initial begin #20000000;$fatal(1,"timeout");end
endmodule
