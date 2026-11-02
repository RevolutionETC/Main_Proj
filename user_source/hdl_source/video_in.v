 
 
module video_in #(parameter FRAME_WORDS=172800)(
 input wire I_rst_n,I_camera_clk,I_camera_frame_start,
 input wire [2:0] I_camera_mode,output wire [11:0] O_slot_modes,
 output wire [63:0] O_slot_sequences,output wire [15:0] O_capture_sequence,
 input wire I_camera_valid,input wire [127:0] I_camera_data,
 input wire I_mipi_rx_error,I_ddr_clk,I_display_pause,I_video_out_rd_busy,
 input wire I_display_frame_release,I_ddr_writes_idle,
 output wire O_video_in_wr_busy,output reg [1:0] O_video_out_rp,
 output reg O_front_valid,
 output wire O_ddr_user_wr_en,output wire [24:0] O_ddr_user_addr,
 output wire [127:0] O_ddr_user_wr_data,input wire I_ddr_user_ready,
 output reg [31:0] O_dropped_frames,O_good_frames,O_fifo_overflows
);
 wire full,empty;wire [149:0] head;wire [9:0] used;
 reg pending_marker,drop_camera,overflow,marker_bad;
 reg [149:0] entry;reg push;reg [2:0] marker_mode;
 reg [15:0] camera_sequence,marker_sequence;
 wire [15:0] camera_sequence_next=camera_sequence+1'b1;
  
 reg [15:0] camera_sequence_gray;
 always @(*)begin
  push=0;entry=0;
  if(I_camera_frame_start)begin push=1;entry={camera_sequence_next,I_camera_mode,I_mipi_rx_error|overflow|pending_marker,1'b1,I_camera_valid,I_camera_data};end
  else if(pending_marker)begin push=1;entry={marker_sequence,marker_mode,marker_bad,1'b1,1'b0,128'd0};end
  else if(I_camera_valid&&!drop_camera)begin push=1;entry={16'd0,I_camera_mode,1'b0,1'b0,1'b1,I_camera_data};end
 end
 always @(posedge I_camera_clk or negedge I_rst_n)
 if(!I_rst_n)begin camera_sequence<=0;camera_sequence_gray<=0;marker_sequence<=0;pending_marker<=0;drop_camera<=1;overflow<=0;marker_bad<=1;marker_mode<=0;O_fifo_overflows<=0;end
 else if(I_camera_frame_start)begin
  camera_sequence<=camera_sequence_next;camera_sequence_gray<=(camera_sequence_next>>1)^camera_sequence_next;marker_sequence<=camera_sequence_next;
  marker_bad<=I_mipi_rx_error|overflow|pending_marker;
  marker_mode<=I_camera_mode;
  pending_marker<=full;drop_camera<=full;overflow<=full;
  if(full)O_fifo_overflows<=O_fifo_overflows+1'b1;
 end else if(pending_marker&&!full)pending_marker<=0;
 else if(push&&full&&!drop_camera)begin
  overflow<=1;drop_camera<=1;O_fifo_overflows<=O_fifo_overflows+1'b1;
 end
 wire pop;
 frame_stream_fifo #(.WIDTH(150)) fifo(.rst_n(I_rst_n),.wclk(I_camera_clk),.we(push&&!full),.di(entry),.full(full),
 .rclk(I_ddr_clk),.re(pop),.dout(head),.empty(empty),.used(used));
 localparam SEEK=0,ALLOC=1,ACTIVE=2,CLOSE=3;
 reg [1:0] state,writer,latest;
  
 reg [2:0] first_mode;
 reg [2:0] writer_mode;reg [11:0] slot_modes;
 reg [15:0] first_sequence,writer_sequence;
 reg [63:0] slot_sequences;
 reg latest_valid,has_frame,bad,first_valid;
 reg [127:0] first_data;
 reg [17:0] words;
 reg burst;reg [7:0] burst_count;
 function [24:0] base(input [1:0] slot);
 begin case(slot)0:base=0;1:base=7000000;2:base=14000000;3:base=21000000;endcase end
 endfunction
 reg [1:0] free_slot;integer s;
 always @(*)begin
  free_slot=0;
  for(s=3;s>=0;s=s-1)
   if((!O_front_valid||s!=O_video_out_rp)&&(!latest_valid||s!=latest))free_slot=s;
 end
 wire marker=!empty&&head[129];
 wire payload=first_valid||(!empty&&!marker&&head[128]);
 assign O_video_in_wr_busy=burst;
 assign O_ddr_user_wr_en=state==ACTIVE&&burst&&payload&&words<FRAME_WORDS&&I_ddr_user_ready;
 assign O_ddr_user_wr_data=first_valid?first_data:head[127:0];
 assign O_ddr_user_addr=base(writer)+{4'd0,words,3'b000};
 assign O_slot_modes=slot_modes;
 assign O_slot_sequences=slot_sequences;
 (* async_reg="true" *) reg [15:0] sequence_gray_sync1,sequence_gray_sync2;
 function [15:0] gray_to_binary(input [15:0] gray);
 integer g;begin gray_to_binary[15]=gray[15];for(g=14;g>=0;g=g-1)gray_to_binary[g]=gray_to_binary[g+1]^gray[g];end
 endfunction
 always @(posedge I_ddr_clk or negedge I_rst_n)
 if(!I_rst_n)begin sequence_gray_sync1<=0;sequence_gray_sync2<=0;end
 else begin sequence_gray_sync1<=camera_sequence_gray;sequence_gray_sync2<=sequence_gray_sync1;end
 assign O_capture_sequence=gray_to_binary(sequence_gray_sync2);
 assign pop=(state==SEEK&&!empty)||(state==CLOSE&&!empty&&I_ddr_writes_idle)||
   (state==ACTIVE&&!first_valid&&!empty&&!marker&&
    ((head[128]&&words<FRAME_WORDS)?O_ddr_user_wr_en:1'b1));
 always @(posedge I_ddr_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  state<=SEEK;writer<=0;latest<=0;latest_valid<=0;O_video_out_rp<=0;O_front_valid<=0;
  first_mode<=0;writer_mode<=0;slot_modes<=0;
  first_sequence<=0;writer_sequence<=0;slot_sequences<=0;
  has_frame<=0;bad<=0;words<=0;first_valid<=0;first_data<=0;burst<=0;burst_count<=0;
  O_dropped_frames<=0;O_good_frames<=0;
 end else begin
  if(I_display_frame_release&&!I_display_pause&&latest_valid)begin
   O_video_out_rp<=latest;O_front_valid<=1;latest_valid<=0;
  end
  case(state)
   SEEK:if(marker)begin
    first_mode<=head[133:131];first_sequence<=head[149:134];
    first_valid<=head[128];first_data<=head[127:0];state<=ALLOC;
   end
   ALLOC:begin writer<=free_slot;writer_mode<=first_mode;writer_sequence<=first_sequence;words<=0;bad<=0;has_frame<=1;state<=ACTIVE;end
   ACTIVE:begin
    if(marker&&!first_valid)begin burst<=0;state<=CLOSE;end
    else begin
     if(!burst&&!I_video_out_rd_busy&&payload)begin burst<=1;burst_count<=0;end
     if(burst&&(!payload||words>=FRAME_WORDS))burst<=0;
     if(O_ddr_user_wr_en)begin
      words<=words+1'b1;first_valid<=0;
      if(burst_count==127)burst<=0;else burst_count<=burst_count+1'b1;
     end
     if(pop&&head[128]&&words>=FRAME_WORDS)bad<=1;
    end
   end
   CLOSE:if(I_ddr_writes_idle&&!empty)begin
     
    if(has_frame&&words==FRAME_WORDS&&!bad&&!head[130])begin
     latest<=writer;latest_valid<=1;slot_modes[writer*3 +: 3]<=writer_mode;
     slot_sequences[writer*16 +: 16]<=writer_sequence;
     O_good_frames<=O_good_frames+1'b1;
    end else O_dropped_frames<=O_dropped_frames+1'b1;
    first_mode<=head[133:131];first_sequence<=head[149:134];
    first_valid<=head[128];first_data<=head[127:0];state<=ALLOC;
   end
  endcase
 end
endmodule
