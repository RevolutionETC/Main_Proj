`timescale 1ns/1ps
module isp_ui_tb;
 reg clk=0,dst=0;always #5 clk=~clk;always #7 dst=~dst;
 reg rst=0,report=0;reg [3:0] contacts=0;reg [9:0] x=0,y=0;
 reg [1:0] keys=3;reg [6:0] applied=80;
 wire [3:0] page;wire ae,show;wire [1:0] meter;wire [6:0] gain;wire [1:0] wb;
 wb_ui_control #(.CLK_HZ(1000)) dut(.I_clk(clk),.I_rst_n(rst),.I_online(1'b1),.I_report(report),
 .I_contacts(contacts),.I_x(x),.I_y(y),.I_buttons_n(keys),.I_applied_gain(applied),
 .O_page(page),.O_ae_enable(ae),.O_meter_mode(meter),.O_show_meter(show),.O_gain(gain),.O_mode(wb));
 wire [9:0] command;
 config_mailbox #(.WIDTH(10),.RESET_VALUE({2'd1,1'b1,7'd80})) box(.I_src_clk(clk),.I_dst_clk(dst),.I_rst_n(rst),
 .I_data({meter,ae,gain}),.O_data(command));
 reg first_manual=1;
 always @(posedge dst)if(rst&&first_manual&&!command[7])begin
  if(command[6:0]!=62)$fatal(1,"AUTO-off mailbox did not atomically capture live gain");first_manual=0;
 end
 task point(input integer n,px,py);begin @(negedge clk);contacts=n;x=px;y=py;report=1;@(negedge clk);report=0;end endtask
 task tap(input integer px,py);begin point(1,px,py);point(0,0,0);repeat(40)@(negedge clk);end endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;repeat(40)@(negedge clk);
  if(!ae||meter!=1||show||gain!=80)$fatal(1,"AE/CW defaults");
  point(1,900,200);repeat(40)@(negedge clk);point(1,790,200);point(0,0,0);repeat(40)@(negedge clk);
  tap(700,140);if(page!=10)$fatal(1,"ISP entry");
  tap(700,300);if(page!=12)$fatal(1,"Histogram ISP entry");tap(620,50);if(page!=10)$fatal(1,"Histogram back to ISP");
  tap(700,220);if(page!=11)$fatal(1,"AE entry");
  tap(700,460);if(page!=11)$fatal(1,"Manual access while automatic");
  keys=2'b01;repeat(30)@(negedge clk);keys=3;repeat(40)@(negedge clk);
  if(gain!=80)$fatal(1,"Manual key changed gain during automatic mode");
  tap(700,220);if(meter!=2)$fatal(1,"Evaluative selection");
  tap(900,220);if(meter!=3)$fatal(1,"Partial selection");
  tap(900,300);if(meter!=0)$fatal(1,"Spot selection");
  tap(700,300);if(meter!=1)$fatal(1,"Centre-weighted selection");
  tap(790,220);if(meter!=1)$fatal(1,"Mode column gap");
  tap(700,380);if(!show)$fatal(1,"Show metering on");
  tap(700,380);if(show)$fatal(1,"Show metering off");
  applied=62;tap(700,140);if(ae||gain!=62)$fatal(1,"AUTO-off handoff");
  tap(700,460);if(page!=5)$fatal(1,"Nested manual gain entry");
  tap(920,140);if(gain!=80)$fatal(1,"Manual preset");
  keys=2'b01;repeat(30)@(negedge clk);keys=3;repeat(40)@(negedge clk);if(gain!=81)$fatal(1,"Manual key");
  tap(620,50);if(page!=11)$fatal(1,"Manual back to AE");
  tap(900,300);if(meter!=0)$fatal(1,"Remember mode while off");
  tap(700,380);if(!show||ae)$fatal(1,"Overlay switch independent of automatic gain");
  tap(700,140);if(!ae||gain!=81)$fatal(1,"Resume auto keeps saved manual value");
  tap(620,50);tap(700,140);tap(700,140);if(page!=2||wb!=0||!ae)$fatal(1,"AWB independent of AE");
  tap(620,50);tap(620,50);tap(700,220);if(page!=11||meter!=0||!show)$fatal(1,"Mode memory after WB");
  tap(620,50);tap(620,50);tap(620,50);if(page!=0)$fatal(1,"Nested return");
  if(first_manual)$fatal(1,"No manual mailbox handoff observed");
  $display("PASS ISP/WB/AE hierarchy, four metering modes and independent overlay switch, manual-only controls, independent WB, atomic live-gain handoff and nested return");$finish;
 end
endmodule

module ui_decimal_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,vs=0,de=0;
 reg [42:0] cfg=0;reg [36:0] tel=0;reg [9:0] agc=80;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(
 .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_telemetry(tel),.I_ae_telemetry(agc),
 .I_vsync(vs),.I_hsync(1'b0),.I_de(de),.I_data(24'd0),.O_vsync(),.O_hsync(),.O_de(),.O_data());
 function [15:0] bcd(input integer n);
  begin bcd={4'((n/1000)%10),4'((n/100)%10),4'((n/10)%10),4'(n%10)};end
 endfunction
 integer k,a,r,g,b,actual,shown,expected_gain;reg [15:0] locked;
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(a=0;a<2;a=a+1)for(k=16;k<=89;k=k+1)begin
   actual=105-k;r=(k*17)%4096;g=(k*31)%4096;b=(k*97)%4096;
   cfg={1'b0,2'(k%4),a[0],1'b0,5'd0,5'd0,1'b0,1'b0,4'd11,2'd0,2'd0,7'd30,k[6:0],3'd0,1'b1};
   tel={1'b1,r[11:0],g[11:0],b[11:0]};agc={3'b110,actual[6:0]};vs=1;de=1;
   @(negedge clk);vs=0;repeat(80)@(negedge clk);
   shown=a?actual:k;
   expected_gain=shown<48?((shown+16)*25+4)/8:shown<80?((shown-16)*25+2)/4:((shown-48)*25+1)/2;
   if(dut.dec_gain!==bcd(expected_gain)||dut.dec_r!==bcd((r*100+512)/1024)||
      dut.dec_g!==bcd((g*100+512)/1024)||dut.dec_b!==bcd((b*100+512)/1024))$fatal(1,"Shared live gain BCD formatting %0d",k);
   locked=dut.dec_gain;agc=0;repeat(8)@(negedge clk);
   if(dut.dec_gain!==locked)$fatal(1,"Gain telemetry tears mid-frame");
   de=0;repeat(3)@(negedge clk);
  end
  $display("PASS all 74 live/manual gain readouts, shared RGB BCD, mode bits and display-frame atomicity");$finish;
 end
endmodule

module tint_product_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,u=0,v=0;reg [95:0] d=0;reg signed [4:0] offset=0;
 wire [95:0] out;wire ov;
 wb_tint_96 dut(.I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_ab(offset),.I_gm(offset),
 .I_data(d),.I_valid(v),.I_user(u),.I_last(1'b0),.O_data(out),.O_valid(ov),.O_user(),.O_last());
 integer a,p,r,b;reg [95:0] expected;
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(a=-9;a<=9;a=a+1)for(p=0;p<256;p=p+1)begin
   offset=a;d={12{p[7:0]}};u=1;v=1;@(negedge clk);u=0;v=0;@(negedge clk);
   r=(p*(32+a)+16)/32;b=(p*(32-a)+16)/32;if(r>255)r=255;if(b>255)b=255;
   expected={4{{r[7:0],r[7:0],b[7:0]}}};
   if(!ov||out!==expected)$fatal(1,"Tint residual product %0d %0d got %h expected %h",a,p,out,expected);
   @(negedge clk);
  end
  $display("PASS exact residual tint pipeline: all 4864 pixel/offset combinations, all four lanes, rounding and clipping");$finish;
 end
endmodule
