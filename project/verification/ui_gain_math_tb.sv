`timescale 1ns/1ps
module ui_gain_math_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0;reg [51:0] cfg=0;reg [9:0] ae=0;
 integer m,g,want,n=0;
 wb_ui_overlay #(.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex"),.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex")) dut(
 .I_clk(clk),.I_rst_n(rst),.I_latency(9'd0),.I_diagnostics(24'd0),.I_underflow(8'd0),.I_config(cfg),.I_ae_telemetry(ae),.I_hist_height(8'd0),.I_hist_valid(1'b0),.O_hist_read_addr(),.O_hist_frame_start(),
 .I_telemetry(37'd0),.I_target_info(52'd0),.I_vsync(1'b0),.I_hsync(1'b0),.I_de(1'b0),.I_data(24'd0),.O_tag_enable(),.O_vsync(),.O_hsync(),.O_de(),.O_data());
 initial begin
  repeat(3)@(negedge clk);rst=1;
  for(m=0;m<2;m=m+1)for(g=0;g<128;g=g+1)begin
   cfg[39]=m;cfg[10:4]=g;ae=g;#1;
   want=g<48?((g+16)*25+4)>>3:g<80?((g-16)*25+2)>>2:((g-48)*25+1)>>1;
   if(dut.gain_scaled!==want||dut.gain100!==(want&1023))$fatal(1,"display gain changed mode%0d g%0d",m,g);
   n=n+1;@(negedge clk);
  end
  $display("PASS shared UI gain product: all 128 gain codes in manual and AE modes, exact original rounding and clipping, 256 combinations");$finish;
 end
endmodule
