 
 
module ae_meter_96 #(
 parameter FRAME_BEATS=230400,FRAME_LINES=720,LINE_BEATS=320,
 parameter VIEW_X=32,VIEW_Y=60,VIEW_BEATS=256,VIEW_LINES=600,
 parameter SPOT_X=144,SPOT_Y=296,SPOT_BEATS=32,SPOT_LINES=128,
 parameter CENTER_X=96,CENTER_Y=210,CENTER_BEATS=128,CENTER_LINES=300,
 parameter PARTIAL_X=130,PARTIAL_Y=240,PARTIAL_BEATS=60,PARTIAL_LINES=240,
 parameter BLACK_LEVEL=0,WHITE_LEVEL=255,
 parameter TARGET_LEVEL=(BLACK_LEVEL*82+WHITE_LEVEL*18+50)/100
)(
 input wire I_clk,I_rst_n,I_valid,I_user,I_last,I_previous_bad,
 input wire [1:0] I_meter_mode,
 input wire [95:0] I_data,
  
 output reg [7:0] O_stats
);
 localparam VIEW_WEIGHT=VIEW_BEATS*VIEW_LINES;
 localparam PARTIAL_WEIGHT=PARTIAL_BEATS*PARTIAL_LINES;
 localparam SPOT_WEIGHT=SPOT_BEATS*SPOT_LINES;
 localparam CENTER_WEIGHT=VIEW_BEATS*VIEW_LINES+7*CENTER_BEATS*CENTER_LINES;
 reg user_d,started,bad;reg [1:0] frame_mode;
 reg [17:0] beats;reg [10:0] lines;reg [8:0] column;
 reg [26:0] sum;
 wire sof=I_user&&!user_d;
 wire [8:0] sx=sof?9'd0:column;
 wire [10:0] sy=sof?11'd0:lines;
 wire [1:0] mode_now=sof?I_meter_mode:frame_mode;
 wire in_view=sx>=VIEW_X&&sx<VIEW_X+VIEW_BEATS&&sy>=VIEW_Y&&sy<VIEW_Y+VIEW_LINES;
 wire in_spot=sx>=SPOT_X&&sx<SPOT_X+SPOT_BEATS&&sy>=SPOT_Y&&sy<SPOT_Y+SPOT_LINES;
 wire in_center=sx>=CENTER_X&&sx<CENTER_X+CENTER_BEATS&&sy>=CENTER_Y&&sy<CENTER_Y+CENTER_LINES;
 wire in_partial=sx>=PARTIAL_X&&sx<PARTIAL_X+PARTIAL_BEATS&&sy>=PARTIAL_Y&&sy<PARTIAL_Y+PARTIAL_LINES;
 wire [9:0] weighted={2'd0,I_data[95:88]}+{1'd0,I_data[87:80],1'b0}+{2'd0,I_data[79:72]};
 wire [7:0] y=weighted[9:2];
 wire selected=mode_now==0?in_spot:mode_now==3?in_partial:in_view;
 wire [10:0] contribution=!selected?11'd0:(mode_now==1&&in_center)?{y,3'd0}:{3'd0,y};
 wire complete=started&&!bad&&!I_previous_bad&&frame_mode==I_meter_mode&&
                     beats==FRAME_BEATS&&lines==FRAME_LINES&&column==0;
  
  
 wire [26:0] low_far=frame_mode==0?SPOT_WEIGHT*(TARGET_LEVEL/2):frame_mode==1?CENTER_WEIGHT*(TARGET_LEVEL/2):frame_mode==2?VIEW_WEIGHT*(TARGET_LEVEL/2):PARTIAL_WEIGHT*(TARGET_LEVEL/2);
 wire [26:0] low_mid=frame_mode==0?SPOT_WEIGHT*(TARGET_LEVEL-8):frame_mode==1?CENTER_WEIGHT*(TARGET_LEVEL-8):frame_mode==2?VIEW_WEIGHT*(TARGET_LEVEL-8):PARTIAL_WEIGHT*(TARGET_LEVEL-8);
 wire [26:0] low_near=frame_mode==0?SPOT_WEIGHT*(TARGET_LEVEL-2):frame_mode==1?CENTER_WEIGHT*(TARGET_LEVEL-2):frame_mode==2?VIEW_WEIGHT*(TARGET_LEVEL-2):PARTIAL_WEIGHT*(TARGET_LEVEL-2);
 wire [26:0] high_near=frame_mode==0?SPOT_WEIGHT*(TARGET_LEVEL+2):frame_mode==1?CENTER_WEIGHT*(TARGET_LEVEL+2):frame_mode==2?VIEW_WEIGHT*(TARGET_LEVEL+2):PARTIAL_WEIGHT*(TARGET_LEVEL+2);
 wire [26:0] high_mid=frame_mode==0?SPOT_WEIGHT*(TARGET_LEVEL+8):frame_mode==1?CENTER_WEIGHT*(TARGET_LEVEL+8):frame_mode==2?VIEW_WEIGHT*(TARGET_LEVEL+8):PARTIAL_WEIGHT*(TARGET_LEVEL+8);
 wire [26:0] high_far=frame_mode==0?SPOT_WEIGHT*(TARGET_LEVEL+24):frame_mode==1?CENTER_WEIGHT*(TARGET_LEVEL+24):frame_mode==2?VIEW_WEIGHT*(TARGET_LEVEL+24):PARTIAL_WEIGHT*(TARGET_LEVEL+24);
 reg reduce;reg [2:0] step_count;
 always @(*)begin
  reduce=0;step_count=0;
  if(sum>high_far)begin reduce=1;step_count=4;end
  else if(sum>high_mid)begin reduce=1;step_count=2;end
  else if(sum>high_near)begin reduce=1;step_count=1;end
  else if(sum<low_far)step_count=4;
  else if(sum<low_mid)step_count=2;
  else if(sum<low_near)step_count=1;
 end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  user_d<=0;started<=0;bad<=0;frame_mode<=1;beats<=0;lines<=0;column<=0;sum<=0;O_stats<=8'd64;
 end else begin
  user_d<=I_user;
  if(started&&I_meter_mode!=frame_mode)bad<=1;
  if(sof)begin
   O_stats<={frame_mode,!O_stats[5],complete,reduce,step_count};frame_mode<=I_meter_mode;
   started<=1;bad<=I_valid&&(I_last!=(LINE_BEATS==1));
   beats<=I_valid?1:0;lines<=I_valid&&I_last?1:0;column<=I_valid&&!I_last?1:0;
   sum<=I_valid?{16'd0,contribution}:27'd0;
  end else if(I_valid&&started)begin
   if(beats<262143)beats<=beats+1'b1;else bad<=1;
   if(beats>=FRAME_BEATS)bad<=1;
   sum<=sum+contribution;
   if(I_last)begin
    column<=0;if(column!=LINE_BEATS-1)bad<=1;
    if(lines<2047)lines<=lines+1'b1;else bad<=1;
   end else if(column<511)column<=column+1'b1;else bad<=1;
  end
 end
endmodule
