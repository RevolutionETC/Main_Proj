`timescale 1ns/1ps
module filter_transport_tb;
 localparam W=64,H=24,F=4,BEATS=W*H/4,WORDS=W*H*3/16;
 reg src=0,run_src=1,clk=0,ddr=0,rst=0;
 always #6.667 if(run_src)src=~src;
 always #20.833 clk=~clk;
 always #5 ddr=~ddr;
 reg v=0,u=0,l=0;reg [95:0] rgb=0;reg [2:0] mode=0;
 wire [95:0] bdata,out;wire bv,bu,bl,ov,ou,ol,error;wire [2:0] bm,om;
 filter_clock_bridge bridge(.src_clk(src),.dst_clk(clk),.rst_n(rst),.rgb(rgb),.valid(v),.sof(u),.last(l),.previous_bad(1'b0),.mode(mode),
  .out_rgb(bdata),.out_valid(bv),.out_sof(bu),.out_last(bl),.out_mode(bm),.overflow(error));
 image_filter_bank_96 #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) bank(.I_clk(clk),.I_rst_n(rst),.I_mode(bm),
  .I_data(bdata),.I_valid(bv),.I_user(bu),.I_last(bl),.I_ready(1'b1),.O_data(out),
  .O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(),.O_frame_mode(om));
 wire pv,pu;wire [127:0] pd;
 data_96bit_to_128bit pack(.I_clk(clk),.I_rst_n(rst),.I_96b_frame_start(ou),.I_96b_valid(ov),.I_96b_data(out),
  .O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(pd));
 reg ready=1;wire wr;wire [127:0] wd;wire [24:0] address;wire [11:0] modes;
 wire [31:0] good,dropped,overflows;
 video_in #(.FRAME_WORDS(WORDS)) store(.I_rst_n(rst),.I_camera_clk(clk),.I_camera_frame_start(pu),.I_camera_mode(om),
  .O_slot_modes(modes),.I_camera_valid(pv),.I_camera_data(pd),.I_mipi_rx_error(error),.I_ddr_clk(ddr),.I_display_pause(1'b0),
  .I_video_out_rd_busy(1'b0),.I_display_frame_release(1'b0),.I_ddr_writes_idle(1'b1),.O_video_in_wr_busy(),
  .O_video_out_rp(),.O_front_valid(),.O_ddr_user_wr_en(wr),.O_ddr_user_addr(address),.O_ddr_user_wr_data(wd),
  .I_ddr_user_ready(ready),.O_dropped_frames(dropped),.O_good_frames(good),.O_fifo_overflows(overflows));
 reg [95:0] source[0:F*BEATS-1],expected[0:F*BEATS-1];
 reg [127:0] packed_expected[0:F*WORDS-1];
 integer put=0,take=0,written=0,committed=0,slot[0:F-1];integer f,y,x;
 function integer select_mode(input integer n);
  begin case(n)0:select_mode=6;1:select_mode=7;2:select_mode=0;default:select_mode=5;endcase end
 endfunction
 always @(posedge clk)if(rst)begin
  #1;
  if(error)$fatal(1,"RGB clock bridge overflow");
  if(ov)begin
   if(take>=F*BEATS||out!==expected[take])$fatal(1,"Transport pixel %0d",take);
   if(om!==select_mode(take/BEATS))$fatal(1,"Transport mode %0d",take);
   take=take+1;
  end
 end
 always @(posedge ddr)if(rst)begin
  if(wr)begin
   if(written>=F*WORDS||wd!==packed_expected[written])$fatal(1,"DDR word %0d expected=%h got=%h",written,packed_expected[written],wd);
   if(written%WORDS==0)slot[written/WORDS]=address/7000000;
   if(address!==slot[written/WORDS]*7000000+(written%WORDS)*8)$fatal(1,"DDR address ordering");
   written=written+1;
  end
  #1;
  if(good!=committed)begin
   if(modes[slot[committed]*3+:3]!==select_mode(committed))$fatal(1,"DDR mode must travel with SOF despite stalls");
   committed=good;
  end
 end
 initial begin
  $readmemh("transport_input.hex",source);$readmemh("transport_expected.hex",expected);
  $readmemh("transport_packed.hex",packed_expected);
  repeat(8)@(negedge src);rst=1;
  for(f=0;f<F;f=f+1)begin
   mode=select_mode(f);u=1;@(negedge src);u=0;
   for(y=0;y<H;y=y+1)begin
    for(x=0;x<W/4;x=x+1)begin
     v=1;l=x==W/4-1;rgb=source[put];put=put+1;
     // Twenty-four MHz destination is slower than the active source burst.
     if(y==H-1&&x==W/4-1)begin
      @(posedge src);#1;run_src=0;v=0;l=0;
     end else @(negedge src);
     mode=(select_mode(f)+2)%8;
    end
    if(y!=H-1)begin v=0;l=0;repeat(40)@(negedge src);end
   end
   // No further source edges while the FIFO and both spatial rows drain.
   repeat(400)@(negedge clk);
   if(take!=(f+1)*BEATS)$fatal(1,"Stopped source stranded tail frame=%0d take=%0d",f,take);
   run_src=1;@(negedge src);
  end
  mode=0;u=1;@(negedge src);u=0;
  repeat(600)@(negedge clk);
  if(good!=F||dropped||overflows||written!=F*WORDS||take!=F*BEATS)$fatal(1,"Transport coverage good=%0d dropped=%0d overflow=%0d written=%0d",good,dropped,overflows,written);
  $display("PASS shared RGB FIFO + stopped CSI clock + eight-filter selector + packing + DDR store: 6144 pixels, 1152 words, four mode-tagged frames and zero drops");$finish;
 end
 // Exercise DDR backpressure without exceeding the frame-store FIFO capacity.
 initial begin wait(rst);wait(written==20);ready=0;repeat(800)@(negedge ddr);ready=1;end
 initial begin #10000000;$fatal(1,"Transport watchdog");end
endmodule
