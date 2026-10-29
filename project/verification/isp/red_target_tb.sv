`timescale 1ns/1ps
module red_target_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,en=0,v=0,h=0,de=0;reg [2:0] page=0;reg [23:0] rgb=0;
 wire ov,oh,od;wire [23:0] data;
 red_target_video dut(.I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_page(page),
 .I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(data));
 integer xx,yy,kind=0,fd=0,ui_fd=0,total=0,black=0,text_pixels=0;
 reg efound=0,een=0;reg [2:0] epage=0;
 wire [38:0] ui_cfg={1'b0,5'd0,5'd0,en,1'b0,{1'b0,page},2'd0,2'd0,7'd30,7'd80,3'd0,1'b1};
 reg [38:0] ui_c1=0,ui_c2=0,ui_c3=0;
 reg ui_vd=0;reg [38:0] ui_frame=0;
 always @(posedge clk)begin
  ui_vd<=v;if(v&&!ui_vd)ui_frame<=ui_cfg;
  ui_c1<=(v&&!ui_vd)?ui_cfg:ui_frame;ui_c2<=ui_c1;ui_c3<=ui_c2;
 end
 wire uv,uh,ud;wire [23:0] ui_rgb;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) final_ui(.I_telemetry({1'b1,12'd1536,12'd1024,12'd768}),
  .I_clk(clk),.I_rst_n(rst),.I_config(ui_c3),.I_vsync(ov),.I_hsync(oh),.I_de(od),.I_data(data),
  .O_vsync(uv),.O_hsync(uh),.O_de(ud),.O_data(ui_rgb));
 reg check_uv=0,check_uh=0,check_ud=0;
 reg check2_uv=0,check2_uh=0,check2_ud=0;
 reg sampled_uv,sampled_uh,sampled_ud;
 always @(posedge clk)if(rst)begin
  sampled_uv=ov;sampled_uh=oh;sampled_ud=od;
  #2;
  if({uv,uh,ud}!=={check2_uv,check2_uh,check2_ud})$fatal(1,"Target plus UI controls");
  if(ud&&(final_ui.cfg[27]!==een||final_ui.cfg[25:22]!=={1'b0,epage}))$fatal(1,"UI and detector frame configuration split");
  check2_uv=check_uv;check2_uh=check_uh;check2_ud=check_ud;
  check_uv=sampled_uv;check_uh=sampled_uh;check_ud=sampled_ud;
  if(ud&&ui_fd)$fwrite(ui_fd,"%c%c%c",ui_rgb[23:16],ui_rgb[15:8],ui_rgb[7:0]);
 end
 integer el=0,er=0,et=0,eb=0,ecx=0,ecy=0;
 reg vv0=0,hh0=0,dd0=0,vv1=0,hh1=0,dd1=0;
 reg [23:0] ref0=0,ref1=0;reg skip0=0,skip1=0;
 reg [23:0] expected;reg skip,edge_expected,cross_expected;
 integer px,py,dx,dy,tag_x,tag_y,view_width;
 always @(posedge clk)if(rst)begin
  px=xx;py=yy;expected=rgb;skip=0;
  dx=(px>=ecx)?px-ecx:ecx-px;dy=(py>=ecy)?py-ecy:ecy-py;
  edge_expected=efound&&px>=el&&px<=er&&py>=et&&py<=eb&&
    (px<el+3||px>er-3||py<et+3||py>eb-3);
  cross_expected=efound&&((dx<=10&&dy<=1)||(dy<=10&&dx<=1));
  if(een&&(epage==0||px<560))begin
   view_width=(epage==0)?1024:560;
   tag_x=efound?((el<=view_width-252)?el:view_width-252):(view_width-252)/2;
   tag_y=efound?((et>=92)?et-28:((eb<=520)?eb+4:64)):516;
   if(px>=tag_x&&px<tag_x+252&&py>=tag_y&&py<tag_y+24)skip=1;
   else if(edge_expected||cross_expected)expected=0;
  end
  if(!de)expected=0;
  #1;
  if({ov,oh,od}!=={vv1,hh1,dd1})$fatal(1,"Three-cycle target controls");
  if(od)begin
   if(data===24'hxxxxxx)$fatal(1,"Unknown target pixel");
   if(!skip1&&data!==ref1)$fatal(1,"Pixel oracle mismatch kind=%d data=%h expected=%h",kind,data,ref1);
   if(fd)begin $fwrite(fd,"%c%c%c",data[23:16],data[15:8],data[7:0]);end
   if(data==0)black=black+1;
   if(skip1&&data==24'hffffff)text_pixels=text_pixels+1;
   total=total+1;
  end
  vv1=vv0;hh1=hh0;dd1=dd0;ref1=ref0;skip1=skip0;
  vv0=v;hh0=h;dd0=de;ref0=expected;skip0=skip;
 end
 task check(input bit f,input integer l,r,t,b);
  begin
   if(dut.found!==f)$fatal(1,"Found=%b expected=%b kind=%d",dut.found,f,kind);
   if(f&&{dut.left,dut.right,dut.top,dut.bottom}!=={11'(l),11'(r),11'(t),11'(b)})$fatal(1,"Bounding coordinates");
   if(f&&(dut.cx!=(l+r)/2||dut.cy!=(t+b)/2))$fatal(1,"Center coordinates");
  end
 endtask
 task start_frame(input bit f,input integer l,r,t,b);
  begin
   efound=f;el=l;er=r;et=t;eb=b;ecx=(l+r)/2;ecy=(t+b)/2;een=en;epage=page;
   v=1;de=0;repeat(5)@(negedge clk);v=0;repeat(5)@(negedge clk);
   check(f,l,r,t,b);
  end
 endtask
 function [23:0] pixel(input integer k,x,y);
  begin
   pixel=24'hf0f0f0;
   case(k)
    1:begin
     if(x>=400&&x<=599&&y>=200&&y<=359)pixel=24'hd02028;
     // Isolated red noise cannot extend the frame's box.
     if((x==15&&y==10)||(x==1000&&y==590))pixel=24'hff0000;
    end
    2:if(x>=100&&x<300&&y>=200&&y<400)pixel=24'h20d028;
    3:if(x>=100&&x<300&&y>=200&&y<400)pixel=24'h2028d0;
    4:if(x>=100&&x<300&&y>=200&&y<400)pixel=24'hdc7828; // orange
    5:if(x>=100&&x<300&&y>=200&&y<400)pixel=24'hdc9682; // skin-like
    6:if(x>=100&&x<110&&y>=200&&y<210)pixel=24'hd02028;
    7:if(x>=1000&&x<=1023&&y>=576&&y<=599)pixel=24'hd02028;
    8:if(x<24&&y<24)pixel=24'hd02028;
    9:if(x>=100&&x<300&&y>=200&&y<400)pixel=24'h321010; // too dark
    10:if(x>=400&&x<=599&&y>=200&&y<=359)pixel=24'h702020; // shadow red
    11:if(x>=100&&x<108&&y>=200&&y<300)pixel=24'hd02028; // narrow, area is large
    12:if(x>=100&&x<200&&y>=200&&y<208)pixel=24'hd02028; // short, area is large
    13:if(x%8<3&&y>=200&&y<400)pixel=24'hd02028; // many disconnected short runs
    default:;
   endcase
  end
 endfunction
 task image(input integer k,input bit change_midframe);
  begin
   kind=k;
   for(yy=0;yy<600;yy=yy+1)begin
    for(xx=0;xx<1024;xx=xx+1)begin
     de=1;h=0;rgb=pixel(k,xx,yy);
     if(change_midframe&&yy==300&&xx==10)en=0;
     @(negedge clk);
    end
    de=0;h=1;repeat(3)@(negedge clk);h=0;
   end
   repeat(8)@(negedge clk);
  end
 endtask
 initial begin
  xx=0;yy=0;repeat(4)@(negedge clk);rst=1;
  start_frame(0,0,0,0,0);image(1,0); // disabled is exact bypass
  en=1;start_frame(0,0,0,0,0);image(1,0);
  start_frame(0,0,0,0,0);image(1,0); // two full frames to confirm
  start_frame(1,400,599,200,359);
  if(dut.bcd_x!==16'h0499||dut.bcd_y!==16'h0279)$fatal(1,"Decimal center");
  fd=$fopen("red_target_found.ppm","wb");$fwrite(fd,"P6\n1024 600\n255\n");
  ui_fd=$fopen("red_target_preview.ppm","wb");$fwrite(ui_fd,"P6\n1024 600\n255\n");
  image(1,0);$fclose(fd);fd=0;$fclose(ui_fd);ui_fd=0;
  start_frame(1,400,599,200,359);image(0,0);
  start_frame(0,0,0,0,0);
  fd=$fopen("red_target_absent.ppm","wb");$fwrite(fd,"P6\n1024 600\n255\n");
  image(2,0);$fclose(fd);fd=0;
  start_frame(0,0,0,0,0);image(3,0);
  start_frame(0,0,0,0,0);image(4,0);
  start_frame(0,0,0,0,0);image(5,0);
  start_frame(0,0,0,0,0);image(6,0);
  start_frame(0,0,0,0,0);image(9,0);
  start_frame(0,0,0,0,0);image(11,0);
  start_frame(0,0,0,0,0);image(12,0);
  start_frame(0,0,0,0,0);image(13,0);
  start_frame(0,0,0,0,0);image(10,0);
  start_frame(0,0,0,0,0);image(10,0);
  start_frame(1,400,599,200,359);image(1,1);
  start_frame(0,0,0,0,0);image(1,0); // disable is frame atomic
  en=1;start_frame(0,0,0,0,0);image(7,0);
  start_frame(0,0,0,0,0);image(7,0);
  start_frame(1,1000,1023,576,599);image(8,0);
  start_frame(1,0,23,0,23);image(8,0);
  page=2;start_frame(1,0,23,0,23);image(1,0);
  start_frame(1,400,599,200,359);
  ui_fd=$fopen("red_target_auto_page.ppm","wb");$fwrite(ui_fd,"P6\n1024 600\n255\n");
  image(1,0);$fclose(ui_fd);ui_fd=0;
  // An incomplete frame must clear a previously found region.
  start_frame(1,400,599,200,359);de=1;rgb=24'hd02028;
  repeat(100)@(negedge clk);de=0;repeat(5)@(negedge clk);
  start_frame(0,0,0,0,0);
  if(total<12000000||black==0||text_pixels==0)$fatal(1,"Coverage counters");
  $display("PASS red target: 1024x600 pixel oracle, RGB negatives, dark/shadow red, run/area rejection, exact inclusive bbox/center/BCD, black border/cross, two-frame confirmation, immediate loss, enable atomicity, screen edges, incomplete frame, three-cycle sync; pixels=%0d",total);$finish;
 end
 initial begin #180000000;$fatal(1,"Target watchdog");end
endmodule

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
