`timescale 1ns/1ps
module restored_ui_mailbox_tb;
 reg clk=0,dc=0;always #5 clk=~clk;always #7 dc=~dc;
 reg rst=0,report=0;reg [3:0] contacts=0;reg [9:0] x=0,y=0;
 wire [3:0] page;wire [1:0] mode,meter;wire [6:0] index,gain,strength;wire [2:0] filter;
 wire hist_en,hist_auto,show,ae,key_axis,detect,tag,bars;wire signed [4:0] ab,gm;
 wb_ui_control #(.CLK_HZ(1000)) dut(.I_clk(clk),.I_rst_n(rst),.I_online(1'b1),.I_report(report),.I_contacts(contacts),.I_x(x),.I_y(y),.I_buttons_n(2'b11),.I_applied_gain(7'd80),
 .O_page(page),.O_mode(mode),.O_index(index),.O_gain(gain),.O_image_mode(filter),.O_bars_hide(bars),.O_detect_enable(detect),.O_tag_enable(tag),
 .O_hist_enable(hist_en),.O_hist_auto(hist_auto),.O_hist_strength(strength),.O_show_meter(show),.O_ae_enable(ae),.O_meter_mode(meter),.O_key_axis(key_axis),.O_ab(ab),.O_gm(gm));
 wire [51:0] source={strength,hist_auto,hist_en,show,meter,ae,key_axis,ab,gm,detect,tag,page,mode,1'b0,bars,index,gain,filter,1'b1};
 wire [51:0] received;
 config_mailbox #(.WIDTH(52),.RESET_VALUE(52'd0)) box(.I_src_clk(clk),.I_dst_clk(dc),.I_rst_n(rst),.I_data(source),.O_data(received));
 task point(input integer c,px,py);begin @(negedge clk);contacts=c;x=px;y=py;report=1;@(negedge clk);report=0;repeat(2)@(negedge clk);end endtask
 task lift;begin point(0,0,0);repeat(40)@(negedge clk);end endtask
 task tap(input integer px,py);begin point(1,px,py);lift();end endtask
 integer checks=0;
 task check(input integer p,m,ki,b);begin
  repeat(60)@(negedge clk);
  if({page,mode,index,bars}!=={4'(p),2'(m),7'(ki),1'(b)})$fatal(1,"preset mailbox state p%0d m%0d k%0d b%0d",page,mode,index,bars);
  if(received!==source||received[21:20]!==2'(m)||received[19]!==0||received[18]!==1'(b)||received[17:11]!==7'(ki))$fatal(1,"preset payload overlaps mode/reserved/bar/index fields");
  checks=checks+1;
 end endtask
 integer i,wanted;
 initial begin
  repeat(5)@(negedge clk);rst=1;lift();check(0,0,30,0);
  point(1,900,200);point(1,790,200);lift();tap(700,300);tap(700,300);check(8,0,30,1);
  tap(620,50);tap(700,140);tap(700,140);tap(700,300);tap(685,290);check(4,2,17,1);
  tap(620,50);tap(700,220);check(3,2,17,1);
  // Invalid preset hitboxes must not change mode or index.
  tap(583,140);tap(1000,140);tap(700,176);tap(700,191);tap(700,256);tap(700,271);tap(700,336);tap(700,351);tap(700,416);check(3,2,17,1);
  for(i=0;i<4;i=i+1)begin
   wanted=i==0?5:i==1?30:i==2?40:50;
   point(1,584,112+i*80);check(3,1,wanted,1);
   point(1,700,112+((i+1)%4)*80);check(3,1,wanted,1); // held contact cannot select another row
   lift();tap(999,175+i*80);check(3,1,wanted,1);
  end
  tap(620,50);tap(700,140);check(2,0,50,1);tap(800,430);check(2,0,50,1);
  tap(620,50);tap(700,300);check(4,2,17,1);
  if(detect||tag||filter!=0||ab!=0||gm!=0||gain!=80)$fatal(1,"presets altered independent feature state");
  @(negedge clk);rst=0;repeat(5)@(negedge clk);rst=1;lift();check(0,0,30,0);
  point(1,900,200);point(1,790,200);lift();tap(700,140);tap(700,140);tap(700,220);tap(700,380);check(3,1,50,0);
  tap(620,50);tap(700,300);check(4,2,30,0);
  $display("PASS restored WB 52-bit mailbox: %0d coherent asynchronous observations, mode1 transmitted in full two-bit field, bit19 reserved and bit18 bars independent, four preset exact hitboxes and held-contact cancellation, manual K memory, AWB isolation and reset defaults",checks);$finish;
 end
 initial begin #500000;$fatal(1,"restored mailbox watchdog");end
endmodule
