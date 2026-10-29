`timescale 1ns/1ps
module ui_serial_scale_ui2_tb;
 reg clk=0;always #5 clk=~clk;reg [51:0] cfg=0;reg [36:0] tel=0;reg [9:0] ae=0;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(
 .I_clk(clk),.I_rst_n(1'b0),.I_config(cfg),.I_ae_telemetry(ae),.I_hist_height(8'd0),.I_hist_valid(1'b0),
 .I_telemetry(tel),.I_target_info(52'd0),.I_latency(9'd0),.I_diagnostics(24'd0),.I_underflow(8'd0),
 .I_vsync(1'b0),.I_hsync(1'b0),.I_de(1'b0),.I_data(24'd0),.O_hist_read_addr(),.O_hist_frame_start(),
 .O_tag_enable(),.O_vsync(),.O_hsync(),.O_de(),.O_data());
 optimization_reference_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) reference(
 .I_clk(clk),.I_rst_n(1'b0),.I_config(cfg),.I_ae_telemetry(ae),.I_hist_height(8'd0),.I_hist_valid(1'b0),
 .I_telemetry(tel),.I_target_info(52'd0),.I_latency(9'd0),.I_diagnostics(24'd0),.I_underflow(8'd0),
 .I_vsync(1'b0),.I_hsync(1'b0),.I_de(1'b0),.I_data(24'd0),.O_hist_read_addr(),.O_hist_frame_start(),
 .O_tag_enable(),.O_vsync(),.O_hsync(),.O_de(),.O_data());
 integer state,count,pos,n,field,mode,wanted,selected,checks=0;reg [51:0] packet=0;reg force_start=0;reg [3:0] force_field=0;
 initial begin
  force dut.decimal_start=force_start;force dut.decimal_field=force_field;
  repeat(3)@(negedge clk);
  for(state=0;state<8;state=state+1)for(count=0;count<16;count=count+1)for(pos=0;pos<32;pos=pos+1)begin
   packet={3'(state),4'(count),45'd0};
   if(dut.hud_char(2'd0,5'(pos),packet)!==reference.hud_char(2'd0,5'(pos),packet))$fatal(1,"status ASCII mismatch %0d/%0d/%0d",state,count,pos);
   checks=checks+1;
  end
  force_start=1;
  for(mode=0;mode<2;mode=mode+1)for(n=0;n<128;n=n+1)begin
   cfg[39]=1'(mode);cfg[10:4]=7'(n);ae[6:0]=7'(127-n);#1;
   selected=mode?127-n:n;
   wanted=selected<48?((selected+16)*25+4)/8:selected<80?((selected-16)*25+2)/4:((selected-48)*25+1)/2;
   if(dut.serial_scale100!==10'(wanted))$fatal(1,"serial gain scale mismatch %0d/%0d",mode,n);
   checks=checks+1;
  end
  force_start=0;
  for(n=0;n<4096;n=n+1)begin
   tel={1'b1,12'(n),12'((n+123)%4096),12'(n^2210)};
   for(field=0;field<3;field=field+1)begin
    force_field=4'(field);#1;selected=field==0?n:field==1?(n+123)%4096:n^2210;
    wanted=(selected*100+512)/1024;
    if(dut.serial_scale100!==10'(wanted))$fatal(1,"serial RGB scale mismatch %0d/%0d got%0d expected%0d",field,n,dut.serial_scale100,wanted);
    checks=checks+1;
   end
  end
  $display("PASS shared UI scale/status prototype: %0d exhaustive comparisons covering all 8 status states/16 count nibbles/32 positions, all 128 gain codes in both manual/AE modes, and all 4096 values in every RGB slot",checks);$finish;
 end
endmodule
