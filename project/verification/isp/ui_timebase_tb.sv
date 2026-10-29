`timescale 1ns/1ps
module ui_timebase_tb;
 reg clk=0;always #20 clk=~clk;
 reg rst=0,report=0;reg [3:0] contacts=0;reg [9:0] x=0;wire [3:0] page;
 wb_ui_control #(.LONG_MS(3),.SWIPE_MS(3),.RELEASE_MS(1)) dut(.I_clk(clk),.I_rst_n(rst),.I_online(1'b1),
  .I_report(report),.I_contacts(contacts),.I_x(x),.I_y(10'd200),
  .I_buttons_n(2'b11),.I_applied_gain(7'd16),.O_page(page));
 task point(input integer c,px);
  begin @(negedge clk);contacts=c;x=px;report=1;@(negedge clk);report=0;end
 endtask
 initial begin
  repeat(5)@(negedge clk);rst=1;
  point(1,900);repeat(100001)@(negedge clk);
  if(page!==0)$fatal(1,"Stationary long press still opened menu");
  point(1,790);point(0,0);if(page!==0)$fatal(1,"25 MHz slow swipe was not rejected");
  repeat(30000)@(negedge clk);
  point(1,900);repeat(40000)@(negedge clk);point(1,790);
  if(page!==0)$fatal(1,"25 MHz swipe opened before release");
  point(0,0);if(page!==9)$fatal(1,"25 MHz 1.6-ms swipe did not open after release");
  $display("PASS ui_timebase_tb: actual 25 MHz clock rejects 4-ms swipe against 3-ms test limit, accepts 1.6-ms left swipe on release, and stationary long press stays inactive");$finish;
 end
 initial begin #20000000;$fatal(1,"Timebase watchdog");end
endmodule
