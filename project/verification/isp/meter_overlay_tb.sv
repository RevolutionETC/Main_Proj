`timescale 1ns/1ps
module meter_overlay_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,vs=0,hs=0,de=0;reg [42:0] cfg=0;
 wire ov,oh,od;wire [23:0] pixel;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_ae_telemetry(10'd80),
  .I_telemetry({1'b0,12'd1024,12'd1024,12'd1024}),
  .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(24'h102030),
  .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(pixel));
 // Independent pixel-space oracle: integer modulo/grid boundaries rather
 // than DUT wires. All non-HUD preview pixels are checked, on and off.
 function bit edge_ref(input integer x,y,l,t,r,b);
  edge_ref=x>=l&&x<r&&y>=t&&y<b&&(x-l<2||r-x<=2||y-t<2||b-y<=2);
 endfunction
 function bit region_ref(input integer x,y,m);
  case(m)
   0:region_ref=edge_ref(x,y,448,236,576,364);
   1:region_ref=edge_ref(x,y,0,0,1024,600)||edge_ref(x,y,256,150,768,450);
   2:region_ref=edge_ref(x,y,0,0,1024,600)||(x%128<2)||(y%120<2);
   3:region_ref=edge_ref(x,y,392,180,632,420);
  endcase
 endfunction
 integer f,x,y,n=0,px,py,fd,red_count,expected_count,m;
 bit enabled;reg [2:0] controls=0,controls2=0;reg [23:0] expected;
 always @(posedge clk)if(rst)begin
  #1;
  if({ov,oh,od}!==controls2)$fatal(1,"Meter overlay altered control latency");
  controls2=controls;controls={vs,hs,de};
  if(od)begin
   px=n%1024;py=n/1024;
   if((py>=64&&py<548)||px<2||py<2||py>=598)begin
    expected=(enabled&&region_ref(px,py,m))?24'hff0000:
             (py<64||py>=548)?24'h04080c:24'h102030;
    if(pixel!==expected)$fatal(1,"Meter overlay frame=%0d mode=%0d x=%0d y=%0d got=%h expected=%h",f,m,px,py,pixel,expected);
    if(pixel==24'hff0000)red_count=red_count+1;
    if(enabled&&region_ref(px,py,m))expected_count=expected_count+1;
   end
   $fwrite(fd,"%c%c%c",pixel[23:16],pixel[15:8],pixel[7:0]);n=n+1;
  end
 end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(f=0;f<6;f=f+1)begin
   m=f%4;enabled=f!=4;
   // Last frame explicitly shows regions with automatic gain disabled.
   cfg={enabled,2'(m),1'(f!=5),1'b0,5'd0,5'd0,1'b0,1'b0,
        4'd0,2'd0,2'd0,7'd30,7'd80,3'd0,1'b1};
   n=0;red_count=0;expected_count=0;
   fd=$fopen($sformatf("meter_mode_%0d.ppm",f),"wb");$fwrite(fd,"P6\n1024 600\n255\n");
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin
     de=1;hs=0;vs=(x==0&&y==0);@(negedge clk);
     // A mid-frame request must not tear mode or visibility.
     if(x==500&&y==300)begin cfg[42]=!enabled;cfg[41:40]=3-m;end
    end
    de=0;vs=0;hs=1;repeat(3)@(negedge clk);hs=0;
   end
   repeat(5)@(negedge clk);$fclose(fd);
   if(n!=614400||red_count!=expected_count||(!enabled&&red_count!=0))$fatal(1,"Meter overlay count/on-off mismatch");
  end
  $display("PASS all four 1024x600 red metering geometries, every non-HUD pixel, on/off, manual-mode visibility, coincident first pixel, mid-frame atomicity and exact control latency");$finish;
 end
 initial begin #50000000;$fatal(1,"Meter overlay watchdog");end
endmodule
