`timescale 1ns/1ps
module probe_mask_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,start=0,fs=0,en=1,cancel=0,limit=0,capacity=0;
 reg [383:0] objects=0;reg [15:0] colors=0;reg [10:0] x=0,y=0;
 wire [2:0] status;wire [3:0] count;wire busy,done,valid;wire [1:0] ink;
 target_mask dut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_enable(en),.I_frame_start(fs),
  .I_objects(objects),.I_colors(colors),.I_limit(limit),.I_capture_limit(capacity),.O_busy(busy),.O_done(done),.O_valid(valid),.O_status(status),.O_count(count),.I_x(x),.I_y(y),.O_color(ink));
 wire ref_busy,ref_done,ref_valid;wire [2:0] ref_status;wire [3:0] ref_count;wire [1:0] ref_ink;
 reference_mask refdut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_enable(en),.I_frame_start(fs),
  .I_objects(objects),.I_colors(colors),.I_limit(limit),.I_capture_limit(capacity),.O_busy(ref_busy),.O_done(ref_done),.O_valid(ref_valid),.O_status(ref_status),.O_count(ref_count),.I_x(x),.I_y(y),.O_color(ref_ink));
 always @(posedge clk)begin #1;if(rst)begin
  if({busy,done,valid,status,count,ink}!=={ref_busy,ref_done,ref_valid,ref_status,ref_count,ref_ink})$fatal(1,"Merged glyph bank cycle mismatch");
  if({dut.state,dut.front_bank,dut.pending_ready}!=={refdut.state,refdut.front_bank,refdut.pending_ready})$fatal(1,"Mask ownership/commit cycle changed");
 end end

 task sample(input integer xx,yy,expected);begin x=xx;y=yy;repeat(2)@(negedge clk);if(ink!==expected[1:0])$fatal(1,"Streaming pixel %0d,%0d got=%b expected=%0d",xx,yy,ink,expected);end endtask
 task prepare;integer c;begin start=1;@(negedge clk);start=0;c=0;while(!done&&c<1000)begin @(negedge clk);c=c+1;end if(!done||!busy)$fatal(1,"Annotation preparation/ownership");end endtask
 task commit;begin fs=1;@(negedge clk);fs=0;repeat(2)@(negedge clk);end endtask
 task rectangle(input integer slot,col,left,top);begin
  objects[slot*48+:48]={1'b1,2'd2,11'(left),11'(left+79),11'(top),11'(top+89),1'b0};colors[slot*2+:2]=col;
 end endtask
 integer color,a,b,i;
 initial begin
  repeat(5)@(negedge clk);rst=1;
  // Every single color, and two objects of the same color.
  for(color=1;color<=3;color=color+1)begin
   objects=0;colors=0;rectangle(0,color,100,120);rectangle(1,color,360,120);prepare();
   if(color==1)sample(100,160,0);commit();
   sample(100,160,color);sample(178,160,color);sample(140,120,color);sample(140,208,color);
   sample(150,170,0);sample(138,164,color);sample(128,102,color);sample(360,160,color);sample(388,102,color);
  end
  // All three distinct pairs; do not allow one color to suppress another.
  for(a=1;a<=3;a=a+1)for(b=a+1;b<=3;b=b+1)begin
   objects=0;colors=0;rectangle(0,a,100,120);rectangle(1,b,360,120);prepare();commit();
   sample(100,160,a);sample(128,102,a);sample(360,160,b);sample(388,102,b);
  end
  objects=0;colors=0;for(i=0;i<8;i=i+1)rectangle(i,i%3+1,60+i*110,180);prepare();commit();
  for(i=0;i<8;i=i+1)sample(60+i*110,220,i%3+1);
  sample(458,530,0); // NO TARGET absent only when visible target annotations exist.
  // Hold a complete front snapshot while a newer result awaits frame commit.
  objects=0;colors=0;rectangle(0,2,100,120);prepare();commit();
  objects=0;colors=0;rectangle(0,3,500,120);prepare();sample(100,160,2);sample(500,160,0);commit();
  sample(100,160,0);sample(500,160,3);commit();sample(500,160,3);
  // Bounded hold, followed by an explicit LIMIT rather than silent blank video.
  repeat(3)commit();sample(500,160,0);sample(458,530,0);sample(466,530,0);if(status!=2)$fatal(1,"LIMIT metadata missing");
  // An unusable color must not hide NO TARGET.
  objects=0;colors=0;rectangle(0,0,100,120);prepare();commit();sample(100,160,0);sample(458,530,0);sample(466,530,0);if(status!=3)$fatal(1,"NO TARGET metadata missing");
  objects=0;colors=0;prepare();commit();sample(458,530,0);sample(466,530,0);if(status!=3)$fatal(1,"NO TARGET metadata missing");
  rectangle(0,3,100,120);prepare();commit();en=0;cancel=1;@(negedge clk);cancel=0;sample(100,160,0);if(valid)$fatal(1,"Disable stale annotations");
  $display("PASS original/new cycle-equivalence: streaming annotations: single red/blue/green, same-color pairs, all RGB pairs, eight mixed slots, matching boxes/cross/type glyphs, atomic commit, bounded late-result hold, explicit LIMIT/NO TARGET metadata without floating status text, invalid-color NO TARGET and disable");$finish;
 end
 initial begin #1000000;$fatal(1,"Streaming overlay watchdog");end
endmodule
