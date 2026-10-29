`timescale 1ns/1ps
module ui_fix_preview_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,vs=0,hs=0,de=0;
 reg [51:0] cfg;reg [23:0] rgb=0;wire ov,oh,od;wire [23:0] out;
 wb_ui_overlay #(.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex"),
  .TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_latency(9'd0),.I_diagnostics(24'd0),.I_underflow(8'd0),.I_config(cfg),.I_ae_telemetry(10'd80),
  .I_hist_height(8'd0),.I_hist_valid(1'b0),
  .I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),
  .I_target_info({3'd4,4'd3,12'h060,12'h060,1'b1,20'h01234}),
  .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),
  .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 function [23:0] scene(input integer x,y);
  integer dx,dy;reg [7:0] a,b,c;begin
   a=70+x/12;b=90+y/6;c=140+((x/32+y/32)%2)*30;
   if(x>620&&x<900&&y>170&&y<440)begin a=40;b=200;c=100;end
   dx=x-300;dy=y-290;if(dx*dx+dy*dy<110*110)begin a=210;b=70;c=55;end
   scene={a,b,c};
  end
 endfunction
 function [23:0] half(input [23:0] a,b);
  integer rr,gg,bb;begin rr=(a[23:16]+b[23:16])/2;gg=(a[15:8]+b[15:8])/2;bb=(a[7:0]+b[7:0])/2;half={rr[7:0],gg[7:0],bb[7:0]};end
 endfunction
 integer f,x,y,page,hide,ox=0,oy=0,n=0,checks=0,fd;
 reg old_vs=0;reg [23:0] expected,src;reg [2:0] pv=0,ph=0,pd=0;
 always @(posedge clk)begin
  pv={pv[1:0],vs};ph={ph[1:0],hs};pd={pd[1:0],de};#1;
  if(rst)begin
   if({ov,oh,od}!=={pv[2],ph[2],pd[2]})$fatal(1,"preview UI latency changed");
   if(ov&&!old_vs)begin ox=0;oy=0;end old_vs=ov;
   if(od)begin
    if(^out===1'bx)$fatal(1,"unknown preview pixel");src=scene(ox,oy);
    if(ox==590&&(oy==30||oy==72)&&page!=0)begin
     expected=half(src,24'h34495e);if(out!==expected)$fatal(1,"return rectangle clipped");checks=checks+1;
    end
    if(page==0&&hide&&(oy<64||oy>=548))begin
     if(out!==src)$fatal(1,"hidden preview bar/glyph left a pixel %0d,%0d",ox,oy);checks=checks+1;
    end
    if(page==2&&ox==610&&oy==410)begin
     expected=half(src,24'h111e2c);if(out!==expected)$fatal(1,"AWB target button remains");checks=checks+1;
    end
    if(page==8&&ox==590&&oy==280)begin
     expected=half(src,hide?24'h26394d:24'h087f83);if(out!==expected)$fatal(1,"bar toggle state background wrong");checks=checks+1;
    end
    $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);n=n+1;
    if(ox==1023)begin ox=0;oy=oy+1;end else ox=ox+1;
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<5;f=f+1)begin
   page=f==0?7:f<3?8:f==3?0:2;hide=f==2||f==3;
   cfg={7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b1,1'b0,4'(page),2'd0,1'b0,1'(hide),7'd30,7'd80,3'd7,1'b1};
   fd=$fopen($sformatf("ui_fix_%0d_page_%0d_hide_%0d.ppm",f,page,hide),"wb");if(fd==0)$fatal(1,"preview open");
   $fwrite(fd,"P6\n1024 600\n255\n");n=0;
   vs=1;repeat(4)@(negedge clk);vs=0;repeat(8)@(negedge clk);
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin de=1;rgb=scene(x,y);@(negedge clk);end
    de=0;hs=1;repeat(4)@(negedge clk);hs=0;
   end
   repeat(8)@(negedge clk);$fclose(fd);if(n!=614400)$fatal(1,"preview pixel count");
  end
  if(checks<118000)$fatal(1,"preview coverage");
  $display("PASS UI fix RTL previews: five complete 1024x600 frames, exact unclipped return rectangle, bars shown/hidden feature page and unobstructed preview, removed AWB target button, %0d independent probes, unchanged sync latency",checks);
  $finish;
 end
 initial begin #60000000;$fatal(1,"preview watchdog");end
endmodule
