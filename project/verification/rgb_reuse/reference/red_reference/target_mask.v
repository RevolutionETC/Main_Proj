// Double-buffered half-resolution annotation mask, two display pixels per bit.
// Shared sequential painter replaces a large parallel pixel-rate OSD mux.
module reference_target_mask #(parameter WIDTH=1024,HEIGHT=600,MAX_OBJECTS=8)(
 input wire I_clk,I_rst_n,I_start,I_cancel,I_write_bank,
 input wire [MAX_OBJECTS*48-1:0] I_objects,input wire I_limit,
 output reg O_busy,O_done,
 input wire I_read_bank,input wire [10:0] I_x,I_y,output wire O_ink
);
 localparam W=(WIDTH+1)/2,H=(HEIGHT+1)/2,STRIDE=(W+31)/32,WORDS=STRIDE*H;
 (* ram_style="bram" *) reg [31:0] mask0[0:WORDS-1],mask1[0:WORDS-1];
 reg [12:0] wa;reg [31:0] wd;reg we,wb;
 wire [12:0] scan_addr=(I_y>>1)*STRIDE+(I_x>>6);
 reg [31:0] scan0,scan1,render0,render1;reg [4:0] scan_bit;reg scan_bank;
 always @(posedge I_clk)begin
  if(we&&!wb)mask0[wa]<=wd;
  if(we&&wb)mask1[wa]<=wd;
  render0<=mask0[wa];render1<=mask1[wa];
  scan0<=mask0[scan_addr];scan1<=mask1[scan_addr];
  scan_bit<=I_x[5:1];scan_bank<=I_read_bank;
 end
 assign O_ink=scan_bank?scan1[scan_bit]:scan0[scan_bit];
 wire [31:0] render=wb?render1:render0;
 localparam IDLE=0,CLEAR=1,DRAIN=2,LOAD=3,PIXEL=4,RWAIT=5,RWRITE=6,ADVANCE=7,
  TEXT=8,TEXT_NEXT=9,FINISH=10,LABEL_CHECK=11,LABEL_RETRY=12,LABEL_SAVE=13;
 reg [3:0] state,back;reg [MAX_OBJECTS*48-1:0] batch;reg [3:0] index;
 reg [47:0] cur;reg [9:0] l,r,t,b,x,y,cx,cy,tx,ty;reg [2:0] phase;
 reg [3:0] char_index;reg [2:0] font_row,font_col;reg [1:0] shape;reg any_shape,limit,status;
 reg [4:0] bit_to_set;
 reg [9:0] tag_x[0:MAX_OBJECTS-1],tag_y[0:MAX_OBJECTS-1];
 reg [MAX_OBJECTS-1:0] tag_valid;reg [3:0] tag_scan;reg [2:0] tag_attempt;
 wire tag_collision=tag_valid[tag_scan]&&tx<tag_x[tag_scan]+54&&tag_x[tag_scan]<tx+54&&ty<tag_y[tag_scan]+7&&tag_y[tag_scan]<ty+7;
 reg [7:0] char_code;wire [4:0] font_bits;
 target_ascii_font font(.I_char(char_code),.I_row(font_row),.O_bits(font_bits));
 always @(*)begin
  char_code=" ";
  if(status)begin
   if(limit)case(char_index)0:char_code="L";1:char_code="I";2:char_code="M";3:char_code="I";4:char_code="T";default:;endcase
   else case(char_index)0:char_code="N";1:char_code="O";3:char_code="T";4:char_code="A";5:char_code="R";6:char_code="G";7:char_code="E";8:char_code="T";default:;endcase
  end else case(shape)
   1:case(char_index)0:char_code="C";1:char_code="I";2:char_code="R";3:char_code="C";4:char_code="L";5:char_code="E";default:;endcase
   2:case(char_index)0:char_code="R";1:char_code="E";2:char_code="C";3:char_code="T";4:char_code="A";5:char_code="N";6:char_code="G";7:char_code="L";8:char_code="E";default:;endcase
   3:case(char_index)0:char_code="T";1:char_code="R";2:char_code="I";3:char_code="A";4:char_code="N";5:char_code="G";6:char_code="L";7:char_code="E";default:;endcase
   default:;
  endcase
 end
 task automatic paint(input [9:0] px,py,input [3:0] resume);
 begin wa<=py*STRIDE+(px>>5);bit_to_set<=px[4:0];back<=resume;state<=RWAIT;end endtask
 task automatic text_begin(input [9:0] px,py);
 begin tx<=px;ty<=py;font_row<=0;font_col<=0;char_index<=0;state<=TEXT;end endtask
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  tag_valid<=0;tag_scan<=0;tag_attempt<=0;state<=IDLE;back<=0;batch<=0;index<=0;cur<=0;l<=0;r<=0;t<=0;b<=0;x<=0;y<=0;cx<=0;cy<=0;tx<=0;ty<=0;phase<=0;
  char_index<=0;font_row<=0;font_col<=0;shape<=0;any_shape<=0;limit<=0;status<=0;
  wa<=0;wd<=0;we<=0;wb<=0;bit_to_set<=0;O_busy<=0;O_done<=0;
 end else begin
  O_done<=0;we<=0;
  if(I_cancel)begin state<=IDLE;O_busy<=0;end
  else if(I_start&&!O_busy)begin
   tag_valid<=0;wb<=I_write_bank;batch<=I_objects;limit<=I_limit;O_busy<=1;wa<=0;wd<=0;index<=0;any_shape<=0;status<=0;state<=CLEAR;
  end else case(state)
   CLEAR:begin we<=1;wd<=0;if(we&&wa==WORDS-1)begin we<=0;state<=DRAIN;end else if(we)wa<=wa+1'b1;end
   DRAIN:begin cur<=batch[0+:48];state<=LOAD;end
   LOAD:begin
    if(cur[47]&&cur[46:45]!=0)begin
     any_shape<=1;shape<=cur[46:45];l<=cur[44:35];r<=cur[33:24];t<=cur[22:13];b<=cur[11:2];
     cx<=({1'b0,cur[44:35]}+cur[33:24])>>1;cy<=({1'b0,cur[22:13]}+cur[11:2])>>1;
     x<=cur[44:35];y<=cur[22:13];phase<=0;state<=PIXEL;
    end else if(index==MAX_OBJECTS-1)begin
     if(!any_shape||limit)begin status<=1;text_begin((W-54)/2,H-35);end else state<=FINISH;
    end else begin index<=index+1'b1;cur<=batch[(index+1)*48+:48];end
   end
   PIXEL:paint(x,y,ADVANCE);
   RWAIT:state<=RWRITE;
   RWRITE:begin we<=1;wd<=render|(32'd1<<bit_to_set);state<=back;end
   ADVANCE:begin
    case(phase)
     0:if(x>=r)begin x<=l;y<=b;phase<=1;end else x<=x+1'b1;
     1:if(x>=r)begin x<=l;y<=t;phase<=2;end else x<=x+1'b1;
     2:if(y>=b)begin x<=r;y<=t;phase<=3;end else y<=y+1'b1;
     3:if(y>=b)begin x<=cx>=4?cx-4:0;y<=cy;phase<=4;end else y<=y+1'b1;
     4:if(x>=cx+4)begin x<=cx;y<=cy>=4?cy-4:0;phase<=5;end else x<=x+1'b1;
     5:if(y>=cy+4)begin phase<=6;end else y<=y+1'b1;
     default:;
    endcase
    if(phase==6)begin
     status<=0;text_begin(l>W-54?W-54:l,t>=42?t-9:b<H-44?b+3:H-44);
     tag_attempt<=0;tag_scan<=0;state<=LABEL_CHECK;
    end else state<=PIXEL;
   end
   LABEL_CHECK:begin
    if(tag_collision&&tag_attempt<6)state<=LABEL_RETRY;
    else if(tag_scan==MAX_OBJECTS-1)state<=LABEL_SAVE;
    else tag_scan<=tag_scan+1'b1;
   end
   LABEL_RETRY:begin
    tag_attempt<=tag_attempt+1'b1;tag_scan<=0;state<=LABEL_CHECK;
    case(tag_attempt)
     0:begin tx<=l>W-54?W-54:l;ty<=b<H-44?b+3:H-44;end
     1:begin tx<=r>=53?r-53:0;ty<=t>=42?t-9:33;end
     2:begin tx<=r>=53?r-53:0;ty<=b<H-44?b+3:H-44;end
     3:begin tx<=l>=57?l-57:0;ty<=t<33?33:t>H-44?H-44:t;end
     4:begin tx<=r<W-58?r+4:W-54;ty<=t<33?33:t>H-44?H-44:t;end
     default:begin tx<=l>W-54?W-54:l;ty<=t>=52?t-19:b<H-54?b+13:H-44;end
    endcase
   end
   LABEL_SAVE:begin tag_x[index]<=tx;tag_y[index]<=ty;tag_valid[index]<=1;state<=TEXT;end
   TEXT:begin
    if(font_bits[4-font_col]&&tx+char_index*6+font_col<W&&ty+font_row<H)
     paint(tx+char_index*6+font_col,ty+font_row,TEXT_NEXT);
    else state<=TEXT_NEXT;
   end
   TEXT_NEXT:begin
    if(font_col==4)begin
     font_col<=0;
     if(font_row==6)begin
      font_row<=0;
      if(char_index==8)begin
       if(status)state<=FINISH;
       else if(index==MAX_OBJECTS-1)begin if(limit)begin status<=1;text_begin((W-54)/2,H-35);end else state<=FINISH;end
       else begin index<=index+1'b1;cur<=batch[(index+1)*48+:48];state<=LOAD;end
      end else begin char_index<=char_index+1'b1;state<=TEXT;end
     end else begin font_row<=font_row+1'b1;state<=TEXT;end
    end else begin font_col<=font_col+1'b1;state<=TEXT;end
   end
   FINISH:begin O_done<=1;O_busy<=0;state<=IDLE;end
   default:;
  endcase
 end
endmodule
