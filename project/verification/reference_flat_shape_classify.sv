// Filled planar shape classification from affine-invariant second moments.
// 144 det(covariance)/area^2: ellipse=.91189, rectangle=1, triangle=4/3.
// All moments are exact integer sums. One serial multiplier is shared by
// every row and the final invariant; no division or dedicated DSP is needed.
(* dsp_style="no" *) module reference_flat_shape_classify #(
 parameter WIDTH=1024,HEIGHT=600,MIN_SIZE=32
)(
 input wire I_clk,I_rst_n,I_start,I_good,I_abort,I_clipped,
 input wire [10:0] I_left,I_right,I_top,I_bottom,
 input wire I_row_wr,input wire [10:0] I_row_y,input wire [33:0] I_row_data,
 output reg [1:0] O_shape,output reg O_ready,O_busy
);
 (* ram_style="bram" *) reg [33:0] rows[0:HEIGHT-1];
 reg [10:0] ra;reg [33:0] q;
 always @(posedge I_clk)begin
  if(I_row_wr&&I_row_y<HEIGHT)rows[I_row_y]<=I_row_data;
  q<=rows[ra];
 end
 localparam IDLE=0,REQ=1,WAIT_ROW=2,ROW=3,LL=4,LR=5,RR=6,XX=7,
  SX=8,SY=9,YY=10,YYN=11,XY=12,XYN=13,NEXT_ROW=14,
  CXX_A=15,CXX_B=16,CYY_A=17,CYY_B=18,CXY_A=19,CXY_B=20,
  DET_A=21,DET_B=22,A2=23,A4=24,A6=25,TLO=26,TC=27,TR=28,THI=29,
  FINISH=30,MUL=31;
 reg [4:0] state,ret;
 // An unreset registered read address is required for TD embedded RAM.
 // Every read follows REQ/WAIT_ROW; uninitialized contents are never consumed.
 reg [10:0] row_y,bottom,l,r,yy;reg [11:0] n;
 always @(posedge I_clk)if(state==REQ)ra<=row_y;
 reg [63:0] area,hits,x2,y2,xx6,yy6,xy2;
 reg [63:0] cxx,cyy,cxy;reg cxy_neg;
 reg [127:0] aa,bb,product,mres,temp,det,a2,a4,a6,norm;
 reg [31:0] squares;
 reg good;
 task automatic multiply(input [127:0] a,b,input [4:0] back);
 begin aa<=a;bb<=b;product<=0;ret<=back;state<=MUL;end endtask
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  state<=IDLE;ret<=0;row_y<=0;bottom<=0;l<=0;r<=0;yy<=0;n<=0;
  area<=0;hits<=0;x2<=0;y2<=0;xx6<=0;yy6<=0;xy2<=0;
  aa<=0;bb<=0;product<=0;mres<=0;temp<=0;det<=0;a2<=0;a4<=0;a6<=0;norm<=0;
  cxx<=0;cyy<=0;cxy<=0;cxy_neg<=0;squares<=0;good<=0;O_shape<=0;O_ready<=0;O_busy<=0;
 end else begin
  O_ready<=0;
  if(I_abort)begin state<=IDLE;O_busy<=0;O_shape<=0;end
  else if(I_start&&!O_busy)begin
   O_busy<=1;O_shape<=0;row_y<=I_top;bottom<=I_bottom;
   area<=0;hits<=0;x2<=0;y2<=0;xx6<=0;yy6<=0;xy2<=0;
   good<=I_good&&!I_clipped&&I_right>=I_left&&I_bottom>=I_top&&
    I_right-I_left+1>=MIN_SIZE&&I_bottom-I_top+1>=MIN_SIZE;
   state<=REQ;
  end else case(state)
   MUL:begin
    if(bb==0)begin mres<=product;state<=ret;end
    else begin if(bb[0])product<=product+aa;aa<=aa<<1;bb<=bb>>1;end
   end
   REQ:state<=WAIT_ROW;
   WAIT_ROW:state<=ROW;
   ROW:begin
    l<=q[32:22];r<=q[21:11];yy<=row_y;n<={1'b0,q[21:11]}-{1'b0,q[32:22]}+1'b1;
    if(!q[33]||q[21:11]<q[32:22])begin good<=0;state<=NEXT_ROW;end
    else begin
     area<=area+({1'b0,q[21:11]}-{1'b0,q[32:22]}+1'b1);hits<=hits+q[10:0];
     multiply({117'd0,q[32:22]},{117'd0,q[32:22]},LL);
    end
   end
   LL:begin squares<=mres[31:0];multiply(l,r,LR);end
   LR:begin squares<=squares+mres[31:0];multiply(r,r,RR);end
   RR:begin multiply(n,((squares+mres)<<1)+r-l,XX);end
   XX:begin xx6<=xx6+mres[63:0];multiply(n,{116'd0,l}+r,SX);end
   SX:begin x2<=x2+mres[63:0];multiply(n,yy,SY);end
   SY:begin y2<=y2+(mres[63:0]<<1);multiply(yy,yy,YY);end
   YY:begin multiply(mres,n,YYN);end
   YYN:begin yy6<=yy6+(mres[63:0]<<2)+(mres[63:0]<<1);multiply(yy,{116'd0,l}+r,XY);end
   XY:begin multiply(mres,n,XYN);end
   XYN:begin xy2<=xy2+mres[63:0];state<=NEXT_ROW;end
   NEXT_ROW:begin
    if(row_y>=bottom)begin multiply(area,xx6,CXX_A);end
    else begin row_y<=row_y+1'b1;state<=REQ;end
   end
   CXX_A:begin temp<=mres<<1;multiply(x2,x2,CXX_B);end
   CXX_B:begin cxx<=temp-(mres<<1)-mres;multiply(area,yy6,CYY_A);end
   CYY_A:begin temp<=mres<<1;multiply(y2,y2,CYY_B);end
   CYY_B:begin cyy<=temp-(mres<<1)-mres;multiply(area,xy2,CXY_A);end
   CXY_A:begin temp<=(mres<<2)+(mres<<1);multiply(x2,y2,CXY_B);end
   CXY_B:begin
    cxy_neg<=temp<((mres<<1)+mres);
    cxy<=temp>=((mres<<1)+mres)?temp-(mres<<1)-mres:(mres<<1)+mres-temp;
    multiply(cxx,cyy,DET_A);
   end
   DET_A:begin temp<=mres;multiply(cxy,cxy,DET_B);end
   DET_B:begin det<=temp-mres;if(temp<=mres)good<=0;multiply(area,area,A2);end
   A2:begin a2<=mres;multiply(mres,mres,A4);end
   A4:begin a4<=mres;multiply(mres,a2,A6);end
   A6:begin a6<=mres;norm<=det<<10;multiply(mres,128'd880,TLO);end
   TLO:begin
    if(norm<mres||area==0||hits*64'd100<area*64'd86)good<=0;
    multiply(a6,128'd985,TC);
   end
   TC:begin if(norm<mres)O_shape<=1;multiply(a6,128'd1165,TR);end
   TR:begin if(norm>=mres)O_shape<=3;else if(O_shape==0)O_shape<=2;multiply(a6,128'd1530,THI);end
   THI:begin if(norm>mres)good<=0;state<=FINISH;end
   FINISH:begin if(!good)O_shape<=0;O_busy<=0;O_ready<=1;state<=IDLE;end
   default:;
  endcase
 end
endmodule
