`timescale 1ns/1ps
module ui_optimized_equivalence_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,vs=0,hs=0,de=0;reg [23:0] rgb=0;
 reg [51:0] cfg=0;reg [36:0] tel={1'b1,12'd1500,12'd1024,12'd2500};
 reg [8:0] age={1'b1,8'd255};reg [23:0] diagnostic={8'd255,8'd10,8'd100};
 reg [51:0] info={3'd4,4'd8,12'h123,12'h098,1'b1,20'h12345};
 wire v0,h0,d0,t0,v1,h1,d1,t1;wire [23:0] out0,out1;wire [5:0] ha0,ha1;wire hf0,hf1;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(
 .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_ae_telemetry(10'd80),.I_hist_height(8'd80),.I_hist_valid(1'b1),
 .I_telemetry(tel),.I_target_info(info),.I_latency(age),.I_diagnostics(diagnostic),.I_underflow(8'd9),
 .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),.O_hist_read_addr(ha0),.O_hist_frame_start(hf0),
 .O_tag_enable(t0),.O_vsync(v0),.O_hsync(h0),.O_de(d0),.O_data(out0));
 optimization_reference_ui_overlay #(.TEXT_FILE("../qualified_ui_assets/wb_ui_text.hex"),.FONT_FILE("../qualified_ui_assets/wb_ui_font.hex")) reference(
 .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_ae_telemetry(10'd80),.I_hist_height(8'd80),.I_hist_valid(1'b1),
 .I_telemetry(tel),.I_target_info(info),.I_latency(age),.I_diagnostics(diagnostic),.I_underflow(8'd9),
 .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),.O_hist_read_addr(ha1),.O_hist_frame_start(hf1),
 .O_tag_enable(t1),.O_vsync(v1),.O_hsync(h1),.O_de(d1),.O_data(out1));
 integer f,x,y,checks=0,pixels=0;reg [23:0] prng=24'h123456;
 always @(posedge clk)begin #1;if(rst)begin
  checks=checks+1;if(d0)pixels=pixels+1;
  if({v0,h0,d0,t0,out0,ha0,hf0}!=={v1,h1,d1,t1,out1,ha1,hf1})
   $fatal(1,"UI pixel/control equivalence f=%0d x=%0d y=%0d got%h expected%h",f,x,y,out0,out1);
 end end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(f=0;f<4;f=f+1)begin
   cfg={7'd87,1'b0,1'b1,1'b1,2'd2,1'b1,1'b0,5'd8,5'b10110,1'b1,1'b1,4'd0,2'd0,2'd0,7'd75,7'd80,3'd7,1'b1};
   case(f)0:cfg[25:22]=0;1:cfg[25:22]=13;2:cfg[25:22]=6;3:cfg[25:22]=12;endcase
   info[51:49]=f==0?4:f==1?2:3;age={1'(f!=0),8'(255-f*60)};
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin
     de=1;hs=0;vs=x==0&&y==0;
     prng={prng[22:0],prng[23]^prng[22]^prng[21]^prng[16]};rgb=prng;
     @(negedge clk);
     if(x==500&&y==300)begin cfg[18]=1;tel=0;diagnostic=0;info=0;age=0;end
    end
    de=0;vs=0;hs=1;repeat(3)@(negedge clk);hs=0;
   end
   repeat(5)@(negedge clk);
  end
  if(pixels!=2457600)$fatal(1,"short full-frame comparison");
  $display("PASS UI full-output equivalence: %0d pixels and %0d cycles across preview/HUD, information, full colour-shift grid and histogram pages; all pixels, sync/tag/histogram control and frame atomicity identical to frozen INFO_SWIPE baseline",pixels,checks);$finish;
 end
 initial begin #30000000;$fatal(1,"UI optimized equivalence watchdog");end
endmodule
