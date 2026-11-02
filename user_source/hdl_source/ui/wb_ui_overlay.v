 
module wb_ui_overlay #(parameter HUD_ENABLE=1,parameter FONT_FILE="../../../user_source/hdl_source/ui/wb_ui_font.hex",
 parameter TEXT_FILE="../../../user_source/hdl_source/ui/wb_ui_text.hex")(
 input wire I_clk,I_rst_n,input wire [51:0] I_config,
 input wire [9:0] I_ae_telemetry,
 input wire [7:0] I_hist_height,input wire I_hist_valid,
 output wire [5:0] O_hist_read_addr,output wire O_hist_frame_start,
 input wire [36:0] I_telemetry,input wire [51:0] I_target_info,
 input wire [8:0] I_latency,input wire [23:0] I_diagnostics,input wire [7:0] I_underflow,
 input wire I_vsync,I_hsync,I_de,input wire [23:0] I_data,
 output reg O_tag_enable,output reg O_vsync,O_hsync,O_de,output reg [23:0] O_data
);
 localparam [51:0] CONFIG_RESET={7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b0,1'b0,4'd0,
                                  2'd0,2'd0,7'd30,7'd80,3'd0,1'b0};
 reg [51:0] cfg;
 reg vs_d,de_d,pending;
 reg [10:0] x_count,y_count;
 wire frame_start=I_vsync&&!vs_d;
 wire [10:0] x=frame_start?11'd0:x_count,y=frame_start?11'd0:y_count;
  
 wire [51:0] active=(pending||frame_start)?I_config:cfg;
 reg [36:0] telemetry_cfg;reg [9:0] ae_cfg;
 wire [9:0] ae=(pending||frame_start)?I_ae_telemetry:ae_cfg;
 wire hist_enable=active[43],hist_auto=active[44];
 wire [6:0] hist_strength=hist_auto?7'd100:active[51:45];
 wire [10:0] hist_thumb=11'd592+{2'd0,hist_strength,2'd0};
 wire hist_manual=hist_enable&&!hist_auto;
 assign O_hist_frame_start=frame_start;
 assign O_hist_read_addr=x[8:3]-6'd4;
 wire ae_enable=active[39],show_meter=active[42];wire [1:0] meter_mode=active[41:40];
 wire [36:0] telemetry=(pending||frame_start)?I_telemetry:telemetry_cfg;
 reg [8:0] latency_cfg;reg [23:0] diagnostics_cfg;reg [7:0] underflow_cfg;
 wire [8:0] latency=(pending||frame_start)?I_latency:latency_cfg;
 wire [23:0] diagnostics=(pending||frame_start)?I_diagnostics:diagnostics_cfg;
 wire [7:0] underflow=(pending||frame_start)?I_underflow:underflow_cfg;
 wire latency_valid=latency[8];wire [7:0] latency_frames=latency[7:0];
 wire signed [4:0] ab=active[37:33],gm=active[32:28];
 wire signed [10:0] point_x=11'sd800+$signed(ab)*11'sd14;
 wire signed [10:0] point_y=11'sd300-$signed(gm)*11'sd14;
 wire [21:0] rr=telemetry[35:24]*22'd100+22'd512;
 wire [21:0] rg=telemetry[23:12]*22'd100+22'd512;
 wire [21:0] rb=telemetry[11:0]*22'd100+22'd512;
 wire [9:0] tr100=rr[19:10],tg100=rg[19:10],tb100=rb[19:10];
 wire [3:0] page=active[25:22];wire [1:0] wb_mode=active[21:20];wire manual_mode=wb_mode==2;
 wire [6:0] index=active[17:11],gain=ae_enable?ae[6:0]:active[10:4];wire [2:0] image_mode=active[3:1];
 wire online=active[0],tag_enable=active[26],detect_enable=active[27];
  
 wire bars_visible=!active[18];
 wire menu_panel=page!=0&&x>=560&&x<1024&&y<600;
 wire [7:0] k_units={1'b0,index}+8'd25;
 wire [6:0] gain_level=(gain<16)?7'd0:gain-7'd16;
  
 wire [7:0] gain_argument=(gain<48)?{1'b0,gain}+8'd16:
                          (gain<80)?{1'b0,gain}-8'd16:{1'b0,gain}-8'd48;
 wire [11:0] gain_product=gain_argument*12'd25;
 wire [15:0] gain_scaled=(gain<48)?({4'd0,gain_product}+16'd4)>>3:
                            (gain<80)?({4'd0,gain_product}+16'd2)>>2:
                                      ({4'd0,gain_product}+16'd1)>>1;
 wire [9:0] gain100=gain_scaled[9:0];
 wire [10:0] thumb_x=11'd600+index*11'd5;
 wire [10:0] gain_x=11'd600+gain_level*11'd5;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin ae_cfg<=10'd80;telemetry_cfg<={1'b0,12'd1024,12'd1024,12'd1024};latency_cfg<=0;diagnostics_cfg<=0;underflow_cfg<=0;cfg<=CONFIG_RESET;vs_d<=0;de_d<=0;pending<=1;x_count<=0;y_count<=0;end
 else begin
  vs_d<=I_vsync;de_d<=I_de;
  if(frame_start)begin x_count<=I_de?11'd1:11'd0;y_count<=0;pending<=1;end
  else begin
   if(I_de)x_count<=x_count+1'b1;else x_count<=0;
   if(de_d&&!I_de)y_count<=y_count+1'b1;
  end
  if(I_de&&(pending||frame_start))begin cfg<=I_config;telemetry_cfg<=I_telemetry;ae_cfg<=I_ae_telemetry;latency_cfg<=I_latency;diagnostics_cfg<=I_diagnostics;underflow_cfg<=I_underflow;pending<=0;end
 end
  
 reg [51:0] target_info_cfg;
 wire [51:0] target_info=(pending||frame_start)?I_target_info:target_info_cfg;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)target_info_cfg<=0;else if(I_de&&(pending||frame_start))target_info_cfg<=I_target_info;
 function [7:0] hud_char(input [1:0] field,input [4:0] pos,input [51:0] info);
  reg [11:0] rate;reg [3:0] digit;begin
   rate=field==1?info[44:33]:info[32:21];digit=0;hud_char=" ";
   case(field)
    0:begin
      
     case(pos)
      0:case(info[51:49])0:hud_char="O";1:hud_char="W";2:hud_char="L";3:hud_char="N";default:hud_char="R";endcase
      1:case(info[51:49])0:hud_char="F";1:hud_char="A";2:hud_char="I";3:hud_char="O";default:hud_char="U";endcase
      2:case(info[51:49])0:hud_char="F";1:hud_char="I";2:hud_char="M";3:hud_char=" ";default:hud_char="N";endcase
      3:case(info[51:49])1:hud_char="T";2:hud_char="I";3:hud_char="T";4:hud_char=":";default:;endcase
      4:case(info[51:49])2:hud_char="T";3:hud_char="A";4:hud_char="0"+info[48:45];default:;endcase
      5:if(info[51:49]==3)hud_char="R";
      6:if(info[51:49]==3)hud_char="G";
      7:if(info[51:49]==3)hud_char="E";
      8:if(info[51:49]==3)hud_char="T";
      default:;
     endcase
    end
    1,2:begin
     case(pos)
      0:hud_char=field==1?"F":"D";1:hud_char=field==1?"P":"E";2:hud_char=field==1?"S":"T";3:hud_char=":";
      4:if(rate[11:8]!=0)hud_char="0"+rate[11:8];
      5:if(rate[11:4]!=0)hud_char="0"+rate[7:4];6:hud_char="0"+rate[3:0];default:;
     endcase
    end
    3:begin
     case(pos)
      0:hud_char="L";1:hud_char="A";2:hud_char="T";3:hud_char=":";
      4:if(info[20])begin if(info[19:16]!=0)hud_char="0"+info[19:16];end else hud_char="-";
      5:if(info[20])begin if(info[19:12]!=0)hud_char="0"+info[15:12];end else hud_char="-";
      6:hud_char=info[20]?"0"+info[11:8]:"-";7:hud_char=".";
      8:hud_char=info[20]?"0"+info[7:4]:"-";9:hud_char=info[20]?"0"+info[3:0]:"-";
      10:hud_char="m";11:hud_char="s";default:;
     endcase
    end
   endcase
  end
 endfunction
 reg hud_on;reg [1:0] hud_field;reg [10:0] hud_dx,hud_y;
 reg [23:0] hud_color;
 always @(*)begin
  hud_on=0;hud_field=0;hud_dx=0;hud_y=552;hud_color=24'hf3f6fa;
  if(HUD_ENABLE&&bars_visible&&!menu_panel&&y>=552&&y<566)begin
   if(x>=16&&x<136)begin hud_on=1;hud_field=0;hud_dx=x-16;
   end else if(x>=152&&x<236)begin hud_on=1;hud_field=1;hud_dx=x-152;end
   else if(x>=260&&x<344)begin hud_on=1;hud_field=2;hud_dx=x-260;end
   else if(x>=368&&x<512)begin hud_on=1;hud_field=3;hud_dx=x-368;end
  end
   
   
  if(HUD_ENABLE&&page==13)begin
   if(y>=112&&y<126&&x>=600&&x<720)begin hud_on=1;hud_field=0;hud_dx=x-600;hud_y=112;end
   else if(y>=148&&y<162)begin
    if(x>=600&&x<684)begin hud_on=1;hud_field=1;hud_dx=x-600;hud_y=148;end
    else if(x>=800&&x<884)begin hud_on=1;hud_field=2;hud_dx=x-800;hud_y=148;end
   end else if(y>=180&&y<194&&x>=600&&x<744)begin hud_on=1;hud_field=3;hud_dx=x-600;hud_y=180;end
  end
  if(hud_on&&hud_field==0)
   case(target_info[51:49])2:hud_color=24'hffb43c;3:hud_color=24'hff6060;4:hud_color=24'h50df90;default:hud_color=24'hb6c6d8;endcase
 end
  
  
 function [6:0] divide_by3_6(input [5:0] value);begin case(value)
  6'd0:divide_by3_6={5'd0,2'd0};
  6'd1:divide_by3_6={5'd0,2'd1};
  6'd2:divide_by3_6={5'd0,2'd2};
  6'd3:divide_by3_6={5'd1,2'd0};
  6'd4:divide_by3_6={5'd1,2'd1};
  6'd5:divide_by3_6={5'd1,2'd2};
  6'd6:divide_by3_6={5'd2,2'd0};
  6'd7:divide_by3_6={5'd2,2'd1};
  6'd8:divide_by3_6={5'd2,2'd2};
  6'd9:divide_by3_6={5'd3,2'd0};
  6'd10:divide_by3_6={5'd3,2'd1};
  6'd11:divide_by3_6={5'd3,2'd2};
  6'd12:divide_by3_6={5'd4,2'd0};
  6'd13:divide_by3_6={5'd4,2'd1};
  6'd14:divide_by3_6={5'd4,2'd2};
  6'd15:divide_by3_6={5'd5,2'd0};
  6'd16:divide_by3_6={5'd5,2'd1};
  6'd17:divide_by3_6={5'd5,2'd2};
  6'd18:divide_by3_6={5'd6,2'd0};
  6'd19:divide_by3_6={5'd6,2'd1};
  6'd20:divide_by3_6={5'd6,2'd2};
  6'd21:divide_by3_6={5'd7,2'd0};
  6'd22:divide_by3_6={5'd7,2'd1};
  6'd23:divide_by3_6={5'd7,2'd2};
  6'd24:divide_by3_6={5'd8,2'd0};
  6'd25:divide_by3_6={5'd8,2'd1};
  6'd26:divide_by3_6={5'd8,2'd2};
  6'd27:divide_by3_6={5'd9,2'd0};
  6'd28:divide_by3_6={5'd9,2'd1};
  6'd29:divide_by3_6={5'd9,2'd2};
  6'd30:divide_by3_6={5'd10,2'd0};
  6'd31:divide_by3_6={5'd10,2'd1};
  6'd32:divide_by3_6={5'd10,2'd2};
  6'd33:divide_by3_6={5'd11,2'd0};
  6'd34:divide_by3_6={5'd11,2'd1};
  6'd35:divide_by3_6={5'd11,2'd2};
  6'd36:divide_by3_6={5'd12,2'd0};
  6'd37:divide_by3_6={5'd12,2'd1};
  6'd38:divide_by3_6={5'd12,2'd2};
  6'd39:divide_by3_6={5'd13,2'd0};
  6'd40:divide_by3_6={5'd13,2'd1};
  6'd41:divide_by3_6={5'd13,2'd2};
  6'd42:divide_by3_6={5'd14,2'd0};
  6'd43:divide_by3_6={5'd14,2'd1};
  6'd44:divide_by3_6={5'd14,2'd2};
  6'd45:divide_by3_6={5'd15,2'd0};
  6'd46:divide_by3_6={5'd15,2'd1};
  6'd47:divide_by3_6={5'd15,2'd2};
  6'd48:divide_by3_6={5'd16,2'd0};
  6'd49:divide_by3_6={5'd16,2'd1};
  6'd50:divide_by3_6={5'd16,2'd2};
  6'd51:divide_by3_6={5'd17,2'd0};
  6'd52:divide_by3_6={5'd17,2'd1};
  6'd53:divide_by3_6={5'd17,2'd2};
  6'd54:divide_by3_6={5'd18,2'd0};
  6'd55:divide_by3_6={5'd18,2'd1};
  6'd56:divide_by3_6={5'd18,2'd2};
  6'd57:divide_by3_6={5'd19,2'd0};
  6'd58:divide_by3_6={5'd19,2'd1};
  6'd59:divide_by3_6={5'd19,2'd2};
  6'd60:divide_by3_6={5'd20,2'd0};
  6'd61:divide_by3_6={5'd20,2'd1};
  6'd62:divide_by3_6={5'd20,2'd2};
  6'd63:divide_by3_6={5'd21,2'd0};
 endcase end endfunction
 wire [6:0] hud_div3=divide_by3_6(hud_dx[7:2]);
 wire [4:0] hud_cell=hud_div3[6:2];
 wire [2:0] hud_col={hud_div3[1:0],hud_dx[1]},hud_row=(y-hud_y)>>1;
 wire [7:0] hud_ascii=hud_char(hud_field,hud_cell,target_info);
 wire [4:0] hud_bits;
 target_ascii_font hud_font(.I_char(hud_ascii),.I_row(hud_row),.O_bits(hud_bits),.O_glyph());
 wire hud_pixel=hud_on&&hud_col<5&&hud_bits[4-hud_col];
 reg hud_pixel_a,hud_pixel_d;reg [23:0] hud_color_a,hud_color_d;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin hud_pixel_a<=0;hud_pixel_d<=0;hud_color_a<=0;hud_color_d<=0;end
 else begin hud_pixel_a<=hud_pixel;hud_pixel_d<=hud_pixel_a;hud_color_a<=hud_color;hud_color_d<=hud_color_a;end
  
  
 reg decimal_start,decimal_busy;
 reg [3:0] decimal_field;reg [4:0] decimal_bit;
  
  
 wire [11:0] scale_argument=decimal_start?{4'd0,gain_argument}:
    decimal_field==0?telemetry[35:24]:decimal_field==1?telemetry[23:12]:telemetry[11:0];
 wire [16:0] scale_product=scale_argument*17'd25;
 wire [7:0] scale_rounding=decimal_start?(gain<48?8'd4:gain<80?8'd2:8'd1):8'd128;
 wire [17:0] rounded_scale={1'b0,scale_product}+{10'd0,scale_rounding};
 wire [9:0] serial_scale100=!decimal_start?{1'b0,rounded_scale[16:8]}:
     gain<48?rounded_scale[12:3]:gain<80?rounded_scale[11:2]:rounded_scale[10:1];
 reg [15:0] decimal_binary,decimal_bcd;
 reg [15:0] dec_gain,dec_r,dec_g,dec_b;
 reg [11:0] dec_age,dec_peak,dec_drop,dec_overflow,dec_underflow;
 reg [15:0] adjusted_bcd;integer nib;
 always @(*)begin
  adjusted_bcd=decimal_bcd;
  for(nib=0;nib<4;nib=nib+1)
   if(decimal_bcd[nib*4+:4]>=5)adjusted_bcd[nib*4+:4]=decimal_bcd[nib*4+:4]+4'd3;
 end
 wire [15:0] shifted_bcd={adjusted_bcd[14:0],decimal_binary[15]};
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  decimal_start<=0;decimal_busy<=0;decimal_field<=0;decimal_bit<=0;
  decimal_binary<=0;decimal_bcd<=0;dec_gain<=16'h0400;
  dec_r<=16'h0100;dec_g<=16'h0100;dec_b<=16'h0100;
  dec_age<=0;dec_peak<=0;dec_drop<=0;dec_overflow<=0;dec_underflow<=0;
 end else begin
  decimal_start<=I_de&&(pending||frame_start);
  if(decimal_start)begin
   decimal_busy<=1;decimal_field<=0;decimal_bit<=0;decimal_bcd<=0;decimal_binary<={6'd0,serial_scale100};
  end else if(decimal_busy)begin
   decimal_binary<={decimal_binary[14:0],1'b0};decimal_bcd<=shifted_bcd;decimal_bit<=decimal_bit+1'b1;
   if(decimal_bit==15)begin
    decimal_bit<=0;decimal_bcd<=0;decimal_field<=decimal_field+1'b1;
    case(decimal_field)
     0:begin dec_gain<=shifted_bcd;decimal_binary<={6'd0,serial_scale100};end
     1:begin dec_r<=shifted_bcd;decimal_binary<={6'd0,serial_scale100};end
     2:begin dec_g<=shifted_bcd;decimal_binary<={6'd0,serial_scale100};end
     3:begin dec_b<=shifted_bcd;decimal_binary<={8'd0,latency_frames};end
     4:begin dec_age<=shifted_bcd[11:0];decimal_binary<={8'd0,diagnostics[23:16]};end
     5:begin dec_peak<=shifted_bcd[11:0];decimal_binary<={8'd0,diagnostics[15:8]};end
     6:begin dec_drop<=shifted_bcd[11:0];decimal_binary<={8'd0,diagnostics[7:0]};end
     7:begin dec_overflow<=shifted_bcd[11:0];decimal_binary<={8'd0,underflow};end
     8:begin dec_underflow<=shifted_bcd[11:0];decimal_busy<=0;end
     default:decimal_busy<=0;
    endcase
   end
  end
 end
     localparam [7:0] CHAR_MINUS=8'd2;
    localparam [7:0] CHAR_PERCENT=8'd1;
    localparam [7:0] DIGIT_0=8'd5;
    localparam [7:0] DIGIT_1=8'd6;
    localparam [7:0] DIGIT_7=8'd12;
    localparam [7:0] DIGIT_3=8'd8;
    localparam [7:0] LETTER_K=8'd20;
    localparam [7:0] CHAR_ZENG=8'd62;
    localparam [7:0] CHAR_YI=8'd129;
    localparam [7:0] CHAR_SLASH=8'd4;
    localparam [7:0] CHAR_DOT=8'd3;
    localparam [7:0] CHAR_BEI=8'd37;
    localparam [7:0] CHAR_R=8'd24;
    localparam [7:0] CHAR_G=8'd18;
    localparam [7:0] CHAR_B=8'd16;
    localparam [7:0] CHAR_A=8'd15;
    localparam [7:0] CHAR_M=8'd21;
    localparam [7:0] CHAR_AN=8'd93;
    localparam [7:0] CHAR_JIAN=8'd169;
    function [7:0] digit_glyph(input [3:0] n);begin case(n)
        4'd0:digit_glyph=8'd5;
        4'd1:digit_glyph=8'd6;
        4'd2:digit_glyph=8'd7;
        4'd3:digit_glyph=8'd8;
        4'd4:digit_glyph=8'd9;
        4'd5:digit_glyph=8'd10;
        4'd6:digit_glyph=8'd11;
        4'd7:digit_glyph=8'd12;
        4'd8:digit_glyph=8'd13;
        4'd9:digit_glyph=8'd14;
        default:digit_glyph=8'd0;endcase end endfunction
    function [7:0] glyph(input [6:0] text_id,input [5:0] pos);
        reg [11:0] diagnostic_digits;
        begin
            diagnostic_digits=text_id==106?dec_age:text_id==107?dec_peak:text_id==108?dec_drop:text_id==109?dec_overflow:dec_underflow;
            glyph=8'd0;
            case(text_id)
            7'd106,7'd107,7'd108,7'd109,7'd110:case(pos)
                0:glyph=(text_id==106&&!latency_valid)?CHAR_MINUS:digit_glyph(diagnostic_digits[11:8]);
                1:glyph=(text_id==106&&!latency_valid)?CHAR_MINUS:digit_glyph(diagnostic_digits[7:4]);
                2:glyph=(text_id==106&&!latency_valid)?CHAR_MINUS:digit_glyph(diagnostic_digits[3:0]);
                default:;endcase
            7'd88:case(pos)
                0:if(hist_strength>=100)glyph=DIGIT_1;
                1:if(hist_strength>=10)glyph=digit_glyph((hist_strength/10)%10);
                2:glyph=digit_glyph(hist_strength%10);
                3:glyph=CHAR_PERCENT;
                default:;endcase
            6'd28:case(pos)
                0:if(k_units>=100)glyph=DIGIT_1;
                1:glyph=digit_glyph((k_units/10)%10);
                2:glyph=digit_glyph(k_units%10);
                3,4:glyph=DIGIT_0;
                5:glyph=LETTER_K;
                default:;endcase
            6'd29:case(pos)
                0:glyph=digit_glyph(dec_gain[11:8]);
                1:glyph=CHAR_DOT;
                2:glyph=digit_glyph(dec_gain[7:4]);
                3:glyph=digit_glyph(dec_gain[3:0]);
                4:glyph=CHAR_BEI;
                default:;endcase
            6'd47,6'd48,6'd49:case(pos)
                0:glyph=(text_id==47)?CHAR_R:(text_id==48)?CHAR_G:CHAR_B;
                2:glyph=digit_glyph(((text_id==47)?dec_r[11:8]:(text_id==48)?dec_g[11:8]:dec_b[11:8]));
                3:glyph=CHAR_DOT;
                4:glyph=digit_glyph(((text_id==47)?dec_r[7:4]:(text_id==48)?dec_g[7:4]:dec_b[7:4]));
                5:glyph=digit_glyph(((text_id==47)?dec_r[3:0]:(text_id==48)?dec_g[3:0]:dec_b[3:0]));
                6:glyph=CHAR_BEI;
                default:;endcase
            6'd52:case(pos)
                0:glyph=CHAR_AN;1:glyph=CHAR_JIAN;
                3:glyph=active[38]?CHAR_G:CHAR_B;
                4:glyph=active[38]?CHAR_M:CHAR_A;
                default:;endcase
            6'd50:case(pos)
                0:glyph=ab<0?CHAR_B:CHAR_A;
                1:glyph=digit_glyph(ab<0?-ab:ab);
                default:;endcase
            6'd51:case(pos)
                0:glyph=gm<0?CHAR_M:CHAR_G;
                1:glyph=digit_glyph(gm<0?-gm:gm);
                default:;endcase
            default:;
            endcase
        end
    endfunction

 function [23:0] blend50(input [23:0] a,b);
  reg [8:0] r,g,bb;begin
   r={1'b0,a[23:16]}+{1'b0,b[23:16]};
   g={1'b0,a[15:8]}+{1'b0,b[15:8]};
   bb={1'b0,a[7:0]}+{1'b0,b[7:0]};blend50={r[8:1],g[8:1],bb[8:1]};
  end endfunction
 function automatic in_rect(input [10:0] px,py,input integer left,top,right,bottom);
  begin in_rect=px>=left&&px<right&&py>=top&&py<bottom;end
 endfunction
  
  
 function grid14(input [7:0] distance);
  reg [3:0] residue;begin
   residue={3'b0,distance[7]}+{1'b0,distance[6:4]}+{1'b0,distance[3:1]};
   grid14=!distance[0]&&(residue==0||residue==7||residue==14);
  end
 endfunction
 function automatic box_edge(input [10:0] px,py,input integer left,top,right,bottom);
  begin box_edge=px>=left&&px<right&&py>=top&&py<bottom&&
          (px<left+2||px>=right-2||py<top+2||py>=bottom-2);end
 endfunction
 wire meter_edge=meter_mode==0?box_edge(x,y,448,236,576,364):
                 meter_mode==3?box_edge(x,y,392,180,632,420):
                 meter_mode==1?(box_edge(x,y,0,0,1024,600)||box_edge(x,y,256,150,768,450)):
                 (x<1024&&y<600&&(box_edge(x,y,0,0,1024,600)||x[6:0]<2||
                   (y>=120&&y<122)||(y>=240&&y<242)||(y>=360&&y<362)||(y>=480&&y<482)));
 reg [4:0] background_code;
  
 function [23:0] background_palette(input [4:0] code,input [23:0] scene);begin case(code)
  5'd1:background_palette=24'h000000;
  5'd2:background_palette=24'h087f83;
  5'd3:background_palette=24'h0a1018;
  5'd4:background_palette=24'h111e2c;
  5'd5:background_palette=24'h16b86a;
  5'd6:background_palette=24'h16b8ad;
  5'd7:background_palette=24'h172b3c;
  5'd8:background_palette=24'h1b2937;
  5'd9:background_palette=24'h26394d;
  5'd10:background_palette=24'h34495e;
  5'd11:background_palette=24'h3d68df;
  5'd12:background_palette=24'h3e5369;
  5'd13:background_palette=24'h50bd86;
  5'd14:background_palette=24'h609cea;
  5'd15:background_palette=24'h6d879c;
  5'd16:background_palette=24'h8190a0;
  5'd17:background_palette=24'h8a96a5;
  5'd18:background_palette=24'hd45abb;
  5'd19:background_palette=24'hdd6464;
  5'd20:background_palette=24'hf3f6fa;
  5'd21:background_palette=24'hf4f7fa;
  5'd22:background_palette=24'hff0000;
  5'd23:background_palette=24'hffaa55;
  5'd24:background_palette=24'hffffff;
  default:background_palette=scene;
 endcase end endfunction
 reg [23:0] background,foreground;
 reg text_on;
 reg [6:0] text_id;
 reg [10:0] origin_x,origin_y;
 reg [10:0] dx,dy;
 reg [5:0] char_pos;
 reg [4:0] char_col,char_row;
 reg [7:0] char_glyph;
 reg [12:0] font_addr;
 wire [6:0] text_div3=divide_by3_6(dx[8:3]);
  
  
 task automatic label(input [6:0] id,input integer lx,ly,length);
  begin if(in_rect(x,y,lx,ly,lx+length*24,ly+24))begin text_on=1;text_id=text_id|id;origin_x=origin_x|lx;origin_y=origin_y|ly;end end
 endtask
 always @(*)begin
  background_code=5'd0;foreground=24'hf3f6fa;text_on=0;text_id=0;origin_x=0;origin_y=0;
  if(page==0)begin
   
   if(show_meter&&meter_edge)background_code=5'd22;
   if(bars_visible)begin
    label(wb_mode==0?1:wb_mode==1?2:3,176,20,8);
    if(wb_mode!=0)label(28,400,20,6);
    label(image_mode==1?56:image_mode==2?57:image_mode==3?58:image_mode==4?59:image_mode==5?60:image_mode==6?63:image_mode==7?38:55,600,20,4);
    label(29,864,20,5);
    label(4,16,574,8);
    if(!online)label(26,736,574,5);
   end
  end else begin
   if(show_meter&&meter_edge)background_code=5'd22;
   if(x>=560)background_code=5'd4;
   if(in_rect(x,y,584,24,688,80))background_code=5'd10;
   label(5,612,44,2);
   label(page==13?100:page==9?65:page==10?64:page==11?66:page==12?84:page==1?6:page==2?7:page==3?8:page==4?9:page==6?39:page==7?53:page==8?54:page==5?10:0,720,44,6);
   if(bars_visible)label(27,16,574,4);
   case(page)
    9:begin
     if(in_rect(x,y,584,112,1000,176)||in_rect(x,y,584,192,1000,256)||in_rect(x,y,584,272,1000,336)||in_rect(x,y,584,352,1000,416))background_code=5'd9;
     label(64,744,132,3);label(53,744,212,3);label(54,744,292,3);
     label(100,744,372,4);
    end
    10:begin
     if(in_rect(x,y,584,112,1000,176)||in_rect(x,y,584,192,1000,256)||in_rect(x,y,584,272,1000,336))background_code=5'd9;
     label(6,672,132,5);label(66,696,212,4);label(84,672,292,5);
    end
    12:begin
     if(in_rect(x,y,584,112,1000,176))background_code=hist_enable?5'd2:5'd9;
     label(84,620,132,5);label(hist_enable?36:37,916,132,2);
     if(in_rect(x,y,584,192,784,256))background_code=hist_auto?5'd2:5'd9;
     if(in_rect(x,y,800,192,1000,256))background_code=!hist_auto?5'd2:5'd9;
     label(85,660,212,2);label(86,876,212,2);
     label(87,600,276,4);label(88,864,276,4);
     if(in_rect(x,y,592,324,993,332))background_code=x<=hist_thumb?5'd6:5'd12;
     if(x+6>=hist_thumb&&x<hist_thumb+7&&y>=314&&y<342)background_code=hist_manual?5'd20:5'd16;
     label(hist_auto?96:95,600,360,6);
     if(in_rect(x,y,584,400,1000,456))background_code=5'd9;
     label(25,744,416,4);label(I_hist_valid?94:93,600,500,7);
     if(in_rect(x,y,16,292,552,548))background_code=5'd4;
     label(89,32,304,7);label(90,360,336,6);
     if(in_rect(x,y,30,374,546,506))background_code=5'd15;
     if(in_rect(x,y,32,376,544,504))background_code=5'd7;
     if(in_rect(x,y,32,376,544,504)&&(y==408||y==440||y==472||x==160||x==288||x==416))background_code=5'd9;
     label(91,32,512,1);label(92,472,512,3);
    end
    11:begin
     if(in_rect(x,y,584,112,1000,176))background_code=ae_enable?5'd2:5'd9;
     label(66,620,132,4);label(ae_enable?36:37,916,132,2);
     if(in_rect(x,y,584,192,784,256))background_code=meter_mode==2?5'd2:5'd9;
     if(in_rect(x,y,800,192,1000,256))background_code=meter_mode==3?5'd2:5'd9;
     if(in_rect(x,y,584,272,784,336))background_code=meter_mode==1?5'd2:5'd9;
     if(in_rect(x,y,800,272,1000,336))background_code=meter_mode==0?5'd2:5'd9;
     label(81,636,212,4);label(82,852,212,4);
     label(78,612,292,6);label(77,864,292,3);
     if(in_rect(x,y,584,352,1000,416))background_code=show_meter?5'd2:5'd9;
     label(83,620,372,4);label(show_meter?36:37,916,372,2);
     if(in_rect(x,y,584,432,1000,496))background_code=ae_enable?5'd8:5'd9;
     if(y>=432&&y<496&&ae_enable)foreground=24'h8190a0;
     label(79,672,452,5);
     label(!ae_enable?80:!ae[9]?70:ae[7]?73:ae[8]?72:71,600,532,8);
    end
    1:begin
     if(in_rect(x,y,584,112,1000,176))background_code=wb_mode==0?5'd2:5'd9;
     if(in_rect(x,y,584,192,1000,256))background_code=wb_mode==1?5'd2:5'd9;
     if(in_rect(x,y,584,272,1000,336))background_code=wb_mode==2?5'd2:5'd9;
     label(7,620,132,5);label(8,620,212,4);label(9,620,292,5);
    end
    2:begin
     label(47,600,120,7);label(48,600,190,7);label(49,600,260,7);
     if(x>=600&&x<984&&y>=154&&y<166)background_code=x<(600+(telemetry[35:24]>>3))?5'd19:5'd10;
     if(x>=600&&x<984&&y>=224&&y<236)background_code=x<(600+(telemetry[23:12]>>3))?5'd13:5'd10;
     if(x>=600&&x<984&&y>=294&&y<306)background_code=x<(600+(telemetry[11:0]>>3))?5'd14:5'd10;
     label(telemetry[36]?41:42,600,332,5);
    end
    3:begin
     if(in_rect(x,y,584,112,1000,176))background_code=(wb_mode==1&&index==5)?5'd2:5'd9;
     if(in_rect(x,y,584,192,1000,256))background_code=(wb_mode==1&&index==30)?5'd2:5'd9;
     if(in_rect(x,y,584,272,1000,336))background_code=(wb_mode==1&&index==40)?5'd2:5'd9;
     if(in_rect(x,y,584,352,1000,416))background_code=(wb_mode==1&&index==50)?5'd2:5'd9;
     label(15,620,132,12);label(16,620,212,8);label(17,620,292,8);label(18,620,372,8);
     label(14,600,464,6);
    end
    4:begin
     label(19,600,116,9);label(28,720,184,6);
     if(in_rect(x,y,600,284,976,300))background_code=x<=thumb_x?5'd6:5'd12;
     if(x+8>=thumb_x&&x<thumb_x+8&&y>=272&&y<312)background_code=5'd21;
     label(20,600,344,5);label(21,856,344,6);label(30,600,424,7);
     if(x>=584&&x<1000&&y>=472&&y<536)background_code=5'd2;
     label(39,744,492,4);
    end
    6:begin
     if(x>=674&&x<=926&&y>=174&&y<=426)begin
      background_code=5'd3;
      if(grid14(x[7:0]-8'd162)||grid14(y[7:0]-8'd174))background_code=5'd10;
      if(x==800||y==300)background_code=5'd17;
     end
     if(x>=671&&x<674&&y>=171&&y<430)background_code=5'd11;
     if(x>=927&&x<930&&y>=171&&y<430)background_code=5'd23;
     if(x>=671&&x<930&&y>=171&&y<174)background_code=5'd5;
     if(x>=671&&x<930&&y>=427&&y<430)background_code=5'd18;
     if(x+5>=point_x&&x<point_x+6&&y+5>=point_y&&y<point_y+6)background_code=5'd1;
     if(x+3>=point_x&&x<point_x+4&&y+3>=point_y&&y<point_y+4)background_code=5'd24;
     if(x>=584&&x<656&&y>=268&&y<332)background_code=5'd9;
     if(x>=944&&x<1016&&y>=268&&y<332)background_code=5'd9;
     if(x>=768&&x<832&&y>=104&&y<164)background_code=5'd9;
     if(x>=768&&x<832&&y>=436&&y<496)background_code=5'd9;
     label(43,608,288,1);label(44,968,288,1);label(45,788,122,1);label(46,788,454,1);
     label(50,592,116,2);label(51,920,116,2);
     if(x>=588&&x<644&&y>=144&&y<148&&!active[38])background_code=5'd6;
     if(x>=916&&x<972&&y>=144&&y<148&&active[38])background_code=5'd6;
     label(52,584,490,5);
     if(x>=584&&x<1000&&y>=520&&y<576)background_code=5'd2;
     label(40,768,540,2);
    end
    5:begin
     if(x>=584&&x<712&&y>=112&&y<168)background_code=(gain==16)?5'd2:5'd9;
     if(x>=728&&x<856&&y>=112&&y<168)background_code=(gain==48)?5'd2:5'd9;
     if(x>=872&&x<1000&&y>=112&&y<168)background_code=(gain==80)?5'd2:5'd9;
     label(32,624,128,2);label(33,768,128,2);label(34,912,128,2);
     label(29,732,196,5);
     if(in_rect(x,y,600,250,966,266))background_code=x<=gain_x?5'd6:5'd12;
     if(in_rect(x,y,608,300,736,388)||in_rect(x,y,856,300,984,388))background_code=5'd2;
     label(23,648,332,2);label(24,888,332,2);
     if(in_rect(x,y,584,432,1000,488))background_code=5'd9;
     label(25,744,448,4);label(31,600,524,8);
    end
    7:begin
     if(in_rect(x,y,584,112,784,176))background_code=(image_mode==0)?5'd2:5'd9;
     if(in_rect(x,y,800,112,1000,176))background_code=(image_mode==5)?5'd2:5'd9;
     if(in_rect(x,y,584,192,784,256))background_code=(image_mode==4)?5'd2:5'd9;
     if(in_rect(x,y,800,192,1000,256))background_code=(image_mode==6)?5'd2:5'd9;
     if(in_rect(x,y,584,272,784,336))background_code=(image_mode==7)?5'd2:5'd9;
     if(in_rect(x,y,800,272,1000,336))background_code=(image_mode==1)?5'd2:5'd9;
     if(in_rect(x,y,584,352,784,416))background_code=(image_mode==2)?5'd2:5'd9;
     if(in_rect(x,y,800,352,1000,416))background_code=(image_mode==3)?5'd2:5'd9;
     label(55,648,132,2);label(60,864,132,2);
     label(59,636,212,3);label(63,864,212,2);
     label(38,636,292,4);label(56,864,292,2);
     label(57,648,372,2);label(58,864,372,2);
    end
    8:begin
     if(in_rect(x,y,584,112,1000,176))background_code=tag_enable?5'd2:5'd9;
     if(in_rect(x,y,584,192,1000,256))background_code=detect_enable?5'd2:5'd9;
     if(in_rect(x,y,584,272,1000,336))background_code=bars_visible?5'd2:5'd9;
     label(61,620,132,6);label(tag_enable?36:37,916,132,2);
     label(62,620,212,4);label(detect_enable?36:37,916,212,2);
     label(97,620,292,4);label(bars_visible?99:98,916,292,2);
    end
    13:begin
     label(101,600,232,4);label(106,880,232,3);
     label(102,600,284,4);label(107,880,284,3);
     label(103,600,336,4);label(108,880,336,3);
     label(104,600,388,4);label(109,880,388,3);
     label(105,600,440,4);label(110,880,440,3);
     label(111,600,496,7);
     if(in_rect(x,y,880,232,952,256))foreground=!latency_valid?24'h8a96a5:
         latency_frames<=2?24'h16b8ad:latency_frames<=4?24'hffaa55:24'hdd6464;
    end
   endcase
  end
  background=background_palette(background_code,I_data);
   
   
   
  if(menu_panel)background=blend50(background,I_data);
  else if(bars_visible&&(y<64||y>=548))background={2'b0,I_data[23:18],2'b0,I_data[15:10],2'b0,I_data[7:2]};
  else if(page!=0)background=blend50(background,I_data);
  dx=x-origin_x;dy=y-origin_y;char_pos={1'b0,text_div3[6:2]};char_col={text_div3[1:0],dx[2:0]};char_row=dy[4:0];
  char_glyph=glyph(text_id,char_pos);

 end
 wire [7:0] stored_glyph;
 wb_ui_text_rom #(.TEXT_FILE(TEXT_FILE)) texts(.I_clk(I_clk),.I_addr({text_id,char_pos[3:0]}),.O_glyph(stored_glyph));
 wire dynamic_text=text_id==28||text_id==29||text_id==47||text_id==48||text_id==49||text_id==50||text_id==51||text_id==52||text_id==88||(text_id>=106&&text_id<=110);
 reg [23:0] bg_a,fg_a,bg_d,fg_d;
 reg [4:0] col_a,row_a,col_d;reg [7:0] glyph_a,hist_height_d;
 reg text_a,v_a,h_a,d_a,dynamic_a,hist_plot_a,tag_a,tag_d;
 reg text_d,v_d,h_d,d_d,hist_plot_d;reg [6:0] hist_row_a,hist_row_d;
 wire [23:0] font_bits;
 wire [12:0] selected_font={dynamic_a?glyph_a:stored_glyph,row_a};
 wb_ui_font #(.FONT_FILE(FONT_FILE)) rom(.I_clk(I_clk),.I_addr(selected_font),.O_bits(font_bits));
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  bg_a<=0;fg_a<=0;col_a<=0;row_a<=0;glyph_a<=0;dynamic_a<=0;text_a<=0;
  v_a<=0;h_a<=0;d_a<=0;tag_a<=0;tag_d<=0;O_tag_enable<=0;hist_plot_a<=0;hist_row_a<=0;
  hist_plot_d<=0;hist_row_d<=0;hist_height_d<=0;bg_d<=0;fg_d<=0;col_d<=0;text_d<=0;v_d<=0;h_d<=0;d_d<=0;
  O_vsync<=0;O_hsync<=0;O_de<=0;O_data<=0;
 end else begin
  bg_a<=background;fg_a<=foreground;col_a<=char_col;row_a<=char_row;
  glyph_a<=char_glyph;dynamic_a<=dynamic_text;text_a<=text_on;
  v_a<=I_vsync;h_a<=I_hsync;d_a<=I_de;tag_a<=page==0&&tag_enable;
  hist_plot_a<=page==12&&I_hist_valid&&x>=32&&x<544&&y>=376&&y<504&&x[2:0]!=7;
  hist_row_a<=11'd503-y;
  bg_d<=bg_a;fg_d<=fg_a;col_d<=col_a;text_d<=text_a;
  v_d<=v_a;h_d<=h_a;d_d<=d_a;tag_d<=tag_a;
  hist_plot_d<=hist_plot_a;hist_row_d<=hist_row_a;hist_height_d<=I_hist_height;
  O_vsync<=v_d;O_hsync<=h_d;O_de<=d_d;O_tag_enable<=tag_d;
  O_data<=d_d?(hud_pixel_d?hud_color_d:(text_d&&font_bits[23-col_d])?fg_d:
             (hist_plot_d&&{1'b0,hist_row_d}<hist_height_d)?24'h16b8ad:bg_d):24'd0;
 end
endmodule
