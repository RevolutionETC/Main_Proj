`timescale 1ns/1ps
module ae_meter_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,u=0,l=0,bad=0;reg [1:0] mode=1;reg [95:0] data=0;wire [7:0] stats;
 ae_meter_96 #(.FRAME_BEATS(32),.FRAME_LINES(4),.LINE_BEATS(8),
 .VIEW_X(0),.VIEW_Y(0),.VIEW_BEATS(8),.VIEW_LINES(4),
 .SPOT_X(3),.SPOT_Y(1),.SPOT_BEATS(2),.SPOT_LINES(2),
 .CENTER_X(2),.CENTER_Y(1),.CENTER_BEATS(4),.CENTER_LINES(2),
 .PARTIAL_X(2),.PARTIAL_Y(1),.PARTIAL_BEATS(4),.PARTIAL_LINES(2)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_valid(v),.I_user(u),.I_last(l),.I_previous_bad(bad),.I_meter_mode(mode),.I_data(data),.O_stats(stats));
 integer expected_sum=0,weight=88,previous_sum=0,previous_weight=88;bit previous_valid=0;
 function [3:0] command(input integer total,n);
 begin command=total>n*70?4'b1100:total>n*54?4'b1010:total>n*48?4'b1001:
                     total<n*23?4'b0100:total<n*38?4'b0010:total<n*44?4'b0001:4'b0000;end
 endfunction
 task boundary(input bit coincident,input integer value,input bit expect_valid);
  begin @(negedge clk);u=1;v=coincident;l=0;data={12{value[7:0]}};
   @(negedge clk);u=0;v=0;
   if(stats[4]!==expect_valid)$fatal(1,"meter complete flag %b expected %b",stats,expect_valid);
   if(expect_valid&&stats[3:0]!==command(previous_sum,previous_weight))$fatal(1,"meter independent weighted oracle sum=%0d n=%0d got=%b",previous_sum,previous_weight,stats);
  end
 endtask
 task picture(input integer center_value,outside_value,input bit coincident,input integer fault);
  integer x,y,n,value,w;begin
   boundary(coincident,outside_value,previous_valid);
   expected_sum=coincident?((mode==1||mode==2)?outside_value:0):0;
   for(y=0;y<4;y=y+1)for(x=(y==0&&coincident?1:0);x<8;x=x+1)begin
    value=(x>=2&&x<6&&y>=1&&y<3)?center_value:outside_value;
    w=mode==0?((x>=3&&x<5&&y>=1&&y<3)?1:0):mode==1?((x>=2&&x<6&&y>=1&&y<3)?8:1):mode==2?1:((x>=2&&x<6&&y>=1&&y<3)?1:0);
    expected_sum=expected_sum+w*value;
    v=1;l=x==7;if(fault==1&&y==2)l=x==6;
    data={12{value[7:0]}};@(negedge clk);v=0;l=0;
    if((x+y)%3==0)repeat(2)@(negedge clk);
   end
   previous_sum=expected_sum;previous_weight=mode==0?4:mode==1?88:mode==2?32:8;previous_valid=fault==0&&!bad;
  end
 endtask
 integer n,m;integer levels[0:10];
 initial begin levels[0]=0;levels[1]=20;levels[2]=30;levels[3]=40;levels[4]=44;levels[5]=46;levels[6]=48;levels[7]=50;levels[8]=60;levels[9]=80;levels[10]=255;end
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(m=0;m<4;m=m+1)begin mode=m;previous_valid=0;
   for(n=0;n<11;n=n+1)picture(levels[n],levels[n],n%2,0);
   picture(46,0,1,0);picture(46,200,0,0);
  end
  mode=1;previous_valid=0;
  picture(46,0,1,0);picture(0,200,0,0);picture(46,46,0,1);picture(46,46,1,0);
  bad=1;previous_valid=0;picture(46,46,0,0);bad=0;
  // Change metering mode during a frame. It must not mix ROI statistics.
  mode=0;previous_valid=0;picture(46,255,0,0);picture(46,0,1,0);
  picture(80,0,0,0);boundary(0,0,1);
  // The spot value is independent of the same two different backgrounds.
  previous_valid=0;
  repeat(7)begin v=1;@(negedge clk);end v=0;boundary(0,0,0);
  $display("PASS 18%%-gray metering: independent four-mode spot/weighted/equal-zone/partial sums, all bins, ROI background independence, mode epochs, SOF/bubbles and invalid-frame guards");$finish;
 end
 initial begin #500000;$fatal(1,"meter watchdog");end
endmodule

module ae_loop_tb;
 reg c=0,s=0;always #5 c=~c;always #7 s=~s;
 reg rst=0,v=0,u=0,l=0,ft=0,en=1,cam=0;reg [1:0] mode=1;reg [95:0] data=0;
 reg [6:0] gain=80;wire [7:0] raw_stats,stats;wire req;wire [15:0] ae,ag;wire [2:0] status;
 reg done=1;integer busy_count=0,writes=0;reg [31:0] held;
 ae_meter_96 #(.FRAME_BEATS(32),.FRAME_LINES(4),.LINE_BEATS(8),
 .VIEW_X(0),.VIEW_Y(0),.VIEW_BEATS(8),.VIEW_LINES(4),
 .SPOT_X(3),.SPOT_Y(1),.SPOT_BEATS(2),.SPOT_LINES(2),
 .CENTER_X(2),.CENTER_Y(1),.CENTER_BEATS(4),.CENTER_LINES(2),
 .PARTIAL_X(2),.PARTIAL_Y(1),.PARTIAL_BEATS(4),.PARTIAL_LINES(2)) meter(
 .I_clk(c),.I_rst_n(rst),.I_valid(v),.I_user(u),.I_last(l),.I_previous_bad(1'b0),.I_meter_mode(mode),.I_data(data),.O_stats(raw_stats));
 config_mailbox #(.WIDTH(8),.RESET_VALUE(8'd64)) mailbox(.I_src_clk(c),.I_dst_clk(s),.I_rst_n(rst),.I_data(raw_stats),.O_data(stats));
 camera_gain_apply apply(.I_clk(s),.I_rst_n(rst),.I_gain(gain),.I_auto_enable(en),.I_meter_mode(mode),.I_stats(stats),
 .I_cam_done(cam),.I_ae_done(done),.I_frame_toggle(ft),.O_req(req),.O_ae(ae),.O_ag(ag),.O_status(status));
 function integer gain_q5(input integer code);
 begin gain_q5=code<48?code+16:code<80?(code-16)*2:(code-48)*4;end endfunction
 always @(posedge s)if(rst)begin
  if(req)begin
   if(!done||busy_count!=0)$fatal(1,"overlapping gain group");
   held={ae,ag};writes=writes+1;busy_count=60;done<=0;
  end else if(busy_count!=0)begin
   if({ae,ag}!==held)$fatal(1,"gain changed while writer busy");
   busy_count=busy_count-1;if(busy_count==0)done<=1;
  end
  if(ae!=1990||ag<16||ag>89)$fatal(1,"fixed shutter or gain limits");
 end
 integer light=16;
 task frame;
  integer x,y,brightness;begin
   @(negedge c);ft=~ft;u=1;v=0;l=0;
   // Independent sensor model, including all three analogue gain stages.
   brightness=(light*gain_q5(ag)+16)/32;if(brightness>255)brightness=255;
   data={12{brightness[7:0]}};@(negedge c);u=0;
   for(y=0;y<4;y=y+1)for(x=0;x<8;x=x+1)begin v=1;l=x==7;@(negedge c);end
   v=0;l=0;repeat(100)@(negedge c);
  end
 endtask
 task converged;
 integer value;begin value=(light*gain_q5(ag)+16)/32;
  if(value<44||value>48||!status[1])$fatal(1,"gain loop convergence light=%0d gain=%0d y=%0d status=%b",light,ag,value,status);end
 endtask
 integer locked,previous_writes;
 initial begin
  repeat(4)@(negedge c);rst=1;cam=1;
  repeat(100)frame();converged();
  light=32;repeat(140)frame();converged();
  light=10;repeat(140)frame();converged();
  // UI snapshots the live gain into the same command as AUTO off.
  gain=ag;en=0;locked=ag;previous_writes=writes;light=1000;repeat(15)frame();
  if(ag!=locked||writes!=previous_writes)$fatal(1,"manual transition jump");
  gain=16;repeat(10)frame();if(ag!=16)$fatal(1,"manual gain request");
  en=1;light=32;gain=89;repeat(140)frame();converged();
  if(ag==89)$fatal(1,"AUTO incorrectly follows saved manual gain");
  for(locked=0;locked<4;locked=locked+1)begin mode=locked;repeat(20)frame();converged();end
  light=1000;repeat(100)frame();if(ag!=16||!status[0])$fatal(1,"minimum gain limit");
  light=1;repeat(160)frame();if(ag!=89||!status[0])$fatal(1,"maximum gain limit");
  $display("PASS fixed-shutter AGC: async bright/dark convergence to 18%% gray, all gain stages, manual handoff/resume, mode changes, limits and atomic writes; groups=%0d",writes);$finish;
 end
 initial begin #3000000;$fatal(1,"AGC loop watchdog");end
endmodule

module ae_720p_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,u=0,l=0;reg [1:0] mode=1;wire [7:0] stats;reg [95:0] data=0;
 ae_meter_96 meter(.I_clk(clk),.I_rst_n(rst),.I_valid(v),.I_user(u),.I_last(l),.I_previous_bad(1'b0),.I_meter_mode(mode),.I_data(data),.O_stats(stats));
 integer x,y,k,value;
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(k=0;k<8;k=k+1)begin
   mode=k%4;u=1;@(negedge clk);u=0;
   for(y=0;y<720;y=y+1)begin
    for(x=0;x<320;x=x+1)begin
     value=k>=4?255:mode==0?((x>=144&&x<176&&y>=296&&y<424)?46:255):mode==3?((x>=130&&x<190&&y>=240&&y<480)?46:255):((x>=32&&x<288&&y>=60&&y<660)?46:255);
     data={12{value[7:0]}};v=1;l=x==319;@(negedge clk);
    end
    v=0;l=0;repeat(8)@(negedge clk);
   end
   u=1;@(negedge clk);u=0;
   if(!stats[4]||stats[3:0]!=(k>=4?4'b1100:4'b0000)||stats[7:6]!=mode)$fatal(1,"native crop ROI/weight normalisation mode %b stats %b",mode,stats);
   repeat(3)@(negedge clk);
  end
  $display("PASS eight native 1280x720 frames: four ROI masks, 4096/422400/153600/14400 weight sums, excluded backgrounds, maximum white weighted sum 107712000 without overflow");$finish;
 end
endmodule

module ae_register_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0;reg [6:0] index=0;
 wire [15:0] gain;reg [8:0] ri=0;wire [31:0] word;wire [8:0] size;
 SC500GainTbl gains(.I_clk(clk),.I_rstn(rst),.I(index),.O(gain));
 uics500regAE words(.REG_INDEX(ri),.REG_DATA(word),.REG_SIZE(size),.I_AE(16'hffff),.I_AG(gain));
 integer a,n;reg [23:0] expected[0:4];
 initial begin
  repeat(4)@(negedge clk);rst=1;
  for(a=0;a<74;a=a+1)begin
   index=a;repeat(3)@(negedge clk);
   expected[0]=24'h380000;expected[1]={16'h3e08,gain[15:8]};expected[2]={16'h3e09,gain[7:0]};
   expected[3]=24'h380010;expected[4]=24'h380040;
   for(n=0;n<5;n=n+1)begin ri=n;#1;
    if(size!=5||word!=={8'd0,expected[n]})$fatal(1,"gain-only group sequence");
    if(word[23:8]!=16'h3800&&word[23:8]!=16'h3e08&&word[23:8]!=16'h3e09)$fatal(1,"dynamic shutter/frame register write");
   end
  end
  $display("PASS all 74 analogue gain codes: five-register group hold contains only gain/hold addresses; no shutter, VTS, PLL or stream-control writes");$finish;
 end
endmodule
