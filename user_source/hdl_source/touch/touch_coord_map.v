 
 
module touch_coord_map #(parameter AUTO_SWAP=1,INVERT_X=0,INVERT_Y=0)(
 input wire I_clk,I_rst_n,I_report,input wire [3:0] I_contacts,
 input wire [15:0] I_x,I_y,I_width,I_height,
 output reg O_report,output reg [3:0] O_contacts,output reg [9:0] O_x,O_y
);
 wire sane=I_width>=128&&I_width<=4096&&I_height>=128&&I_height<=4096;
 wire swap_axes=AUTO_SWAP&&sane&&(I_height>I_width);
 wire [15:0] width=sane?(swap_axes?I_height:I_width):16'd1024;
 wire [15:0] height=sane?(swap_axes?I_width:I_height):16'd600;
 wire [15:0] raw_x=swap_axes?I_y:I_x,raw_y=swap_axes?I_x:I_y;
 wire [15:0] cx=(raw_x>=width)?width-1'b1:raw_x;
 wire [15:0] cy=(raw_y>=height)?height-1'b1:raw_y;
 wire [31:0] ywide={16'd0,cy};
 reg [31:0] qx,qy;
 reg [16:0] rx,ry;reg [15:0] dx,dy;
 reg [5:0] count;reg busy;
 wire [16:0] tx={rx[15:0],qx[31]},ty={ry[15:0],qy[31]};
 wire gx=tx>={1'b0,dx},gy=ty>={1'b0,dy};
 wire [31:0] nx={qx[30:0],gx},ny={qy[30:0],gy};
 wire [9:0] sx=(nx>1023)?10'd1023:nx[9:0];
 wire [9:0] sy=(ny>599)?10'd599:ny[9:0];
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin O_report<=0;O_contacts<=0;O_x<=0;O_y<=0;qx<=0;qy<=0;rx<=0;ry<=0;dx<=1;dy<=1;count<=0;busy<=0;end
 else begin
  O_report<=0;
  if(I_report)begin
   O_contacts<=I_contacts;
   if(I_contacts!=1)begin O_report<=1;busy<=0;end
   else begin
    qx<={6'd0,cx,10'd0};qy<=(ywide<<9)+(ywide<<6)+(ywide<<4)+(ywide<<3);
    dx<=width;dy<=height;rx<=0;ry<=0;count<=31;busy<=1;
   end
  end else if(busy)begin
   qx<=nx;qy<=ny;rx<=gx?tx-dx:tx;ry<=gy?ty-dy:ty;
   if(count==0)begin busy<=0;O_report<=1;O_x<=INVERT_X?10'd1023-sx:sx;O_y<=INVERT_Y?10'd599-sy:sy;end
   else count<=count-1'b1;
  end
 end
endmodule
