`timescale 1ns/1ps
module metrics_tb;
 localparam HZ=100003;
 reg clk=0;always #5 clk=~clk;reg rst=0,en=1,frame=0,start=0,done=0;
 wire [11:0] fps,det;wire [19:0] latency;wire valid;
 target_video_metrics #(.CLOCK_HZ(HZ)) dut(.I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_frame(frame),.I_start(start),.I_done(done),.O_fps(fps),.O_detection_fps(det),.O_latency(latency),.O_latency_valid(valid));
 integer n,cycles=0,window=0,frames=0,results=0,checks=0,started=0,expected_latency=0,last_finish=0;
 function integer decimal(input [19:0] b);begin decimal=b[3:0]+10*b[7:4]+100*b[11:8]+1000*b[15:12]+10000*b[19:16];end endfunction
 always @(posedge clk)if(rst)begin
  cycles=cycles+1;window=window+1;if(frame)frames=frames+1;if(en&&done)results=results+1;
  if(!en)results=0;
  if(start&&en)started=cycles;
  if(done&&en)begin expected_latency=(64'(cycles)*100000/HZ)-(64'(started)*100000/HZ);last_finish=cycles;end
  #1;
  if(done&&en)begin if(!valid||decimal(latency)!=expected_latency)$fatal(1,"Measured latency got=%0d expected=%0d",decimal(latency),expected_latency);checks=checks+1;end
  if(!en&&(valid||latency!=0||det!=0))$fatal(1,"Disabled latency/rate not cleared");
  if(window==HZ)begin
   if(decimal({8'd0,fps})!=frames||decimal({8'd0,det})!=(en?results:0))$fatal(1,"Measured FPS got=%0d/%0d expected=%0d/%0d",decimal({8'd0,fps}),decimal({8'd0,det}),frames,results);
   window=0;frames=0;results=0;checks=checks+1;
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(n=1;n<=HZ*3;n=n+1)begin
   frame=(n%5000==0||n%HZ==0);start=(n%20000==100);done=(n%20000==1334);
   en=n<HZ*2;@(negedge clk);
  end
  if(checks<10||last_finish==0)$fatal(1,"Missing measurement coverage");
  $display("PASS measured FPS and detection FPS: exact one-second windows including boundary pulses, non-divisible reference clock, independently computed 0.01ms latency, multiple results, invalid-before-first-result and disable with display FPS retained");$finish;
 end
endmodule
