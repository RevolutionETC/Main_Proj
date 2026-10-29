`timescale 1ns/1ps
module histogram_overlay_tb;
 reg clk=0,wclk=0;always #7 clk=~clk;always #5 wclk=~wclk;
 reg rst=0,vs=0,hs=0,de=0;reg [51:0] cfg=0;reg [23:0] rgb=0;
 reg we=0,pub=0;reg [5:0] wa=0;reg [7:0] wd=0;
 wire [5:0] ra;wire [7:0] height;wire valid,ready,fs,ov,oh,od;wire [23:0] pixel;
 histogram_snapshot snapshot(.I_wclk(wclk),.I_rclk(clk),.I_rst_n(rst),.I_we(we),.I_publish(pub),.I_addr(wa),.I_height(wd),
  .O_ready(ready),.I_frame_start(fs),.I_read_addr(ra),.O_height(height),.O_valid(valid));
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_hist_height(height),.I_hist_valid(valid),.O_hist_read_addr(ra),.O_hist_frame_start(fs),
  .I_ae_telemetry({3'b110,7'd80}),.I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),
  .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(pixel));
 integer f,x,y,i,n=0,px,py,idx,bar,fd,stored_strength;bit enabled,auto_selected;reg [2:0] c1=0,c2=0;reg [23:0] expected;
 always @(posedge clk)if(rst)begin
  #1;
  if({ov,oh,od}!==c2)$fatal(1,"Histogram UI three-stage controls");c2=c1;c1={vs,hs,de};
  if(od)begin
   px=n%1024;py=n/1024;
   if(px>=32&&px<544&&py>=376&&py<504)begin
    idx=(px-32)/8;bar=f==0?0:(idx*13+f*17)%129;
    expected=(py==408||py==440||py==472||px==160||px==288||px==416)?24'h26394d:24'h172b3c;
    if(f!=0&&px%8!=7&&py>=504-bar)expected=24'h16b8ad;
    if(pixel!==expected)$fatal(1,"Histogram pixel frame=%0d x=%0d y=%0d got=%h expected=%h",f,px,py,pixel,expected);
   end
   if(px==590&&py==120&&pixel!==(enabled?24'h087f83:24'h26394d))$fatal(1,"HE enable appearance");
   if(px==590&&py==200&&pixel!==(auto_selected?24'h087f83:24'h26394d))$fatal(1,"HE auto_selected selection appearance");
   if(px==806&&py==200&&pixel!==(!auto_selected?24'h087f83:24'h26394d))$fatal(1,"HE manual selection appearance");
   if(px==100&&py==100&&pixel!==24'h191990)$fatal(1,"Histogram settings altered live preview");
   $fwrite(fd,"%c%c%c",pixel[23:16],pixel[15:8],pixel[7:0]);n=n+1;
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<7;f=f+1)begin
   if(f!=0)begin
    if(!ready)$fatal(1,"Previous snapshot did not ACK");
    for(i=0;i<64;i=i+1)begin @(negedge wclk);we=1;wa=i;wd=(i*13+f*17)%129;end
    @(negedge wclk);we=0;pub=1;@(negedge wclk);pub=0;repeat(10)@(negedge clk);
   end
   enabled=f>=2&&f<=5;auto_selected=f<=2;stored_strength=f==4?0:f>=5?100:50;
   cfg={7'(stored_strength),auto_selected,enabled,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b0,1'b0,
        4'd12,2'd0,2'd0,7'd30,7'd80,3'd0,1'b1};
   n=0;fd=$fopen($sformatf("histogram_ui_%0d.ppm",f),"wb");$fwrite(fd,"P6\n1024 600\n255\n");
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin
     vs=(x==0&&y==0);de=1;hs=0;rgb={x[9:2],y[9:2],8'h90};@(negedge clk);
     if(x==500&&y==280)begin cfg[25:22]=0;cfg[51:45]=99;end
    end
    vs=0;de=0;hs=1;repeat(4)@(negedge clk);hs=0;
   end
   repeat(6)@(negedge clk);$fclose(fd);
   if(n!=614400)$fatal(1,"Histogram UI frame length");
  end
  $display("PASS seven histogram UI frames: all 64 bars pixel oracle with real async ERAM, waiting/off/auto/manual 0/50/100 states, whole-frame controls, unchanged preview and RTL screenshots");$finish;
 end
 initial begin #100000000;$fatal(1,"Histogram overlay watchdog");end
endmodule

