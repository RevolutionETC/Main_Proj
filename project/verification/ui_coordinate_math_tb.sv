`timescale 1ns/1ps
module ui_coordinate_math_tb;
 reg clk=0;always #5 clk=~clk;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(
 .I_clk(clk),.I_rst_n(1'b0),.I_config(52'd0),.I_ae_telemetry(10'd0),.I_hist_height(8'd0),.I_hist_valid(1'b0),
 .I_telemetry(37'd0),.I_target_info(52'd0),.I_latency(9'd0),.I_diagnostics(24'd0),.I_underflow(8'd0),
 .I_vsync(1'b0),.I_hsync(1'b0),.I_de(1'b0),.I_data(24'd0),.O_hist_read_addr(),.O_hist_frame_start(),
 .O_tag_enable(),.O_vsync(),.O_hsync(),.O_de(),.O_data());
 integer n,d,q,r,checks=0;reg [6:0] v;
 initial begin
  for(n=0;n<64;n=n+1)begin
   v=dut.divide_by3_6(6'(n));
   if(v[6:2]!==5'(n/3)||v[1:0]!==2'(n%3))$fatal(1,"six-bit quotient/remainder mismatch %0d",n);
   checks=checks+1;
  end
  for(d=0;d<384;d=d+1)begin
   v=dut.divide_by3_6(6'(d/8));q=v[6:2];r={v[1:0],3'(d%8)};
   if(q!=d/24||r!=d%24)$fatal(1,"text coordinate mismatch %0d",d);
   checks=checks+1;
  end
  for(d=0;d<144;d=d+1)begin
   v=dut.divide_by3_6(6'(d/4));q=v[6:2];r={v[1:0],1'((d/2)%2)};
   if(q!=d/12||r!=(d/2)%6)$fatal(1,"HUD coordinate mismatch %0d",d);
   checks=checks+1;
  end
  for(d=0;d<256;d=d+1)begin
   if(dut.grid14(8'(d))!==(d%14==0))$fatal(1,"grid coordinate mismatch %0d",d);
   checks=checks+1;
  end
  $display("PASS UI coordinate arithmetic: %0d independent integer-division/remainder comparisons across all 64 decoder values, 384 text pixels, 144 HUD pixels and all 256 grid coordinates",checks);$finish;
 end
endmodule
