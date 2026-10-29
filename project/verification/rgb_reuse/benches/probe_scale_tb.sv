`timescale 1ns/1ps
module probe_scale_tb;
 target_shape_stabilizer dut(.I_clk(1'b0),.I_rst_n(1'b1),.I_start(1'b0),.I_cancel(1'b0),.I_frame_id(16'd0),.I_age(4'd0),.I_colors(16'd0),.I_objects(384'd0),.I_count(4'd0),.I_limit(1'b0));
 reference_stabilizer refdut(.I_clk(1'b0),.I_rst_n(1'b1),.I_start(1'b0),.I_cancel(1'b0),.I_frame_id(16'd0),.I_age(4'd0),.I_colors(16'd0),.I_objects(384'd0),.I_count(4'd0),.I_limit(1'b0));
 integer v,a,n=0,l,r,t,b,cx,cy,edgecase,boundary=0;
 reg signed [15:0] actual,expected;
 task compare;begin
  #2;
  if({dut.vx,dut.vy,dut.shift_x,dut.shift_y,dut.pl,dut.pr,dut.pt,dut.pb}!=={refdut.vx,refdut.vy,refdut.shift_x,refdut.shift_y,refdut.pl,refdut.pr,refdut.pt,refdut.pb})
   $fatal(1,"Actual combinational projection differs v=%0d age=%0d bounds=%0d/%0d/%0d/%0d",v,a,l,r,t,b);
 end endtask
 initial begin
  dut.slot=0;refdut.slot=0;dut.matched=1;refdut.matched=1;
  dut.frame_id=1;refdut.frame_id=1;dut.stamp[0]=0;refdut.stamp[0]=0;
  l=200;r=399;t=200;b=399;cx=(l+r)/2;cy=(t+b)/2;
  for(v=-64;v<=64;v=v+1)for(a=0;a<4;a=a+1)begin
   expected=v*a;actual=dut.scale_age(v,a);
   if(actual!==expected)$fatal(1,"Signed scale v=%0d age=%0d got=%0d expected=%0d",v,a,actual,expected);
   dut.age=a;refdut.age=a;
   dut.cur={1'b1,2'd2,11'(l),11'(r),11'(t),11'(b),1'b0};refdut.cur=dut.cur;
   dut.geometry[0]={1'b0,11'(cx-v),11'(cy+v),11'd200,11'd200};refdut.geometry[0]=dut.geometry[0];
   compare();n=n+1;
  end
  for(edgecase=0;edgecase<4;edgecase=edgecase+1)begin
   l=edgecase[0]?824:0;r=l+199;t=edgecase[1]?400:0;b=t+199;cx=(l+r)/2;cy=(t+b)/2;
   for(v=-64;v<=64;v=v+1)for(a=0;a<4;a=a+1)begin
    dut.age=a;refdut.age=a;dut.cur={1'b1,2'd2,11'(l),11'(r),11'(t),11'(b),1'b0};refdut.cur=dut.cur;
    dut.geometry[0]={1'b0,11'(cx-v),11'(cy+v),11'd200,11'd200};refdut.geometry[0]=dut.geometry[0];
    compare();boundary=boundary+1;
   end
  end
  $display("PASS exact signed scale 516 velocity/age pairs plus %0d actual original/new projection and boundary clip combinations",n+boundary);$finish;
 end
endmodule
