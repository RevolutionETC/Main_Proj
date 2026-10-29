`timescale 1ns/1ps
// Model the real three-stage detector followed by the three-stage UI.
// A single base-frame snapshot must remain coherent even if the mailbox
// changes before the detector's delayed VS reaches the UI.
module ui_frame_config_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,bv=0,bh=0,bd=0;reg [51:0] request=0,frame_cfg=0;
 reg bv_d=0;reg [2:0] pv=0,ph=0,pd=0;reg [23:0] rgb[0:2];integer k;
 always @(posedge clk)begin
  if(!rst)begin frame_cfg<=0;bv_d<=0;pv<=0;ph<=0;pd<=0;end
  else begin
   bv_d<=bv;if(bv&&!bv_d)frame_cfg<=request;
   pv<={pv[1:0],bv};ph<={ph[1:0],bh};pd<={pd[1:0],bd};
   rgb[0]<=24'h102030;for(k=1;k<3;k=k+1)rgb[k]<=rgb[k-1];
  end
 end
 wire ov,oh,od,tag;wire [23:0] data;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_latency(9'd0),.I_diagnostics(24'd0),.I_underflow(8'd0),.I_config(frame_cfg),.I_ae_telemetry(10'd80),.I_telemetry(37'd0),
  .I_hist_height(8'd0),.I_hist_valid(1'b0),.I_vsync(pv[2]),.I_hsync(ph[2]),.I_de(pd[2]),.I_data(rgb[2]),
  .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(data),.O_tag_enable(tag));
 bit expected_tag[0:3071];reg [23:0] expected_rgb[0:3071];
 integer put=0,take=0,f,x,y,page;bit watermark,bars_hide;
 always @(posedge clk)if(rst)begin
  if(bd)begin expected_tag[put]=watermark&&page==0;
   // All sampled rows are y=0..15, on the left of the popup panel.
   expected_rgb[put]=bars_hide?24'h102030:24'h04080c;put=put+1;end
  #1;
  if(od)begin
   if(dut.page!==page[3:0])$fatal(1,"Base-frame page snapshot mismatch expected=%0d got=%0d",page,dut.page);
   if(take>=put||tag!==expected_tag[take]||data!==expected_rgb[take])$fatal(1,"Base-frame/UI/watermark mismatch at pixel %0d",take);
   if(ov!==(take%512==0))$fatal(1,"First pixel VS changed");take=take+1;
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<6;f=f+1)begin
   page=f==1?12:f==4?7:0;watermark=f!=2;bars_hide=f%2;request=0;request[0]=1;request[25:22]=page;request[26]=watermark;request[18]=bars_hide;
   for(y=0;y<16;y=y+1)begin
    for(x=0;x<32;x=x+1)begin
     bv=x==0&&y==0;bd=1;bh=0;@(negedge clk);
     if(x==0&&y==0)begin request[25:22]=9;request[26]=!watermark;request[18]=!bars_hide;end
    end
    bv=0;bd=0;bh=1;repeat(4)@(negedge clk);bh=0;
   end
   repeat(10)@(negedge clk);
  end
  if(put!=3072||take!=put)$fatal(1,"Frame snapshot coverage");
  $display("PASS one base-frame config snapshot through real detector/UI delays, near-VS mailbox updates, six page/tag/bar-hide combinations, exact RGB and pixel-aligned watermark enable");$finish;
 end
 initial begin #100000;$fatal(1,"Frame-config watchdog");end
endmodule
