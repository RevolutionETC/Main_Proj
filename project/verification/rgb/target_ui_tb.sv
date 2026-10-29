`timescale 1ns/1ps
module target_ui_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,report=0;reg [3:0] contacts=0;reg [9:0] x=0,y=0;
 wire [3:0] page;wire [1:0] mode;wire [6:0] index,gain;wire enabled;
 wb_ui_control #(.CLK_HZ(1000)) dut(.I_clk(clk),.I_rst_n(rst),.I_online(1'b1),.I_report(report),
  .I_contacts(contacts),.I_x(x),.I_y(y),.I_applied_gain(7'd80),.I_buttons_n(2'b11),.O_page(page),.O_mode(mode),.O_index(index),.O_gain(gain),.O_detect_enable(enabled));
 reg display_clk=0;always #7 display_clk=~display_clk;
 wire [23:0] cfg;
 config_mailbox #(.WIDTH(24),.RESET_VALUE(24'd7840)) mailbox23(
  .I_src_clk(clk),.I_dst_clk(display_clk),.I_rst_n(rst),
  .I_data({enabled,page,mode,2'd0,index,gain,1'b1}),.O_data(cfg));
 task point(input integer c,px,py);
  begin @(negedge clk);contacts=c;x=px;y=py;report=1;@(negedge clk);report=0;repeat(2)@(negedge clk);end
 endtask
 task lift;begin point(0,0,0);repeat(40)@(negedge clk);end endtask
 task tap(input integer px,py);begin point(1,px,py);lift();end endtask
 task settled;
  begin repeat(60)@(negedge clk);if(cfg!=={enabled,page,mode,2'd0,index,gain,1'b1})$fatal(1,"24-bit UI config mailbox");end
 endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;lift();if(enabled)$fatal(1,"Default must be OFF");
  point(1,900,200);repeat(40)@(negedge clk);point(1,790,200);lift();tap(700,140);tap(700,140);tap(700,140);
  if(page!=2||mode!=0)$fatal(1,"Auto page");
  point(1,800,430);repeat(1600)@(negedge clk);if(enabled)$fatal(1,"Removed AWB target button still active");lift();settled();
  tap(590,430);tap(600,400);tap(999,471);if(enabled||page!=2)$fatal(1,"AWB has target hitbox");
  tap(620,50);tap(620,50);tap(620,50);if(page!=9)$fatal(1,"Return to root");
  tap(700,300);if(page!=8)$fatal(1,"Function library");
  point(1,700,220);repeat(1600)@(negedge clk);if(!enabled)$fatal(1,"Held function toggle repeated");lift();settled();
  tap(583,220);tap(1000,220);tap(700,191);tap(700,256);if(!enabled)$fatal(1,"Function target hitbox boundary");
  tap(620,50);tap(620,50);if(page!=0||!enabled)$fatal(1,"Preview persistence");
  point(1,900,200);repeat(40)@(negedge clk);point(1,790,200);lift();tap(700,140);tap(700,140);tap(700,300);
  if(page!=4||mode!=2||!enabled)$fatal(1,"Manual keeps independent recognition switch");settled();
  if(cfg[16:15]!=0||cfg[18:17]!=2)$fatal(1,"Reserved WB config slot must stay zero");
  tap(620,50);tap(700,220);if(page!=3||mode!=2)$fatal(1,"Preset selector entry keeps active configuration");
  tap(700,140);if(mode!=1||index!=5||!enabled)$fatal(1,"Preset keeps recognition independent");tap(620,50);
  tap(700,140);if(mode!=0||page!=2||!enabled)$fatal(1,"Return to auto");
  tap(800,430);if(!enabled)$fatal(1,"AWB must not disable independent target switch");settled();
  tap(620,50);tap(620,50);tap(620,50);tap(700,300);tap(700,220);if(enabled||page!=8)$fatal(1,"Function target OFF");settled();
  $display("PASS recognition switch only in function library: AWB former button inactive for OFF and ON, exact hitbox, one toggle per hold, preview/manual persistence, coherent 24-bit asynchronous mailbox");$finish;
 end
 initial begin #1000000;$fatal(1,"Target UI watchdog");end
endmodule
