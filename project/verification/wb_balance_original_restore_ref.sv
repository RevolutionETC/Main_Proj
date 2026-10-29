// Frame-atomic manual/preset WB, or filtered gray-world AWB from raw RGB.
// Statistics use one spatial sample per 4-pixel beat, excluding dark/clipped
// samples. Complete-frame ratios are calculated in blanking/background.
module wb_balance_original_restore_ref #(parameter MIN_SAMPLES=4096, FRAME_BEATS=230400, FRAME_LINES=720)(
 input wire I_clk,I_rst_n,input wire [1:0] I_mode,input wire [6:0] I_kelvin_index,
 input wire [95:0] I_data,input wire I_valid,I_user,I_last,I_ready,I_previous_bad,
 output reg [95:0] O_data,output reg O_valid,O_user,O_last,output wire O_ready,
 output reg [11:0] O_gain_r,O_gain_b,output reg O_statistics_ok
);
 reg user_d;
 wire sof=I_user&&!user_d;
 wire [6:0] safe_index=(I_kelvin_index>75)?7'd75:I_kelvin_index;
 wire [11:0] manual_r,manual_b;
 wb_gain_lut lut(.I_index(safe_index),.O_r(manual_r),.O_b(manual_b));
 reg [25:0] sum_r,sum_g,sum_b;
 reg [17:0] samples,frame_beats;
 reg [10:0] frame_lines;reg frame_bad;
 reg [25:0] previous_g;
 wire [27:0] g4={sum_g,2'b00},pg3={2'b0,previous_g}+{1'b0,previous_g,1'b0};
 wire [28:0] pg5={1'b0,previous_g,2'b00}+{3'b0,previous_g};
 wire complete=frame_beats==FRAME_BEATS&&frame_lines==FRAME_LINES&&!frame_bad&&!I_previous_bad;
 wire enough=samples>=MIN_SAMPLES&&samples>=(FRAME_BEATS/8);
 wire steady=previous_g==0||(g4>=pg3&&{1'b0,g4}<=pg5);
 wire [7:0] sr=I_data[95:88],sg=I_data[87:80],sb=I_data[79:72];
 wire use_sample=sr>=8&&sg>=8&&sb>=8&&sr<245&&sg<245&&sb<245;
 reg [11:0] auto_r,auto_b,next_r;
 reg [25:0] latched_g,latched_b;
 reg div_start;
 reg [25:0] div_g,div_c;
 wire div_done,div_busy;wire [11:0] div_gain;
 reg [1:0] phase;
 wb_ratio_seq ratio(.I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(div_start),.I_g(div_g),.I_channel(div_c),
   .O_busy(div_busy),.O_done(div_done),.O_gain(div_gain));
 // 1/16 IIR, Q10 deadband 8, maximum step 8 per accepted frame.
 function [11:0] slow_gain(input [11:0] current,target);
 reg [11:0] delta,step;
 begin
  delta=(target>current)?target-current:current-target;
  step=(delta+12'd8)>>4;if(step>8)step=8;
  if(delta<=8)slow_gain=current;
  else slow_gain=(target>current)?current+step:current-step;
 end endfunction
 wire [11:0] requested_r=(I_mode==1||I_mode==2)?manual_r:auto_r;
 wire [11:0] requested_b=(I_mode==1||I_mode==2)?manual_b:auto_b;
 wire [11:0] effective_r=sof?requested_r:O_gain_r;
 wire [11:0] effective_b=sof?requested_b:O_gain_b;
 reg [19:0] pr[0:3],pb[0:3];
 reg [7:0] pg[0:3];
 reg v1,u1,l1;
 function [7:0] clip(input [19:0] product);
  reg [20:0] rounded;
  begin rounded={1'b0,product}+21'd512;clip=(rounded>21'd261632)?8'd255:rounded[17:10];end
 endfunction
 integer p;
 assign O_ready=I_ready;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  O_statistics_ok<=0;frame_beats<=0;frame_lines<=0;frame_bad<=0;previous_g<=0;
  user_d<=0;sum_r<=0;sum_g<=0;sum_b<=0;samples<=0;
  auto_r<=1024;auto_b<=1024;next_r<=1024;latched_g<=0;latched_b<=0;
  div_start<=0;div_g<=0;div_c<=1;phase<=0;O_gain_r<=1024;O_gain_b<=1024;
  O_data<=0;O_valid<=0;O_user<=0;O_last<=0;v1<=0;u1<=0;l1<=0;
  for(p=0;p<4;p=p+1)begin pr[p]<=0;pb[p]<=0;pg[p]<=0;end
 end else begin
  user_d<=I_user;div_start<=0;
  if(sof)begin
   O_statistics_ok<=complete&&enough&&steady&&(I_mode==0);
   O_gain_r<=requested_r;O_gain_b<=requested_b;
   if(complete&&enough&&steady&&phase==0&&I_mode==0)begin
    latched_g<=sum_g;latched_b<=sum_b;div_g<=sum_g;div_c<=sum_r;div_start<=1;phase<=1;
   end
   if(complete&&enough)previous_g<=sum_g;
   frame_beats<=I_valid?1:0;frame_lines<=(I_valid&&I_last)?1:0;frame_bad<=0;
   sum_r<=I_valid&&use_sample?{18'd0,sr}:26'd0;
   sum_g<=I_valid&&use_sample?{18'd0,sg}:26'd0;
   sum_b<=I_valid&&use_sample?{18'd0,sb}:26'd0;
   samples<=I_valid&&use_sample?18'd1:18'd0;
  end else if(I_valid)begin
   if(frame_beats<262143)frame_beats<=frame_beats+1'b1;else frame_bad<=1;
   if(frame_beats>=FRAME_BEATS)frame_bad<=1;
   if(I_last)begin if(frame_lines<2047)frame_lines<=frame_lines+1'b1;else frame_bad<=1;end
   if(use_sample)begin sum_r<=sum_r+sr;sum_g<=sum_g+sg;sum_b<=sum_b+sb;
    if(samples<262143)samples<=samples+1'b1;
   end
  end
  if(div_done&&phase==1)begin
   next_r<=div_gain;div_g<=latched_g;div_c<=latched_b;div_start<=1;phase<=2;
  end else if(div_done&&phase==2)begin
   auto_r<=slow_gain(auto_r,next_r);auto_b<=slow_gain(auto_b,div_gain);phase<=0;
  end
  v1<=I_valid;u1<=I_user;l1<=I_last;
  O_valid<=v1;O_user<=u1;O_last<=l1;
  for(p=0;p<4;p=p+1)begin
   pr[p]<=I_data[p*24+16+:8]*effective_r;
   pb[p]<=I_data[p*24+:8]*effective_b;pg[p]<=I_data[p*24+8+:8];
   O_data[p*24+:24]<=v1?{clip(pr[p]),pg[p],clip(pb[p])}:24'd0;
  end
 end
endmodule
