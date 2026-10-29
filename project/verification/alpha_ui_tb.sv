`timescale 1ns/1ps
module alpha_ui_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,vs=0,hs=0,de=0;
 reg [51:0] cfg;reg [23:0] rgb=0;wire ov,oh,od;wire [23:0] out;
 wb_ui_overlay #(.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex"),.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_latency(9'd0),.I_diagnostics(24'd0),.I_underflow(8'd0),.I_config(cfg),.I_ae_telemetry({3'b110,7'd80}),
  .I_hist_height(8'd0),.I_hist_valid(1'b0),.I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),
  .I_target_info({3'd4,4'd3,12'h060,12'h060,1'b1,20'h01234}),
  .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 function [23:0] scene(input integer x,y);
  integer dx,dy;reg [7:0] a,b,c;begin
   a=70+x/12;b=90+y/6;c=140+((x/32+y/32)%2)*30;
   if(x>620&&x<900&&y>170&&y<440)begin a=40;b=200;c=100;end
   dx=x-300;dy=y-290;if(dx*dx+dy*dy<110*110)begin a=210;b=70;c=55;end
   scene={a,b,c};
  end
 endfunction
 function [23:0] half(input [23:0] a,b);
  integer r,g,c;begin r=(a[23:16]+b[23:16])/2;g=(a[15:8]+b[15:8])/2;c=(a[7:0]+b[7:0])/2;half={r[7:0],g[7:0],c[7:0]};end
 endfunction
 integer f,x,y,page,ox=0,oy=0,n=0,checks=0,fd;reg lastvs=0;reg [23:0] expected,src;
 always @(posedge clk)begin #1;if(rst)begin
  if(ov&&!lastvs)begin ox=0;oy=0;end lastvs=ov;
  if(od)begin
   if(^out===1'bx)$fatal(1,"unknown UI output");
   src=scene(ox,oy);
   if(oy==100||oy==200||oy==300)begin
    if(ox==100||ox==570)begin
     expected=(page!=0&&(ox>=560||(page==12&&oy==300)))?half(24'h111e2c,src):src;
     if(out!==expected)$fatal(1,"alpha page%0d (%0d,%0d) got%h exp%h",page,ox,oy,out,expected);checks=checks+1;
    end
   end
   if(ox==100&&(oy==10||oy==555))begin expected={2'b0,src[23:18],2'b0,src[15:10],2'b0,src[7:2]};
    if(out!==expected)$fatal(1,"top/footer style");checks=checks+1;end
   if(ox==590&&oy==120&&page!=0&&page!=6)begin
    expected=half(24'h26394d,src);if(out!==expected)$fatal(1,"button alpha page%0d %h %h",page,out,expected);checks=checks+1;
   end
   $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);n=n+1;
   if(ox==1023)begin ox=0;oy=oy+1;end else ox=ox+1;
  end
 end end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(f=0;f<5;f=f+1)begin
   page=f==0?0:f==1?9:f==2?7:f==3?12:6;
   cfg={7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b1,1'b0,4'(page),2'd0,2'd0,7'd30,7'd80,3'd7,1'b1};
   fd=$fopen($sformatf("integrated_ui_%0d.ppm",page),"wb");$fwrite(fd,"P6\n1024 600\n255\n");n=0;
   vs=1;repeat(4)@(negedge clk);vs=0;repeat(8)@(negedge clk);
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin de=1;rgb=scene(x,y);@(negedge clk);end
    de=0;hs=1;repeat(4)@(negedge clk);hs=0;
   end
   repeat(8)@(negedge clk);$fclose(fd);if(n!=614400)$fatal(1,"frame count");
  end
  $display("PASS transparent ISP UI: 5 complete frames, exact 50-percent panel/button arithmetic, live left preview, retained dark top/footer, %0d independent pixel probes and RTL previews",checks);$finish;
 end
 initial begin #60000000;$fatal(1,"timeout");end
endmodule
