`timescale 1ns/1ps
module histogram_ui_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,report=0;reg [3:0] contacts=0;reg [9:0] x=0,y=0;
 wire en,auto_mode,ae;wire [6:0] strength;wire [3:0] page;wire [2:0] filter;wire [1:0] wb_mode;wire [6:0] kelvin;
 wb_ui_control #(.CLK_HZ(1000)) dut(.I_clk(clk),.I_rst_n(rst),.I_online(1'b1),.I_report(report),
  .I_contacts(contacts),.I_x(x),.I_y(y),.I_buttons_n(2'b11),.I_applied_gain(7'd80),
  .O_mode(wb_mode),.O_index(kelvin),.O_hist_enable(en),.O_hist_auto(auto_mode),.O_hist_strength(strength),.O_page(page),.O_image_mode(filter),.O_ae_enable(ae));
 task point(input integer c,px,py);begin @(negedge clk);contacts=c;x=px;y=py;report=1;@(negedge clk);report=0;end endtask
 task lift;begin point(0,0,0);repeat(40)@(negedge clk);end endtask
 task tap(input integer px,py);begin point(1,px,py);lift();end endtask
 integer n;
 initial begin
  repeat(5)@(negedge clk);rst=1;lift();
  if(en||!auto_mode||strength!=50||!ae||wb_mode!=0||kelvin!=30)$fatal(1,"HE defaults or AE independence");
  point(1,900,200);repeat(40)@(negedge clk);point(1,790,200);lift();tap(700,140);tap(700,140);tap(700,300);
  if(page!=4||wb_mode!=2)$fatal(1,"Manual WB before histogram");
  tap(685,290);if(kelvin!=17)$fatal(1,"Set manual K for histogram independence");
  tap(620,50);tap(620,50);tap(700,300);
  if(page!=12)$fatal(1,"Histogram under ISP");
  tap(700,140);if(!en||!auto_mode)$fatal(1,"HE enable");
  tap(592,328);if(strength!=50)$fatal(1,"Automatic mode permits dragging");
  tap(900,220);if(auto_mode)$fatal(1,"Manual selection");
  point(1,592,328);
  for(n=0;n<=100;n=n+1)begin point(1,592+n*4,328);if(strength!=n)$fatal(1,"Drag %0d got %0d",n,strength);end
  point(1,1023,10);if(strength!=100)$fatal(1,"Captured drag high clamp");
  point(1,0,590);if(strength!=0)$fatal(1,"Captured drag low clamp");lift();
  tap(800,420);if(strength!=50)$fatal(1,"Restore saved manual strength");
  tap(700,220);if(!auto_mode||strength!=50)$fatal(1,"Auto/manual memory");
  tap(900,220);point(1,792,328);point(2,900,328);point(1,992,328);
  if(strength!=50)$fatal(1,"Multitouch did not cancel slider");lift();
  tap(700,140);tap(592,328);if(en||strength!=50)$fatal(1,"Disabled HE permits drag");
  tap(620,50);if(page!=10)$fatal(1,"HE back to ISP");tap(700,300);
  if(page!=12||en||auto_mode||strength!=50||!ae||wb_mode!=2||kelvin!=17)$fatal(1,"HE state/WB/AE independence");
  tap(620,50);tap(700,140);tap(700,140);
  if(page!=2||wb_mode!=0||kelvin!=17||en||auto_mode||strength!=50)$fatal(1,"AWB/histogram state independence");
  tap(620,50);tap(700,300);if(page!=4||wb_mode!=2||kelvin!=17)$fatal(1,"Manual K survived histogram/AWB roundtrip");
  tap(620,50);tap(620,50);tap(620,50);tap(700,220);if(page!=7)$fatal(1,"Filter library");
  tap(900,140);if(filter!=5)$fatal(1,"Edge selection");
  tap(900,220);if(filter!=6)$fatal(1,"Retro selection");tap(680,300);if(filter!=7)$fatal(1,"Enhancement selection");
  tap(900,300);if(filter!=1)$fatal(1,"Gray restored");
  tap(680,380);if(filter!=2)$fatal(1,"Cartoon restored");
  tap(900,380);if(filter!=3)$fatal(1,"Negative restored");
  $display("PASS ISP histogram menu, enable/auto/manual, all 101 drag values, endpoint capture, disabled/auto guards, restore/memory, multitouch cancellation WB manual-K independence and restored display-choice navigation");$finish;
 end
 initial begin #100000;$fatal(1,"Histogram UI watchdog");end
endmodule

module bright_rom_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,u=0,l=0,bad=0;reg [2:0] mode=0;reg [95:0] rgb=0;
 wire [95:0] out,bypass;wire ov,ou,ol,ob;wire [2:0] om;
 rgb_brighten_eram_96 dut(.I_clk(clk),.I_rst_n(rst),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),
  .I_mode(mode),.I_previous_bad(bad),.O_data(out),.O_valid(ov),.O_user(ou),.O_last(ol),.O_mode(om),.O_previous_bad(ob));
 rgb_brighten_eram_96 #(.ENABLE(0)) plain(.I_clk(clk),.I_rst_n(rst),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),
  .I_mode(mode),.I_previous_bad(bad),.O_data(bypass));
 integer c,j,value,want;
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(c=0;c<256;c=c+1)begin
   v=c%3!=0;u=c%13==0;l=c%7==0;bad=c%2;mode=c%8;
   for(j=0;j<12;j=j+1)rgb[j*8+:8]=(c+j*13)%256;
   @(posedge clk);#1;
   if({ov,ou,ol,om,ob}!=={v,u,l,mode,bad}||bypass!==rgb)$fatal(1,"Tone ROM metadata/bypass stage");
   for(j=0;j<12;j=j+1)begin
    value=rgb[j*8+:8];want=value<64?value+value/2:value<192?value+32:value+(255-value)/2;
    if(out[j*8+:8]!==8'(want))$fatal(1,"Tone lookup changed at value=%0d channel=%0d",value,j);
   end
   @(negedge clk);
  end
  $display("PASS ERAM tone curve: all 256 inputs on all twelve channels, exact legacy rounding, bypass and one-stage frame/mode/CSI-quality metadata");$finish;
 end
endmodule

module histogram_native_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,u=0,l=0;reg [8:0] cfg=9'd484;reg [95:0] data=0;
 wire [95:0] out;wire ov,hw,hp;wire [5:0] ha;wire [7:0] height;
 histogram_equalizer_96 dut(.I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_data(data),.I_valid(v),.I_user(u),.I_last(l),
  .I_previous_bad(1'b0),.I_frame_mode(3'd0),.O_data(out),.O_valid(ov),.O_user(),.O_last(),.O_frame_mode(),
  .I_hist_ready(1'b1),.O_hist_we(hw),.O_hist_publish(hp),.O_hist_addr(ha),.O_hist_height(height));
 integer f,x,y,g,bin,d,map,expected,put=0,take=0,bars=0,commits=0;
 reg [7:0] queue[0:921599];
 always @(posedge clk)if(rst)begin
  if(v)begin
   g=data[7:0];expected=g;
   if(f==2)begin bin=g/4;map=((bin-16)*255+3)/7;d=map-(bin*4+2);expected=g+d;
    if(expected<0)expected=0;if(expected>255)expected=255;end
   queue[put]=expected;put=put+1;
  end
  #1;
  if(ov)begin if(out!=={12{queue[take]}})$fatal(1,"Native HE pixels frame=%0d beat=%0d",f,take);take=take+1;end
  if(hw)begin
   expected=f==0?(ha==63?128:0):(ha>=16&&ha<24?128:0);
   if(height!==8'(expected))$fatal(1,"Native histogram count/peak normalisation bin=%0d",ha);bars=bars+1;
  end
  if(hp)commits=commits+1;
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;repeat(80)@(negedge clk);
  for(f=0;f<4;f=f+1)begin
   cfg=f==3?9'd178:9'd484;u=1;@(negedge clk);u=0;
   for(y=0;y<720;y=y+1)begin
    for(x=0;x<320;x=x+1)begin
     g=f==0?255:64+(x+y)%32;data={12{8'(g)}};v=1;l=x==319;@(negedge clk);
    end
    v=0;l=0;repeat(2)@(negedge clk);
   end
   repeat(80)@(negedge clk);
  end
  repeat(4)@(negedge clk);
  if(put!=921600||take!=put||bars!=256||commits!=3)$fatal(1,"Native HE incomplete %0d %0d %0d %0d",put,take,bars,commits);
  $display("PASS four native 1280x720 HE frames: 153600-sample white single-bin maximum, all 64 plot bins, low-contrast CDF pixels, exact disabled bypass, frame commits and no frame buffer");$finish;
 end
 initial begin #15000000;$fatal(1,"Native HE watchdog");end
endmodule
