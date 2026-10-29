`timescale 1ns/1ps
module ratio_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,start=0;reg [25:0] g=0,c=1;
 wire busy,done;wire [11:0] gain;
 wb_ratio_seq dut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_g(g),.I_channel(c),.O_busy(busy),.O_done(done),.O_gain(gain));
 integer n,expected;longint unsigned num;
 initial begin
  repeat(3)@(negedge clk);rst=1;
  for(n=0;n<300;n=n+1)begin
   g=$random&26'h3ffffff;c=$random&26'h3ffffff;if(n==0)c=0;if(n==1)g=0;
   num=g;num=num*1024;
   expected=(c==0)?1024:num/c; if(expected<512)expected=512;if(expected>3072)expected=3072;
   start=1;@(negedge clk);start=0;wait(done);#1;
   if(gain!==expected)$fatal(1,"Ratio %0d/%0d: got %0d expected %0d",g,c,gain,expected);
   @(negedge clk);
  end
  $display("PASS sequential Q10 ratios, 300 independent 64-bit division references, zero denominator, clamp and completion");$finish;
 end
 initial begin #1000000;$fatal(1,"Ratio watchdog");end
endmodule

module wb_unit_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,u=0,l=0;reg [95:0] rgb=0;reg [1:0] mode=2;reg [6:0] index=30;
 wire [95:0] data;wire ov,ou,ol,ready;wire [11:0] gr,gb;
 wb_balance_96 #(.MIN_SAMPLES(16),.FRAME_BEATS(128),.FRAME_LINES(1)) dut(.I_clk(clk),.I_rst_n(rst),.I_mode(mode),.I_kelvin_index(index),
 .I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),.I_ready(1'b1),.I_previous_bad(1'b0),.O_data(data),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(ready),.O_gain_r(gr),.O_gain_b(gb));
 integer table_r[0:75],table_b[0:75],k,a,b,csv,scan,idx;
 reg pv=0,pu=0,pl=0,prev_u=0;reg [95:0] expected_pipe=0,expected_now;
 integer active_r=1024,active_b=1024,p,r,bv,checked=0;
 function automatic [7:0] scale(input integer channel,gain);
  integer q;begin q=(channel*gain+512)/1024;scale=(q>255)?255:q;end
 endfunction
 always @(posedge clk)if(rst)begin
  if(u&&!prev_u)begin
   if(mode[1])begin active_r=table_r[index>75?75:index];active_b=table_b[index>75?75:index];end
   else begin active_r=dut.auto_r;active_b=dut.auto_b;end
  end
  prev_u=u;
  for(p=0;p<4;p=p+1)begin
   r=(rgb[p*24+16+:8]*active_r+512)/1024;
   bv=(rgb[p*24+0+:8]*active_b+512)/1024;
   if(r>255)r=255;if(bv>255)bv=255;
   expected_now[p*24+:24]={r[7:0],rgb[p*24+8+:8],bv[7:0]};
  end
  #1;
  if({ov,ou,ol,ready}!=={pv,pu,pl,1'b1})$fatal(1,"WB two-stage controls");
  if(gr!==active_r||gb!==active_b)$fatal(1,"Gains changed mid-frame");
  if(pv)begin if(data!==expected_pipe)$fatal(1,"WB pixels actual=%h expected=%h gr=%0d gb=%0d",data,expected_pipe,active_r,active_b);checked=checked+4;end
  else if(data!==0)$fatal(1,"WB blanking");
  expected_pipe=expected_now;pv=v;pu=u;pl=l;
 end
 task frame(input integer beats,input bit constant_color);
  integer x;
  begin
   u=1;v=0;@(negedge clk);u=0;
   for(x=0;x<beats;x=x+1)begin
    v=1;l=(x==beats-1);rgb=constant_color?{4{24'h5078a0}}:{$random,$random,$random};
    @(negedge clk);
   end
   v=0;l=0;repeat(100)@(negedge clk);
  end
 endtask
 initial begin
  csv=$fopen("../../user_source/hdl_source/wb/kelvin_gains_demo.csv","r");if(!csv)$fatal(1,"Gain CSV missing");
  begin reg [1023:0] line;scan=$fgets(line,csv);end
  for(idx=0;idx<76;idx=idx+1)begin scan=$fscanf(csv,"%d,%d,%d\n",k,a,b);if(scan!=3)$fatal(1,"CSV row %0d scan=%0d",idx,scan);table_r[idx]=a;table_b[idx]=b;end
  $fclose(csv);
  repeat(4)@(negedge clk);rst=1;
  for(idx=0;idx<76;idx=idx+1)begin
   index=idx;mode=2;frame(32,0);mode=3;frame(32,0);
  end
  index=127;mode=2;frame(32,0); // clamp the external manual index to the LUT end
  // Config change inside a frame must wait until the next SOF.
  index=5;mode=2;u=1;v=1;rgb={24'hffffff,24'hff0000,24'h00ff00,24'h0000ff};@(negedge clk);u=0;index=75;mode=0;
  repeat(20)@(negedge clk);v=0;repeat(100)@(negedge clk);
  for(idx=0;idx<180;idx=idx+1)begin mode=idx%2;frame(128,1);end
  if(gr<1528||gr>1540||gb<764||gb>776)$fatal(1,"Gray-world convergence R=%0d B=%0d",gr,gb);
  if(data!==0)$fatal(1,"Blanking after convergence");
  // Dark and clipped frames must preserve a settled estimate.
  a=dut.auto_r;b=dut.auto_b;u=1;@(negedge clk);u=0;v=1;rgb=0;
  repeat(128)@(negedge clk);v=0;repeat(100)@(negedge clk);
  u=1;@(negedge clk);u=0;repeat(100)@(negedge clk);
  if(dut.auto_r!=a||dut.auto_b!=b)$fatal(1,"Empty statistics changed AWB");
  $display("PASS WB all 76 manual K entries with mode-low-bit ignored, AWB codes 0/1 equivalent, rounding/clipping/four lanes, first-pixel SOF, frame-atomic config, gray-world convergence and dark-frame hold; %0d pixels",checked);$finish;
 end
 initial begin #2000000;$fatal(1,"WB unit watchdog");end
endmodule

module coord_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,report=0;reg [3:0] contacts=1;reg [15:0] x=0,y=0,w=1024,h=600;
 wire out,invout;wire [3:0] oc;wire [9:0] ox,oy,ix,iy;
 touch_coord_map dut(.I_clk(clk),.I_rst_n(rst),.I_report(report),.I_contacts(contacts),.I_x(x),.I_y(y),.I_width(w),.I_height(h),.O_report(out),.O_contacts(oc),.O_x(ox),.O_y(oy));
 touch_coord_map #(.INVERT_X(1),.INVERT_Y(1)) inv(.I_clk(clk),.I_rst_n(rst),.I_report(report),.I_contacts(contacts),.I_x(x),.I_y(y),.I_width(w),.I_height(h),.O_report(invout),.O_contacts(),.O_x(ix),.O_y(iy));
 integer n,xx,yy,ww,hh,tmp,ex,ey;
 initial begin
  repeat(3)@(negedge clk);rst=1;
  for(n=0;n<500;n=n+1)begin
   case(n%4)0:begin w=1024;h=600;end 1:begin w=800;h=480;end 2:begin w=600;h=1024;end 3:begin w=0;h=0;end endcase
   x=$random&16'h7ff;y=$random&16'h7ff;contacts=(n%11==0)?0:(n%13==0)?2:1;
   ww=w;hh=h;xx=x;yy=y;
   if(ww<128||hh<128)begin ww=1024;hh=600;end
   else if(hh>ww)begin tmp=ww;ww=hh;hh=tmp;tmp=xx;xx=yy;yy=tmp;end
   if(xx>=ww)xx=ww-1;if(yy>=hh)yy=hh-1;ex=xx*1024/ww;ey=yy*600/hh;
   report=1;@(negedge clk);report=0;wait(out);#1;
   if(oc!==contacts||invout!==1)$fatal(1,"Contact mapping transaction");
   if(contacts==1&&(ox!==ex||oy!==ey||ix!==1023-ex||iy!==599-ey))$fatal(1,"Coordinate reference %0d",n);
   @(negedge clk);
  end
  $display("PASS 500 coordinate reports, stored resolutions, portrait swap, clamping, invalid-resolution fallback, both inversions and multi-touch forwarding");$finish;
 end
 initial begin #1000000;$fatal(1,"Coordinate watchdog");end
endmodule

module gain_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,cam=0,done=0,frame_toggle=0;
 always begin repeat(40)@(negedge clk);frame_toggle=~frame_toggle;end reg [6:0] desired=80;
 wire req;wire [15:0] ae,ag;
 camera_gain_apply dut(.I_clk(clk),.I_rst_n(rst),.I_gain(desired),.I_cam_done(cam),.I_ae_done(done),.I_frame_toggle(frame_toggle),.O_req(req),.O_ae(ae),.O_ag(ag));
 task acknowledge;
  begin wait(req);@(negedge clk);done=0;repeat(20)@(negedge clk);done=1;repeat(3)@(negedge clk);end
 endtask
 initial begin
  repeat(3)@(negedge clk);rst=1;repeat(3)@(negedge clk);
  if(req||ae!=1990)$fatal(1,"Gain startup");cam=1;done=1;acknowledge();
  if(ag!=80)$fatal(1,"Startup AG mismatch");
  desired=81;wait(req);@(negedge clk);done=0;desired=85;repeat(8)@(negedge clk);desired=89;
  repeat(12)@(negedge clk);if(ag!=81||req)$fatal(1,"Gain changed during sensor write");
  done=1;acknowledge();if(ag!=89)$fatal(1,"Latest gain not coalesced");
  desired=0;acknowledge();if(ag!=16)$fatal(1,"Lower gain clamp");
  desired=127;acknowledge();if(ag!=89)$fatal(1,"Upper gain clamp");
  $display("PASS shared sensor gain startup, fixed exposure, busy/ACK handshake, latest-value coalescing and original AG16..89 limits");$finish;
 end
 initial begin #100000;$fatal(1,"Gain watchdog");end
endmodule

module mailbox_tb;
 reg a=0,b=0,rst=0;always #7 a=~a;always #11 b=~b;
 reg [21:0] value=7840;wire [21:0] received;
 config_mailbox #(.WIDTH(22),.RESET_VALUE(22'd7840)) dut(.I_src_clk(a),.I_dst_clk(b),.I_rst_n(rst),.I_data(value),.O_data(received));
 reg [21:0] sent[0:255];integer sent_count=1,j;reg match;
 initial sent[0]=22'd7840;
 always @(posedge a)if(rst&&dut.request==dut.ack_sync[1]&&value!=dut.payload)begin sent[sent_count]=value;sent_count=sent_count+1;end
 always @(posedge b)if(rst)begin
  #1;match=0;for(j=0;j<sent_count;j=j+1)if(received===sent[j])match=1;
  if(!match)$fatal(1,"Mailbox captured a torn or unsent word");
 end
 integer n;
 initial begin
  #50;rst=1;
  for(n=0;n<200;n=n+1)begin @(negedge a);value={$random}&22'h3fffff;repeat(n%8)@(negedge a);end
  value=22'h2abcde;repeat(30)@(negedge b);
  if(received!==value)$fatal(1,"Mailbox lost final latest state");
  $display("PASS 22-bit held-payload mailbox, asynchronous clocks, rapid coalesced state changes and final latest state");$finish;
 end
endmodule

