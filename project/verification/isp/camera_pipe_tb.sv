`timescale 1ns/1ps
// Models only for storage primitives; camera decode, RAW unpack, demosaic,
// white balance, frame ownership, arbitration and pixel unpack are real RTL.
module blk_mem_gen_zhenghe(input clka,wea,input [10:0] addra,input [31:0] dia,
 input clkb,input [10:0] addrb,output reg [31:0] dob);
 reg [31:0] mem[0:2047];integer j;initial for(j=0;j<2048;j=j+1)mem[j]=0;
 always @(posedge clka)if(wea)mem[addra]<=dia;
 always @(posedge clkb)dob<=mem[addrb];
endmodule
module blk_mem_gen_demosaic(input clka,wea,input [10:0] addra,input [32:0] dia,
 input clkb,input [10:0] addrb,output reg [32:0] dob);
 reg [32:0] mem[0:2047];integer j;initial for(j=0;j<2048;j=j+1)mem[j]=0;
 always @(posedge clka)if(wea)mem[addra]<=dia;
 always @(posedge clkb)dob<=mem[addrb];
endmodule
module camera_pipe_tb;
 reg cam=0,ddr=0,dsi=0;always #8.333 cam=~cam;always #5 ddr=~ddr;always #9.583 dsi=~dsi;
 reg rst=0,hs=0;reg [15:0] hd=0;
 wire fs,fe,cv,le;wire [31:0] cd;wire previous_bad,ft,old_bad;
 wire [31:0] bad_count,old_bad_count;
 csi_unpacket_2lane decode(.I_clk(cam),.I_rst_n(rst),.I_hs_valid(hs),.I_hs_data(hd),
 .O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(cv),.O_csi_hs(),.O_csi_line_end(le),.O_csi_data(cd));
 camera_frame_check check_frame(.I_clk(cam),.I_rst_n(rst),.I_sof(fs),.I_eof(fe),.I_valid(cv),.I_line_end(le),.I_lane_error(1'b0),
 .O_previous_bad(previous_bad),.O_frame_toggle(ft),.O_bad_frames(bad_count));
 previous_frame_check legacy(.I_clk(cam),.I_rst_n(rst),.I_sof(fs),.I_eof(fe),.I_valid(cv),.I_lane_error(1'b0),
 .O_previous_bad(old_bad),.O_frame_toggle(),.O_bad_frames(old_bad_count));
 wire rfs,rfe,rv;wire [39:0] raw;
 raw10_unpacket_2lane rawdecode(.I_clk(cam),.I_rst_n(rst),.I_csi_frame_start(fs),.I_csi_frame_end(fe),.I_csi_valid(cv),
 .I_csi_data(cd),.I_camera_black_level(10'd0),.O_raw10_frame_start(rfs),.O_raw10_frame_end(rfe),.O_raw10_valid(rv),.O_raw10_data(raw));
 wire av,au,al;wire [39:0] ad;
 uial2axis #(.IMG_WIDTH(1280),.IMG_HEIGHT(720),.INPUT_DATA_WIDTH(40)) axis(.I_native_clk(cam),.I_rst_n(rst),
 .I_data(raw),.I_data_valid(rv),.I_data_start(rfs),.I_data_end(rfe),.axis_tvalid(av),.axis_tdata(ad),.axis_tuser(au),.axis_tlast(al));
 reg [18:0] wb_cfg=30;
 wire pv,pu,pl;wire [127:0] pd;wire [7:0] ae_stats;
 isp_top isp(.I_process_clk(cam),.O_cdc_overflow(),.axi4s_video_aclk(cam),.I_rst_n(rst),.I_wb_config(wb_cfg),.I_image_mode(3'd0),.I_hist_config(9'd178),.I_hist_ready(1'b1),.I_previous_bad(previous_bad),.O_frame_mode(),
 .I_tlast(al),.I_tuser(au),.I_tdata(ad),.I_tvalid(av),.I_tdest(10'd0),.O_tready(1'b1),.I_tready(),
 .O_tdata(pd),.O_tlast(pl),.O_tuser(pu),.O_tvalid(pv),.I_meter_mode(2'd1),.O_ae_stats(ae_stats));
 reg ae_seen=0;integer ae_complete_frames=0;
 always @(posedge cam)if(rst)begin
  #1;if(ae_stats[5]!=ae_seen)begin
   ae_seen=ae_stats[5];if(ae_stats[4])ae_complete_frames=ae_complete_frames+1;
  end
 end
 wire vb,rb,front,release_frame,writes_idle,ready,wr,rd;wire [1:0] rp;wire [24:0] wa,ra;wire [127:0] wd;
 wire [31:0] good,drops,overflows,underflows,display_overflows;
 wire [63:0] slot_sequences;wire [15:0] capture_sequence;
 wire [7:0] frame_age;wire frame_age_valid;
 video_in vin(.I_rst_n(rst),.I_camera_clk(cam),.I_camera_frame_start(pu),.I_camera_mode(3'd0),.O_slot_modes(),
 .O_slot_sequences(slot_sequences),.O_capture_sequence(capture_sequence),
 .I_camera_valid(pv),.I_camera_data(pd),.I_mipi_rx_error(previous_bad),.I_ddr_clk(ddr),.I_display_pause(1'b0),.I_video_out_rd_busy(rb),
 .I_display_frame_release(release_frame),.I_ddr_writes_idle(writes_idle),.O_video_in_wr_busy(vb),.O_video_out_rp(rp),.O_front_valid(front),
 .O_ddr_user_wr_en(wr),.O_ddr_user_addr(wa),.O_ddr_user_wr_data(wd),.I_ddr_user_ready(ready),
 .O_dropped_frames(drops),.O_good_frames(good),.O_fifo_overflows(overflows));
 reg vs=0,active=0;wire [23:0] pixel;wire rvalid;wire [127:0] rdata;
 video_out vout(.I_rst_n(rst),.I_ddr_clk(ddr),.O_video_out_rd_busy(rb),.I_video_in_wr_busy(vb),.I_video_out_rp(rp),
 .I_front_valid(front),.O_frame_release(release_frame),.O_underflow_frames(underflows),.O_overflow_frames(display_overflows),
 .I_slot_modes(12'd0),.O_frame_mode(),.O_ddr_user_rd_en(rd),.O_ddr_user_addr(ra),.I_ddr_user_ready(ready),
 .I_slot_sequences(slot_sequences),.I_capture_sequence(capture_sequence),.O_frame_latency(frame_age),.O_frame_latency_valid(frame_age_valid),
 .I_ddr_user_rd_valid(rvalid),.I_ddr_user_rd_data(rdata),.I_dsi_clk(dsi),.I_video_vsync(vs),.I_video_rd_en(active),.O_vdieo_data(pixel));
 reg [127:0] memory[0:691199],return_data[0:30];reg [30:0] return_valid=0;
 wire appen,wren;wire [24:0] appaddr;wire [2:0] cmd;wire [127:0] appwd;
 integer cycle=0;wire ar=cycle%13!=0,dr=cycle%17!=0;
 mc_to_user_interface mc(.I_clk(ddr),.I_rst_n(rst),.I_ddr_user_wr_en(wr),.I_ddr_user_rd_en(rd),.I_ddr_user_addr(wr?wa:ra),.I_ddr_user_wr_data(wd),
 .O_ddr_user_ready(ready),.O_writes_idle(writes_idle),.O_ddr_user_rd_valid(rvalid),.O_ddr_user_rd_data(rdata),
 .O_mc_app_en(appen),.O_mc_app_addr(appaddr),.O_mc_app_cmd(cmd),.I_mc_app_rdy(ar),.O_mc_app_wdf_wren(wren),.O_mc_app_wdf_data(appwd),
 .O_mc_app_wdf_end(),.O_mc_app_wdf_mask(),.I_mc_app_wdf_rdy(dr),.I_mc_app_rd_data(return_data[30]),
 .I_mc_app_rd_data_end(return_valid[30]),.I_mc_app_rd_data_valid(return_valid[30]));
 integer s,off,m,j,read_commands=0,write_commands=0;
 always @(posedge ddr)begin
  cycle=cycle+1;
  if(!rst)return_valid<=0;else return_valid<={return_valid[29:0],appen&&cmd==1};
  for(j=30;j>0;j=j-1)return_data[j]<=return_data[j-1];
  if(rst&&wr&&rd)$fatal(1,"Read/write arbitration collision");
  if(rst&&appen)begin
   s=appaddr/7000000;off=(appaddr-s*7000000)/8;m=s*172800+off;
   if(s>3||off>=172800)$fatal(1,"DDR address outside frame");
   if(cmd==0)begin memory[m]<=appwd;write_commands=write_commands+1;end
   else begin return_data[0]<=memory[m];read_commands=read_commands+1;end
  end
 end
 integer csi_words=0,line_words=0,line_ends=0,decoded_frames=0,raw_beats=0,packed_words=0,isp_frames=0;
 reg cv_d=0;
 always @(posedge cam)if(rst)begin
  if(cv)begin if(cv_d)$fatal(1,"Source not exercising alternate-cycle CSI valid");csi_words=csi_words+1;line_words=line_words+1;end
  cv_d=cv;
  if(le)begin if(line_words!=400)$fatal(1,"Payload-end alignment %d",line_words);line_words=0;line_ends=line_ends+1;end
  if(rv)raw_beats=raw_beats+1;
  if(pv)packed_words=packed_words+1;
  if(pu)isp_frames=isp_frames+1;
  if(fe)begin
   decoded_frames=decoded_frames+1;
   if(csi_words!=288000*decoded_frames||line_ends!=720*decoded_frames)$fatal(1,"CSI native frame counts");
   #1;
   if(previous_bad||!old_bad)$fatal(1,"Regression not reproduced or fixed old=%d new=%d",old_bad,previous_bad);
  end
 end
 integer lit=0,shown=0,trimmed=0;
 always @(posedge dsi)if(rst&&active&&front)begin
  #1;if(pixel!=0&&pixel!==24'hxxxxxx)lit=lit+1;
  if(pixel===24'ha0a0a0)shown=shown+1;
  if(pixel===24'h8cb8b4)trimmed=trimmed+1;
 end
 task packet(input [7:0] dtype,input integer bytes);
 integer i;begin
 @(negedge cam);hs=1;hd={dtype,8'(bytes)};
 @(negedge cam);hd={8'(bytes>>8),8'h00};
 for(i=0;i<bytes/2;i=i+1)begin @(negedge cam);hd=16'h8080;end
 if(bytes!=0)begin @(negedge cam);hd=0;end // CRC slot, ignored by reference decoder
 @(negedge cam);hs=0;hd=0;repeat(10)@(negedge cam);
 end endtask
 integer f,y;
 initial begin
 repeat(20)@(negedge cam);rst=1;
 for(f=0;f<4;f=f+1)begin
  wb_cfg=(f==0)?19'd30:(f==1)?19'd286:(f==2)?{5'b11011,5'd6,9'd286}:19'd286;
  packet(8'h00,0);
  for(y=0;y<720;y=y+1)begin packet(8'h2b,1600);repeat(380)@(negedge cam);end
  packet(8'h01,0);repeat(120000)@(negedge cam);
 end
 repeat(2000000)@(negedge ddr);
 if(decoded_frames!=4||ae_complete_frames!=3||bad_count!=0||old_bad_count!=4||good<3||!front||lit<614400||shown<614000||trimmed<614000||overflows!=0||underflows!=0||display_overflows!=0)
  $fatal(1,"Camera path failed frames=%d bad=%d oldbad=%d good=%d front=%d lit=%d gray=%d over=%d under=%d dispov=%d raw=%d packed=%d ispfs=%d",decoded_frames,bad_count,old_bad_count,good,front,lit,shown,overflows,underflows,display_overflows,raw_beats,packed_words,isp_frames);
 $display("PASS actual two-lane CSI->RAW10->AXIS->demosaic->WB->frame FIFO->MC queue->DDR model->1024x600 output: 4 native frames, 3 complete AE measurements, B5/G6 pixel reference; %0d valid frame commits, %0d nonblack pixels; no FIFO fault or arbitration collision",good,lit);$finish;
 end
 // Independent display with real blanking timing, never tied to camera SOF.
 integer dy;
 initial begin wait(rst);forever begin
 @(negedge dsi);vs=1;active=0;repeat(1344*2)@(negedge dsi);vs=0;
 repeat(1344*21)@(negedge dsi);
 for(dy=0;dy<600;dy=dy+1)begin active=1;repeat(1024)@(negedge dsi);active=0;repeat(320)@(negedge dsi);end
 repeat(1344*12)@(negedge dsi);
 end end
 initial begin #100000000;$fatal(1,"Full camera path watchdog");end
endmodule
