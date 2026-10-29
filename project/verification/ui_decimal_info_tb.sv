`timescale 1ns/1ps
module ui_decimal_info_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,vs=0,de=0;
 reg [51:0] cfg=0;reg [36:0] tel=0;reg [9:0] agc=80;
 reg [8:0] age=0;reg [23:0] counters=0;reg [7:0] underflow=0;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_telemetry(tel),.I_ae_telemetry(agc),
  .I_latency(age),.I_diagnostics(counters),.I_underflow(underflow),.I_target_info(52'd0),
  .I_hist_height(8'd0),.I_hist_valid(1'b0),.I_vsync(vs),.I_hsync(1'b0),.I_de(de),.I_data(24'd0),.O_vsync(),.O_hsync(),.O_de(),.O_data());
 reference_ui_overlay #(.TEXT_FILE("../reference_ui_assets/wb_ui_text.hex"),.FONT_FILE("../reference_ui_assets/wb_ui_font.hex")) baseline(
  .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_telemetry(tel),.I_ae_telemetry(agc),.I_target_info(52'd0),
  .I_hist_height(8'd0),.I_hist_valid(1'b0),.I_vsync(vs),.I_hsync(1'b0),.I_de(de),.I_data(24'd0),.O_vsync(),.O_hsync(),.O_de(),.O_data());
 function [15:0] bcd(input integer n);
  begin bcd={4'((n/1000)%10),4'((n/100)%10),4'((n/10)%10),4'(n%10)};end
 endfunction
 integer n,k,a,r,g,b,actual,shown,gain_value,checks=0;
 integer va,vp,vd,vo,vu;
 reg [15:0] lock_gain,lock_r,lock_g,lock_b;
 always @(posedge clk)begin #1;
  if(rst)begin
   checks=checks+1;
   if({dut.dec_gain,dut.dec_r,dut.dec_g,dut.dec_b}!=={baseline.dec_gain,baseline.dec_r,baseline.dec_g,baseline.dec_b})
    $fatal(1,"first four numeric results/completion cycles changed");
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(n=0;n<256;n=n+1)begin
   a=n%2;k=16+n%74;actual=105-k;
   r=(n*17)%4096;g=(n*31)%4096;b=(n*97)%4096;
   va=n;vp=(n+1)%256;vd=(n*3)%256;vo=n^85;vu=255-n;
   cfg={7'd50,1'b1,1'b0,1'b0,2'd1,1'(a),1'b0,5'd0,5'd0,1'b0,1'b0,4'd13,2'd0,2'd0,7'd30,7'(k),3'd0,1'b1};
   tel={1'b1,12'(r),12'(g),12'(b)};agc={3'b110,7'(actual)};
   age={1'(n%7!=0),8'(va)};counters={8'(vp),8'(vd),8'(vo)};underflow=vu;
   vs=1;de=1;@(negedge clk);vs=0;
   repeat(80)@(negedge clk);
   shown=a?actual:k;
   gain_value=shown<48?((shown+16)*25+4)/8:shown<80?((shown-16)*25+2)/4:((shown-48)*25+1)/2;
   if(dut.dec_gain!==bcd(gain_value)||dut.dec_r!==bcd((r*100+512)/1024)||
      dut.dec_g!==bcd((g*100+512)/1024)||dut.dec_b!==bcd((b*100+512)/1024))$fatal(1,"old gain/RGB value not complete by old deadline");
   lock_gain=dut.dec_gain;lock_r=dut.dec_r;lock_g=dut.dec_g;lock_b=dut.dec_b;
   age=0;counters=0;underflow=0;tel=0;agc=0;
   repeat(80)@(negedge clk);
   if(dut.decimal_busy!==0)$fatal(1,"nine-field conversion did not finish by 160 cycles");
   if(dut.dec_age!==12'(bcd(va))||dut.dec_peak!==12'(bcd(vp))||dut.dec_drop!==12'(bcd(vd))||
      dut.dec_overflow!==12'(bcd(vo))||dut.dec_underflow!==12'(bcd(vu)))$fatal(1,"new serial numeric conversion or frame freeze failed input%0d",n);
   if({dut.dec_gain,dut.dec_r,dut.dec_g,dut.dec_b}!=={lock_gain,lock_r,lock_g,lock_b})$fatal(1,"old values overwritten by new diagnostic slots");
   de=0;repeat(4)@(negedge clk);
  end
  if(checks<40000)$fatal(1,"short numeric timing coverage");
  $display("PASS nine-field shared serial decimal converter: all256 values for each diagnostic counter, %0d cycle comparisons prove original four values/deadlines unchanged, valid/invalid age and frame-atomic appended fields",checks);$finish;
 end
 initial begin #1000000;$fatal(1,"shared decimal watchdog");end
endmodule
