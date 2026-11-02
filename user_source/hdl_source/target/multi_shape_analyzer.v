 
module multi_shape_analyzer #(
 parameter WIDTH=1024,HEIGHT=600,MAX_OBJECTS=8,MIN_PIXELS=1200,MIN_WIDTH=32,MIN_HEIGHT=32
)(
 input wire I_clk,I_rst_n,I_start,I_cancel,I_bank,input wire [12:0] I_runs,
 output reg O_busy,O_done,O_read_bank,output reg [11:0] O_read_addr,
 input wire [39:0] I_read_data,input wire [6:0] I_root,
 output reg [6:0] O_color_label,input wire [1:0] I_label_color,
 output reg [MAX_OBJECTS*2-1:0] O_colors,
 output reg [MAX_OBJECTS*48-1:0] O_objects,output reg [3:0] O_count,output reg O_limit
);
 localparam IDLE=0,CLEAR=1,STAT_REQ=2,STAT_WAIT=3,STAT_USE=4,
  RANK_INIT=5,RANK_SCAN=6,RANK_SAVE=7,OBJ_BEGIN=8,DESC_INIT=9,DESC_REQ=10,DESC_WAIT=11,
  DESC_USE=12,DESC_FLUSH=13,CLASS_START=14,CLASS_ARM=15,CLASS_WAIT=16,TAG=17,SAVE=18,FINISH=19,
  STAT_RAM_WAIT=20,STAT_UPDATE=21,RANK_REQ=22,RANK_WAIT=23,OBJ_WAIT=24,OBJ_LOAD=25;
 reg [4:0] state;
  
 (* ram_style="bram" *) reg [64:0] stats[0:127];
 reg [6:0] stat_ra,stat_wa;reg stat_we;reg [64:0] stat_wd,stat_q;
 always @(posedge I_clk)begin
  if(stat_we)stats[stat_wa]<=stat_wd;
  stat_q<=stats[stat_ra];
 end
 reg [7:0] clear_id,rank_id;reg [127:0] chosen;
 reg [6:0] selected[0:MAX_OBJECTS-1],best_root,cur_root;
 reg [19:0] best_area;reg [3:0] selected_count,obj_index;
 reg [12:0] runs,scan_index;
 wire color=I_read_data[39];wire [10:0] ry={1'b0,I_read_data[38:29]};
 wire [10:0] rl=I_read_data[28:18],rr=I_read_data[17:7];
 wire [11:0] run_size={1'b0,rr}-{1'b0,rl}+12'd1;
 wire [19:0] added_area=stat_q[64:45]+run_size;
 wire [10:0] added_l=(rl<stat_q[44:34])?rl:stat_q[44:34];
 wire [10:0] added_r=(rr>stat_q[33:23])?rr:stat_q[33:23];
 wire [10:0] added_t=(ry<stat_q[22:12])?ry:stat_q[22:12];
 wire [10:0] added_b=(ry>stat_q[11:1])?ry:stat_q[11:1];
 reg [10:0] cur_l,cur_r,cur_t,cur_b;reg [1:0] cur_color;
 reg row_have;reg [10:0] row_y,row_l,row_r,row_hits;
 reg row_wr,class_start;reg [10:0] wr_y;reg [33:0] wr_data;
 wire [1:0] class_shape;wire class_ready;
 flat_shape_classify #(.WIDTH(WIDTH),.HEIGHT(HEIGHT)) classifier(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(class_start),.I_good(1'b1),.I_abort(I_cancel),
  .I_clipped(cur_l==0||cur_t==0||cur_r==WIDTH-1||cur_b==HEIGHT-1),
  .I_left(cur_l),.I_right(cur_r),.I_top(cur_t),.I_bottom(cur_b),
  .I_row_wr(row_wr),.I_row_y(wr_y),.I_row_data(wr_data),.O_shape(class_shape),.O_ready(class_ready),.O_busy());
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  O_color_label<=0;O_colors<=0;state<=IDLE;O_busy<=0;O_done<=0;O_read_bank<=0;O_read_addr<=0;O_objects<=0;O_colors<=0;O_count<=0;O_limit<=0;
  clear_id<=0;rank_id<=1;chosen<=0;best_root<=0;best_area<=0;cur_root<=0;selected_count<=0;obj_index<=0;
  runs<=0;scan_index<=0;cur_l<=0;cur_r<=0;cur_t<=0;cur_b<=0;cur_color<=0;
  row_have<=0;row_y<=0;row_l<=0;row_r<=0;row_hits<=0;row_wr<=0;class_start<=0;wr_y<=0;wr_data<=0;
  stat_ra<=0;stat_wa<=0;stat_we<=0;stat_wd<=0;
 end else begin
  O_done<=0;row_wr<=0;class_start<=0;stat_we<=0;
  if(I_cancel)begin state<=IDLE;O_busy<=0;O_objects<=0;O_colors<=0;O_count<=0;O_limit<=0;end
  else if(I_start&&!O_busy)begin
   O_busy<=1;O_read_bank<=I_bank;runs<=I_runs;state<=CLEAR;clear_id<=0;
   O_objects<=0;O_colors<=0;O_count<=0;O_limit<=0;chosen<=0;selected_count<=0;obj_index<=0;
  end else case(state)
   CLEAR:begin
    stat_we<=1;stat_wa<=clear_id[6:0];stat_wd<={20'd0,11'd2047,11'd0,11'd2047,11'd0,1'b0};
    if(clear_id==127)begin scan_index<=0;state<=(runs==0)?RANK_INIT:STAT_REQ;end else clear_id<=clear_id+1'b1;
   end
   STAT_REQ:begin O_read_addr<=scan_index[11:0];state<=STAT_WAIT;end
   STAT_WAIT:state<=STAT_USE;
   STAT_USE:begin stat_ra<=I_root;state<=STAT_RAM_WAIT;end
   STAT_RAM_WAIT:state<=STAT_UPDATE;
   STAT_UPDATE:begin
    if(I_root!=0)begin stat_we<=1;stat_wa<=I_root;stat_wd<={added_area,added_l,added_r,added_t,added_b,color};end
    if(scan_index+1>=runs)state<=RANK_INIT;else begin scan_index<=scan_index+1'b1;state<=STAT_REQ;end
   end
   RANK_INIT:begin rank_id<=1;best_root<=0;best_area<=0;state<=RANK_REQ;end
   RANK_REQ:begin stat_ra<=rank_id[6:0];state<=RANK_WAIT;end
   RANK_WAIT:state<=RANK_SCAN;
   RANK_SCAN:begin
    if(!chosen[rank_id[6:0]]&&stat_q[64:45]>=MIN_PIXELS&&stat_q[64:45]>best_area&&
       stat_q[33:23]-stat_q[44:34]+1>=MIN_WIDTH&&stat_q[11:1]-stat_q[22:12]+1>=MIN_HEIGHT)begin
     best_root<=rank_id[6:0];best_area<=stat_q[64:45];
    end
    if(rank_id==127)state<=RANK_SAVE;else begin rank_id<=rank_id+1'b1;state<=RANK_REQ;end
   end
   RANK_SAVE:begin
    if(best_root==0||selected_count==MAX_OBJECTS)begin
     if(best_root!=0)O_limit<=1;
     obj_index<=0;state<=(selected_count==0)?FINISH:OBJ_BEGIN;
    end else begin
     selected[selected_count]<=best_root;chosen[best_root]<=1;selected_count<=selected_count+1'b1;state<=RANK_INIT;
    end
   end
   OBJ_BEGIN:begin O_color_label<=selected[obj_index];cur_root<=selected[obj_index];stat_ra<=selected[obj_index];state<=OBJ_WAIT;end
   OBJ_WAIT:state<=OBJ_LOAD;
   OBJ_LOAD:begin cur_l<=stat_q[44:34];cur_r<=stat_q[33:23];cur_t<=stat_q[22:12];cur_b<=stat_q[11:1];cur_color<=I_label_color;state<=DESC_INIT;end
   DESC_INIT:begin scan_index<=0;row_have<=0;state<=DESC_REQ;end
   DESC_REQ:begin O_read_addr<=scan_index[11:0];state<=DESC_WAIT;end
   DESC_WAIT:state<=DESC_USE;
   DESC_USE:begin
    if(I_root==cur_root)begin
     if(!row_have||ry!=row_y)begin
      if(row_have)begin row_wr<=1;wr_y<=row_y;wr_data<={1'b1,row_l,row_r,row_hits};end
      row_have<=1;row_y<=ry;row_l<=rl;row_r<=rr;row_hits<=run_size[10:0];
     end else begin
      if(rl<row_l)row_l<=rl;if(rr>row_r)row_r<=rr;row_hits<=row_hits+run_size[10:0];
     end
    end
    if(scan_index+1>=runs)state<=DESC_FLUSH;else begin scan_index<=scan_index+1'b1;state<=DESC_REQ;end
   end
   DESC_FLUSH:begin row_wr<=row_have;wr_y<=row_y;wr_data<={1'b1,row_l,row_r,row_hits};state<=CLASS_START;end
   CLASS_START:begin class_start<=1;state<=CLASS_ARM;end
   CLASS_ARM:state<=CLASS_WAIT;
   CLASS_WAIT:if(class_ready)state<=SAVE;
   SAVE:begin
    O_colors[obj_index*2+:2]<=cur_color;
    O_objects[obj_index*48+:48]<={1'b1,class_shape,cur_l,cur_r,cur_t,cur_b,1'b0};
    if(obj_index+1>=selected_count)state<=FINISH;else begin obj_index<=obj_index+1'b1;state<=OBJ_BEGIN;end
   end
   FINISH:begin O_count<=selected_count;O_busy<=0;O_done<=1;state<=IDLE;end
   default:;
  endcase
 end
endmodule
