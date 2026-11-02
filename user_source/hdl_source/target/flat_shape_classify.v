 
 
 
 
(* dsp_style="no" *) module flat_shape_classify #(
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
  
  
 reg [10:0] row_y,bottom,l,r,yy;reg [11:0] n;
 always @(posedge I_clk)if(state==REQ)ra<=row_y;
  
  
 localparam AB=$clog2(WIDTH*HEIGHT+1),XB=$clog2(WIDTH),YB=$clog2(HEIGHT);
 reg [AB-1:0] area,hits;
 reg [AB+XB:0] x2;reg [AB+YB:0] y2;
 reg [AB+2*XB+2:0] xx6;reg [AB+2*YB+2:0] yy6;
 reg [AB+XB+YB:0] xy2;
 reg [63:0] cxx,cyy,cxy;reg cxy_neg;
  
  
  
  
 localparam BB_BITS=(2*AB<=64&&AB+2*XB+3<=64&&AB+2*YB+3<=64&&AB+XB+YB+1<=64)?64:128;
 reg [127:0] aa,product,temp;reg [BB_BITS-1:0] bb;
  
  
  
 wire [127:0] mres=product,det=temp,norm=temp<<10;
 reg [2*AB-1:0] a2;reg [4*AB-1:0] a4;reg [6*AB-1:0] a6;
 reg [2*XB+1:0] squares;
  
 localparam CXX_TEMP_BITS=(2*AB+2*XB+4<128)?2*AB+2*XB+4:128;
 localparam CYY_TEMP_BITS=(2*AB+2*YB+4<128)?2*AB+2*YB+4:128;
 localparam CXY_TEMP_BITS=(2*AB+XB+YB+4<128)?2*AB+XB+YB+4:128;
 localparam AREA2_BITS=2*AB<128?2*AB:128;
 localparam AREA4_BITS=4*AB<128?4*AB:128;
 localparam AREA6_BITS=6*AB<128?6*AB:128;
 wire [CXX_TEMP_BITS-1:0] cxx_twice=mres[CXX_TEMP_BITS-1:0]<<1;
 wire [CYY_TEMP_BITS-1:0] cyy_twice=mres[CYY_TEMP_BITS-1:0]<<1;
 wire [CXY_TEMP_BITS-1:0] cxy_six=(mres[CXY_TEMP_BITS-1:0]<<2)+(mres[CXY_TEMP_BITS-1:0]<<1);

  
  
 localparam SQUARE_BITS=2*XB+2,FACTOR_BITS=(SQUARE_BITS>22?SQUARE_BITS:22)+3;
 wire [FACTOR_BITS-1:0] row_square_factor=
     (({{(FACTOR_BITS-SQUARE_BITS){1'b0}},squares}+
       {{(FACTOR_BITS-22){1'b0}},mres[21:0]})<<1)+
       {{(FACTOR_BITS-11){1'b0}},r}-{{(FACTOR_BITS-11){1'b0}},l};
 wire [128:0] determinant_difference={1'b0,temp}-{1'b0,mres};
  
  
 wire [63:0] covariance_b=(mres[63:0]<<1)+mres[63:0];
 wire covariance_negative=temp[63:0]<covariance_b;
 wire [63:0] covariance_difference=temp[63:0]-covariance_b;
 reg good;
 task automatic multiply(input [127:0] a,b,input [4:0] back);
 begin aa<=a;bb<=b;product<=0;ret<=back;state<=MUL;end endtask
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  state<=IDLE;ret<=0;row_y<=0;bottom<=0;l<=0;r<=0;yy<=0;n<=0;
  area<=0;hits<=0;x2<=0;y2<=0;xx6<=0;yy6<=0;xy2<=0;
  aa<=0;bb<=0;product<=0;temp<=0;a2<=0;a4<=0;a6<=0;
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
    if(bb==0)begin state<=ret;end
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
   RR:begin multiply(n,row_square_factor,XX);end
   XX:begin xx6<=xx6+mres[63:0];multiply(n,{116'd0,l}+r,SX);end
   SX:begin x2<=x2+mres[63:0];multiply(n,yy,SY);end
   SY:begin y2<=y2+(mres[63:0]<<1);multiply(yy,yy,YY);end
   YY:begin multiply(mres[21:0],n,YYN);end
   YYN:begin yy6<=yy6+(mres[63:0]<<2)+(mres[63:0]<<1);multiply(yy,{116'd0,l}+r,XY);end
   XY:begin multiply(mres[22:0],n,XYN);end
   XYN:begin xy2<=xy2+mres[63:0];state<=NEXT_ROW;end
   NEXT_ROW:begin
    if(row_y>=bottom)begin multiply(area,xx6,CXX_A);end
    else begin row_y<=row_y+1'b1;state<=REQ;end
   end
   CXX_A:begin temp<=cxx_twice;multiply(x2,x2,CXX_B);end
   CXX_B:begin cxx<=covariance_difference;multiply(area,yy6,CYY_A);end
   CYY_A:begin temp<=cyy_twice;multiply(y2,y2,CYY_B);end
   CYY_B:begin cyy<=covariance_difference;multiply(area,xy2,CXY_A);end
   CXY_A:begin temp<=cxy_six;multiply(x2,y2,CXY_B);end
   CXY_B:begin
    cxy_neg<=covariance_negative;
    cxy<=covariance_negative?(~covariance_difference+64'd1):covariance_difference;
    multiply(cxx,cyy,DET_A);
   end
   DET_A:begin temp<=mres;multiply(cxy,cxy,DET_B);end
   DET_B:begin temp<=determinant_difference[127:0];if(determinant_difference[128]||determinant_difference[127:0]==0)good<=0;multiply(area,area,A2);end
   A2:begin a2<=mres;multiply(mres[AREA2_BITS-1:0],mres[AREA2_BITS-1:0],A4);end
   A4:begin a4<=mres;multiply(mres[AREA4_BITS-1:0],a2,A6);end
   A6:begin a6<=mres;multiply(mres[AREA6_BITS-1:0],128'd880,TLO);end
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
