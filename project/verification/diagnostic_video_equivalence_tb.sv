`timescale 1ns/1ps
module diagnostic_video_equivalence_tb;
 reg ddr=0,dsi=0;always #5 ddr=~ddr;always #9.58 dsi=~dsi;
 reg rst=0,vs=0,rd=0,stall=0;reg [1:0] rp=1;
 reg [63:0] sequences={16'd400,16'd1,16'd65530,16'd65534};reg [15:0] capture=2;
 wire [7:0] age;wire age_valid;
 wire req,busy,release_frame;wire [24:0] addr;wire [23:0] pixel;wire [31:0] under,over;
 reg [30:0] returns=0;reg [127:0] words[0:30];
 integer cycle=0,accepted=0,frames=0,expected_base=0,next_row,next_word,expected,j,k,checked=0;
 wire ready=rst&&!stall&&(cycle%7!=0)&&(cycle%11!=0);
 video_out dut(.I_rst_n(rst),.I_ddr_clk(ddr),.O_video_out_rd_busy(busy),.I_video_in_wr_busy(1'b0),
 .I_video_out_rp(rp),.I_front_valid(1'b1),.O_frame_release(release_frame),.O_underflow_frames(under),.O_overflow_frames(over),
 .I_slot_modes(12'd0),.O_frame_mode(),.I_slot_sequences(sequences),.I_capture_sequence(capture),
 .O_frame_latency(age),.O_frame_latency_valid(age_valid),.O_ddr_user_rd_en(req),.O_ddr_user_addr(addr),.I_ddr_user_ready(ready),
 .I_ddr_user_rd_valid(returns[30]),.I_ddr_user_rd_data(words[30]),.I_dsi_clk(dsi),.I_video_vsync(vs),.I_video_rd_en(rd),.O_vdieo_data(pixel));
 wire ref_req,ref_busy,ref_release;wire [24:0] ref_addr;wire [23:0] ref_pixel;wire [31:0] ref_under,ref_over;
 diagnostic_reference_video_out original(.I_rst_n(rst),.I_ddr_clk(ddr),.O_video_out_rd_busy(ref_busy),.I_video_in_wr_busy(1'b0),
 .I_video_out_rp(rp),.I_front_valid(1'b1),.O_frame_release(ref_release),.O_underflow_frames(ref_under),.O_overflow_frames(ref_over),
 .I_slot_modes(12'd0),.O_frame_mode(),.O_ddr_user_rd_en(ref_req),.O_ddr_user_addr(ref_addr),.I_ddr_user_ready(ready),
 .I_ddr_user_rd_valid(returns[30]),.I_ddr_user_rd_data(words[30]),.I_dsi_clk(dsi),.I_video_vsync(vs),.I_video_rd_en(rd),.O_vdieo_data(ref_pixel));
 integer eq_pixels=0,age_samples=0,delta;reg taking;
 always @(posedge dsi)begin #0.1;
  if(rst)begin
   if({pixel,under}!=={ref_pixel,ref_under})$fatal(1,"age diagnostics changed pixel/underflow cycle");
   if(rd)eq_pixels=eq_pixels+1;
  end
 end
 always @(posedge ddr)begin
  if(rst&&{req,busy,release_frame,addr,over}!=={ref_req,ref_busy,ref_release,ref_addr,ref_over})
   $fatal(1,"age diagnostics changed DDR address/control/overflow cycle");
  taking=rst&&dut.S_frame_load;
  delta=(capture-sequences[rp*16+:16])&65535;
  #0.1;if(taking)begin
   if(!age_valid||age!==(delta>255?8'd255:8'(delta)))$fatal(1,"age not sampled on actual DDR address-load edge");
   age_samples=age_samples+1;
  end
 end
 always @(posedge ddr)begin
  cycle=cycle+1;
  if(!rst)returns<=0;else returns<={returns[29:0],req};
  for(k=30;k>0;k=k-1)words[k]<=words[k-1];
  if(dut.S_video_frame_start&&rst)begin accepted=0;expected_base=rp*7000000;frames=frames+1;end
  if(req)begin
   next_row=accepted/192;next_word=accepted%192;
   expected=expected_base+115392+next_row*1920+next_word*8;
   if(addr!==expected||accepted>=115200)$fatal(1,"Crop address/limit addr=%d expected=%d",addr,expected);
   if(dut.S_frame_pending||dut.S_fifo_rst)$fatal(1,"Read during drain/reset");
   for(j=0;j<16;j=j+1)case((((addr-expected_base)*2)+j)%3)
    0:words[0][127-j*8-:8]<=8'h12;1:words[0][127-j*8-:8]<=8'h34;2:words[0][127-j*8-:8]<=8'h56;endcase
   accepted=accepted+1;
  end
 end
 reg rd_old=0;
 always @(posedge dsi)begin
  #1;
  if(rst&&rd_old&&frames==1)begin if(pixel!==24'h123456)$fatal(1,"Pixel unpacking %h under=%d",pixel,under);checked=checked+1;end
  rd_old=rd;
 end
 task frame(input bit inject);
 integer y;begin
 @(negedge dsi);vs=1;repeat(8)@(negedge dsi);vs=0;repeat(700)@(negedge dsi);
 for(y=0;y<600;y=y+1)begin
  if(inject&&y==30)stall=1;
  rd=1;repeat(1024)@(negedge dsi);rd=0;repeat(320)@(negedge dsi);
 end
 stall=0;repeat(600)@(negedge dsi);
 end endtask
 initial begin
 repeat(6)@(negedge dsi);rst=1;frame(0);
 if(accepted!=115200||checked!=614400||under!=0||over!=0)$fatal(1,"Complete display frame counts %d %d %d %d",accepted,checked,under,over);
 if(age!=8)$fatal(1,"modulo wrapped age");capture=1500;rp=2;frame(1);if(under!=1||over!=0)$fatal(1,"Underflow count/overflow %d %d",under,over);
 if(age!=255)$fatal(1,"age saturation");capture=420;rp=3;frame(0);if(accepted!=115200||under!=1||over!=0)$fatal(1,"Next-frame recovery");
 if(age!=20||age_samples!=3||eq_pixels!=1843200)$fatal(1,"metadata/pixel coverage");
 $display("PASS diagnostic reader: original/new every-cycle pixel/address/control equivalence for 1843200 active pixels, correct wrap/saturation and actual address-edge age samples; full 1024x600 crop/pixel byte order with async DDR/DSI, delayed returns/stalls, 614400 exact pixels, credit-based FIFO protection, one underflow event and next-frame recovery");$finish;end
 initial begin #65000000;$fatal(1,"Crop watchdog");end
endmodule
