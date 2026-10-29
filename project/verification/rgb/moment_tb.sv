`timescale 1ns/1ps
module moment_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,start=0,wr=0,clip=0;reg [10:0] wy=0,l=0,r=0,t=0,b=0;reg [33:0] wd=0;
 wire ready;wire [1:0] shape;
 flat_shape_classify dut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_good(1'b1),.I_abort(1'b0),.I_clipped(clip),
 .I_left(l),.I_right(r),.I_top(t),.I_bottom(b),.I_row_wr(wr),.I_row_y(wy),.I_row_data(wd),.O_shape(shape),.O_ready(ready),.O_busy());
 reg [33:0] rows[0:599];reg [63:0] meta[0:125-1];integer i,y,c,failures=0,max_cycles=0;
 task negative_check;integer c;begin start=1;@(negedge clk);start=0;c=0;repeat(2)@(negedge clk);
  while(!ready&&c<150000)begin c=c+1;@(negedge clk);end
  if(!ready||shape!=0)$fatal(1,"Rejected input was assigned a shape");end endtask
 initial begin
  $readmemh("../fixtures/moment_meta.hex",meta);repeat(4)@(negedge clk);rst=1;
  for(i=0;i<125;i=i+1)begin
   $readmemh($sformatf("../fixtures/moment_%0d.hex",i),rows);
   l=meta[i][12:2];r=meta[i][23:13];t=meta[i][34:24];b=meta[i][45:35];
   for(y=0;y<600;y=y+1)begin wr=1;wy=y;wd=rows[y];@(negedge clk);end
   wr=0;start=1;@(negedge clk);start=0;c=0;repeat(2)@(negedge clk);
   while(!ready&&c<150000)begin c=c+1;@(negedge clk);end
   if(c>max_cycles)max_cycles=c;
   if(!ready||shape!==meta[i][1:0])begin failures=failures+1;$display("BAD moment case=%0d expected=%0d got=%0d cycles=%0d det=%h a6=%h",i,meta[i][1:0],shape,c,dut.det,dut.a6);end
  end
  $readmemh("../fixtures/moment_0.hex",rows);
  l=meta[0][12:2];r=meta[0][23:13];t=meta[0][34:24];b=meta[0][45:35];
  for(y=0;y<600;y=y+1)begin wr=1;wy=y;wd=rows[y];@(negedge clk);end wr=0;
  clip=1;negative_check();clip=0;r=l+20;negative_check();r=meta[0][23:13];
  for(y=0;y<600;y=y+1)begin wr=1;wy=y;wd={rows[y][33:11],11'((rows[y][10:0]*3)/4)};@(negedge clk);end wr=0;
  negative_check();
  if(failures)$fatal(1,"Moment mismatches=%0d",failures);
  $display("PASS 125 independent raster masks: rotations, ellipse aspect, rectangle aspect, four triangle families, perspective, one-pixel contour jitter plus clipped/small/low-fill negatives; maximum cycles=%0d",max_cycles);$finish;
 end
 initial begin #2000000000;$fatal(1,"moment watchdog");end
endmodule
