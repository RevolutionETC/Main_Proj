// Automatic analogue gain only. The shutter is a constant and dynamic
// register groups contain gain registers only. Manual gain is ignored in AUTO.
module camera_gain_apply #(parameter FIXED_EXPOSURE=1990,SETTLE_FRAMES=3)(
 input wire I_clk,I_rst_n,input wire [6:0] I_gain,
 input wire I_auto_enable,input wire [1:0] I_meter_mode,input wire [7:0] I_stats,
 input wire I_cam_done,I_ae_done,I_frame_toggle,
 output reg O_req,output wire [15:0] O_ae,output reg [15:0] O_ag,output reg [2:0] O_status
);
 assign O_ae=FIXED_EXPOSURE;
 reg initialized,wait_busy,seen,auto_d;reg [1:0] mode_d;
 (* async_reg="true" *) reg [1:0] fs_sync;
 reg fs_old;reg [2:0] cooldown;
 wire frame_tick=fs_sync[1]!=fs_old;
 wire [6:0] desired=(I_gain<16)?7'd16:(I_gain>89)?7'd89:I_gain;
 wire [3:0] step_count={1'b0,I_stats[2:0]};
 wire [7:0] increased={1'b0,O_ag[6:0]}+step_count;
 wire [6:0] next_gain=I_stats[2:0]==0?O_ag[6:0]:I_stats[3]?
    ((O_ag[6:0]<=7'd16+step_count)?7'd16:O_ag[6:0]-step_count):
    ((increased>=89)?7'd89:increased[6:0]);
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  O_req<=0;O_ag<=80;O_status<=0;initialized<=0;wait_busy<=0;seen<=0;
  mode_d<=1;auto_d<=1;fs_sync<=0;fs_old<=0;cooldown<=0;
 end else begin
  fs_sync<={fs_sync[0],I_frame_toggle};fs_old<=fs_sync[1];O_req<=0;
  mode_d<=I_meter_mode;auto_d<=I_auto_enable;
  if(I_stats[5]!=seen)seen<=I_stats[5];
  if(frame_tick&&cooldown!=0)cooldown<=cooldown-1'b1;
  if(!I_cam_done)begin initialized<=0;wait_busy<=0;cooldown<=SETTLE_FRAMES;O_status<=0;end
  else if(wait_busy)begin if(!I_ae_done)wait_busy<=0;end
  else if(!I_ae_done)cooldown<=SETTLE_FRAMES;
  else if(frame_tick&&cooldown==0&&(!initialized||(!I_auto_enable&&O_ag!={9'd0,desired})))begin
   if(!I_auto_enable)O_ag<={9'd0,desired};
   O_req<=1;initialized<=1;wait_busy<=1;cooldown<=SETTLE_FRAMES;O_status<=0;
  end else if(I_stats[5]!=seen)begin
   if(!I_stats[4]||I_stats[7:6]!=I_meter_mode)O_status<=0;
   else if(I_auto_enable&&initialized&&cooldown==0&&mode_d==I_meter_mode&&auto_d)begin
    O_status<={1'b1,I_stats[2:0]==0,I_stats[2:0]!=0&&next_gain==O_ag[6:0]};
    if(next_gain!=O_ag[6:0])begin O_ag<={9'd0,next_gain};O_req<=1;wait_busy<=1;cooldown<=SETTLE_FRAMES;end
   end
  end
  if(!I_auto_enable||auto_d!=I_auto_enable||mode_d!=I_meter_mode)O_status<=0;
 end
endmodule
