`timescale 1ns/1ps
module effects_ui_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,report=0;
 reg [3:0] contacts=0;reg [9:0] x=0,y=0;wire [3:0] page;wire [2:0] image_mode;
 wb_ui_control #(.CLK_HZ(1000)) dut(.I_clk(clk),.I_rst_n(rst),.I_online(1'b1),.I_report(report),
  .I_contacts(contacts),.I_x(x),.I_y(y),.I_buttons_n(2'b11),.I_applied_gain(7'd80),
  .O_page(page),.O_image_mode(image_mode));
 reg dst=0;always #7 dst=~dst;
 wire [51:0] payload={26'd0,page,18'd0,image_mode,1'b1};wire [51:0] received;
 config_mailbox #(.WIDTH(52),.RESET_VALUE(52'd0)) mailbox(.I_src_clk(clk),.I_dst_clk(dst),.I_rst_n(rst),.I_data(payload),.O_data(received));
 task coherent;begin repeat(60)@(negedge clk);if(received!==payload)$fatal(1,"52-bit UI payload lost or torn");end endtask
 task point(input integer c,xx,yy);begin @(negedge clk);contacts=c;x=xx;y=yy;report=1;@(negedge clk);report=0;repeat(2)@(negedge clk);end endtask
 task lift;begin point(0,0,0);repeat(40)@(negedge clk);end endtask
 task tap(input integer xx,yy);begin point(1,xx,yy);lift();end endtask
 initial begin repeat(3)@(negedge clk);rst=1;lift();
  point(1,900,200);repeat(40)@(negedge clk);point(1,790,200);lift();if(page!=9)$fatal(1,"Settings entry");
  tap(700,220);if(page!=7)$fatal(1,"Filter page");
  tap(900,140);coherent();if(image_mode!=5)$fatal(1,"Edge");
  tap(680,300);coherent();if(image_mode!=7)$fatal(1,"Enhancement");
  tap(680,140);coherent();if(image_mode!=0)$fatal(1,"Original");
  tap(680,220);coherent();if(image_mode!=4)$fatal(1,"Pixel");
  tap(900,220);coherent();if(image_mode!=6)$fatal(1,"Retro");
  tap(900,300);coherent();if(image_mode!=1)$fatal(1,"Gray");
  tap(680,380);coherent();if(image_mode!=2)$fatal(1,"Cartoon");
  tap(900,380);coherent();if(image_mode!=3)$fatal(1,"Negative");
  tap(620,50);tap(700,140);tap(700,140);if(page!=1)$fatal(1,"WB menu after filters");
  tap(700,300);if(page!=4)$fatal(1,"Manual WB third row");
  tap(620,50);tap(700,140);if(page!=2)$fatal(1,"AWB first row");
  $display("PASS all eight display choices, coherent 52-bit mailbox and three-choice WB navigation");$finish;
 end
 initial begin #1000000;$fatal(1,"Effects UI watchdog");end
endmodule
