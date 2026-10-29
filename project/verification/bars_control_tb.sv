`timescale 1ns/1ps
module bars_control_tb;
 reg clk=0;always #5 clk=~clk;
 reg display_clk=0;always #7 display_clk=~display_clk;
 reg rst=0,online=1,report=0;reg [3:0] contacts=0;
 reg [9:0] x=0,y=0;wire [3:0] page;wire [1:0] mode,meter_mode;
 wire [6:0] index,gain,hist_strength;wire [2:0] image_mode;
 wire detect,tag,bars_hide,hist_enable,hist_auto,ae_enable,show_meter,key_axis;
 wire signed [4:0] ab,gm;
 wb_ui_control #(.CLK_HZ(1000)) dut(
  .I_clk(clk),.I_rst_n(rst),.I_online(online),.I_report(report),
  .I_contacts(contacts),.I_x(x),.I_y(y),.I_buttons_n(2'b11),.I_applied_gain(7'd80),
  .O_hist_enable(hist_enable),.O_hist_auto(hist_auto),.O_hist_strength(hist_strength),
  .O_ae_enable(ae_enable),.O_show_meter(show_meter),.O_meter_mode(meter_mode),
  .O_page(page),.O_mode(mode),.O_index(index),.O_gain(gain),
  .O_detect_enable(detect),.O_tag_enable(tag),.O_image_mode(image_mode),
  .O_ab(ab),.O_gm(gm),.O_key_axis(key_axis),.O_bars_hide(bars_hide));
 // Exactly the production 52-bit mailbox layout; the new setting reuses bit 18.
 wire [51:0] source_config={hist_strength,hist_auto,hist_enable,show_meter,meter_mode,
  ae_enable,key_axis,ab,gm,detect,tag,page,mode,1'b0,bars_hide,index,gain,image_mode,online};
 wire [51:0] display_config;
 config_mailbox #(.WIDTH(52),.RESET_VALUE({7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,
  5'd0,5'd0,1'b0,1'b0,4'd0,2'd0,2'd0,7'd30,7'd80,3'd0,1'b0})) mailbox(
  .I_src_clk(clk),.I_dst_clk(display_clk),.I_rst_n(rst),
  .I_data(source_config),.O_data(display_config));
 task point(input integer c,px,py);
  begin @(negedge clk);contacts=c;x=px;y=py;report=1;
   @(negedge clk);report=0;repeat(2)@(negedge clk);end
 endtask
 task lift;begin point(0,0,0);repeat(40)@(negedge clk);end endtask
 task tap(input integer px,py);begin point(1,px,py);lift();end endtask
 task expect_page(input integer wanted);
  begin if(page!==wanted)$fatal(1,"page %0d expected %0d",page,wanted);end
 endtask
 task settled;
  begin repeat(60)@(negedge clk);
   if(display_config!==source_config)$fatal(1,"52-bit display config did not transfer coherently");
   if(display_config[18]!==bars_hide||display_config[19]!==0||display_config[21:20]!==mode)
    $fatal(1,"bar setting changed WB mode/reserved bit layout");
  end
 endtask
 task open_menu;begin point(1,900,200);repeat(40)@(negedge clk);point(1,790,200);expect_page(0);lift();expect_page(9);end endtask
 integer i;
 initial begin
  repeat(4)@(negedge clk);rst=1;lift();
  if(bars_hide!==0||detect!==0||tag!==0)$fatal(1,"bars must be shown after reset");
  settled();open_menu();tap(700,300);expect_page(8);
  // Exclusive edges of the third feature row, before entering any active control.
  tap(583,300);tap(1000,300);tap(700,271);tap(700,336);tap(700,400);
  if(bars_hide||detect||tag)$fatal(1,"bar toggle hitbox extends beyond third row");
  point(1,584,272);if(!bars_hide)$fatal(1,"inclusive bar toggle corner missing");
  repeat(1600)@(negedge clk);
  for(i=0;i<8;i=i+1)point(1,700,300);
  point(1,700,140);
  if(!bars_hide||detect||tag)$fatal(1,"holding/dragging a bar press repeated or clicked through");
  lift();settled();tap(999,335);
  if(bars_hide||detect||tag)$fatal(1,"far inclusive bar toggle corner or independent feature state");
  settled();tap(700,300);if(!bars_hide)$fatal(1,"hide setting ON");
  tap(620,50);expect_page(9);tap(620,50);expect_page(0);settled();
  if(!bars_hide)$fatal(1,"closing the popup lost bar visibility setting");
  open_menu();tap(700,300);expect_page(8);
  if(!bars_hide)$fatal(1,"reopening features lost bar visibility setting");
  tap(700,140);tap(700,220);
  if(!tag||!detect||!bars_hide)$fatal(1,"other feature toggles changed bar visibility");
  tap(700,300);if(bars_hide||!detect||!tag)$fatal(1,"bar visibility changed tracking/watermark");
  settled();tap(620,50);tap(700,140);expect_page(10);tap(700,140);expect_page(1);
  tap(700,140);expect_page(2);
  // The removed AWB button must be inactive regardless of the saved detect state.
  tap(600,400);tap(800,430);tap(999,471);point(1,800,430);
  repeat(1600)@(negedge clk);lift();
  if(!detect||!tag||bars_hide||mode!==0||index!==30||page!==2)
   $fatal(1,"AWB former target control still has an action");
  settled();tap(620,50);tap(620,50);tap(620,50);tap(700,300);expect_page(8);
  // Bounce/recontact cannot re-arm the feature while release is unstable.
  point(1,700,300);if(!bars_hide)$fatal(1,"bar toggle before bounce");
  point(0,0,0);repeat(5)@(negedge clk);point(1,700,300);
  repeat(200)@(negedge clk);point(1,700,300);
  if(!bars_hide)$fatal(1,"short-release bounce repeated bar toggle");
  lift();tap(700,300);if(bars_hide)$fatal(1,"stable release did not re-arm bar toggle");
  point(2,700,300);point(1,700,300);repeat(900)@(negedge clk);
  if(bars_hide)$fatal(1,"multitouch must block bar toggle");
  lift();point(1,700,300);if(!bars_hide)$fatal(1,"bar toggle before offline cancellation");
  online=0;repeat(1000)@(negedge clk);online=1;point(1,700,300);
  if(!bars_hide)$fatal(1,"offline cancellation repeated bar toggle");
  lift();settled();
  @(negedge clk);rst=0;#1;
  if(bars_hide!==0)$fatal(1,"asynchronous reset must show bars");
  repeat(4)@(negedge clk);rst=1;lift();settled();
  if(page!==0||detect||tag||bars_hide)$fatal(1,"reset did not restore independent features");
  $display("PASS bar controls: function-library third-row exact hitbox, single held gesture, bounce/multitouch/offline cancellation, preview/reopen persistence, reset-visible default, independent tracking/watermark, AWB removed control inert, coherent unchanged-width 52-bit config using bit18 only");
  $finish;
 end
 initial begin #2000000;$fatal(1,"bar control watchdog");end
endmodule
