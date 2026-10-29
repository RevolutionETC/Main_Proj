`timescale 1ns/1ps
// Side-by-side exact pixel comparison with the previously delivered UI_FIX.
// Only the intentional "long press" -> "left swipe" hint rectangle is excluded.
module info_bars_equivalence_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,h=0,de=0;reg [23:0] rgb=0;reg [51:0] cfg=0;
 reg [8:0] latency=9'h100;reg [23:0] diagnostics=0;reg [7:0] underflow=0;
 wire ov,oh,od,rv,rh,rd;wire [23:0] out,ref_out;
 wb_ui_overlay #(.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex"),
  .TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_ae_telemetry(10'd80),
  .I_hist_height(8'd0),.I_hist_valid(1'b0),
  .I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),
  .I_latency(latency),.I_diagnostics(diagnostics),.I_underflow(underflow),
  .I_target_info({3'd4,4'd3,12'h060,12'h030,1'b1,20'h01234}),
  .I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),
  .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 reference_ui_overlay #(.FONT_FILE("../reference_ui_assets/wb_ui_font.hex"),
  .TEXT_FILE("../reference_ui_assets/wb_ui_text.hex")) baseline(
  .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_ae_telemetry(10'd80),
  .I_hist_height(8'd0),.I_hist_valid(1'b0),
  .I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),
  .I_target_info({3'd4,4'd3,12'h060,12'h030,1'b1,20'h01234}),
  .I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),
  .O_vsync(rv),.O_hsync(rh),.O_de(rd),.O_data(ref_out));
 function [23:0] scene(input integer x,y);
  reg [7:0] a,b,c;begin a=13+x%229;b=9+y%239;c=(x+y)%253;scene={a,b,c};end
 endfunction
 integer f,x,y,width,page,hide,k,xx,yy,pp,pixels=0,checks=0,top_checks=0,bottom_checks=0;
 integer px[0:2],py[0:2],pg[0:2];reg [2:0] pv=0,ph=0,pd=0;reg verify;
 always @(posedge clk)begin
  pv={pv[1:0],v};ph={ph[1:0],h};pd={pd[1:0],de};
  for(k=2;k>0;k=k-1)begin px[k]=px[k-1];py[k]=py[k-1];pg[k]=pg[k-1];end
  px[0]=x;py[0]=y;pg[0]=page;#1;
  if(rst)begin
   if({ov,oh,od}!=={rv,rh,rd}||{ov,oh,od}!=={pv[2],ph[2],pd[2]})$fatal(1,"baseline UI synchronization changed");
   if(od)begin
    pixels=pixels+1;xx=px[2];yy=py[2];pp=pg[2];
    verify=(yy<64||yy>=548)&&(pp==0||xx<560);
    if(pp==0&&xx>=16&&xx<208&&yy>=574&&yy<598)verify=0;
    if(verify)begin
     checks=checks+1;if(yy<64)top_checks=top_checks+1;else bottom_checks=bottom_checks+1;
     if(out!==ref_out)$fatal(1,"existing bar pixel changed page%0d (%0d,%0d) new=%h old=%h",pp,xx,yy,out,ref_out);
    end
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<16;f=f+1)begin
   page=f<14?f:0;hide=f>=14;
   cfg={7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b1,1'b0,4'(page),2'(f%2?2:0),1'b0,1'(hide),7'd30,7'd80,3'd7,1'(f!=15)};
   latency={1'(f%2),8'(17*f)};diagnostics=24'h123456+f;underflow=f;
   for(y=0;y<600;y=y+1)begin
    width=(y<64||y>=548)?(page==0?1024:560):1;
    for(x=0;x<width;x=x+1)begin
     if(x==0&&y==0&&f%2==0)begin v=1;de=0;repeat(3)@(negedge clk);v=0;repeat(3)@(negedge clk);end
     v=(f%2==1&&x==0&&y==0);de=1;rgb=scene(x,y);@(negedge clk);
     if(x==0&&y==200)begin latency=~latency;diagnostics=~diagnostics;underflow=~underflow;end
    end
    v=0;de=0;h=1;repeat(3)@(negedge clk);h=0;
   end
   repeat(8)@(negedge clk);
  end
  if(checks<1000000||top_checks<500000||bottom_checks<400000)$fatal(1,"insufficient baseline bar coverage");
  $display("PASS existing-bar exact equivalence: %0d compared top/bottom pixels across pages0..13 and both hidden/offline preview states, all status/count/FPS/DET/LAT/filter/WB/gain pixels unchanged; only intentional gesture-hint text excluded",checks);$finish;
 end
 initial begin #50000000;$fatal(1,"existing-bar comparison watchdog");end
endmodule
