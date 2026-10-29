`timescale 1ns/1ps
module meter_epoch_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,ft=0,done=1,seq=0;reg [1:0] mode=0;reg [7:0] stats=0;
 wire req;wire [15:0] exposure,gain;wire [2:0] status;
 integer busy=0,m,k,requests=0,before_requests;
 camera_gain_apply dut(.I_clk(clk),.I_rst_n(rst),.I_gain(7'd80),
  .I_auto_enable(1'b1),.I_meter_mode(mode),.I_stats(stats),.I_cam_done(1'b1),
  .I_ae_done(done),.I_frame_toggle(ft),.O_req(req),.O_ae(exposure),.O_ag(gain),.O_status(status));
 always @(negedge clk)begin
  if(!rst)begin busy=0;done=1;end
  else if(req)begin requests=requests+1;busy=4;done=0;end
  else if(busy>0)begin busy=busy-1;if(busy==0)done=1;end
 end
 task settle;
  begin for(k=0;k<10;k=k+1)begin @(posedge clk);#1;ft=~ft;repeat(40)@(posedge clk);end end
 endtask
 initial begin
  for(m=0;m<4;m=m+1)begin
   rst=0;mode=m;stats={2'(m),6'd0};seq=0;ft=0;
   repeat(5)@(posedge clk);#1;rst=1;settle();before_requests=requests;
   // Same low mode bit, different high bit. A truncated 1-bit tag fails here.
   seq=!seq;stats={2'(m^2),seq,1'b1,1'b0,3'd1};repeat(30)@(posedge clk);#1;
   if(gain!=80||requests!=before_requests||status!=0)$fatal(1,"Stale upper-bit meter epoch was accepted mode=%0d",m);
   seq=!seq;stats={2'(m),seq,1'b1,1'b0,3'd1};repeat(30)@(posedge clk);#1;
   if(gain!=81||requests!=before_requests+1||exposure!=1990)$fatal(1,"Current complete epoch was not accepted mode=%0d",m);
  end
  $display("PASS all four 2-bit meter epochs: stale same-low-bit results rejected, current complete stats accepted once, fixed shutter and writer handshake");$finish;
 end
 initial begin #100000;$fatal(1,"Meter epoch watchdog");end
endmodule
