`timescale 1ns/1ps
// Behavioral model of the existing non-show-ahead dual-clock vendor FIFO.
module w128_d512_fifo(input rst,clkw,we,input [127:0] di,output [8:0] wrusedw,output afull,full_flag,
 input clkr,re,output reg [127:0] dout,output [8:0] rdusedw,output reg valid,output empty_flag,aempty);
 reg [127:0] mem[0:511];reg [9:0] wp=0,rp=0,ws1=0,ws2=0,rs1=0,rs2=0;
 wire [9:0] wc=wp-rs2,rc=ws2-rp;
 assign full_flag=wc>=510;assign empty_flag=rc==0;assign afull=wc>=253;assign aempty=rc<=2;
 assign wrusedw=wc>511?511:wc[8:0];assign rdusedw=rc>511?511:rc[8:0];
 always @(posedge clkw or posedge rst)if(rst)begin wp<=0;rs1<=0;rs2<=0;end
 else begin rs1<=rp;rs2<=rs1;if(we)begin if(full_flag)$fatal(1,"FIFO overflow");mem[wp[8:0]]<=di;wp<=wp+1'b1;end end
 always @(posedge clkr or posedge rst)if(rst)begin rp<=0;ws1<=0;ws2<=0;dout<=0;valid<=0;end
 else begin ws1<=wp;ws2<=ws1;valid<=re;if(re)begin if(empty_flag)$fatal(1,"FIFO underflow");dout<=mem[rp[8:0]];rp<=rp+1'b1;end end
endmodule
module crop_tb;
 reg ddr=0,dsi=0;always #5 ddr=~ddr;always #9.58 dsi=~dsi;
 reg rst=0,vs=0,rd=0,stall=0;reg [1:0] rp=1;
 wire req,busy,release_frame;wire [24:0] addr;wire [23:0] pixel;wire [31:0] under,over;
 reg [30:0] returns=0;reg [127:0] words[0:30];
 integer cycle=0,accepted=0,frames=0,expected_base=0,next_row,next_word,expected,j,k,checked=0;
 wire ready=rst&&!stall&&(cycle%7!=0)&&(cycle%11!=0);
 video_out dut(.I_rst_n(rst),.I_ddr_clk(ddr),.O_video_out_rd_busy(busy),.I_video_in_wr_busy(1'b0),
 .I_video_out_rp(rp),.I_front_valid(1'b1),.O_frame_release(release_frame),.O_underflow_frames(under),.O_overflow_frames(over),
 .I_slot_modes(12'd0),.O_frame_mode(),.O_ddr_user_rd_en(req),.O_ddr_user_addr(addr),.I_ddr_user_ready(ready),
 .I_ddr_user_rd_valid(returns[30]),.I_ddr_user_rd_data(words[30]),.I_dsi_clk(dsi),.I_video_vsync(vs),.I_video_rd_en(rd),.O_vdieo_data(pixel));
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
 rp=2;frame(1);if(under!=1||over!=0)$fatal(1,"Underflow count/overflow %d %d",under,over);
 rp=3;frame(0);if(accepted!=115200||under!=1||over!=0)$fatal(1,"Next-frame recovery");
 $display("PASS full 1024x600 crop/pixel byte order with async DDR/DSI, delayed returns/stalls, 614400 exact pixels, credit-based FIFO protection, one underflow event and next-frame recovery");$finish;end
 initial begin #65000000;$fatal(1,"Crop watchdog");end
endmodule
