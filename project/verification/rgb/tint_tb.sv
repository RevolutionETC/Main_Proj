`timescale 1ns/1ps
module tint_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,en=1,v=0,u=0,l=0;
 reg signed [4:0] ab=0,gm=0;reg [95:0] rgb=0;
 wire [95:0] out;wire ov,ou,ol;
 wb_tint_96 dut(.I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_ab(ab),.I_gm(gm),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),
 .O_data(out),.O_valid(ov),.O_user(ou),.O_last(ol));
 integer qr,qg,qb;
 integer er=1024,eg=1024,eb=1024,ar,ag,p,n,checked=0,a,g,k;
 reg pv=0,pu=0,pl=0;reg [95:0] expected=0,now=0;
 function automatic [7:0] scale(input integer x,gain);
 integer q;begin q=(x*gain+512)/1024;scale=q>255?255:q;end endfunction
 always @(posedge clk)if(rst)begin
  if(u)begin ar=ab;ag=gm;if(ar>9)ar=9;if(ar< -9)ar=-9;if(ag>9)ag=9;if(ag< -9)ag=-9;
   er=en?1024+ar*32:1024;eg=en?1024+ag*32:1024;eb=en?1024-ar*32:1024;end
  for(p=0;p<4;p=p+1)begin
   qr=(rgb[p*24+16+:8]*er+512)/1024;qg=(rgb[p*24+8+:8]*eg+512)/1024;qb=(rgb[p*24+:8]*eb+512)/1024;
   if(qr>255)qr=255;if(qg>255)qg=255;if(qb>255)qb=255;
   now[p*24+:24]={qr[7:0],qg[7:0],qb[7:0]};
  end
  #1;if({ov,ou,ol}!=={pv,pu,pl})$fatal(1,"Tint sideband latency");
  if(pv)begin if(out!==expected)$fatal(1,"Tint oracle ab=%d gm=%d got=%h expected=%h",ab,gm,out,expected);checked=checked+4;end
  else if(out!==0)$fatal(1,"Tint blanking");
  pv=v;pu=u;pl=l;expected=now;
 end
 task frame(input integer x,y,input bit enabled);
 integer j;begin
 ab=x;gm=y;en=enabled;u=1;v=1;
 for(j=0;j<20;j=j+1)begin rgb=j==0?{24'hffffff,24'hff0000,24'h00ff00,24'h0000ff}:{$random,$random,$random};l=j==19;
 @(negedge clk);u=0;
 if(j==7)begin ab=9;gm=-9;en=!enabled;end // must wait for next frame
 end
 v=0;l=0;repeat(4)@(negedge clk);
 end endtask
 initial begin repeat(4)@(negedge clk);rst=1;
 for(a=-9;a<=9;a=a+1)for(g=-9;g<=9;g=g+1)frame(a,g,1);
 frame(0,0,1);frame(9,9,0);frame(-16,15,1);
 $display("PASS manual tint all 361 B/A G/M positions, four RGB lanes, independent integer gain oracle, rounding/clipping, neutral identity, disabled bypass, illegal clamp, first-pixel SOF and mid-frame edit deferral; pixels=%0d",checked);$finish;end
 initial begin #1000000;$fatal(1,"Tint watchdog");end
endmodule

module shift_ui_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,online=1,report=0;reg [1:0] keys=3;reg [3:0] contacts=0;reg [9:0] x=0,y=0;
 wire [3:0] page;wire [1:0] mode;wire [6:0] index,gain;wire enabled,tag,key_axis;wire [2:0] image_mode;wire signed [4:0] ab,gm;
 wb_ui_control #(.CLK_HZ(1000)) dut(.I_clk(clk),.I_rst_n(rst),.I_online(online),.I_report(report),.I_contacts(contacts),.I_x(x),.I_y(y),
 .I_applied_gain(7'd80),.I_buttons_n(keys),.O_page(page),.O_mode(mode),.O_index(index),.O_gain(gain),.O_detect_enable(enabled),.O_tag_enable(tag),.O_image_mode(image_mode),.O_ab(ab),.O_gm(gm),.O_key_axis(key_axis));
 reg dst=0;always #7 dst=~dst;wire [38:0] cfg;
 config_mailbox #(.WIDTH(39),.RESET_VALUE({1'b0,5'd0,5'd0,1'b0,1'b0,4'd0,2'd0,2'd0,7'd30,7'd80,3'd0,1'b0})) mailbox39(.I_src_clk(clk),.I_dst_clk(dst),.I_rst_n(rst),
 .I_data({key_axis,ab,gm,enabled,tag,page,mode,2'd0,index,gain,image_mode,1'b1}),.O_data(cfg));
 task point(input integer c,px,py);begin @(negedge clk);contacts=c;x=px;y=py;report=1;@(negedge clk);report=0;repeat(2)@(negedge clk);end endtask
 task lift;begin point(0,0,0);repeat(40)@(negedge clk);end endtask
 task tap(input integer px,py);begin point(1,px,py);lift();end endtask
 initial begin repeat(4)@(negedge clk);rst=1;lift();point(1,900,200);repeat(40)@(negedge clk);point(1,790,200);lift();tap(700,140);tap(700,220);tap(700,140);tap(620,50);tap(700,140);
 tap(700,300);if(page!=4||mode!=2)$fatal(1,"Manual page");
 tap(850,290);if(index!=50)$fatal(1,"Manual K before tint edit");
 tap(800,500);if(page!=6)$fatal(1,"Shift panel entry");
 tap(730,216);if(ab!=-5||gm!=6)$fatal(1,"Reference B5 G6 position %d %d",ab,gm);
 point(1,800,300);point(1,1023,599);if(ab!=9||gm!=-9)$fatal(1,"Captured lower-right clamp");
 point(1,0,0);if(ab!=-9||gm!=9)$fatal(1,"Captured upper-left clamp");lift();
 tap(800,550);if(ab!=0||gm!=0||index!=50)$fatal(1,"Reset preserves K");
 tap(620,300);tap(800,130);if(ab!=-1||gm!=1)$fatal(1,"B/G nudge");
 tap(970,300);tap(800,460);if(ab!=0||gm!=0)$fatal(1,"A/M nudge");
 point(1,970,300);repeat(2400)@(negedge clk);lift();if(ab!=9||gm!=0)$fatal(1,"Held arrow repeat bound");
 tap(620,50);if(page!=4||ab!=9)$fatal(1,"Back to manual preserves point");
 tap(620,50);tap(700,140);if(page!=2||mode!=0||index!=50)$fatal(1,"Auto route preserves manual K");
 tap(800,430);if(enabled)$fatal(1,"AWB must not control target recognition");
 repeat(60)@(negedge clk);if(cfg!=={key_axis,ab,gm,enabled,tag,page,mode,2'd0,index,gain,image_mode,1'b1})$fatal(1,"39-bit config torn");
 tap(620,50);tap(700,300);tap(800,500);if(page!=6||ab!=9||index!=50)$fatal(1,"Manual K and tint point memory");
 point(2,800,300);point(1,730,216);if(ab!=9)$fatal(1,"Multi-touch must block");lift();
 point(1,620,300);online=0;repeat(1500)@(negedge clk);online=1;lift();if(ab!=8)$fatal(1,"Fault cancels repeat");
 tap(940,130);if(!key_axis)$fatal(1,"G/M key-axis selector");
 keys=2'b01;repeat(30)@(negedge clk);keys=3;repeat(40)@(negedge clk);
 if(ab!=8||gm!=1||gain!=80)$fatal(1,"Physical G+ without sensitivity change");
 tap(620,130);if(key_axis)$fatal(1,"B/A key-axis selector");
 keys=2'b10;repeat(30)@(negedge clk);keys=3;repeat(40)@(negedge clk);
 if(ab!=7||gm!=1||gain!=80)$fatal(1,"Physical B- without sensitivity change");
 keys=2'b10;repeat(20000)@(negedge clk);keys=3;repeat(40)@(negedge clk);
 if(ab!=-9||gain!=80)$fatal(1,"Physical shift repeat/clamp");
 tap(620,50);keys=2'b01;repeat(30)@(negedge clk);keys=3;repeat(40)@(negedge clk);
 if(page!=4||gain!=81)$fatal(1,"Keys resume sensitivity outside shift panel");
 $display("PASS manual UI nested back, reference B5/G6 mapping, drag/clamp, AWB target-control isolation and coherent 39-bit config");$finish;end
 initial begin #1000000;$fatal(1,"Shift UI watchdog");end
endmodule
