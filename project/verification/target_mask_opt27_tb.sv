`timescale 1ns/1ps
module target_mask_opt27_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,start=0,fs=0,en=1,cancel=0,limit=0,capacity=0;
 reg [383:0] objects=0;reg [15:0] colors=0;reg [10:0] x=0,y=0;
 wire [2:0] status,ref_status;wire [3:0] count,ref_count;
 wire busy,done,valid,ref_busy,ref_done,ref_valid;wire [1:0] ink,ref_ink;
 target_mask dut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_enable(en),.I_frame_start(fs),
  .I_objects(objects),.I_colors(colors),.I_limit(limit),.I_capture_limit(capacity),.O_busy(busy),.O_done(done),.O_valid(valid),.O_status(status),.O_count(count),.I_x(x),.I_y(y),.O_color(ink));
 reference_target_mask_opt27 old(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_enable(en),.I_frame_start(fs),
  .I_objects(objects),.I_colors(colors),.I_limit(limit),.I_capture_limit(capacity),.O_busy(ref_busy),.O_done(ref_done),.O_valid(ref_valid),.O_status(ref_status),.O_count(ref_count),.I_x(x),.I_y(y),.O_color(ref_ink));
 integer cycles=0,pixels=0,maths=0,a,b,i,s,xx,yy,nx,ny,pos,kind,c;
 reg [15:0] bx,by;reg [9:0] offset;
 reg [10:0] left,right,top,bottom;
 always @(posedge clk)begin
  #1;cycles=cycles+1;
  if({busy,done,valid,status,count,ink}!=={ref_busy,ref_done,ref_valid,ref_status,ref_count,ref_ink})
   $fatal(1,"Painter cycle mismatch cycle%0d x%0d y%0d new%b old%b",cycles,x,y,{busy,done,valid,status,count,ink},{ref_busy,ref_done,ref_valid,ref_status,ref_count,ref_ink});
 end
 task prepare;integer timeout;begin
  start=1;@(negedge clk);start=0;timeout=0;
  while(!done&&timeout<1000)begin @(negedge clk);timeout=timeout+1;end
  if(!done||!busy)$fatal(1,"Painter prepare watchdog");
 end endtask
 task commit;begin fs=1;@(negedge clk);fs=0;end endtask
 task sample(input integer px,py);begin x=px;y=py;@(negedge clk);pixels=pixels+1;end endtask
 initial begin
  // All character positions/counts and arbitrary packed digit nibbles.
  for(kind=0;kind<4;kind=kind+1)for(pos=0;pos<32;pos=pos+1)
   for(nx=0;nx<8;nx=nx+1)for(ny=0;ny<8;ny=ny+1)begin
    bx=$random;by=$random;
    if(dut.label_char(pos,kind,bx,by,nx,ny)!==old.label_char(pos,kind,bx,by,nx,ny))
     $fatal(1,"Character mismatch kind%0d pos%0d nx%0d ny%0d",kind,pos,nx,ny);
    maths=maths+1;
   end
  force dut.selected_dx=offset;
  for(i=0;i<1024;i=i+1)begin
   offset=i;#1;
   if(dut.read_char!==(i/6)%32||dut.read_col!==i%6)$fatal(1,"Quotient/remainder mismatch %0d",i);
   maths=maths+1;
  end
  release dut.selected_dx;
  repeat(3)@(negedge clk);rst=1;@(negedge clk);
  for(s=0;s<24;s=s+1)begin
   objects=0;colors=0;limit=(s%5==0);
   for(i=0;i<8;i=i+1)begin
    left=$urandom_range(0,1023);right=$urandom_range(left,1023);
    top=$urandom_range(0,599);bottom=$urandom_range(top,599);
    if(s==0)begin left=32+i*100;right=left+79;top=160;bottom=249;end
    if(s==1)begin left=0;right=1023;top=0;bottom=599;end
    if(s==2)begin left=$urandom_range(0,2047);right=$urandom_range(0,2047);top=$urandom_range(0,2047);bottom=$urandom_range(0,2047);end
    objects[i*48+:48]={1'b1,2'(i%3+1),left,right,top,bottom,1'b0};colors[i*2+:2]=i%3+1;
   end
   prepare();commit();
   // Complete native raster includes every character/border/cross intersection.
   if(s==0)for(yy=0;yy<600;yy=yy+1)for(xx=0;xx<1024;xx=xx+1)sample(xx,yy);
   else for(c=0;c<2048;c=c+1)sample($urandom_range(0,2047),$urandom_range(0,2047));
   if(s%4==0)begin capacity=1;commit();capacity=0;sample(100,100);end
   if(s%3==0)begin repeat(5)commit();sample(500,300);end
  end
  en=0;cancel=1;@(negedge clk);cancel=0;sample(0,0);
  $display("PASS exact name-case-only painter resource optimization: %0d exhaustive math/character offsets, %0d streamed pixels, %0d cycle-matched old/new status/ownership/output checks including native raster, overlap/offscreen snapshots, commit/LIMIT/stale/disable",maths,pixels,cycles);
  $finish;
 end
 initial begin #20000000;$fatal(1,"Painter equivalence watchdog");end
endmodule
