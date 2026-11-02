 
 
module target_mask #(
 parameter WIDTH=1024,HEIGHT=600,MAX_OBJECTS=8,STALE_FRAMES=3
)(
 input wire I_clk,I_rst_n,I_start,I_cancel,I_enable,I_frame_start,
 input wire [MAX_OBJECTS*48-1:0] I_objects,
 input wire [MAX_OBJECTS*2-1:0] I_colors,
 input wire I_limit,I_capture_limit,
 output reg O_busy,O_done,O_valid,
 output reg [2:0] O_status,output reg [3:0] O_count,
 input wire [10:0] I_x,I_y,output wire [1:0] O_color
);
 localparam W=(WIDTH+1)/2,H=(HEIGHT+1)/2;
 localparam IDLE=0,LOAD=1,BCD=2,LABEL=3,GLYPHS=4,CHECK=5,RETRY=6,SAVE=7,NEXT=8,READY=9;
 reg [3:0] state,index,scan,missed;
 reg [2:0] attempt;reg [3:0] bit_count;
 reg [MAX_OBJECTS*48-1:0] pending_objects,front_objects;
 reg [MAX_OBJECTS*2-1:0] pending_colors,front_colors;
 reg pending_limit,front_limit,pending_ready,front_fault,front_bank;
 reg [9:0] pending_x[0:MAX_OBJECTS-1],pending_y[0:MAX_OBJECTS-1];
 reg [9:0] front_x[0:MAX_OBJECTS-1],front_y[0:MAX_OBJECTS-1];
 reg [4:0] pending_len[0:MAX_OBJECTS-1],front_len[0:MAX_OBJECTS-1];
 reg [MAX_OBJECTS-1:0] tag_valid;
 reg [9:0] tx,ty;
 reg [10:0] bin_x,bin_y;reg [15:0] bcd_x,bcd_y;
 reg [2:0] digits_x,digits_y;reg [4:0] label_len,char_index;
 wire [47:0] cur=pending_objects[index*48+:48];
 wire [10:0] full_l=cur[44:34],full_r=cur[33:23],full_t=cur[22:12],full_b=cur[11:1];
 wire [11:0] center_x_sum={1'b0,full_l}+{1'b0,full_r},center_y_sum={1'b0,full_t}+{1'b0,full_b};
 wire [9:0] l=full_l[10:1],r=full_r[10:1],t=full_t[10:1],b=full_b[10:1];
 wire [7:0] text_width={3'd0,label_len}*8'd6;
 wire [7:0] other_width={3'd0,pending_len[scan]}*8'd6;
 wire tag_collision=tag_valid[scan]&&tx<pending_x[scan]+other_width&&pending_x[scan]<tx+text_width&&ty<pending_y[scan]+7&&pending_y[scan]<ty+7;
 function [15:0] adjust_bcd(input [15:0] value);
  integer a;reg [15:0] q;begin q=value;for(a=0;a<4;a=a+1)if(q[a*4+:4]>=5)q[a*4+:4]=q[a*4+:4]+4'd3;adjust_bcd=q;end
 endfunction
 function [2:0] digit_count(input [15:0] value);begin
  digit_count=value[15:12]!=0?4:value[11:8]!=0?3:value[7:4]!=0?2:1;
 end endfunction
 function [4:0] name_length(input [1:0] kind);begin name_length=kind==1?6:kind==2?9:8;end endfunction
  
  
 function [7:0] name_char(input [4:0] pos,input [1:0] kind);begin
  name_char=0;
  case(kind)
   1:case(pos)0:name_char="C";1:name_char="I";2:name_char="R";3:name_char="C";4:name_char="L";5:name_char="E";default:;endcase
   2:case(pos)0:name_char="R";1:name_char="E";2:name_char="C";3:name_char="T";4:name_char="A";5:name_char="N";6:name_char="G";7:name_char="L";8:name_char="E";default:;endcase
   default:case(pos)0:name_char="T";1:name_char="R";2:name_char="I";3:name_char="A";4:name_char="N";5:name_char="G";6:name_char="L";7:name_char="E";default:;endcase
  endcase
 end endfunction
 wire [4:0] computed_len=name_length(cur[46:45])+5'd4+digit_count(bcd_x)+digit_count(bcd_y);
 wire [7:0] computed_width={3'd0,computed_len}*8'd6;
 function [7:0] label_char(input [4:0] pos,input [1:0] kind,input [15:0] bx,by,input [2:0] nx,ny);
  integer n,p;begin
   n=name_length(kind);p=pos-n-2;
   if(pos<n)label_char=name_char(pos,kind);
   else if(pos==n)label_char=" ";else if(pos==n+1)label_char="(";
   else if(p<nx)label_char="0"+((bx>>((nx-1-p)*4))&15);
   else if(p==nx)label_char=",";
   else if(p<nx+1+ny)label_char="0"+((by>>((ny-1-(p-nx-1))*4))&15);
   else label_char=")";
  end
 endfunction
 wire [7:0] write_char=label_char(char_index,cur[46:45],bcd_x,bcd_y,digits_x,digits_y);
 wire [34:0] write_glyph;
 target_ascii_font glyph_encoder(.I_char(write_char),.I_row(3'd0),.O_bits(),.O_glyph(write_glyph));
  
 (* ram_style="bram" *) reg [34:0] glyphs[0:MAX_OBJECTS*64-1];
 wire [8:0] write_addr={1'b0,index[2:0],char_index}+(!front_bank?MAX_OBJECTS*32:0);
 always @(posedge I_clk)begin
  if(I_rst_n&&!I_cancel&&state==GLYPHS)begin
   glyphs[write_addr]<=write_glyph;
  end
 end
 integer j;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  state<=IDLE;attempt<=0;index<=0;scan<=0;missed<=0;pending_objects<=0;front_objects<=0;
  pending_colors<=0;front_colors<=0;pending_limit<=0;front_limit<=0;pending_ready<=0;front_fault<=0;front_bank<=0;
  tag_valid<=0;tx<=0;ty<=0;O_busy<=0;O_done<=0;O_valid<=0;bit_count<=0;bin_x<=0;bin_y<=0;bcd_x<=0;bcd_y<=0;digits_x<=0;digits_y<=0;label_len<=0;char_index<=0;
  for(j=0;j<MAX_OBJECTS;j=j+1)begin pending_x[j]<=0;pending_y[j]<=0;front_x[j]<=0;front_y[j]<=0;pending_len[j]<=0;front_len[j]<=0;end
 end else begin
  O_done<=0;
  if(I_cancel)begin state<=IDLE;pending_ready<=0;O_busy<=0;O_valid<=0;front_fault<=0;missed<=0;end
  else begin
   if(I_frame_start)begin
    if(!I_enable)begin O_valid<=0;pending_ready<=0;O_busy<=0;state<=IDLE;front_fault<=0;missed<=0;end
    else if(pending_ready)begin
     front_objects<=pending_objects;front_colors<=pending_colors;front_limit<=pending_limit;front_bank<=!front_bank;
     for(j=0;j<MAX_OBJECTS;j=j+1)begin front_x[j]<=pending_x[j];front_y[j]<=pending_y[j];front_len[j]<=pending_len[j];end
     pending_ready<=0;O_busy<=0;O_valid<=1;front_fault<=0;missed<=0;
    end else if(I_capture_limit)begin O_valid<=1;front_fault<=1;end
    else if(O_valid)begin if(missed<STALE_FRAMES)missed<=missed+1'b1;else front_fault<=1;end
   end
   if(I_start&&!O_busy&&I_enable)begin
    pending_objects<=I_objects;pending_colors<=I_colors;pending_limit<=I_limit;
    pending_ready<=0;O_busy<=1;tag_valid<=0;index<=0;state<=LOAD;
   end else case(state)
    LOAD:begin
     if(cur[47]&&cur[46:45]!=0&&pending_colors[index*2+:2]!=0)begin
      bin_x<=center_x_sum[11:1];bin_y<=center_y_sum[11:1];bcd_x<=0;bcd_y<=0;bit_count<=0;state<=BCD;
     end else begin pending_len[index]<=0;state<=NEXT;end
    end
    BCD:begin
     bcd_x<={adjust_bcd(bcd_x),bin_x[10]};bcd_y<={adjust_bcd(bcd_y),bin_y[10]};bin_x<=bin_x<<1;bin_y<=bin_y<<1;
     if(bit_count==10)state<=LABEL;else bit_count<=bit_count+1'b1;
    end
    LABEL:begin
     digits_x<=digit_count(bcd_x);digits_y<=digit_count(bcd_y);label_len<=computed_len;pending_len[index]<=computed_len;char_index<=0;
     tx<=l>W-computed_width?W-computed_width:l;ty<=t>=42?t-9:b<H-44?b+3:H-44;attempt<=0;scan<=0;state<=GLYPHS;
    end
    GLYPHS:if(char_index+1>=label_len)state<=CHECK;else char_index<=char_index+1'b1;
    CHECK:begin if(tag_collision&&attempt<6)state<=RETRY;else if(scan==MAX_OBJECTS-1)state<=SAVE;else scan<=scan+1'b1;end
    RETRY:begin
     attempt<=attempt+1'b1;scan<=0;state<=CHECK;
     case(attempt)
      0:begin tx<=l>W-text_width?W-text_width:l;ty<=b<H-44?b+3:H-44;end
      1:begin tx<=r+1>=text_width?r+1-text_width:0;ty<=t>=42?t-9:33;end
      2:begin tx<=r+1>=text_width?r+1-text_width:0;ty<=b<H-44?b+3:H-44;end
      3:begin tx<=l>=text_width+3?l-text_width-3:0;ty<=t<33?33:t>H-44?H-44:t;end
      4:begin tx<=r<W-text_width-4?r+4:W-text_width;ty<=t<33?33:t>H-44?H-44:t;end
      default:begin tx<=l>W-text_width?W-text_width:l;ty<=t>=52?t-19:b<H-54?b+13:H-44;end
     endcase
    end
    SAVE:begin pending_x[index]<=tx;pending_y[index]<=ty;tag_valid[index]<=1;state<=NEXT;end
    NEXT:if(index==MAX_OBJECTS-1)state<=READY;else begin index<=index+1'b1;state<=LOAD;end
    READY:begin pending_ready<=1;O_done<=1;state<=IDLE;end
    default:;
   endcase
  end
 end
 wire [9:0] hx=I_x[10:1],hy=I_y[10:1];
 wire [MAX_OBJECTS-1:0] visible,box_ink,text_region;
 wire [9:0] text_dx[0:MAX_OBJECTS-1],text_dy[0:MAX_OBJECTS-1];
 genvar k;
 generate for(k=0;k<MAX_OBJECTS;k=k+1)begin: target_pixel
  wire [47:0] item=front_objects[k*48+:48];
  wire [1:0] kind=item[46:45],palette=front_colors[k*2+:2];
  wire [9:0] xl=item[44:35],xr=item[33:24],yt=item[22:13],yb=item[11:2];
  wire [11:0] sx={1'b0,item[44:34]}+{1'b0,item[33:23]},sy={1'b0,item[22:12]}+{1'b0,item[11:1]};
  wire [9:0] cx=sx[11:2],cy=sy[11:2];
  wire hit=((hx==xl||hx==xr)&&hy>=yt&&hy<=yb)||((hy==yt||hy==yb)&&hx>=xl&&hx<=xr);
  wire cross_hit=(hy==cy&&hx>=(cx>=4?cx-4:0)&&hx<=cx+4)||(hx==cx&&hy>=(cy>=4?cy-4:0)&&hy<=cy+4);
  assign visible[k]=item[47]&&kind!=0&&palette!=0&&xl<=xr&&yt<=yb;
  assign box_ink[k]=visible[k]&&(hit||cross_hit);
  assign text_dx[k]=hx-front_x[k];assign text_dy[k]=hy-front_y[k];
  assign text_region[k]=visible[k]&&hx>=front_x[k]&&hy>=front_y[k]&&text_dx[k]<front_len[k]*6&&text_dy[k]<7;
 end endgenerate
 integer n;reg [1:0] box_palette,text_palette;reg [2:0] box_slot,text_slot;
 reg text_on;reg [9:0] selected_dx;reg [2:0] selected_row;
 always @(*)begin
  O_count=0;for(n=0;n<MAX_OBJECTS;n=n+1)if(visible[n])O_count=O_count+1'b1;
  if(!I_enable)O_status=0;else if(!O_valid)O_status=1;else if(front_fault||front_limit)O_status=2;else if(O_count==0)O_status=3;else O_status=4;
  if(front_fault||!O_valid||!I_enable)O_count=0;
  box_palette=0;text_palette=0;box_slot=0;text_slot=0;text_on=0;selected_dx=0;selected_row=0;
  if(O_valid&&I_enable&&!front_fault&&I_x<WIDTH&&I_y<HEIGHT)begin
   for(n=0;n<MAX_OBJECTS;n=n+1)begin
    if(box_ink[n])begin box_palette=front_colors[n*2+:2];box_slot=n;end
    if(text_region[n])begin text_on=1;text_slot=n;text_palette=front_colors[n*2+:2];selected_dx=text_dx[n];selected_row=text_dy[n][2:0];end
   end
  end
 end
 wire [4:0] read_char=selected_dx/10'd6;wire [2:0] read_col=selected_dx%10'd6;
 wire [8:0] read_addr={1'b0,text_slot,read_char}+(front_bank?MAX_OBJECTS*32:0);
 reg [34:0] glyph_q;reg text_d;
 reg [2:0] row_d,col_d,box_slot_d,text_slot_d;reg [1:0] box_d,text_palette_d;
  
 always @(posedge I_clk)begin glyph_q<=glyphs[read_addr];end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin text_d<=0;row_d<=0;col_d<=0;box_d<=0;text_palette_d<=0;box_slot_d<=0;text_slot_d<=0;end
 else begin text_d<=text_on;row_d<=selected_row;col_d<=read_col;box_d<=box_palette;text_palette_d<=text_palette;box_slot_d<=box_slot;text_slot_d<=text_slot;end
 wire [34:0] pixel_glyph=glyph_q;
 wire [5:0] glyph_bit=6'd34-{3'd0,row_d}*6'd5-{3'd0,col_d};
 wire letter_hit=text_d&&col_d<5&&row_d<7&&pixel_glyph[glyph_bit];
 assign O_color=letter_hit&&(box_d==0||text_slot_d>=box_slot_d)?text_palette_d:box_d;
endmodule
