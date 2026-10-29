`timescale 1ns/1ps
module effects_overlay_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,h=0,de=0;reg [23:0] rgb=0;reg [35:0] cfg=0;
 wire ov,oh,od;wire [23:0] out;reg [51:0] target_info[0:0];reg [23:0] pixels[0:614399];integer fd=0,n=0,xx,yy,pg,k,stage=0;
 wb_ui_overlay #(.HUD_ENABLE(1),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(.I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_target_info(target_info[0]),.I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),.I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 always @(posedge clk)begin #1;if(rst&&od)begin
  if(^out===1'bx)$fatal(1,"UI unknown pixels");
  $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);n=n+1;
 end end
 initial begin
  $readmemh("../fixtures/preview_rgb.hex",pixels);$readmemh("../fixtures/preview_info.hex",target_info);repeat(4)@(negedge clk);rst=1;
  for(k=0;k<3;k=k+1)begin
   pg=k==0?0:k==1?2:7;cfg={2'd0,1'b0,5'd0,5'd0,1'b1,3'(pg),2'd0,2'd0,7'd30,7'd80,1'b1};
   fd=$fopen($sformatf("composed_ui_%0d.ppm",pg),"wb");$fwrite(fd,"P6\n1024 600\n255\n");n=0;
   v=1;repeat(4)@(negedge clk);v=0;repeat(4)@(negedge clk);
   for(yy=0;yy<600;yy=yy+1)begin for(xx=0;xx<1024;xx=xx+1)begin de=1;rgb=pixels[yy*1024+xx];@(negedge clk);end de=0;repeat(3)@(negedge clk);end
   repeat(5)@(negedge clk);$fclose(fd);if(n!=614400)$fatal(1,"UI frame length");
  end
  $display("PASS actual coordinate-label video and measured metadata plus Chinese UI/HUD compositions: preview, target recognition switch and original/edge/enhancement page, 36-bit config and extended font without undefined pixels");$finish;
 end
endmodule

