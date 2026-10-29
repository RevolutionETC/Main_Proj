`timescale 1ns/1ps
module swipe_control_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,online=1,report=0;reg [3:0] contacts=0;
 reg [9:0] x=0,y=0;wire [3:0] page;wire detect,tag,bars;
 wire [6:0] kelvin,gain;wire [2:0] image_mode;
 wb_ui_control #(.CLK_HZ(1000)) dut(
  .I_clk(clk),.I_rst_n(rst),.I_online(online),.I_report(report),.I_contacts(contacts),
  .I_x(x),.I_y(y),.I_buttons_n(2'b11),.I_applied_gain(7'd80),
  .O_page(page),.O_detect_enable(detect),.O_tag_enable(tag),.O_bars_hide(bars),
  .O_index(kelvin),.O_gain(gain),.O_image_mode(image_mode));
 integer cases=0,cycle=0;
 always @(posedge clk)cycle=cycle+1;
 task point(input integer c,px,py);
  begin @(negedge clk);contacts=c;x=px;y=py;report=1;@(negedge clk);report=0;end
 endtask
 task settle;begin repeat(40)@(negedge clk);end endtask
 task lift;begin point(0,1023,599);settle();end endtask
 task tap(input integer px,py);begin point(1,px,py);lift();end endtask
 task expect_page(input integer p);
  begin if(page!==p)$fatal(1,"case %0d page=%0d wanted=%0d",cases,page,p);end
 endtask
 task fresh;
  begin @(negedge clk);rst=0;report=0;contacts=0;online=1;
   repeat(3)@(negedge clk);rst=1;settle();expect_page(0);cases=cases+1;end
 endtask
 task swipe(input integer sx,sy,ex,ey);
  begin point(1,sx,sy);repeat(25)@(negedge clk);point(1,ex,ey);expect_page(0);end
 endtask
 task timed_swipe(input integer duration,wanted);
  integer started;
  begin
   fresh();point(1,900,300);started=cycle;point(1,800,300);
   while(cycle-started<duration)@(negedge clk);
   // duration counts completed millisecond ticks before the release report.
   contacts=0;x=0;y=0;report=1;@(negedge clk);report=0;settle();expect_page(wanted);
  end
 endtask
 initial begin
  fresh();swipe(900,300,800,380);lift();expect_page(9);
  fresh();swipe(100,0,0,0);lift();expect_page(9);
  fresh();swipe(1023,599,923,519);lift();expect_page(9);
  fresh();swipe(900,300,801,300);lift();expect_page(0);
  fresh();swipe(100,300,300,300);lift();expect_page(0);
  fresh();swipe(900,300,900,100);lift();expect_page(0);
  fresh();swipe(900,300,900,500);lift();expect_page(0);
  fresh();swipe(900,300,800,381);lift();expect_page(0);
  fresh();swipe(900,300,800,219);lift();expect_page(0);
  fresh();swipe(900,300,800,381);point(1,780,300);lift();expect_page(0);
  fresh();swipe(900,300,800,300);point(1,850,300);lift();expect_page(0);
  fresh();point(1,900,300);repeat(2000)@(negedge clk);expect_page(0);lift();expect_page(0);
  fresh();swipe(900,300,800,300);repeat(1001)@(negedge clk);lift();expect_page(0);
  fresh();point(1,900,300);repeat(1001)@(negedge clk);point(1,800,300);lift();expect_page(0);
  fresh();swipe(900,300,800,300);point(0,0,0);settle();expect_page(9);
  fresh();point(1,900,300);point(0,0,300);settle();expect_page(0);
  fresh();swipe(900,300,800,300);point(2,700,300);point(1,600,300);lift();expect_page(0);
  fresh();swipe(900,300,800,300);online=0;repeat(10)@(negedge clk);
   online=1;point(1,700,300);lift();expect_page(0);
  fresh();tap(900,300);point(1,900,300);point(0,900,300);
   repeat(5)@(negedge clk);point(1,900,300);point(1,700,300);lift();expect_page(0);
   swipe(900,300,800,300);lift();expect_page(9);
  fresh();point(1,900,300);@(negedge clk);x=700;y=300;repeat(20)@(negedge clk);
   lift();expect_page(0);
  fresh();swipe(900,700,800,700);lift();expect_page(0);
  timed_swipe(999,9);timed_swipe(1000,9);timed_swipe(1001,0);

  fresh();swipe(900,380,650,380);lift();expect_page(9);
  if(detect||tag||bars||kelvin!==30||gain!==80||image_mode!==0)$fatal(1,"Swipe changed feature values");
  tap(583,380);tap(1000,380);tap(700,351);tap(700,416);expect_page(9);
  tap(584,352);expect_page(13);tap(800,380);expect_page(13);
  tap(620,50);expect_page(9);tap(999,415);expect_page(13);tap(620,50);expect_page(9);
  tap(700,300);expect_page(8);tap(700,380);expect_page(8);
  tap(700,140);tap(700,220);tap(700,300);
  if(!tag||!detect||!bars)$fatal(1,"Existing feature library controls changed");
  tap(620,50);expect_page(9);tap(700,380);expect_page(13);
  if(!tag||!detect||!bars)$fatal(1,"Information entry changed feature library values");
  tap(620,50);expect_page(9);
  point(1,620,50);expect_page(0);point(1,500,50);lift();expect_page(0);
  swipe(900,300,800,300);lift();expect_page(9);
  point(1,620,50);expect_page(0);point(0,0,0);
  repeat(5)@(negedge clk);point(1,900,300);point(1,700,300);lift();expect_page(0);
  fresh();
  if(detect||tag||bars)$fatal(1,"Reset feature defaults changed");
  $display("PASS left-swipe controller: %0d reset-isolated gestures, dx100/dy80 bounds, arbitrary start, release-coordinate independence, latest-point/vertical excursion/timeout cancellation, inactive long press, multitouch/offline/bounce protection, no click-through, exact fourth main-menu information button and page13 back, preserved feature controls",cases);
  $finish;
 end
 initial begin #2000000;$fatal(1,"swipe controller watchdog");end
endmodule
