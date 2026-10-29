`timescale 1ns/1ps
module probe_mask_stream_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,start=0,fs=0,en=1,cancel=0,limit=0,capacity=0;
 reg [383:0] objects=0;reg [15:0] colors=0;reg [10:0] x=0,y=0;
 wire busy,done,valid,rb,rd,rv;wire [2:0] status,rs;wire [3:0] count,rc;wire [1:0] ink,ri;
 target_mask dut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_enable(en),.I_frame_start(fs),.I_objects(objects),.I_colors(colors),.I_limit(limit),.I_capture_limit(capacity),.O_busy(busy),.O_done(done),.O_valid(valid),.O_status(status),.O_count(count),.I_x(x),.I_y(y),.O_color(ink));
 reference_mask refdut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_enable(en),.I_frame_start(fs),.I_objects(objects),.I_colors(colors),.I_limit(limit),.I_capture_limit(capacity),.O_busy(rb),.O_done(rd),.O_valid(rv),.O_status(rs),.O_count(rc),.I_x(x),.I_y(y),.O_color(ri));
 integer cycles=0,pixels=0,commits=0,i,f,xx,yy,a,waited;
 reg prior_bank=0;
 always @(posedge clk)begin #1;
  if(rst)begin
   cycles=cycles+1;
   if({busy,done,valid,status,count,ink}!=={rb,rd,rv,rs,rc,ri})$fatal(1,"Streaming glyph cycle mismatch x=%0d y=%0d cycle=%0d",x,y,cycles);
   if(dut.front_bank!=prior_bank)commits=commits+1;
   prior_bank=dut.front_bank;
  end
 end
 task item(input integer slot,palette,kind,l,r,t,b);begin
  objects[slot*48+:48]={1'b1,2'(kind),11'(l),11'(r),11'(t),11'(b),1'b0};colors[slot*2+:2]=palette;
 end endtask
 task kick;begin start=1;@(negedge clk);start=0;end endtask
 task finish;begin waited=0;while(!done&&waited<2000)begin @(negedge clk);waited=waited+1;end if(!done)$fatal(1,"Preparation missed deadline");end endtask
 task commit;begin fs=1;@(negedge clk);fs=0;repeat(2)@(negedge clk);end endtask
 task memory_check;
  integer bank,slot,ch;reg [34:0] a,b;
  begin
   for(bank=0;bank<2;bank=bank+1)for(slot=0;slot<8;slot=slot+1)for(ch=0;ch<32;ch=ch+1)begin
    a=dut.glyphs[bank*256+slot*32+ch];b=bank?refdut.glyph1[slot*32+ch]:refdut.glyph0[slot*32+ch];
    if(a!==b)$fatal(1,"Logical double-bank contents differ bank=%0d slot=%0d char=%0d",bank,slot,ch);
   end
  end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(i=0;i<8;i=i+1)item(i,i%3+1,i%3+1,80+i*14,240+i*14,150+i*10,310+i*10);
  kick();finish();commit();memory_check();
  for(f=0;f<4;f=f+1)begin
   // Force identical overlapping text regions and box coverage. Highest slot
   // wins even on a blank glyph cell; the original module is the cycle oracle.
   for(i=0;i<8;i=i+1)begin
    dut.front_x[i]=50;refdut.front_x[i]=50;dut.front_y[i]=55;refdut.front_y[i]=55;
   end
   for(i=0;i<8;i=i+1)item(i,(i+f)%3+1,(i+f)%3+1,110+i*9+f,240+i*9+f,180+i*7,310+i*7);
   kick();
   // Active bank streams continuously while the inactive bank is rebuilt.
   for(yy=70;yy<390;yy=yy+1)for(xx=70;xx<390;xx=xx+1)begin x=xx;y=yy;@(negedge clk);pixels=pixels+1;end
   if(!dut.pending_ready)$fatal(1,"Pending preparation not complete during stream");memory_check();
   commit();memory_check();
   for(yy=90;yy<140;yy=yy+1)for(xx=90;xx<350;xx=xx+1)begin x=xx;y=yy;@(negedge clk);pixels=pixels+1;end
  end
  // Cancellation/reset must leave output and ownership identical on both banks.
  kick();repeat(20)@(negedge clk);cancel=1;@(negedge clk);cancel=0;repeat(4)@(negedge clk);
  capacity=1;commit();capacity=0;en=0;commit();en=1;rst=0;repeat(4)@(negedge clk);rst=1;repeat(10)@(negedge clk);
  if(commits<5||pixels!=461600)$fatal(1,"Streaming coverage");
  $display("PASS original/new glyph RAM %0d streaming pixels, %0d sampled cycles, %0d bank commits, complete 512-address dual-bank content equality, overlapping text/box priority, simultaneous write/read, cancellation/capture-limit/disable/reset",pixels,cycles,commits);$finish;
 end
 initial begin #20000000;$fatal(1,"Streaming equivalence timeout");end
endmodule
