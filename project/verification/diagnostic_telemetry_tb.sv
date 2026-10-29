`timescale 1ns/1ps
module diagnostic_telemetry_tb;
 reg dc=0,vc=0;always #3.75 dc=~dc;always #9.583 vc=~vc;
 reg rst=0,valid=0;reg [7:0] age=0;
 reg [31:0] drop=0,overflow=0,underflow=0;
 wire [8:0] latency;wire [23:0] diag;wire [7:0] under;
 diagnostic_telemetry dut(.I_ddr_clk(dc),.I_display_clk(vc),.I_rst_n(rst),
  .I_age_valid(valid),.I_age(age),.I_dropped_frames(drop),.I_read_overflow_frames(overflow),
  .I_display_underflow_frames(underflow),.O_latency(latency),.O_diagnostics(diag),.O_underflow(under));
 function [7:0] sat(input [31:0] n);begin sat=n>255?255:n[7:0];end endfunction
 reg [32:0] legal[0:4095];integer count=1,ddr_checks=0,display_checks=0,i,n,matched;
 reg [7:0] oracle_peak=0;reg [32:0] expected;
 initial legal[0]=0;
 always @(posedge dc or negedge rst)begin
  if(!rst)begin oracle_peak=0;count=1;legal[0]=0;end
  else begin
   if(valid&&age>oracle_peak)oracle_peak=age;
   expected={valid,age,oracle_peak,sat(drop),sat(overflow)};
   if(expected!==legal[count-1])begin
    if(count>=4096)$fatal(1,"scoreboard overflow");
    legal[count]=expected;count=count+1;
   end
   ddr_checks=ddr_checks+1;
  end
 end
 always @(posedge vc)begin #0.01;
  if(rst)begin
   matched=0;for(i=0;i<count;i=i+1)if({latency,diag}===legal[i])matched=1;
   if(!matched)$fatal(1,"torn CDC packet %h not from any complete source snapshot",{latency,diag});
   if(latency[8]&&diag[23:16]<latency[7:0])$fatal(1,"coherent current age exceeds peak");
   if(under!==sat(underflow))$fatal(1,"display-domain underflow saturation");
   display_checks=display_checks+1;
  end
 end
 task settle;
 begin repeat(100)@(negedge vc);
  if({latency,diag}!=={valid,age,oracle_peak,sat(drop),sat(overflow)})
   $fatal(1,"mailbox did not converge to latest packet");end endtask
 reg sample=0,meter_valid=0;reg [15:0] capture=0,shown=0;
 wire measured_valid;wire [7:0] measured;
 frame_latency_meter meter(.I_clk(dc),.I_rst_n(rst),.I_sample(sample),.I_valid(meter_valid),
  .I_capture_sequence(capture),.I_display_sequence(shown),.O_valid(measured_valid),.O_frame_latency(measured));
 integer delta,expected_age;
 initial begin
  repeat(5)@(negedge vc);rst=1;
  for(n=0;n<300;n=n+1)begin
   @(negedge dc);valid=(n%7)!=0;age=(n*37)%256;drop=(age^8'h69);overflow=255-age;
   // Change faster than a full handshake to exercise latest-value coalescing.
   repeat(n%3+1)@(negedge dc);
  end
  @(negedge dc);valid=1;age=13;drop=32'd255;overflow=32'd256;settle();
  if(diag!=={8'd255,8'd255,8'd255})$fatal(1,"peak or 255 saturation");
  for(n=0;n<256;n=n+1)begin @(negedge vc);underflow=n;#0.02;if(under!==n[7:0])$fatal(1,"all 256 underflow values");end
  @(negedge vc);underflow=256;#0.02;if(under!=255)$fatal(1,"underflow 256 saturation");
  @(negedge vc);underflow=32'hffffffff;#0.02;if(under!=255)$fatal(1,"underflow 32-bit maximum");
  @(negedge vc);underflow=0;#0.02;if(under!=0)$fatal(1,"counter wrap is not frozen by UI saturation");
  @(negedge dc);valid=0;age=255;drop=32'hffffffff;overflow=32'h100;settle();
  if(latency[8]!==0||diag[23:16]!=255)$fatal(1,"invalid age changed peak");
  // Exhaust all 16-bit deltas at changing display origins, including wrap.
  for(delta=0;delta<65536;delta=delta+1)begin
   @(negedge dc);shown=(delta*977+16'hfff0)&16'hffff;capture=(shown+delta)&16'hffff;
   sample=1;meter_valid=1;@(posedge dc);#0.02;
   expected_age=delta>255?255:delta;
   if(!measured_valid||measured!==expected_age[7:0])$fatal(1,"age modulo/wrap delta=%0d got%0d",delta,measured);
  end
  @(negedge dc);sample=0;capture=0;shown=0;repeat(5)@(negedge dc);
  if(measured!=255||!measured_valid)$fatal(1,"meter changed without sample");
  sample=1;meter_valid=0;@(posedge dc);#0.02;
  if(measured_valid||measured!=0)$fatal(1,"invalid frame did not clear meter");
  @(negedge vc);rst=0;#0.05;
  if({latency,diag,measured_valid,measured}!==0)$fatal(1,"async reset did not clear diagnostics");
  rst=1;valid=1;age=3;drop=4;overflow=5;underflow=6;settle();
  if(diag[23:16]!=3)$fatal(1,"peak failed to restart after reset");
  $display("PASS diagnostic telemetry: asynchronous coherent 33-bit snapshots, peak/reset/invalid age, all 65536 modulo sequence deltas and saturation, all 256 underflow values, 32-bit counter wrap; %0d display checks",display_checks);$finish;
 end
 initial begin #5000000;$fatal(1,"diagnostic telemetry timeout");end
endmodule
