`timescale 1ns/1ps
module ui_control_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,online=1,report=0;reg [3:0] contacts=0;reg [9:0] x=0,y=0;reg [1:0] keys=3;
 wire [3:0] page;wire [1:0] mode;wire [6:0] index,gain;wire detect,tag;wire [2:0] image_mode;
 wb_ui_control #(.CLK_HZ(1000)) dut(.I_clk(clk),.I_rst_n(rst),.I_online(online),.I_report(report),.I_contacts(contacts),.I_x(x),.I_y(y),.I_applied_gain(7'd80),.I_buttons_n(keys),
 .O_page(page),.O_mode(mode),.O_index(index),.O_gain(gain),
 .O_detect_enable(detect),.O_tag_enable(tag),.O_image_mode(image_mode));
 task point(input integer c,px,py);
  begin @(negedge clk);contacts=c;x=px;y=py;report=1;@(negedge clk);report=0;repeat(2)@(negedge clk);end
 endtask
 task lift;begin point(0,0,0);repeat(40)@(negedge clk);end endtask
 task tap(input integer px,py);begin point(1,px,py);lift();end endtask
 task expect_page(input integer expected);begin if(page!=expected)$fatal(1,"UI page %0d expected %0d",page,expected);end endtask
 always @(posedge clk)if(rst)begin
  if(gain<16||gain>89||index>75)$fatal(1,"UI value bounds");
  if(mode>2)$fatal(1,"Invalid WB mode became reachable");
 end
 integer i;
 initial begin
  repeat(4)@(negedge clk);rst=1;lift();
  tap(100,200);expect_page(0);
  point(1,100,200);point(0,0,0);repeat(5)@(negedge clk);
  for(i=0;i<200;i=i+1)begin point(1,100,200);repeat(2)@(negedge clk);end
  expect_page(0);repeat(100)@(negedge clk);point(1,100,200);repeat(900)@(negedge clk);
  expect_page(0);lift(); // stale reports during a returning contact also cannot rearm


  point(1,100,200);repeat(810)@(negedge clk);expect_page(0);
  repeat(1000)@(negedge clk);expect_page(0);lift(); // stationary long press is inactive
  point(1,900,200);repeat(40)@(negedge clk);point(1,790,200);expect_page(0);lift();expect_page(9);
  lift();tap(700,140);expect_page(10);tap(700,220);expect_page(11);tap(700,140);tap(620,50);tap(700,140);expect_page(1);tap(700,300);expect_page(4);if(mode!=2||index!=30)$fatal(1,"Custom entry");
  point(1,600,290);if(index!=0)$fatal(1,"Slider lower endpoint");
  point(1,900,290);if(index!=60)$fatal(1,"Slider tracking");
  point(1,1023,550);if(index!=75)$fatal(1,"Captured slider upper clamp");
  lift();tap(620,50);expect_page(1);
  tap(700,112);expect_page(2);tap(620,50);
  tap(700,175);expect_page(2);tap(620,50);
  // Environment row opens a selector without altering the applied mode/index.
  tap(700,192);expect_page(3);if(mode!=0||index!=75)$fatal(1,"Preset entry changed applied configuration");tap(620,50);
  tap(700,255);expect_page(3);tap(620,50);
  tap(584,220);expect_page(3);tap(620,50);
  tap(999,220);expect_page(3);tap(620,50);
  tap(700,272);expect_page(4);if(mode!=2||index!=75)$fatal(1,"Manual lower edge");tap(620,50);
  tap(999,335);expect_page(4);tap(620,50);
  tap(583,220);tap(1000,220);tap(700,176);tap(700,191);tap(700,256);tap(700,336);expect_page(1);
  tap(700,140);expect_page(2);if(mode!=0||index!=75)$fatal(1,"AWB changed saved manual K");
  tap(620,50);tap(700,300);expect_page(4);if(mode!=2||index!=75)$fatal(1,"Manual value not remembered");
  // Every 100 K step must survive all four presets and AWB/manual round trips.
  for(i=0;i<76;i=i+1)begin
   tap(600+i*5,290);if(index!=i)$fatal(1,"Manual 2500..10000 K step %0d",i);
   tap(620,50);tap(700,220);expect_page(3);
   tap(700,140);if(mode!=1||index!=5)$fatal(1,"Warm preset step%0d",i);
   tap(700,220);if(mode!=1||index!=30)$fatal(1,"Daylight preset step%0d",i);
   tap(700,300);if(mode!=1||index!=40)$fatal(1,"Cloudy preset step%0d",i);
   tap(700,380);if(mode!=1||index!=50)$fatal(1,"Shadow preset step%0d",i);
   tap(620,50);tap(700,300);expect_page(4);if(mode!=2||index!=i)$fatal(1,"Presets destroyed saved manual K step%0d",i);
   tap(620,50);tap(700,140);expect_page(2);if(mode!=0||index!=i)$fatal(1,"AWB lost manual K step %0d",i);
   tap(620,50);tap(700,300);expect_page(4);if(mode!=2||index!=i)$fatal(1,"Manual restore K step %0d",i);
  end
  tap(620,50);tap(620,50);expect_page(10);tap(700,220);expect_page(11);tap(700,460);expect_page(5);
  tap(620,140);if(gain!=16)$fatal(1,"1x shortcut");
  tap(780,140);if(gain!=48)$fatal(1,"2x shortcut");
  tap(920,140);if(gain!=80)$fatal(1,"4x shortcut");
  tap(900,340);if(gain!=81)$fatal(1,"Touch gain plus");
  tap(650,340);if(gain!=80)$fatal(1,"Touch gain minus");
  point(1,900,340);repeat(2000)@(negedge clk);lift();if(gain!=89)$fatal(1,"Touch gain repeat upper limit");
  tap(800,460);if(gain!=80)$fatal(1,"Touch gain default");
  keys=2'b10;repeat(30)@(negedge clk);keys=3;repeat(30)@(negedge clk);if(gain!=79)$fatal(1,"Physical down synchronization");
  keys=2'b01;repeat(30)@(negedge clk);keys=3;repeat(30)@(negedge clk);if(gain!=80)$fatal(1,"Physical up synchronization");
  keys=2'b10;repeat(20000)@(negedge clk);keys=3;repeat(30)@(negedge clk);if(gain!=16)$fatal(1,"Physical lower clamp");
  tap(620,50);expect_page(11);tap(620,50);expect_page(10);tap(620,50);expect_page(9);tap(620,50);expect_page(0);
  point(2,100,200);point(1,100,200);repeat(900)@(negedge clk);expect_page(0);lift();
  point(1,100,200);point(1,200,250);repeat(900)@(negedge clk);expect_page(0);lift();
  point(1,100,200);repeat(200)@(negedge clk);online=0;repeat(900)@(negedge clk);online=1;expect_page(0);lift();
  point(1,900,200);repeat(40)@(negedge clk);point(1,790,200);expect_page(0);lift();expect_page(9);
  tap(700,220);expect_page(7);tap(900,140);if(image_mode!=5)$fatal(1,"Edge filter");
  tap(680,220);if(image_mode!=4)$fatal(1,"Pixel filter");tap(900,220);if(image_mode!=6)$fatal(1,"Retro filter");
  tap(680,300);if(image_mode!=7)$fatal(1,"Enhancement filter");tap(900,300);if(image_mode!=1)$fatal(1,"Gray filter");
  tap(680,380);if(image_mode!=2)$fatal(1,"Cartoon filter");
  tap(900,380);if(image_mode!=3)$fatal(1,"Negative filter");
  tap(792,380);if(image_mode!=3)$fatal(1,"Column gap must not select a filter");
  tap(900,416);if(image_mode!=3)$fatal(1,"Exclusive bottom boundary");
  tap(620,50);expect_page(9);tap(700,300);expect_page(8);tap(700,140);if(!tag)$fatal(1,"Tag toggle");
  tap(700,220);if(!detect)$fatal(1,"Tracking toggle");
  tap(620,50);tap(700,220);if(image_mode!=3)$fatal(1,"Filter memory lost after navigation");
  $display("PASS UI three-mode WB and four environment presets; all 76 manual K steps retained across every preset and AWB; exact WB hitboxes, left-swipe release opening, inactive long press, all eight display choices, shared gain and fault cancellation");$finish;
 end
 initial begin #1000000;$fatal(1,"UI watchdog");end
endmodule

module wb_720p_tb;
 localparam N=1280*720*3;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,u=0,l=0;reg [95:0] rgb=0;reg [6:0] index=5;
 wire [95:0] data;wire ov,ou,ol,ready,pv,pu;wire [127:0] packed_data;
 wb_balance_96 dut(.I_clk(clk),.I_rst_n(rst),.I_mode(2'd2),.I_kelvin_index(index),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),.I_ready(1'b1),.I_previous_bad(1'b0),
 .O_data(data),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(ready),.O_gain_r(),.O_gain_b());
 data_96bit_to_128bit packer(.I_clk(clk),.I_rst_n(rst),.I_96b_frame_start(ou),.I_96b_valid(ov),.I_96b_data(data),.O_128b_frame_start(pu),.O_128b_valid(pv),.O_128b_data(packed_data));
 integer put=0,take=0,words=0,frames=0,p,j,r,b;
 reg [7:0] expected[0:N-1];
 reg ddr=0;always #3.7 ddr=~ddr;
 wire wr;wire [24:0] address;wire [127:0] write_data;wire [31:0] good,dropped,overflow;
 integer write_bytes=0,write_count=0,ddr_cycle=0,z;
 reg [15:0] pending_writes=0;
 video_in store(.I_rst_n(rst),.I_camera_clk(clk),.I_camera_frame_start(pu),.I_camera_mode(3'd0),.O_slot_modes(),
 .I_camera_valid(pv),.I_camera_data(packed_data),.I_mipi_rx_error(1'b0),.I_ddr_clk(ddr),.I_display_pause(1'b0),
 .I_video_out_rd_busy(1'b0),.I_display_frame_release(1'b0),.I_ddr_writes_idle(pending_writes==0&&!wr),
 .O_video_in_wr_busy(),.O_video_out_rp(),.O_front_valid(),.O_ddr_user_wr_en(wr),.O_ddr_user_addr(address),
 .O_ddr_user_wr_data(write_data),.I_ddr_user_ready(ddr_cycle%13!=0),
 .O_dropped_frames(dropped),.O_good_frames(good),.O_fifo_overflows(overflow));
 always @(posedge ddr)begin
  ddr_cycle=ddr_cycle+1;
  if(!rst)pending_writes<=0;else pending_writes<={pending_writes[14:0],wr};
  if(wr)begin
   if(address!==write_count*8)$fatal(1,"720P DDR write address %d %d",address,write_count*8);
   for(z=0;z<16;z=z+1)begin
    if(write_bytes>=put||write_data[127-z*8-:8]!==expected[write_bytes])$fatal(1,"720P DDR byte %d",write_bytes);
    write_bytes=write_bytes+1;
   end
   write_count=write_count+1;
  end
 end
 reg pv0=0,pu0=0,pl0=0;
 always @(posedge clk)if(rst)begin
  if(v)for(p=3;p>=0;p=p-1)begin
   r=(rgb[p*24+16+:8]*717+512)/1024;b=(rgb[p*24+0+:8]*2048+512)/1024;
   expected[put]=(r>255)?255:r;put=put+1;expected[put]=rgb[p*24+8+:8];put=put+1;
   expected[put]=(b>255)?255:b;put=put+1;
  end
  #1;
  if({ov,ou,ol,ready}!=={pv0,pu0,pl0,1'b1})$fatal(1,"720p WB sidebands");
  pv0=v;pu0=u;pl0=l;
  if(pu)frames=frames+1;
  if(pv)begin
   for(j=0;j<16;j=j+1)begin
    if(take>=put||packed_data[127-j*8-:8]!==expected[take])$fatal(1,"WB 720p byte %0d",take);
    take=take+1;
   end
   words=words+1;
  end
 end
 integer yy,xx;
 initial begin
  repeat(4)@(negedge clk);rst=1;u=1;@(negedge clk);u=0;repeat(3)@(negedge clk);
  for(yy=0;yy<720;yy=yy+1)begin
   if(yy==300)index=75;
   for(xx=0;xx<320;xx=xx+1)begin v=1;l=xx==319;rgb={$random,$random,$random};@(negedge clk);end
   v=0;l=0;repeat(8)@(negedge clk);
  end
  repeat(8)@(negedge clk);
  if(put!=N||take!=N||words!=172800||frames!=1)$fatal(1,"WB 720p coverage");
  u=1;@(negedge clk);u=0;repeat(120)@(negedge clk);
  if(write_count!=172800||write_bytes!=N||good!=1||dropped!=0||overflow!=0)$fatal(1,"Full-frame commit %d %d %d %d %d",write_count,write_bytes,good,dropped,overflow);
  $display("PASS WB plus async frame store 1280x720 frame, 921600 pixels, 2764800 byte oracle, 172800 DDR words, no dropped beats, mid-frame K update deferred and exact controls");$finish;
 end
 initial begin #5000000;$fatal(1,"WB 720p watchdog");end
endmodule

module overlay_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,vs=0,hs=0,de=0;reg [51:0] cfg=0;
 localparam [23:0] VIDEO=24'h204060;
 wire ov,oh,od;wire [23:0] pixel;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_ae_telemetry({3'b110,7'd80}),
  .I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),.I_target_info(52'd0),
  .I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(VIDEO),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(pixel));
 reg [2:0] c1=0,c2=0;integer f,page,mode,index,x,y,px,py,n=0,checks=0,fd;
 reg [23:0] expected;
 function [23:0] half(input [23:0] a,b);
  reg [8:0] r,g,bl;
  begin r={1'b0,a[23:16]}+{1'b0,b[23:16]};g={1'b0,a[15:8]}+{1'b0,b[15:8]};bl={1'b0,a[7:0]}+{1'b0,b[7:0]};half={r[8:1],g[8:1],bl[8:1]};end
 endfunction
 task compare(input [23:0] value);
  begin if(pixel!==value)$fatal(1,"WB UI page%0d mode%0d xy%0d,%0d got%h expected%h",page,mode,px,py,pixel,value);checks=checks+1;end
 endtask
 always @(posedge clk)if(rst)begin
  #1;if({ov,oh,od}!==c2)$fatal(1,"WB UI three-stage controls");c2=c1;c1={vs,hs,de};
  if(od)begin
   px=n%1024;py=n/1024;
   if((^pixel)===1'bx)$fatal(1,"Unknown WB UI pixel");
   if(px==100&&py==100)compare(VIDEO);
   if(px==580&&py==90)compare(half(24'h111e2c,VIDEO));
   if(px==400&&(py==30||py==580))compare(VIDEO>>2);
   if(page==1&&px==590)begin
    if(py==120)compare(half(mode==0?24'h087f83:24'h26394d,VIDEO));
    if(py==200)compare(half(mode==1?24'h087f83:24'h26394d,VIDEO));
    if(py==280)compare(half(mode==2?24'h087f83:24'h26394d,VIDEO));
    if(py==360||py==440)compare(half(24'h111e2c,VIDEO));
   end
   $fwrite(fd,"%c%c%c",pixel[23:16],pixel[15:8],pixel[7:0]);n=n+1;
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<4;f=f+1)begin
   page=f<2?1:f==2?2:4;mode=(f==1||f==3)?2:0;index=f==3?75:30;
   cfg={7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b0,1'b0,
        4'(page),2'(mode),2'd0,7'(index),7'd80,3'd0,1'b1};
   n=0;fd=$fopen($sformatf("wb_ui_page_%0d_mode_%0d.ppm",page,mode),"wb");
   if(!fd)$fatal(1,"WB UI preview open");$fwrite(fd,"P6\n1024 600\n255\n");
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin
     vs=x==0&&y==0;de=1;hs=0;@(negedge clk);
     if(x==500&&y==300)begin cfg[25:22]=9;cfg[21:20]=0;end
    end
    vs=0;de=0;hs=1;repeat(4)@(negedge clk);hs=0;
   end
   repeat(6)@(negedge clk);$fclose(fd);if(n!=614400)$fatal(1,"WB UI frame pixel count");
  end
  if(checks!=26)$fatal(1,"WB UI independent pixel probes %0d",checks);
  $display("PASS four complete WB UI frames: AWB/manual selected states across three WB choices, manual10000K, 26 independent alpha/bar/preview probes, fixed control latency and frame-atomic mode/page");$finish;
 end
 initial begin #50000000;$fatal(1,"WB UI overlay watchdog");end
endmodule
