// Full-resolution, 4-connected, run-length component labeling for two colors.
// Only runs and canonical label maps are double-buffered, not RGB frames.
module reference_color_components #(
 parameter WIDTH=1024,HEIGHT=600,MAX_LINE_RUNS=64,MAX_RUNS=4096,MAX_LABELS=128
)(
 input wire I_clk,I_rst_n,I_frame_start,I_enable,I_de,
 input wire [10:0] I_x,I_y,input wire [1:0] I_color,
 input wire I_analyzer_busy,
 output reg O_start,O_bank,output reg [12:0] O_runs,
 output reg O_limit,output reg [31:0] O_dropped,
 input wire I_read_bank,input wire [11:0] I_read_addr,
 output wire [39:0] O_read_data,input wire [6:0] I_label,
 output wire [6:0] O_root
);
 // Capture buffers are separate from the previous/current labeled row buffers.
 reg [22:0] cap0[0:MAX_LINE_RUNS-1],cap1[0:MAX_LINE_RUNS-1];
 reg [29:0] row0[0:MAX_LINE_RUNS-1],row1[0:MAX_LINE_RUNS-1];
 (* ram_style="bram" *) reg [39:0] runs0[0:MAX_RUNS-1];
 (* ram_style="bram" *) reg [39:0] runs1[0:MAX_RUNS-1];
 reg [6:0] roots0[0:MAX_LABELS-1],roots1[0:MAX_LABELS-1];
 reg [6:0] parent[0:MAX_LABELS-1];reg [3:0] rank[0:MAX_LABELS-1];
 assign O_root=I_read_bank?roots1[I_label]:roots0[I_label];
 reg [39:0] read0,read1;reg read_bank;
 // Register each physical RAM port before selecting the bank. Mixing the
 // banks before the register prevents TD from inferring the embedded RAMs.
 always @(posedge I_clk)begin
  read0<=runs0[I_read_addr];read1<=runs1[I_read_addr];read_bank<=I_read_bank;
 end
 assign O_read_data=read_bank?read1:read0;
 reg capture_bank,cap_bank,de_d,run_open,run_blue;
 reg [10:0] run_left,last_x,last_y;
 reg [6:0] cap_count,line_count;reg line_bank,line_ready;
 reg [10:0] line_y;
 reg [19:0] pixel_count;reg enabled,cap_bad;
 reg engine_bad,built;
 reg [12:0] run_count;
 wire frame_good=built&&!cap_bad&&!engine_bad&&enabled&&pixel_count==WIDTH*HEIGHT;
 reg [4:0] state;
 localparam CLEAR=0,IDLE=1,CUR=2,SCAN=3,FIND=4,MERGE=5,WRITE=6,
  FINAL_START=7,FINAL_FIND=8,FINAL_SAVE=9,COMPLETE=10;
 reg [7:0] clear_id,next_label,final_id;
 reg source_bank,prev_bank,out_bank;
 reg [6:0] cur_count,cur_index,prev_count,prev_pointer,scan_index;
 reg [10:0] cur_y,prev_y,cur_left,cur_right;
 reg cur_blue;reg [6:0] cur_root,walk,original,candidate;
 reg [7:0] hops;
 wire [22:0] cap_record=source_bank?cap1[cur_index[5:0]]:cap0[cur_index[5:0]];
 wire [29:0] prev_record=prev_bank?row1[scan_index[5:0]]:row0[scan_index[5:0]];
 wire [10:0] prev_left=prev_record[29:19],prev_right=prev_record[18:8];
 wire prev_blue=prev_record[7];wire [6:0] prev_label=prev_record[6:0];
 wire [6:0] assigned=(cur_root!=0)?cur_root:((next_label<MAX_LABELS)?next_label[6:0]:7'd0);
 wire [39:0] run_record={cur_blue,cur_y[9:0],cur_left,cur_right,assigned};
 wire run_write=I_rst_n&&!I_frame_start&&state==WRITE&&assigned!=0&&run_count<MAX_RUNS;
 // Embedded RAM contents have no reset. Frame validity controls their use.
 always @(posedge I_clk)begin
  if(run_write&&!capture_bank)runs0[run_count[11:0]]<=run_record;
  if(run_write&&capture_bank)runs1[run_count[11:0]]<=run_record;
 end
 // All pixel-level capture work is constant-time; no backpressure enters video.
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  capture_bank<=0;cap_bank<=0;de_d<=0;run_open<=0;run_blue<=0;run_left<=0;last_x<=0;last_y<=0;
  cap_count<=0;line_count<=0;line_bank<=0;line_ready<=0;line_y<=0;pixel_count<=0;enabled<=0;cap_bad<=0;
  O_start<=0;O_bank<=0;O_runs<=0;O_limit<=0;O_dropped<=0;
 end else begin
  de_d<=I_de;line_ready<=0;O_start<=0;
  if(I_frame_start)begin
   if(I_enable&&frame_good&&!I_analyzer_busy)begin
    O_start<=1;O_bank<=capture_bank;O_runs<=run_count;capture_bank<=!capture_bank;
   end else if(enabled&&(!frame_good||I_analyzer_busy))O_dropped<=O_dropped+1'b1;
   O_limit<=cap_bad||engine_bad;
   cap_bank<=0;cap_count<=0;run_open<=0;pixel_count<=I_de?20'd1:20'd0;cap_bad<=0;enabled<=I_enable;
   if(I_de&&I_color!=0)begin run_open<=1;run_blue<=I_color==2;run_left<=I_x;end
   last_x<=I_x;last_y<=I_y;
  end else begin
   if(I_de)begin
    if(pixel_count<WIDTH*HEIGHT+1)pixel_count<=pixel_count+1'b1;
    if(I_x>=WIDTH||I_y>=HEIGHT)cap_bad<=1;
    last_x<=I_x;last_y<=I_y;
    if(enabled)begin
     if(run_open&&(I_color==0||(I_color==2)!=run_blue))begin
      if(cap_count<MAX_LINE_RUNS)begin
       if(cap_bank)cap1[cap_count[5:0]]<={run_left,I_x-11'd1,run_blue};
       else cap0[cap_count[5:0]]<={run_left,I_x-11'd1,run_blue};
       cap_count<=cap_count+1'b1;
      end else cap_bad<=1;
      run_open<=0;
     end
     if(I_color!=0&&(!run_open||(I_color==2)!=run_blue))begin
      run_open<=1;run_blue<=I_color==2;run_left<=I_x;
     end
    end
   end
   if(de_d&&!I_de)begin
    if(last_x!=WIDTH-1)cap_bad<=1;
    if(run_open)begin
     if(cap_count<MAX_LINE_RUNS)begin
      if(cap_bank)cap1[cap_count[5:0]]<={run_left,last_x,run_blue};
      else cap0[cap_count[5:0]]<={run_left,last_x,run_blue};
     end else cap_bad<=1;
    end
    line_count<=cap_count+((run_open&&cap_count<MAX_LINE_RUNS)?1'b1:1'b0);
    line_bank<=cap_bank;line_y<=last_y;line_ready<=1;
    cap_bank<=!cap_bank;cap_count<=0;run_open<=0;
   end
  end
 end
 // Sequential union/find. Rank bounds tree depth; path compression is applied.
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  state<=CLEAR;clear_id<=0;next_label<=1;final_id<=1;engine_bad<=0;built<=0;run_count<=0;
  source_bank<=0;prev_bank<=0;out_bank<=1;cur_count<=0;cur_index<=0;prev_count<=0;prev_pointer<=0;scan_index<=0;
  cur_y<=0;prev_y<=2047;cur_left<=0;cur_right<=0;cur_blue<=0;cur_root<=0;walk<=0;original<=0;candidate<=0;hops<=0;
 end else if(I_frame_start)begin
  state<=CLEAR;clear_id<=0;next_label<=1;final_id<=1;engine_bad<=0;built<=0;run_count<=0;
  prev_bank<=0;out_bank<=1;prev_count<=0;prev_y<=2047;
 end else begin
  if(line_ready&&state!=IDLE)engine_bad<=1;
  case(state)
   CLEAR:begin
    parent[clear_id[6:0]]<=clear_id[6:0];rank[clear_id[6:0]]<=0;
    if(clear_id==MAX_LABELS-1)state<=IDLE;else clear_id<=clear_id+1'b1;
   end
   IDLE:if(line_ready)begin
    source_bank<=line_bank;cur_count<=line_count;cur_index<=0;cur_y<=line_y;prev_pointer<=0;
    if(prev_y+1!=line_y)prev_count<=0;
    if(line_count==0)begin
     prev_count<=0;prev_y<=line_y;
     if(line_y==HEIGHT-1)state<=FINAL_START;
    end else state<=CUR;
   end
   CUR:begin
    cur_left<=cap_record[22:12];cur_right<=cap_record[11:1];cur_blue<=cap_record[0];
    cur_root<=0;scan_index<=prev_pointer;state<=SCAN;
   end
   SCAN:begin
    if(scan_index>=prev_count)state<=WRITE;
    else if(prev_right<cur_left)begin scan_index<=scan_index+1'b1;prev_pointer<=scan_index+1'b1;end
    else if(prev_left>cur_right)state<=WRITE;
    else if(prev_blue!=cur_blue||prev_label==0)scan_index<=scan_index+1'b1;
    else begin walk<=prev_label;original<=prev_label;hops<=0;state<=FIND;end
   end
   FIND:begin
    if(parent[walk]!=walk)begin
     walk<=parent[walk];hops<=hops+1'b1;
     if(hops>=MAX_LABELS-1)begin engine_bad<=1;state<=WRITE;end
    end else begin candidate<=walk;parent[original]<=walk;state<=MERGE;end
   end
   MERGE:begin
    if(cur_root==0)cur_root<=candidate;
    else if(cur_root!=candidate)begin
     if(rank[cur_root]<rank[candidate])begin parent[cur_root]<=candidate;cur_root<=candidate;end
     else begin parent[candidate]<=cur_root;if(rank[cur_root]==rank[candidate])rank[cur_root]<=rank[cur_root]+1'b1;end
    end
    scan_index<=scan_index+1'b1;state<=SCAN;
   end
   WRITE:begin
    if(assigned==0||run_count>=MAX_RUNS)engine_bad<=1;
    if(cur_root==0&&assigned!=0)begin parent[assigned]<=assigned;rank[assigned]<=0;next_label<=next_label+1'b1;end
    if(out_bank)row1[cur_index[5:0]]<={cur_left,cur_right,cur_blue,assigned};
    else row0[cur_index[5:0]]<={cur_left,cur_right,cur_blue,assigned};
    if(assigned!=0&&run_count<MAX_RUNS)begin
     run_count<=run_count+1'b1;
    end
    if(cur_index+1>=cur_count)begin
     prev_bank<=out_bank;out_bank<=!out_bank;prev_count<=cur_count;prev_y<=cur_y;
     if(cur_y==HEIGHT-1)state<=FINAL_START;else state<=IDLE;
    end else begin cur_index<=cur_index+1'b1;state<=CUR;end
   end
   FINAL_START:begin final_id<=1;walk<=1;hops<=0;state<=FINAL_FIND;end
   FINAL_FIND:begin
    if(final_id>=next_label)begin built<=1;state<=COMPLETE;end
    else if(parent[walk]!=walk)begin
     walk<=parent[walk];hops<=hops+1'b1;
     if(hops>=MAX_LABELS-1)begin engine_bad<=1;built<=0;state<=COMPLETE;end
    end else state<=FINAL_SAVE;
   end
   FINAL_SAVE:begin
    if(capture_bank)roots1[final_id[6:0]]<=walk;else roots0[final_id[6:0]]<=walk;
    final_id<=final_id+1'b1;walk<=final_id+1'b1;hops<=0;state<=FINAL_FIND;
   end
   COMPLETE:;
   default:state<=IDLE;
  endcase
 end
endmodule
