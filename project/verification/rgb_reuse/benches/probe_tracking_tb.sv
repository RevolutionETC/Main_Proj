`timescale 1ns/1ps
module probe_tracking_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,start=0,cancel=0;reg [399:0] objects=0;
 reg [3:0] count=0;reg [15:0] fid=0;reg [3:0] age=2;wire done;wire [399:0] result;
 wire [383:0] geometry_in,geometry_out;wire [15:0] colors_in,colors_out;
 genvar k;generate for(k=0;k<8;k=k+1)begin
  assign geometry_in[k*48+:48]=objects[k*50+:48];
  assign colors_in[k*2+:2]=objects[k*50+48+:2];
  assign result[k*50+:50]={colors_out[k*2+:2],geometry_out[k*48+:48]};
 end endgenerate
 target_shape_stabilizer dut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_frame_id(fid),.I_age(age),.I_objects(geometry_in),.I_colors(colors_in),.I_count(count),.I_limit(1'b0),.O_busy(),.O_done(done),.O_objects(geometry_out),.O_colors(colors_out),.O_count(),.O_limit());
 wire ref_busy,ref_done,ref_limit;wire [383:0] ref_objects;wire [15:0] ref_colors;wire [3:0] ref_count;
 reference_stabilizer refdut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_frame_id(fid),.I_age(age),.I_objects(geometry_in),.I_colors(colors_in),.I_count(count),.I_limit(1'b0),.O_busy(ref_busy),.O_done(ref_done),.O_objects(ref_objects),.O_colors(ref_colors),.O_count(ref_count),.O_limit(ref_limit));
 always @(posedge clk)begin #1;if(rst)begin
  if({done,geometry_out,colors_out}!=={ref_done,ref_objects,ref_colors})$fatal(1,"Bounded age scale changed tracking output/cycle");
  if({dut.O_busy,dut.O_count,dut.O_limit,dut.state}!=={ref_busy,ref_count,ref_limit,refdut.state})$fatal(1,"Tracking control changed");
 end end

 function [49:0] obj(input integer shape,x,y);begin obj={2'd1,1'b1,shape[1:0],11'(x),11'(x+79),11'(y),11'(y+89),1'b0};end endfunction
 task batch;integer c;begin fid=fid+1;start=1;@(negedge clk);start=0;c=0;while(!done&&c<1000)begin c=c+1;@(negedge clk);end if(!done)$fatal(1,"Tracker timeout");end endtask
 integer n;reg [49:0] a,b;
 initial begin
  repeat(4)@(negedge clk);rst=1;count=2;objects[0+:50]=obj(2,100,100);objects[50+:50]=obj(3,400,200);batch();
  if(result[47]||result[97])$fatal(1,"First observation must wait");
  for(n=1;n<40;n=n+1)begin
   objects=0;objects[0+:50]=obj(n%5==0?0:2,100+n*4,100);objects[50+:50]=obj(n%4==0?0:3,400-n*3,200);
   // Change input order every frame to prevent accidental rank-based history.
   if(n%2==1)begin a=objects[0+:50];objects[0+:50]=objects[50+:50];objects[50+:50]=a;end
   batch();a=result[(n%2==1?50:0)+:50];b=result[(n%2==1?0:50)+:50];
   if(!a[47]||a[46:45]!=2||!b[47]||b[46:45]!=3)$fatal(1,"Class flicker at %0d",n);
   if(a[44:34]!==11'(100+n*4+8)||b[44:34]!==11'(400-n*3-6))$fatal(1,"Motion projection %0d: %0d %0d",n,a[44:34],b[44:34]);
  end
  count=0;objects=0;batch();if(result!=0)$fatal(1,"Ghost box");
  cancel=1;@(negedge clk);cancel=0;count=1;
  objects[0+:50]=obj(2,150,100);batch();batch();if(!result[47])$fatal(1,"Reconfirm");
  for(n=0;n<3;n=n+1)begin objects[0+:50]=obj(3,150,100);batch();if(result[46:45]!=2)$fatal(1,"Premature switch");end
  batch();if(result[46:45]!=3)$fatal(1,"Missing supported switch");
  for(n=0;n<11;n=n+1)begin objects[0+:50]=obj(0,150,100);batch();if(!result[47]||result[46:45]!=3)$fatal(1,"Short dropout flicker");end
  batch();if(result[47])$fatal(1,"Unbounded stale class");
  // A new color at the same geometry must acquire its own class evidence.
  cancel=1;@(negedge clk);cancel=0;objects=0;count=1;objects[0+:50]=obj(2,150,100);batch();batch();
  objects[48+:2]=2;objects[46:45]=3;batch();if(result[47])$fatal(1,"Blue inherited red history");
  batch();if(!result[47]||result[49:48]!=2||result[46:45]!=3)$fatal(1,"Blue confirmation");
  objects[48+:2]=3;objects[46:45]=1;batch();if(result[47])$fatal(1,"Green inherited blue history");
  batch();if(!result[47]||result[49:48]!=3||result[46:45]!=1)$fatal(1,"Green confirmation");
  $display("PASS original/new cycle-equivalence: class confirmation, 39 moving/reordered two-object batches, intermittent unknowns, exact frame-age motion, four-vote replacement, bounded hold, absent-object removal reset and no cross-color history inheritance");$finish;
 end
endmodule
