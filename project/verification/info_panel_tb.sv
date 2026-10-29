`timescale 1ns/1ps
// Uses independent decimal division and fixed expected ASCII strings. The font
// bitmaps are assets; no production BCD/formatter or UI internals are consulted.
module info_panel_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,h=0,de=0;reg [23:0] rgb=0;reg [51:0] cfg=0;
 reg [8:0] latency=0;reg [23:0] diagnostics=0;reg [7:0] underflow=0;
 reg [51:0] info=0;
 wire ov,oh,od;wire [23:0] out;
 wb_ui_overlay #(.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex"),
  .TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_ae_telemetry(10'd80),
  .I_hist_height(8'd0),.I_hist_valid(1'b0),
  .I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),
  .I_latency(latency),.I_diagnostics(diagnostics),.I_underflow(underflow),.I_target_info(info),
  .I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),
  .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 reg [7:0] digit_id[0:10],text_asset[0:2047];reg [23:0] font_asset[0:8191];
 reg [4:0] ascii_rows[0:1791];
 initial begin
  $readmemh("../info_digit_indices.hex",digit_id);
  $readmemh("../info_oracle_font.hex",font_asset);
  $readmemh("../../user_source/hdl_source/ui/wb_ui_text.hex",text_asset);
  $readmemh("../info_ascii_rows.hex",ascii_rows);
 end
 function [23:0] scene(input integer x,y);
  reg [7:0] a,b,c;begin a=31+x%199;b=41+y%173;c=19+(x+y)%211;scene={a,b,c};end
 endfunction
 function [23:0] half(input [23:0] a,b);
  integer r,g,c;begin r=(a[23:16]+b[23:16])/2;g=(a[15:8]+b[15:8])/2;c=(a[7:0]+b[7:0])/2;half={r[7:0],g[7:0],c[7:0]};end
 endfunction
 function integer sample(input integer n);
  begin case(n%6)0:sample=0;1:sample=9;2:sample=10;3:sample=99;4:sample=100;default:sample=255;endcase end
 endfunction
 function integer value(input integer frame,field);
  begin
   if(frame==0)value=0;
   else if(frame<7)value=sample(frame-1+field);
   else if(field==0)value=frame-5; // age 2,3,4,5 exercises all warning colours.
   else value=255;
  end
 endfunction
 function [7:0] ascii_expected(input integer field,pos);
  reg [95:0] word;begin
   case(field)0:word={"RUN:3       "};1:word={"FPS: 60     "};
   2:word={"DET: 30     "};default:word={"LAT: 12.34ms"};endcase
   ascii_expected=word>>((11-pos)*8);
  end
 endfunction
 function integer full_row(input integer yy,frame);
  integer q;begin
   full_row=0;
   if(frame<7&&((yy>=112&&yy<126)||(yy>=148&&yy<162)||(yy>=180&&yy<194)))full_row=1;
   for(q=0;q<5;q=q+1)if((frame<7||q==0)&&yy>=232+52*q&&yy<256+52*q)full_row=1;
  end
 endfunction
 reg [2:0] pv=0,ph=0,pd=0;integer px[0:2],py[0:2],pf[0:2];reg [23:0] source[0:2];
 integer f,x,y,width,k,xx,yy,ff,q,base_y,col,row,pos,n,which,gid,ch,ar,ac;
 integer pixels=0,checks=0,digits=0,ascii_pixels=0,invalid_pixels=0,colours=0;
 reg verify,ink;reg [23:0] expected,fg;
 always @(posedge clk)begin
  pv={pv[1:0],v};ph={ph[1:0],h};pd={pd[1:0],de};
  for(k=2;k>0;k=k-1)begin px[k]=px[k-1];py[k]=py[k-1];pf[k]=pf[k-1];source[k]=source[k-1];end
  px[0]=x;py[0]=y;pf[0]=f;source[0]=rgb;#1;
  if(rst)begin
   if({ov,oh,od}!=={pv[2],ph[2],pd[2]})$fatal(1,"information-page sync latency changed");
   if(od)begin
    pixels=pixels+1;if(^out===1'bx)$fatal(1,"unknown information-page pixel");
    xx=px[2];yy=py[2];ff=pf[2];verify=0;ink=0;expected=half(source[2],24'h111e2c);fg=24'hf3f6fa;
    for(q=0;q<5;q=q+1)begin
     base_y=232+52*q;
     if(xx>=880&&xx<952&&yy>=base_y&&yy<base_y+24)begin
      verify=1;pos=(xx-880)/24;col=(xx-880)%24;row=yy-base_y;n=value(ff,q);
      if(q==0)begin
       fg=ff==0?24'h8a96a5:n<=2?24'h16b8ad:n<=4?24'hffaa55:24'hdd6464;
       if(ff==0)begin gid=digit_id[10];invalid_pixels=invalid_pixels+1;end
       else gid=digit_id[pos==0?(n/100)%10:pos==1?(n/10)%10:n%10];
      end else gid=digit_id[pos==0?(n/100)%10:pos==1?(n/10)%10:n%10];
      ink=font_asset[gid*32+row][23-col];if(ink)begin expected=fg;colours=colours+1;end
      digits=digits+1;
     end
    end
    which=-1;base_y=0;pos=0;
    if(yy>=112&&yy<126&&xx>=600&&xx<720)begin which=0;base_y=112;col=xx-600;end
    if(yy>=148&&yy<162&&xx>=600&&xx<684)begin which=1;base_y=148;col=xx-600;end
    if(yy>=148&&yy<162&&xx>=800&&xx<884)begin which=2;base_y=148;col=xx-800;end
    if(yy>=180&&yy<194&&xx>=600&&xx<744)begin which=3;base_y=180;col=xx-600;end
    if(which>=0)begin
     verify=1;ch=ascii_expected(which,col/12);ar=(yy-base_y)/2;ac=(col/2)%6;
     fg=which==0?24'h50df90:24'hf3f6fa;
     if(ac<5&&ascii_rows[ch*7+ar][4-ac])expected=fg;
     ascii_pixels=ascii_pixels+1;
    end
    if(verify)begin
     checks=checks+1;
     if(out!==expected)$fatal(1,"info frame%0d (%0d,%0d) got%h expected%h",ff,xx,yy,out,expected);
    end
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<11;f=f+1)begin
   cfg={7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b1,1'b0,4'd13,2'd0,1'b0,1'(f%2),7'd30,7'd80,3'd0,1'b1};
   latency={1'(f!=0),8'(value(f,0))};diagnostics={8'(value(f,1)),8'(value(f,2)),8'(value(f,3))};underflow=value(f,4);
   info={3'd4,4'd3,12'h060,12'h030,1'b1,20'h01234};
   for(y=0;y<600;y=y+1)begin
    width=full_row(y,f)?1024:1;
    for(x=0;x<width;x=x+1)begin
     if(x==0&&y==0&&f%2==0)begin v=1;de=0;repeat(3)@(negedge clk);v=0;repeat(3)@(negedge clk);end
     v=(f%2==1&&x==0&&y==0);de=1;rgb=scene(x,y);@(negedge clk);
     if(y==80&&x==0)begin latency=9'h1aa;diagnostics=24'hdeadbe;underflow=8'had;info=0;cfg[18]=!cfg[18];end
    end
    de=0;v=0;h=1;repeat(3)@(negedge clk);h=0;
   end
   repeat(8)@(negedge clk);
  end
  if(checks<90000||digits<60000||ascii_pixels<30000||invalid_pixels<1700||colours<1000)$fatal(1,"insufficient information-page oracle coverage");
  $display("PASS information page: %0d output pixels, %0d independent decimal/ASCII pixels; 000/009/010/099/100/255 and invalid age, all age colours, unchanged 3-stage sync, both bar-hide states and mid-frame telemetry edits ignored",pixels,checks);$finish;
 end
 initial begin #50000000;$fatal(1,"information-page watchdog");end
endmodule
