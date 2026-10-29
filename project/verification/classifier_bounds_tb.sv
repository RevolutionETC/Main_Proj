`timescale 1ns/1ps
module classifier_bounds_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,start=0,wr=0;reg [10:0] y=0;reg [33:0] row=0;
 wire [1:0] shape,refshape;wire ready,refready,busy,refbusy;
 flat_shape_classify dut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_good(1'b1),.I_abort(1'b0),.I_clipped(1'b0),.I_left(11'd0),.I_right(11'd1023),.I_top(11'd0),.I_bottom(11'd599),.I_row_wr(wr),.I_row_y(y),.I_row_data(row),.O_shape(shape),.O_ready(ready),.O_busy(busy));
 reference_flat_shape_classify refdut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_good(1'b1),.I_abort(1'b0),.I_clipped(1'b0),.I_left(11'd0),.I_right(11'd1023),.I_top(11'd0),.I_bottom(11'd599),.I_row_wr(wr),.I_row_y(y),.I_row_data(row),.O_shape(refshape),.O_ready(refready),.O_busy(refbusy));
 integer k,iy,l,r,n,c;
 always @(posedge clk)begin #1;if(rst)begin
  if({ready,busy}!=={refready,refbusy})$fatal(1,"changed classifier schedule");
  if(dut.state==20&&(dut.temp[127:64]!=0||dut.mres>128'h5555555555555555))$fatal(1,"invalid 64-bit covariance bound");
 end end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(k=0;k<6;k=k+1)begin
   for(iy=0;iy<600;iy=iy+1)begin
    case(k)
     0:begin l=0;r=1023;end
     1:begin l=950;r=1023;end
     2:begin l=0;r=iy*1023/599;end
     3:begin l=1023-iy*1023/599;r=1023;end
     4:begin l=iy/2;r=1023-iy/3;end
     5:begin l=(iy*97)%900;r=l+32+(iy%70);end
    endcase
    n=r-l+1;wr=1;y=iy;row={1'b1,11'(l),11'(r),11'(n)};@(negedge clk);
   end
   wr=0;start=1;@(negedge clk);start=0;c=0;
   while(!ready&&c<200000)begin c=c+1;@(negedge clk);end
   if(!ready||shape!==refshape||dut.area!==refdut.area||dut.hits!==refdut.hits||dut.x2!==refdut.x2||dut.y2!==refdut.y2||dut.xx6!==refdut.xx6||dut.yy6!==refdut.yy6||dut.xy2!==refdut.xy2||dut.cxx!==refdut.cxx||dut.cyy!==refdut.cyy||dut.cxy!==refdut.cxy||dut.det!==refdut.det||dut.a6!==refdut.a6||dut.norm!==refdut.norm)$fatal(1,"narrowing changed original integer result, case%0d",k);
   repeat(3)@(negedge clk);
  end
  $display("PASS classifier bounds: six full-height native-coordinate cases including all 614400 pixels and x1023/y599; all integer moments, covariance, determinant, area powers, shape and cycle schedule exactly match untouched 128-bit original");$finish;
 end
 initial begin #15000000;$fatal(1,"timeout");end
endmodule
