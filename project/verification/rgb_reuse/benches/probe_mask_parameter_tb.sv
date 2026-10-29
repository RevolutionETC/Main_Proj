`timescale 1ns/1ps
module parameter_mask_probe #(parameter N=1)(output reg finished=0);
 reg clk=0;always #5 clk=~clk;
 reg rst=0,start=0,fs=0,en=1,cancel=0;
 reg [N*48-1:0] objects=0;reg [N*2-1:0] colors=0;reg [10:0] x=0,y=0;
 wire busy,done,valid,rb,rd,rv;wire [2:0] status,rs;wire [3:0] count,rc;wire [1:0] ink,ri;
 target_mask #(.MAX_OBJECTS(N)) dut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_enable(en),.I_frame_start(fs),.I_objects(objects),.I_colors(colors),.I_limit(1'b0),.I_capture_limit(1'b0),.O_busy(busy),.O_done(done),.O_valid(valid),.O_status(status),.O_count(count),.I_x(x),.I_y(y),.O_color(ink));
 reference_mask #(.MAX_OBJECTS(N)) refdut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_enable(en),.I_frame_start(fs),.I_objects(objects),.I_colors(colors),.I_limit(1'b0),.I_capture_limit(1'b0),.O_busy(rb),.O_done(rd),.O_valid(rv),.O_status(rs),.O_count(rc),.I_x(x),.I_y(y),.O_color(ri));
 integer i,f,xx,yy,c,bank,ch,cycles=0,commits=0;reg prior_bank=0;reg [34:0] actual,expected;
 always @(posedge clk)begin #1;if(rst)begin
  cycles=cycles+1;
  if({busy,done,valid,status,count,ink}!=={rb,rd,rv,rs,rc,ri})$fatal(1,"Parameterized N=%0d mask output/cycle mismatch",N);
  if(dut.front_bank!=prior_bank)commits=commits+1;prior_bank=dut.front_bank;
 end end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<5;f=f+1)begin
   for(i=0;i<N;i=i+1)begin
    objects[i*48+:48]={1'b1,2'(1+(i+f)%3),11'(100+10*i+f),11'(239+10*i+f),11'(150+i),11'(289+i),1'b0};colors[i*2+:2]=1+(i+f)%3;
   end
   start=1;@(negedge clk);start=0;
   for(yy=90;yy<135;yy=yy+1)for(xx=90;xx<350;xx=xx+1)begin x=xx;y=yy;@(negedge clk);end
   if(!dut.pending_ready)$fatal(1,"N=%0d pending preparation timeout",N);
   fs=1;@(negedge clk);fs=0;repeat(2)@(negedge clk);
   for(bank=0;bank<2;bank=bank+1)for(i=0;i<N;i=i+1)for(ch=0;ch<32;ch=ch+1)begin
    actual=dut.glyphs[bank*N*32+i*32+ch];expected=bank?refdut.glyph1[i*32+ch]:refdut.glyph0[i*32+ch];
    if(actual!==expected)$fatal(1,"N=%0d bank=%0d slot=%0d char=%0d merged memory mismatch",N,bank,i,ch);
   end
   for(yy=90;yy<135;yy=yy+1)for(xx=90;xx<350;xx=xx+1)begin x=xx;y=yy;@(negedge clk);end
  end
  if(commits!=5)$fatal(1,"N=%0d bank commit coverage",N);
  cancel=1;@(negedge clk);cancel=0;repeat(2)@(negedge clk);finished=1;
 end
endmodule
module probe_mask_parameter_tb;
 wire one,four;
 parameter_mask_probe #(.N(1)) p1(one);
 parameter_mask_probe #(.N(4)) p4(four);
 initial begin wait(one&&four);$display("PASS MAX_OBJECTS 1 and 4 parameter preservation: five dual-bank commits each, simultaneous prepare/stream, original/new per-cycle pixel/control and every logical glyph address equality");$finish;end
 initial begin #10000000;$fatal(1,"Parameterized glyph RAM watchdog");end
endmodule
