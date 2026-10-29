`timescale 1ns/1ps
module info_preview_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,h=0,de=0;
 reg [51:0] cfg=0,info=0;reg [23:0] rgb=0,diagnostics=0;reg [8:0] latency=0;reg [7:0] underflow=0;
 wire ov,oh,od;wire [23:0] out;
 wb_ui_overlay #(.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex"),
  .TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_ae_telemetry(10'd80),
  .I_hist_height(8'd0),.I_hist_valid(1'b0),.I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),
  .I_latency(latency),.I_diagnostics(diagnostics),.I_underflow(underflow),.I_target_info(info),
  .I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
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
  pv={pv[1:0],v};ph={ph[1:0],h};pd={pd[1:0],de};#1;
  if(rst)begin
   if({ov,oh,od}!=={pv[2],ph[2],pd[2]})$fatal(1,"information preview latency changed");
   if(ov&&!old_vs)begin ox=0;oy=0;end old_vs=ov;
   if(od)begin
    if(^out===1'bx)$fatal(1,"unknown information preview pixel");src=scene(ox,oy);
    if(ox==590&&(oy==30||oy==72))begin
     expected=half(src,24'h34495e);if(out!==expected)$fatal(1,"return button clipping regression");checks=checks+1;
    end
    if(page==9&&ox==590&&oy==360)begin
     expected=half(src,24'h26394d);if(out!==expected)$fatal(1,"new information button not below feature library");checks=checks+1;
    end
    if(hide&&ox<560&&(oy<64||oy>=548))begin
     if(out!==src)$fatal(1,"information page changed hidden left bars");checks=checks+1;
    end
    $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);n=n+1;
    if(ox==1023)begin ox=0;oy=oy+1;end else ox=ox+1;
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<3;f=f+1)begin
   page=f==0?9:13;hide=f==2;
   cfg={7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b1,1'b0,4'(page),2'd0,1'b0,1'(hide),7'd30,7'd80,3'd7,1'b1};
   latency=f==2?9'd0:{1'b1,8'd3};diagnostics=f==2?24'hffff64:{8'd5,8'd2,8'd0};underflow=f==2?9:1;
   info=f==2?{3'd3,4'd0,12'h060,12'h030,1'b0,20'h00000}:{3'd4,4'd3,12'h060,12'h030,1'b1,20'h01234};
   fd=$fopen($sformatf("info_swipe_%0d.ppm",f),"wb");if(fd==0)$fatal(1,"preview open");
   $fwrite(fd,"P6\n1024 600\n255\n");n=0;
   v=1;repeat(4)@(negedge clk);v=0;repeat(8)@(negedge clk);
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin de=1;rgb=scene(x,y);@(negedge clk);end
    de=0;h=1;repeat(4)@(negedge clk);h=0;
   end
   repeat(8)@(negedge clk);$fclose(fd);if(n!=614400)$fatal(1,"preview pixel count");
  end
  if(checks<64900)$fatal(1,"information preview probe coverage");
  $display("PASS information RTL previews: three complete 1024x600 frames, main-menu fourth entry below feature library, combined diagnostics and RUN/FPS/DET/LAT, valid/invalid age, bar-hidden page, unclipped return and %0d independent probes",checks);$finish;
 end
 initial begin #40000000;$fatal(1,"information preview watchdog");end
endmodule
