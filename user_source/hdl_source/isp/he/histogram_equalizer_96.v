 
 
 
module histogram_equalizer_96 #(
 parameter FRAME_BEATS=230400,FRAME_LINES=720,LINE_BEATS=320,
 parameter VIEW_X=32,VIEW_Y=60,VIEW_BEATS=256,VIEW_LINES=600
)(
 input wire I_clk,I_rst_n,input wire [8:0] I_config,
 input wire [95:0] I_data,input wire I_valid,I_user,I_last,I_previous_bad,
 input wire [2:0] I_frame_mode,
 output reg [95:0] O_data,output reg O_valid,O_user,O_last,
 output reg [2:0] O_frame_mode,
 input wire I_hist_ready,output reg O_hist_we,O_hist_publish,
 output reg [5:0] O_hist_addr,output reg [7:0] O_hist_height
);
 localparam N=VIEW_BEATS*VIEW_LINES;
 localparam CLEAR=0,RUN=1,DRAIN=2,A_READ=3,A_WAIT=4,A_COUNT=5,
            B_READ=6,B_WAIT=7,B_COUNT=8,DIV_INIT=9,DIV_RUN=10,
            DIV_DONE=11,MULT=12,MAP_WRITE=13,BAR=14,NEXT_BIN=15;
 reg [3:0] state;reg [5:0] index;reg [1:0] drain;
 reg user_d,started,bad,roi_finished,candidate_ready,active_bank,map_valid,build_bank;
 reg [17:0] beats;reg [10:0] lines;reg [8:0] column;
 reg [8:0] frame_config;
 wire fs=I_user&&!user_d;
 wire [8:0] cfg=fs?I_config:frame_config;
 wire [8:0] sx=fs?9'd0:column;
 wire [10:0] sy=fs?11'd0:lines;
 wire in_view=sx>=VIEW_X&&sx<VIEW_X+VIEW_BEATS&&sy>=VIEW_Y&&sy<VIEW_Y+VIEW_LINES;
 wire roi_last=sx==VIEW_X+VIEW_BEATS-1&&sy==VIEW_Y+VIEW_LINES-1;
 wire complete=started&&!bad&&!I_previous_bad&&beats==FRAME_BEATS&&lines==FRAME_LINES&&column==0;
 wire publish=fs&&complete&&candidate_ready;
 wire read_bank=publish?build_bank:active_bank;
 wire use_map=cfg[8]&&(cfg[7]||cfg[6:0]!=0)&&(map_valid||publish);

 wire [9:0] sample_y={2'd0,I_data[95:88]}+{1'd0,I_data[87:80],1'b0}+{2'd0,I_data[79:72]};
 wire sample=I_valid&&(started||fs)&&in_view&&!(fs?1'b0:roi_finished)&&state==RUN;
 wire [5:0] sample_bin=sample_y[9:4];
 reg sample_d;reg [5:0] sample_addr;
 (* ram_style="block" *) reg [17:0] histogram[0:63];
 reg [17:0] hist_q;
 reg forward_valid;reg [5:0] forward_addr;reg [17:0] forward_count;
 wire [17:0] old_count=(forward_valid&&forward_addr==sample_addr)?forward_count:hist_q;
 wire [17:0] incremented=old_count+1'b1;
 wire clearing=state==CLEAR||state==B_COUNT;
 wire hist_we=clearing||sample_d;
 wire [5:0] hist_wa=clearing?index:sample_addr;
 wire [17:0] hist_wd=clearing?18'd0:incremented;
 wire [5:0] hist_ra=state==RUN?sample_bin:index;
 always @(posedge I_clk)begin
  hist_q<=histogram[hist_ra];
  if(hist_we)histogram[hist_wa]<=hist_wd;
 end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin sample_d<=0;sample_addr<=0;forward_valid<=0;forward_addr<=0;forward_count<=0;end
 else begin
  sample_d<=sample;sample_addr<=sample_bin;
  if(state!=RUN&&state!=DRAIN)forward_valid<=0;
  else if(sample_d)begin forward_valid<=1;forward_addr<=sample_addr;forward_count<=incremented;end
 end

 reg [18:0] total,cdf;reg [17:0] first_count,peak,current_count,denominator;
 reg first_seen,send_hist;reg [6:0] strength;
 reg [25:0] div_bits;reg [18:0] div_rem;reg [17:0] div_den;
 reg [4:0] div_count;reg [1:0] div_kind;
 wire [18:0] trial={div_rem[17:0],div_bits[25]};
 wire [19:0] divided_difference={1'b0,trial}-{2'd0,div_den};
 wire subtract=!divided_difference[19];
 wire [25:0] next_quotient={div_bits[24:0],subtract};
 wire [18:0] cdf_next=cdf+{1'b0,hist_q};
 wire [19:0] cdf_difference={1'b0,cdf_next}-{2'd0,first_count};
 wire [18:0] above_first=cdf_difference[19]?19'd0:cdf_difference[18:0];
 wire [25:0] cdf_numerator=({7'd0,above_first}<<8)-{7'd0,above_first}+{9'd0,denominator[17:1]};
 reg signed [8:0] map_value;
 wire signed [8:0] full_delta=$signed({1'b0,div_bits[7:0]})-$signed({1'b0,index,2'b10});
 reg delta_negative;reg [15:0] mul_acc,mul_term;reg [6:0] mul_factor;reg [2:0] mul_count;
 wire [15:0] mul_sum=mul_acc+(mul_factor[0]?mul_term:16'd0);
 wire map_we=state==MAP_WRITE;

  
  
 reg [95:0] rgb_d;reg v_d,u_d,l_d,use_d;reg [2:0] mode_d;
 function [7:0] saturated(input [7:0] channel,input signed [8:0] delta);
  reg [8:0] result;
  begin result={1'b0,channel}+delta;
   saturated=result[8]?(delta[8]?8'd0:8'd255):result[7:0];end
 endfunction
 genvar lane;
 generate for(lane=0;lane<4;lane=lane+1)begin:LUT
  (* ram_style="block" *) reg signed [8:0] table_delta[0:127];
  reg signed [8:0] delta_q;
  wire [23:0] pixel=I_data[lane*24+:24];
  wire [9:0] y={2'd0,pixel[23:16]}+{1'd0,pixel[15:8],1'b0}+{2'd0,pixel[7:0]};
  always @(posedge I_clk)begin
   if(map_we)table_delta[{build_bank,index}]<=map_value;
   delta_q<=table_delta[{read_bank,y[9:4]}];
  end
  always @(posedge I_clk)
   O_data[lane*24+:24]<=use_d?{saturated(rgb_d[lane*24+16+:8],delta_q),
       saturated(rgb_d[lane*24+8+:8],delta_q),saturated(rgb_d[lane*24+:8],delta_q)}:rgb_d[lane*24+:24];
 end endgenerate
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin rgb_d<=0;v_d<=0;u_d<=0;l_d<=0;use_d<=0;mode_d<=0;
  O_valid<=0;O_user<=0;O_last<=0;O_frame_mode<=0;end
 else begin
  rgb_d<=I_data;v_d<=I_valid;u_d<=I_user;l_d<=I_last;use_d<=use_map;mode_d<=I_frame_mode;
  O_valid<=v_d;O_user<=u_d;O_last<=l_d;O_frame_mode<=mode_d;
 end

 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  state<=CLEAR;index<=0;drain<=0;user_d<=0;started<=0;bad<=0;roi_finished<=0;
  candidate_ready<=0;active_bank<=0;map_valid<=0;build_bank<=1;
  beats<=0;lines<=0;column<=0;frame_config<=9'd178;
  total<=0;cdf<=0;first_count<=0;peak<=0;current_count<=0;denominator<=0;
  first_seen<=0;send_hist<=0;strength<=100;
  div_bits<=0;div_rem<=0;div_den<=1;div_count<=0;div_kind<=0;
  map_value<=0;delta_negative<=0;mul_acc<=0;mul_term<=0;mul_factor<=0;mul_count<=0;
  O_hist_we<=0;O_hist_publish<=0;O_hist_addr<=0;O_hist_height<=0;
 end else begin
  user_d<=I_user;O_hist_we<=0;O_hist_publish<=0;
  if(fs)begin
   frame_config<=I_config;started<=1;beats<=I_valid?1:0;
   lines<=I_valid&&I_last?1:0;column<=I_valid&&!I_last?1:0;
   bad<=I_valid&&(I_last!=(LINE_BEATS==1));roi_finished<=0;candidate_ready<=0;
   if(publish)begin active_bank<=build_bank;map_valid<=1;O_hist_publish<=send_hist;end
    
   if((state!=RUN&&state!=CLEAR)||(started&&!roi_finished))begin
    state<=CLEAR;index<=0;
    if(I_valid&&in_view)bad<=1;
   end
  end else begin
   if(I_valid&&started)begin
    if(beats<262143)beats<=beats+1'b1;else bad<=1;
    if(beats>=FRAME_BEATS)bad<=1;
    if(I_last)begin column<=0;if(column!=LINE_BEATS-1)bad<=1;
     if(lines<2047)lines<=lines+1'b1;else bad<=1;end
    else if(column<511)column<=column+1'b1;else bad<=1;
    if(in_view&&!roi_finished&&state!=RUN)bad<=1;
   end
   case(state)
    CLEAR:begin if(index==63)begin index<=0;state<=RUN;end else index<=index+1'b1;end
    RUN:if(sample&&roi_last)begin
     roi_finished<=1;candidate_ready<=0;drain<=2;state<=DRAIN;index<=0;
     total<=0;cdf<=0;first_seen<=0;first_count<=0;peak<=0;
     build_bank<=!active_bank;send_hist<=I_hist_ready;
     strength<=frame_config[7]?7'd100:frame_config[6:0]>100?7'd100:frame_config[6:0];
    end
    DRAIN:if(drain==0)state<=A_READ;else drain<=drain-1'b1;
    A_READ:state<=A_WAIT;
    A_WAIT:state<=A_COUNT;
    A_COUNT:begin
     total<=total+hist_q;
     if(hist_q>peak)peak<=hist_q;
     if(!first_seen&&hist_q!=0)begin first_seen<=1;first_count<=hist_q;end
     if(index==63)begin
      index<=0;cdf<=0;
      if(total+hist_q!=N)begin state<=CLEAR;candidate_ready<=0;end
      else begin denominator<=N-(first_seen?first_count:hist_q);state<=B_READ;end
     end else begin index<=index+1'b1;state<=A_READ;end
    end
    B_READ:state<=B_WAIT;
    B_WAIT:state<=B_COUNT;
    B_COUNT:begin
     current_count<=hist_q;cdf<=cdf_next;
     if(denominator==0||strength==0)begin map_value<=0;state<=MAP_WRITE;end
     else begin div_bits<=cdf_numerator;div_den<=denominator;div_kind<=0;state<=DIV_INIT;end
    end
    DIV_INIT:begin div_rem<=0;div_count<=25;state<=DIV_RUN;end
    DIV_RUN:begin
     div_rem<=subtract?divided_difference[18:0]:trial;div_bits<=next_quotient;
     if(div_count==0)state<=DIV_DONE;else div_count<=div_count-1'b1;
    end
    DIV_DONE:case(div_kind)
     0:if(strength==100)begin map_value<=full_delta;state<=MAP_WRITE;end
       else begin
        delta_negative<=full_delta[8];mul_acc<=0;
        mul_term<=full_delta[8]?-$signed(full_delta):full_delta;
        mul_factor<=strength;mul_count<=0;state<=MULT;
       end
     1:begin map_value<=delta_negative?(~div_bits[8:0]+9'd1):div_bits[8:0];state<=MAP_WRITE;end
     default:begin O_hist_we<=1;O_hist_addr<=index;O_hist_height<=div_bits[7:0];state<=NEXT_BIN;end
    endcase
    MULT:begin
     mul_acc<=mul_sum;mul_term<=mul_term<<1;mul_factor<=mul_factor>>1;
     if(mul_count==6)begin div_bits<={10'd0,mul_sum}+26'd50;div_den<=18'd100;div_kind<=1;state<=DIV_INIT;end
     else mul_count<=mul_count+1'b1;
    end
    MAP_WRITE:state<=BAR;
    BAR:if(send_hist&&peak!=0)begin
     div_bits<=({8'd0,current_count}<<7)+{9'd0,peak[17:1]};div_den<=peak;div_kind<=2;state<=DIV_INIT;
    end else state<=NEXT_BIN;
    NEXT_BIN:if(index==63)begin candidate_ready<=1;state<=RUN;index<=0;end
             else begin index<=index+1'b1;state<=B_READ;end
    default:state<=CLEAR;
   endcase
  end
 end
endmodule
