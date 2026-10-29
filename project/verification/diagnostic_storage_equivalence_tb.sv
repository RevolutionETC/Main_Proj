`timescale 1ns/1ps
module diagnostic_storage_equivalence_tb;
 reg cam=0,ddr=0;always #7 cam=~cam;always #5 ddr=~ddr;
 reg rst=0,sof=0,v=0,bad=0,release_frame=0,stall=0;reg [127:0] data=0;
 wire [63:0] sequences;wire [15:0] capture;
 wire wr,busy,front;wire [1:0] rp;wire [24:0] addr;wire [127:0] wd;wire [31:0] good,dropped,overflow;
 integer cycle=0;reg [25:0] pending=0;wire ready=rst&&!stall&&(cycle%9!=0);
 video_in #(.FRAME_WORDS(768)) dut(.I_rst_n(rst),.I_camera_clk(cam),.I_camera_frame_start(sof),
 .I_camera_mode(3'd0),.O_slot_modes(),.O_slot_sequences(sequences),.O_capture_sequence(capture),.I_camera_valid(v),.I_camera_data(data),.I_mipi_rx_error(bad),
 .I_ddr_clk(ddr),.I_display_pause(1'b0),.I_video_out_rd_busy(1'b0),.I_display_frame_release(release_frame),
 .I_ddr_writes_idle(pending==0&&!wr),.O_video_in_wr_busy(busy),.O_video_out_rp(rp),.O_front_valid(front),
 .O_ddr_user_wr_en(wr),.O_ddr_user_addr(addr),.O_ddr_user_wr_data(wd),.I_ddr_user_ready(ready),
 .O_dropped_frames(dropped),.O_good_frames(good),.O_fifo_overflows(overflow));
 wire ref_wr,ref_busy,ref_front;wire [1:0] ref_rp;wire [24:0] ref_addr;wire [127:0] ref_wd;
 wire [31:0] ref_good,ref_dropped,ref_overflow;
 diagnostic_reference_video_in #(.FRAME_WORDS(768)) original(
 .I_rst_n(rst),.I_camera_clk(cam),.I_camera_frame_start(sof),.I_camera_mode(3'd0),.O_slot_modes(),
 .I_camera_valid(v),.I_camera_data(data),.I_mipi_rx_error(bad),.I_ddr_clk(ddr),.I_display_pause(1'b0),
 .I_video_out_rd_busy(1'b0),.I_display_frame_release(release_frame),.I_ddr_writes_idle(pending==0&&!wr),
 .O_video_in_wr_busy(ref_busy),.O_video_out_rp(ref_rp),.O_front_valid(ref_front),
 .O_ddr_user_wr_en(ref_wr),.O_ddr_user_addr(ref_addr),.O_ddr_user_wr_data(ref_wd),.I_ddr_user_ready(ready),
 .O_dropped_frames(ref_dropped),.O_good_frames(ref_good),.O_fifo_overflows(ref_overflow));
 integer eq_cycles=0,metadata_commits=0,expected_sequence,sweep_i;reg [15:0] previous_gray=16'h8002;
 reg sequence_sweep=0;reg [15:0] sync_delta;
 function integer one_count(input [15:0] bits);
 integer b;begin one_count=0;for(b=0;b<16;b=b+1)one_count=one_count+bits[b];end endfunction
 always @(posedge cam)begin #1;
  if(rst)begin
   if({dut.full,dut.pending_marker,dut.drop_camera,overflow}!=={original.full,original.pending_marker,original.drop_camera,ref_overflow})
    $fatal(1,"capture behavior changed by metadata");
   if((^dut.camera_sequence_gray)===1'bx ||
      (dut.camera_sequence_gray!==previous_gray&&one_count(dut.camera_sequence_gray^previous_gray)!=1))
    $fatal(1,"registered source Gray transition was not one bit got=%h prev=%h",dut.camera_sequence_gray,previous_gray);
   previous_gray=dut.camera_sequence_gray;
  end else previous_gray=0;
 end
 always @(posedge ddr)begin
  if(rst)begin
   if({wr,busy,front,rp,good,dropped,addr}!=={ref_wr,ref_busy,ref_front,ref_rp,ref_good,ref_dropped,ref_addr})
    $fatal(1,"metadata altered writer control/address/count timing");
   if(wr&&wd!==ref_wd)$fatal(1,"metadata altered writer payload");
   eq_cycles=eq_cycles+1;
  end
  #1;if(rst&&sequence_sweep)begin
   sync_delta=dut.camera_sequence-capture;
   if(sync_delta>4)$fatal(1,"synchronized Gray decoder left its bounded recent source history");
  end
 end
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
  if(good!=last_good)begin if(pending!=0)$fatal(1,"Published before MC drained");last_good=good;
   expected_sequence=(65532+content[dut.latest])&65535;
   if(sequences[dut.latest*16+:16]!==expected_sequence[15:0])$fatal(1,"slot sequence not paired with actual first-pixel frame ID");
   metadata_commits=metadata_commits+1;
  end
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
  dut.camera_sequence=16'hfffc;dut.camera_sequence_gray=16'h8002;previous_gray=16'h8002;
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
  repeat(20)@(negedge ddr);if(capture!==16'd4)$fatal(1,"registered Gray CDC did not converge through wrap");
  if(metadata_commits<3||eq_cycles<10000)$fatal(1,"insufficient metadata equivalence coverage");
  sequence_sweep=1;
  @(negedge cam);v=0;sof=1;
  for(sweep_i=0;sweep_i<65536;sweep_i=sweep_i+1)@(negedge cam);
  sof=0;repeat(20)@(negedge ddr);
  if(capture!==16'd4)$fatal(1,"full Gray cycle failed convergence");
  $display("PASS diagnostic metadata writer: all 65536 registered Gray states and bounded asynchronous decode, sequence wrap and first-pixel/slot pairing, original/new every-cycle address/control/payload equivalence, SOF+first pixel, MC drain, exclusive ownership and drop/overflow recovery; %0d writes",count);$finish;
 end
 initial begin #5000000;$fatal(1,"Frame store watchdog state=%d words=%d",dut.state,dut.words);end
endmodule
