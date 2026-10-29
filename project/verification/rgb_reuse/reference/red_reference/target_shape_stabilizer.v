// Sequential per-object association and bounded class hysteresis.
// Geometry is projected to the display frame; absent objects never get a box.
(* dsp_style="no" *) module reference_target_shape_stabilizer #(
 parameter WIDTH=1024,HEIGHT=600,MAX_OBJECTS=8,
 parameter INIT_CONFIRM=2,SWITCH_CONFIRM=4,UNKNOWN_HOLD=12,MISSING_TTL=2,
 parameter MATCH_DISTANCE=64,AMBIGUITY_MARGIN=8
)(
 input wire I_clk,I_rst_n,I_start,I_cancel,
 input wire [15:0] I_frame_id,input wire [3:0] I_age,
 input wire [MAX_OBJECTS*48-1:0] I_objects,input wire [3:0] I_count,input wire I_limit,
 output reg O_busy,O_done,output reg [MAX_OBJECTS*48-1:0] O_objects,
 output reg [3:0] O_count,output reg O_limit
);
 localparam IDLE=0,LOAD=1,OLD_LOAD=2,COST=3,MATCH_SAVE=4,
  CLASS_LOAD=5,ALLOC=6,CLASS_SAVE=7,AGE=8,FINISH=9;
 reg [3:0] state,cur_index,old_index,num;
 reg [MAX_OBJECTS*48-1:0] batch;
 reg batch_limit;reg [MAX_OBJECTS-1:0] used,valid;
 reg [44:0] geometry[0:MAX_OBJECTS-1];
 reg [15:0] stamp[0:MAX_OBJECTS-1],frame_id;reg [3:0] age; // {blue,cx,cy,width,height}
 reg [1:0] stable[0:MAX_OBJECTS-1],candidate[0:MAX_OBJECTS-1],misses[0:MAX_OBJECTS-1];
 reg [2:0] votes[0:MAX_OBJECTS-1];
 reg [3:0] bad[0:MAX_OBJECTS-1];
 reg [3:0] mapping[0:MAX_OBJECTS-1];
 reg [47:0] cur;reg [44:0] old;
 reg [10:0] cw,ch;reg [11:0] best_score,second_score;reg best_found;reg [2:0] best_slot,slot;
 reg matched;integer j;
 wire [11:0] sx={1'b0,cur[44:34]}+cur[33:23],sy={1'b0,cur[22:12]}+cur[11:1];
 wire [10:0] cx=sx[11:1],cy=sy[11:1];
 wire blue=1'b0;wire [1:0] observed=cur[46:45];
 wire [10:0] ox=old[43:33],oy=old[32:22],ow=old[21:11],oh=old[10:0];
 wire [10:0] dx=(cx>=ox)?cx-ox:ox-cx,dy=(cy>=oy)?cy-oy:oy-cy;
 wire [10:0] dw=(cw>=ow)?cw-ow:ow-cw,dh=(ch>=oh)?ch-oh:oh-ch;
 wire [11:0] score={1'b0,dx}+{1'b0,dy};
 wire eligible=valid[old_index]&&!used[old_index]&&old[44]==blue&&frame_id-stamp[old_index]>0&&frame_id-stamp[old_index]<=3&&
  dx<=MATCH_DISTANCE+(ow>>3)&&dy<=MATCH_DISTANCE+(oh>>3)&&dw<=(ow>>2)+8&&dh<=(oh>>2)+8;
 wire hard_invalid=cur[44:34]==0||cur[33:23]>=WIDTH-1||cur[22:12]==0||cur[11:1]>=HEIGHT-1||cw<32||ch<32;
 reg [1:0] ns,nc,display_shape;reg [2:0] nv;reg [3:0] nb;
 // Class state transition is isolated from descriptor association and video.
 always @(*)begin
  ns=matched?stable[slot]:0;nc=matched?candidate[slot]:0;
  nv=matched?votes[slot]:0;nb=matched?bad[slot]:0;display_shape=ns;
  if(hard_invalid)begin ns=0;nc=0;nv=0;nb=0;display_shape=0;end
  else if(ns==0)begin
   display_shape=0;
   if(observed!=0)begin
    nb=0;
    if(observed==nc&&nv>=INIT_CONFIRM-1)begin ns=observed;display_shape=observed;nc=0;nv=0;end
    else begin nv=(observed==nc)?nv+1'b1:2'd1;nc=observed;end
   end else if(nb<2)nb=nb+1'b1;
   else begin nb=0;nc=0;nv=0;end
  end else if(observed==ns)begin nb=0;nc=0;nv=0;end
  else if(observed!=0&&observed==nc&&nv>=SWITCH_CONFIRM-1)begin
   ns=observed;display_shape=observed;nb=0;nc=0;nv=0;
  end else begin
   if(observed==0)begin nc=0;nv=0;end
   else begin nv=(observed==nc)?nv+1'b1:2'd1;nc=observed;end
   if(nb>=UNKNOWN_HOLD-1)begin ns=0;display_shape=0;nb=0;end
   else nb=nb+1'b1;
  end
 end
 // Predict the measured box to the next display frame. Velocity comes from
 // associated measurements and their frame IDs, never from repeated frames.
 reg signed [15:0] vx,vy,shift_x,shift_y;
 reg [10:0] pl,pr,pt,pb;wire [15:0] dt=frame_id-stamp[slot];
 always @(*)begin
  vx=$signed({1'b0,cx})-$signed({1'b0,geometry[slot][43:33]});
  vy=$signed({1'b0,cy})-$signed({1'b0,geometry[slot][32:22]});
  if(dt==2)begin vx=vx>>>1;vy=vy>>>1;end
  if(!matched||dt==0||dt>2||vx>64||vx< -64||vy>64||vy< -64)begin vx=0;vy=0;end
  if(vx>=-2&&vx<=2)vx=0;if(vy>=-2&&vy<=2)vy=0;
  shift_x=vx*$signed({1'b0,age});shift_y=vy*$signed({1'b0,age});
  if($signed({1'b0,cur[44:34]})+shift_x<0)shift_x=-$signed({1'b0,cur[44:34]});
  if($signed({1'b0,cur[33:23]})+shift_x>=WIDTH)shift_x=WIDTH-1-$signed({1'b0,cur[33:23]});
  if($signed({1'b0,cur[22:12]})+shift_y<0)shift_y=-$signed({1'b0,cur[22:12]});
  if($signed({1'b0,cur[11:1]})+shift_y>=HEIGHT)shift_y=HEIGHT-1-$signed({1'b0,cur[11:1]});
  pl=cur[44:34]+shift_x;pr=cur[33:23]+shift_x;pt=cur[22:12]+shift_y;pb=cur[11:1]+shift_y;
 end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  state<=IDLE;O_busy<=0;O_done<=0;O_objects<=0;O_count<=0;O_limit<=0;
  batch<=0;batch_limit<=0;frame_id<=0;age<=0;num<=0;cur_index<=0;old_index<=0;used<=0;valid<=0;
  cur<=0;old<=0;cw<=0;ch<=0;best_score<=4095;second_score<=4095;best_found<=0;best_slot<=0;slot<=0;matched<=0;
  for(j=0;j<MAX_OBJECTS;j=j+1)begin geometry[j]<=0;stamp[j]<=0;stable[j]<=0;candidate[j]<=0;votes[j]<=0;bad[j]<=0;misses[j]<=0;mapping[j]<=0;end
 end else begin
  O_done<=0;
  if(I_cancel)begin
   state<=IDLE;O_busy<=0;O_objects<=0;O_count<=0;O_limit<=0;valid<=0;used<=0;
  end else if(I_start&&!O_busy)begin
   frame_id<=I_frame_id;age<=I_age<=3?I_age:0;batch<=I_objects;batch_limit<=I_limit;num<=I_count;cur_index<=0;used<=0;O_objects<=0;O_busy<=1;
   state<=(I_count==0)?AGE:LOAD;old_index<=0;
  end else case(state)
   LOAD:begin
    cur<=batch[cur_index*48+:48];
    cw<=batch[cur_index*48+23+:11]-batch[cur_index*48+34+:11]+11'd1;
    ch<=batch[cur_index*48+1+:11]-batch[cur_index*48+12+:11]+11'd1;
    best_score<=4095;second_score<=4095;best_found<=0;best_slot<=0;old_index<=0;state<=OLD_LOAD;
   end
   OLD_LOAD:begin old<=geometry[old_index];state<=COST;end
   COST:begin
    if(eligible)begin
     if(score<best_score)begin second_score<=best_score;best_score<=score;best_slot<=old_index[2:0];best_found<=1;end
     else if(score<second_score)second_score<=score;
    end
    if(old_index==MAX_OBJECTS-1)state<=MATCH_SAVE;else begin old_index<=old_index+1'b1;state<=OLD_LOAD;end
   end
   MATCH_SAVE:begin
    if(best_found&&second_score>best_score+AMBIGUITY_MARGIN)begin mapping[cur_index]<={1'b1,best_slot};used[best_slot]<=1;end
    else mapping[cur_index]<=0;
    if(cur_index+1>=num)begin cur_index<=0;state<=CLASS_LOAD;end
    else begin cur_index<=cur_index+1'b1;state<=LOAD;end
   end
   CLASS_LOAD:begin
    cur<=batch[cur_index*48+:48];
    cw<=batch[cur_index*48+23+:11]-batch[cur_index*48+34+:11]+11'd1;
    ch<=batch[cur_index*48+1+:11]-batch[cur_index*48+12+:11]+11'd1;
    matched<=mapping[cur_index][3];slot<=mapping[cur_index][2:0];old_index<=0;
    state<=mapping[cur_index][3]?CLASS_SAVE:ALLOC;
   end
   ALLOC:begin
    if(!used[old_index])begin slot<=old_index[2:0];used[old_index]<=1;state<=CLASS_SAVE;end
    else if(old_index<MAX_OBJECTS-1)old_index<=old_index+1'b1;
   end
   CLASS_SAVE:begin
    stamp[slot]<=frame_id;valid[slot]<=1;geometry[slot]<={blue,cx,cy,cw,ch};stable[slot]<=ns;candidate[slot]<=nc;votes[slot]<=nv;bad[slot]<=nb;misses[slot]<=0;
    O_objects[cur_index*48+:48]<={cur[47]&&display_shape!=0,display_shape,pl,pr,pt,pb,1'b0};
    if(cur_index+1>=num)begin old_index<=0;state<=AGE;end
    else begin cur_index<=cur_index+1'b1;state<=CLASS_LOAD;end
   end
   AGE:begin
    if(!used[old_index]&&valid[old_index])begin
     if(misses[old_index]>=MISSING_TTL)valid[old_index]<=0;
     else misses[old_index]<=misses[old_index]+1'b1;
    end
    if(old_index==MAX_OBJECTS-1)state<=FINISH;else old_index<=old_index+1'b1;
   end
   FINISH:begin O_count<=num;O_limit<=batch_limit;O_busy<=0;O_done<=1;state<=IDLE;end
   default:;
  endcase
 end
endmodule
