module wb_ui_control #(parameter CLK_HZ=25000000,LONG_MS=800,RELEASE_MS=30,
 parameter SWIPE_MIN_X=100,SWIPE_MAX_Y=80,SWIPE_MS=1000)(
 input wire I_clk,I_rst_n,I_online,I_report,
 input wire [3:0] I_contacts,input wire [9:0] I_x,I_y,
 input wire [1:0] I_buttons_n,input wire [6:0] I_applied_gain,
 output reg O_hist_enable,O_hist_auto,output reg [6:0] O_hist_strength,
 output reg O_ae_enable,O_show_meter,output reg [1:0] O_meter_mode,output reg [3:0] O_page,output reg [1:0] O_mode,
 output reg [6:0] O_index,O_gain,output reg O_detect_enable,O_tag_enable,
 output reg [2:0] O_image_mode,
 output reg signed [4:0] O_ab,O_gm,output reg O_key_axis,O_bars_hide
);
  
  
  
 localparam TICK_W=CLK_HZ/1000<=1?1:$clog2(CLK_HZ/1000);
  
 localparam HOLD_MAX=SWIPE_MS>=500?SWIPE_MS+1:500;
 localparam HOLD_W=$clog2(HOLD_MAX+1);
 localparam RELEASE_W=RELEASE_MS<1?1:$clog2(RELEASE_MS+1);
 reg [TICK_W-1:0] tick;wire ms=tick==CLK_HZ/1000-1;
 reg held,blocked,consumed,drag,axis_drag,hist_drag;reg [2:0] axis_direction;
 reg [9:0] start_x,start_y;
 reg preview_gesture,swipe_bad,swipe_ready;
 reg [HOLD_W-1:0] hold_ms;reg [RELEASE_W-1:0] released_ms;reg [6:0] repeat_ms;
 reg [1:0] direction;
 reg inc_req,dec_req,reset_gain;reg [1:0] gain_preset;
 reg [6:0] custom_index;  
 wire ae_switch_press=I_online&&I_report&&I_contacts==1&&!blocked&&!held&&released_ms>=RELEASE_MS&&
                O_page==11&&I_x>=584&&I_x<1000&&I_y>=112&&I_y<176;
 wire [6:0] applied_safe=I_applied_gain<16?7'd16:I_applied_gain>89?7'd89:I_applied_gain;
 (* async_reg="true" *) reg [1:0] keys_meta,keys_sync;
 reg [4:0] key_db[0:1];reg [8:0] key_time[0:1];
 reg [6:0] key_repeat[0:1];reg [1:0] key_event;
 integer i;
 function [6:0] hist_index(input [9:0] x);
  begin hist_index=x<=592?0:x>=992?100:(x-592+2)>>2;end
 endfunction
 function [6:0] slider_index(input [9:0] x);
  begin slider_index=(x<=600)?0:(x>=975)?75:(x-600+2)/5;end
 endfunction
 function [4:0] ab_from_x(input [9:0] x);
 integer n;begin n=(x<=674)?-9:(x>=926)?9:((x-674+7)/14)-9;ab_from_x=n;end endfunction
 function [4:0] gm_from_y(input [9:0] y);
 integer n;begin n=(y<=174)?9:(y>=426)?-9:9-((y-174+7)/14);gm_from_y=n;end endfunction
 task automatic nudge(input [2:0] d);
 begin if(d!=0)O_key_axis<=(d==3||d==4);case(d)
 1:if(O_ab> -5'sd9)O_ab<=O_ab-1'b1;
 2:if(O_ab<5'sd9)O_ab<=O_ab+1'b1;
 3:if(O_gm<5'sd9)O_gm<=O_gm+1'b1;
 4:if(O_gm> -5'sd9)O_gm<=O_gm-1'b1;
 default:;
 endcase end endtask
 wire swipe_left_now=start_x>=I_x&&({1'b0,start_x}-{1'b0,I_x})>=SWIPE_MIN_X;
 wire swipe_y_ok=(I_y>=start_y?({1'b0,I_y}-{1'b0,start_y}):
                                  ({1'b0,start_y}-{1'b0,I_y}))<=SWIPE_MAX_Y;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin tick<=0;keys_meta<=3;keys_sync<=3;key_event<=0;
  for(i=0;i<2;i=i+1)begin key_db[i]<=0;key_time[i]<=0;key_repeat[i]<=0;end
 end else begin
  tick<=ms?0:tick+1'b1;keys_meta<=I_buttons_n;keys_sync<=keys_meta;key_event<=0;
  if(ms)for(i=0;i<2;i=i+1)begin
   if(keys_sync[i])begin key_db[i]<=0;key_time[i]<=0;key_repeat[i]<=0;end
   else if(key_db[i]<20)begin
    key_db[i]<=key_db[i]+1'b1;
    if(key_db[i]==19)key_event[i]<=1;
   end else if(key_time[i]<500)key_time[i]<=key_time[i]+1'b1;
   else if(key_repeat[i]==119)begin key_repeat[i]<=0;key_event[i]<=1;end
   else key_repeat[i]<=key_repeat[i]+1'b1;
  end
 end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)O_gain<=80;
 else if(ae_switch_press&&O_ae_enable)O_gain<=applied_safe;
 else if(!O_ae_enable&&gain_preset!=0)O_gain<=(gain_preset==1)?7'd16:(gain_preset==2)?7'd48:7'd80;
 else if(!O_ae_enable&&reset_gain)O_gain<=80;
 else if(!O_ae_enable&&(inc_req||(O_page!=6&&key_event[1]))&&!(dec_req||(O_page!=6&&key_event[0])))begin if(O_gain<89)O_gain<=O_gain+1'b1;end
 else if(!O_ae_enable&&(dec_req||(O_page!=6&&key_event[0]))&&!(inc_req||(O_page!=6&&key_event[1])))begin if(O_gain>16)O_gain<=O_gain-1'b1;end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  O_hist_enable<=0;O_hist_auto<=1;O_hist_strength<=50;hist_drag<=0;
  O_key_axis<=0;O_ab<=0;O_gm<=0;axis_drag<=0;axis_direction<=0;
  O_detect_enable<=0;O_tag_enable<=0;O_image_mode<=0;O_bars_hide<=0;
  O_ae_enable<=1;O_meter_mode<=1;O_show_meter<=0;O_page<=0;O_mode<=0;O_index<=30;custom_index<=30;
  held<=0;blocked<=0;consumed<=0;drag<=0;hist_drag<=0;direction<=0;
  start_x<=0;start_y<=0;hold_ms<=0;released_ms<=RELEASE_MS;repeat_ms<=0;
  preview_gesture<=0;swipe_bad<=0;swipe_ready<=0;
  inc_req<=0;dec_req<=0;reset_gain<=0;gain_preset<=0;
 end else begin
  inc_req<=0;dec_req<=0;reset_gain<=0;gain_preset<=0;
  if(O_page==6&&(key_event[0]^key_event[1]))
   nudge(O_key_axis?(key_event[0]?3'd4:3'd3):(key_event[0]?3'd1:3'd2));
  if(ms)begin
   if(!held)begin if(released_ms<RELEASE_MS)released_ms<=released_ms+1'b1;end
   else begin
    if(hold_ms<HOLD_MAX)hold_ms<=hold_ms+1'b1;
    if((direction!=0||axis_direction!=0)&&hold_ms>=500)begin
     if(repeat_ms==119)begin repeat_ms<=0;inc_req<=direction==2;dec_req<=direction==1;nudge(axis_direction);end
     else repeat_ms<=repeat_ms+1'b1;
    end
   end
  end
  if(!I_online)begin held<=0;blocked<=1;drag<=0;hist_drag<=0;direction<=0;axis_drag<=0;axis_direction<=0;hold_ms<=0;
   preview_gesture<=0;swipe_bad<=0;swipe_ready<=0;end
  else if(I_report)begin
   if(I_contacts==0)begin
     
     
    if(held&&!blocked&&preview_gesture&&O_page==0&&!swipe_bad&&swipe_ready&&hold_ms<=SWIPE_MS)
     begin O_page<=9;consumed<=1;end
    if(held||blocked)released_ms<=0;
    held<=0;blocked<=0;drag<=0;hist_drag<=0;direction<=0;axis_drag<=0;axis_direction<=0;hold_ms<=0;repeat_ms<=0;
    preview_gesture<=0;swipe_bad<=0;swipe_ready<=0;
   end else if(I_contacts!=1)begin held<=0;blocked<=1;drag<=0;hist_drag<=0;direction<=0;axis_drag<=0;axis_direction<=0;consumed<=1;released_ms<=0;
    preview_gesture<=0;swipe_bad<=0;swipe_ready<=0;end
   else if(!blocked)begin
    if(!held&&released_ms>=RELEASE_MS)begin
     held<=1;start_x<=I_x;start_y<=I_y;hold_ms<=0;consumed<=0;drag<=0;hist_drag<=0;direction<=0;repeat_ms<=0;axis_drag<=0;axis_direction<=0;
     preview_gesture<=O_page==0&&I_y<600;swipe_bad<=0;swipe_ready<=0;
     if(O_page!=0)begin
      consumed<=1;
      if(I_x>=584&&I_x<688&&I_y>=24&&I_y<80)case(O_page)
       9:O_page<=0;10,7,8,13:O_page<=9;1,11,12:O_page<=10;5:O_page<=11;
       6:O_page<=4;default:O_page<=1;endcase
      else case(O_page)
       9:if(I_x>=584&&I_x<1000)begin
        if(I_y>=112&&I_y<176)O_page<=10;
        else if(I_y>=192&&I_y<256)O_page<=7;
        else if(I_y>=272&&I_y<336)O_page<=8;
        else if(I_y>=352&&I_y<416)O_page<=13;
       end
       10:if(I_x>=584&&I_x<1000)begin
        if(I_y>=112&&I_y<176)O_page<=1;
        else if(I_y>=192&&I_y<256)O_page<=11;
        else if(I_y>=272&&I_y<336)O_page<=12;
       end
       12:begin
        if(I_x>=584&&I_x<1000&&I_y>=112&&I_y<176)O_hist_enable<=!O_hist_enable;
        else if(I_y>=192&&I_y<256)begin
         if(I_x>=584&&I_x<784)O_hist_auto<=1;
         else if(I_x>=800&&I_x<1000)O_hist_auto<=0;
        end else if(O_hist_enable&&!O_hist_auto&&I_x>=584&&I_x<1000&&I_y>=300&&I_y<360)begin
         hist_drag<=1;O_hist_strength<=hist_index(I_x);
        end else if(I_x>=584&&I_x<1000&&I_y>=400&&I_y<456)O_hist_strength<=50;
       end
       11:if(I_x>=584&&I_x<1000)begin
        if(I_y>=112&&I_y<176)O_ae_enable<=!O_ae_enable;
        else if(I_y>=192&&I_y<256)begin
         if(I_x<784)O_meter_mode<=2;else if(I_x>=800)O_meter_mode<=3;
        end else if(I_y>=272&&I_y<336)begin
         if(I_x<784)O_meter_mode<=1;else if(I_x>=800)O_meter_mode<=0;
        end else if(I_y>=352&&I_y<416)O_show_meter<=!O_show_meter;
        else if(I_y>=432&&I_y<496&&!O_ae_enable)O_page<=5;
       end
       1:if(I_x>=584&&I_x<1000)begin
        if(I_y>=112&&I_y<176)begin O_page<=2;O_mode<=0;end
        else if(I_y>=192&&I_y<256)O_page<=3;
        else if(I_y>=272&&I_y<336)begin O_page<=4;O_mode<=2;O_index<=custom_index;end
        
        
       end
        
       2:;
        
       3:if(I_x>=584&&I_x<1000)begin
        if(I_y>=112&&I_y<176)begin O_mode<=1;O_index<=5;end
        else if(I_y>=192&&I_y<256)begin O_mode<=1;O_index<=30;end
        else if(I_y>=272&&I_y<336)begin O_mode<=1;O_index<=40;end
        else if(I_y>=352&&I_y<416)begin O_mode<=1;O_index<=50;end
       end
       4:begin
        if(I_y>=252&&I_y<340&&I_x>=584&&I_x<1000)begin
         drag<=1;O_index<=slider_index(I_x);custom_index<=slider_index(I_x);
        end else if(I_x>=584&&I_x<1000&&I_y>=472&&I_y<536)O_page<=6;
       end
       6:begin
        if(I_x>=667&&I_x<934&&I_y>=167&&I_y<434)begin
         axis_drag<=1;O_ab<=ab_from_x(I_x);O_gm<=gm_from_y(I_y);
        end else if(I_x>=584&&I_x<656&&I_y>=104&&I_y<164)O_key_axis<=0;
        else if(I_x>=912&&I_x<1000&&I_y>=104&&I_y<164)O_key_axis<=1;
        else if(I_x>=584&&I_x<656&&I_y>=268&&I_y<332)begin nudge(1);axis_direction<=1;end
        else if(I_x>=944&&I_x<1016&&I_y>=268&&I_y<332)begin nudge(2);axis_direction<=2;end
        else if(I_x>=768&&I_x<832&&I_y>=104&&I_y<164)begin nudge(3);axis_direction<=3;end
        else if(I_x>=768&&I_x<832&&I_y>=436&&I_y<496)begin nudge(4);axis_direction<=4;end
        else if(I_x>=584&&I_x<1000&&I_y>=520&&I_y<576)begin O_ab<=0;O_gm<=0;end
       end
       5:begin
        if(I_y>=112&&I_y<168)begin
         if(I_x>=584&&I_x<712)gain_preset<=1;
         else if(I_x>=728&&I_x<856)gain_preset<=2;
         else if(I_x>=872&&I_x<1000)gain_preset<=3;
        end else if(I_y>=300&&I_y<388)begin
         if(I_x>=608&&I_x<736)begin dec_req<=1;direction<=1;end
         else if(I_x>=856&&I_x<984)begin inc_req<=1;direction<=2;end
        end else if(I_y>=432&&I_y<488&&I_x>=584&&I_x<1000)reset_gain<=1;
       end
       7:begin
        if(I_y>=112&&I_y<176)begin
         if(I_x>=584&&I_x<784)O_image_mode<=0;
         else if(I_x>=800&&I_x<1000)O_image_mode<=5;
        end else if(I_y>=192&&I_y<256)begin
         if(I_x>=584&&I_x<784)O_image_mode<=4;
         else if(I_x>=800&&I_x<1000)O_image_mode<=6;
        end else if(I_y>=272&&I_y<336)begin
         if(I_x>=584&&I_x<784)O_image_mode<=7;
         else if(I_x>=800&&I_x<1000)O_image_mode<=1;
        end else if(I_y>=352&&I_y<416)begin
         if(I_x>=584&&I_x<784)O_image_mode<=2;
         else if(I_x>=800&&I_x<1000)O_image_mode<=3;
        end
       end
       8:begin
        if(I_x>=584&&I_x<1000&&I_y>=112&&I_y<176)
         O_tag_enable<=!O_tag_enable;
        else if(I_x>=584&&I_x<1000&&I_y>=192&&I_y<256)
         O_detect_enable<=!O_detect_enable;
        else if(I_x>=584&&I_x<1000&&I_y>=272&&I_y<336)
         O_bars_hide<=!O_bars_hide;
       end
      endcase
     end
    end else if(!held)begin
      
      
     released_ms<=0;blocked<=1;
    end else if(held)begin
     if(hist_drag)O_hist_strength<=hist_index(I_x);
     if(axis_drag)begin O_ab<=ab_from_x(I_x);O_gm<=gm_from_y(I_y);end
     if(drag)begin O_index<=slider_index(I_x);custom_index<=slider_index(I_x);end
     if(preview_gesture&&O_page==0)begin
      if(!swipe_y_ok||I_y>=600)begin swipe_bad<=1;swipe_ready<=0;end
      else if(!swipe_bad)swipe_ready<=swipe_left_now;
     end
     if(axis_direction!=0&&!((axis_direction==1&&I_x>=584&&I_x<656&&I_y>=268&&I_y<332)||
        (axis_direction==2&&I_x>=944&&I_x<1016&&I_y>=268&&I_y<332)||
        (axis_direction==3&&I_x>=768&&I_x<832&&I_y>=104&&I_y<164)||
        (axis_direction==4&&I_x>=768&&I_x<832&&I_y>=436&&I_y<496)))axis_direction<=0;
     if(direction!=0&&!(I_y>=300&&I_y<388&&((direction==1&&I_x>=608&&I_x<736)||(direction==2&&I_x>=856&&I_x<984))))direction<=0;
    end
   end
  end
 end
endmodule
