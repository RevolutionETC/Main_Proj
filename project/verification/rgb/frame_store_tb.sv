`timescale 1ns/1ps
module frame_store_tb;
 reg cam=0,ddr=0;always #7 cam=~cam;always #5 ddr=~ddr;
 reg rst=0,sof=0,v=0,bad=0,release_frame=0,stall=0;reg [127:0] data=0;
 wire wr,busy,front;wire [1:0] rp;wire [24:0] addr;wire [127:0] wd;wire [31:0] good,dropped,overflow;
 integer cycle=0;reg [25:0] pending=0;wire ready=rst&&!stall&&(cycle%9!=0);
 video_in #(.FRAME_WORDS(768)) dut(.I_rst_n(rst),.I_camera_clk(cam),.I_camera_frame_start(sof),
 .I_camera_mode(3'd0),.O_slot_modes(),.I_camera_valid(v),.I_camera_data(data),.I_mipi_rx_error(bad),
 .I_ddr_clk(ddr),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_display_frame_release(release_frame),
 .I_ddr_writes_idle(pending==0&&!wr),.O_video_in_wr_busy(busy),.O_video_out_rp(rp),.O_front_valid(front),
 .O_ddr_user_wr_en(wr),.O_ddr_user_addr(addr),.O_ddr_user_wr_data(wd),.I_ddr_user_ready(ready),
 .O_dropped_frames(dropped),.O_good_frames(good),.O_fifo_overflows(overflow));
 integer slot,offset,count=0;integer content[0:3];integer last_good=0;
 always @(posedge ddr)begin
  cycle=cycle+1;
  if(!rst)pending<=0;else pending<={pending[24:0],wr};
  if(wr)begin
   slot=addr/7000000;offset=(addr-slot*7000000)/8;
   if(front&&slot==rp)$fatal(1,"Overwriting front");
   if(dut.latest_valid&&slot==dut.latest)$fatal(1,"Overwriting unconsumed complete slot");
   if(offset>=768||wd[95:64]!==offset)$fatal(1,"Lost/reordered word at head or boundary addr=%d data=%h",addr,wd);
   if(offset==0)content[slot]=wd[127:96];
   if(content[slot]!=wd[127:96])$fatal(1,"Mixed frame");
   count=count+1;
  end
  #1;
  if(good!=last_good)begin if(pending!=0)$fatal(1,"Published before MC drained");last_good=good;end
 end
 task start_frame(input integer id,input bit previous_bad);
 begin @(negedge cam);sof=1;bad=previous_bad;v=1;data={32'(id),32'd0,64'h123456789abcdef0};
 @(negedge cam);sof=0;v=0;end endtask
 task remaining(input integer id,n);
 integer j;begin for(j=1;j<n;j=j+1)begin v=1;data={32'(id),32'(j),64'h123456789abcdef0};@(negedge cam);end
 v=0;repeat(20)@(negedge cam);end endtask
 task display_boundary;begin repeat(200)@(negedge ddr);release_frame=1;@(negedge ddr);release_frame=0;repeat(5)@(negedge ddr);end endtask
 integer held_slot;
 initial begin
  repeat(8)@(negedge cam);rst=1;
  start_frame(1,1);remaining(1,768);if(front)$fatal(1,"Unclosed frame visible");
  start_frame(2,0);remaining(2,767);display_boundary();
  if(!front||good!=1||content[rp]!=1)$fatal(1,"First complete frame not selected");held_slot=rp;
  start_frame(3,0);remaining(3,768);display_boundary();if(rp!=held_slot||good!=1)$fatal(1,"Truncated frame selected");
  start_frame(4,1);remaining(4,768);display_boundary();if(rp!=held_slot||good!=1)$fatal(1,"RX error frame selected");
  start_frame(5,0);remaining(5,768);display_boundary();if(good!=2||content[rp]!=4)$fatal(1,"Recovery frame");
  // Slow DDR beyond FIFO capacity: drop this capture, then recover at a marker.
  stall=1;start_frame(6,0);remaining(6,768);stall=0;repeat(1200)@(negedge ddr);
  start_frame(7,0);remaining(7,768);display_boundary();if(overflow==0)$fatal(1,"No overflow injected");
  start_frame(8,0);remaining(8,768);display_boundary();if(content[rp]!=7)$fatal(1,"No recovery after overflow");
  if(dropped<3)$fatal(1,"Missing bad frame drops");
  $display("PASS frame store: asynchronous SOF+first pixel, byte order, incomplete/RX-error rejection, MC drain, exclusive front/latest ownership, overflow/drop/recovery; %0d writes",count);$finish;
 end
 initial begin #1000000;$fatal(1,"Frame store watchdog state=%d words=%d",dut.state,dut.words);end
endmodule

module frame_check_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,s=0,e=0,v=0,err=0,le=0;wire bad,toggle;wire [31:0] count;
 camera_frame_check #(.LINE_WORDS(8),.LINES(4)) dut(.I_clk(clk),.I_rst_n(rst),.I_sof(s),.I_eof(e),.I_valid(v),.I_line_end(le),.I_lane_error(err),.O_previous_bad(bad),.O_frame_toggle(toggle),.O_bad_frames(count));
 task frame(input integer n,width,input bit lane);
 integer y;begin s=1;@(negedge clk);s=0;
 for(y=0;y<n;y=y+1)begin v=1;err=lane&&y==1;repeat(width)@(negedge clk);v=0;err=0;le=1;@(negedge clk);le=0;repeat(2)@(negedge clk);end
 e=1;@(negedge clk);e=0;repeat(3)@(negedge clk);end endtask
 initial begin repeat(4)@(negedge clk);rst=1;
 frame(4,8,0);if(bad)$fatal(1,"Good CSI rejected");
 frame(3,8,0);if(!bad)$fatal(1,"Short CSI accepted");
 frame(4,9,0);if(!bad)$fatal(1,"Bad width accepted");
 frame(4,8,1);if(!bad)$fatal(1,"Lane error accepted");
 frame(4,8,0);if(bad||count!=3)$fatal(1,"CSI recovery/count");
 $display("PASS CSI completed-frame verdict: exact width/height, missing line, extra word, lane error and recovery");$finish;end
endmodule

module group_hold_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0;reg [15:0] index=0;wire [15:0] ag;
 reg [8:0] ri=0;wire [31:0] word;wire [8:0] size;
 SC500GainTbl gains(.I_clk(clk),.I_rstn(rst),.I(index),.O(ag));
 uics500regAE dut(.REG_INDEX(ri),.REG_DATA(word),.REG_SIZE(size),.I_AE(16'd1990),.I_AG(ag));
 integer a,j,coarse,fine;reg [23:0] expected[0:7];
 initial begin repeat(4)@(negedge clk);rst=1;
 for(a=0;a<74;a=a+1)begin index=a;repeat(3)@(negedge clk);
 coarse=a<32?3:a<64?7:15;fine=32+(a%32);
 if(ag!=={8'(coarse),8'(fine)})$fatal(1,"Real multiplier table %d",a);
 expected[0]=24'h380000;expected[1]=24'h3e0000;expected[2]=24'h3e017c;expected[3]=24'h3e0260;
 expected[4]={16'h3e08,8'(coarse)};expected[5]={16'h3e09,8'(fine)};expected[6]=24'h380010;expected[7]=24'h380040;
 if(size!=8)$fatal(1,"Group length");
 for(j=0;j<8;j=j+1)begin ri=j;#1;if(word!=={8'd0,expected[j]})$fatal(1,"Group hold sequence %d %h",j,word);@(negedge clk);end
 end
 $display("PASS SC500CS group0 0x3800 hold/end/frame release, fixed exposure and every analog gain register pair (1x/2x/4x included)");$finish;end
endmodule
