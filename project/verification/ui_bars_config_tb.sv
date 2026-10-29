`timescale 1ns/1ps
// Output-only oracle: real VS/DE raster counters, independent pixel arithmetic.
// Sparse rows keep native x=1023/y=599 coverage without a long preview run.
module ui_bars_config_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,h=0,de=0;reg [23:0] rgb=0;reg [51:0] cfg=0;
 wire ov,oh,od;wire [23:0] out;
 wb_ui_overlay #(.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex"),
  .TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex")) dut(
  .I_clk(clk),.I_rst_n(rst),.I_latency(9'd0),.I_diagnostics(24'd0),.I_underflow(8'd0),.I_config(cfg),.I_ae_telemetry(10'd80),
  .I_hist_height(8'd0),.I_hist_valid(1'b0),
  .I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),
  .I_target_info({3'd4,4'd3,12'h060,12'h030,1'b1,20'h01234}),
  .I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),
  .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 function [23:0] scene(input integer x,y);
  reg [7:0] a,b,c;begin a=37+(x%193);b=41+(y%181);c=19+((x+y)%199);scene={a,b,c};end
 endfunction
 function [23:0] half(input [23:0] a,b);
  integer rr,gg,bb;begin rr=(a[23:16]+b[23:16])/2;gg=(a[15:8]+b[15:8])/2;bb=(a[7:0]+b[7:0])/2;half={rr[7:0],gg[7:0],bb[7:0]};end
 endfunction
 function full_row(input integer y,f);
  begin
   if(f<8)case(y)
    0,10,20,24,30,43,44,63,64,67,68,72,79,80,112,132,175,192,212,256,
    272,292,336,400,424,471,472,547,548,552,555,565,566,574,597,599:full_row=1;
    default:full_row=0;
   endcase
   else case(y)0,24,63,64,79,548,599:full_row=1;default:full_row=0;endcase
  end
 endfunction
 reg [2:0] pv=0,ph=0,pd=0;
 integer px[0:2],py[0:2],pp[0:2];reg pb[0:2];reg [23:0] source[0:2];
 integer f,x,y,width,page,hide,checks=0,pixels=0,returns=0,hidden=0,awb=0,menus=0,reset_button=0;
 integer k,xx,yy;reg verify;reg [23:0] expected;
 always @(posedge clk)begin
  pv={pv[1:0],v};ph={ph[1:0],h};pd={pd[1:0],de};
  for(k=2;k>0;k=k-1)begin px[k]=px[k-1];py[k]=py[k-1];pp[k]=pp[k-1];pb[k]=pb[k-1];source[k]=source[k-1];end
  px[0]=x;py[0]=y;pp[0]=page;pb[0]=hide;source[0]=rgb;
  #1;
  if(rst)begin
   if({ov,oh,od}!=={pv[2],ph[2],pd[2]})$fatal(1,"UI sync/pixel latency changed");
   if(od)begin
    pixels=pixels+1;if(^out===1'bx)$fatal(1,"unknown UI pixel");
    xx=px[2];yy=py[2];verify=0;expected=source[2];
    // All bar pixels, including prior glyphs/HUD, must disappear in preview.
    if(pb[2]&&pp[2]==0&&(yy<64||yy>=548))begin
     verify=1;hidden=hidden+1;
    end
    // Hidden left-side bars on any settings page reveal exact live pixels.
    if(pb[2]&&pp[2]!=0&&xx<560&&(yy<64||yy>=548))begin
     verify=1;hidden=hidden+1;
    end
    // Visible left bars keep their original darkened per-channel video.
    // Avoid their text bounding rectangles; this is a background oracle.
    if(!pb[2]&&xx<560&&(yy<64||yy>=548)&&
      !(yy>=20&&yy<44)&&!(yy>=552&&yy<566)&&!(yy>=574&&yy<598))begin
     verify=1;expected={2'b0,source[2][23:18],2'b0,source[2][15:10],2'b0,source[2][7:2]};
    end
    // Every menu panel occupies the full right edge, including both bar bands.
    if(pp[2]!=0&&(xx==570||xx==1010)&&(yy<64||yy>=548))begin
     verify=1;expected=half(source[2],24'h111e2c);menus=menus+1;
    end
    // Entire return rectangle outside glyph bounds, crossing y=64 unchanged.
    if(pp[2]!=0&&xx>=584&&xx<688&&yy>=24&&yy<80&&
       !(xx>=612&&xx<660&&yy>=44&&yy<68))begin
     verify=1;expected=half(source[2],24'h34495e);returns=returns+1;
    end
    // The removed AWB target button must leave only transparent panel pixels.
    if(pp[2]==2&&xx>=600&&xx<1000&&yy>=400&&yy<472)begin
     verify=1;expected=half(source[2],24'h111e2c);awb=awb+1;
    end
    // Tint reset control extends through y=548; the bottom bar must not clip it.
    if(pp[2]==6&&xx>=584&&xx<1000&&yy>=520&&yy<576&&
       !(xx>=768&&xx<816&&yy>=540&&yy<564))begin
     verify=1;expected=half(source[2],24'h087f83);reset_button=reset_button+1;
    end
    if(verify)begin
     checks=checks+1;
     if(out!==expected)$fatal(1,"UI layer/bar config page=%0d hide=%0d pixel=%0d,%0d got=%h expected=%h",pp[2],pb[2],xx,yy,out,expected);
    end
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<14;f=f+1)begin
   case(f)0,1:page=7;2,3:page=8;4:page=2;5:page=0;6:page=6;7:page=12;
    8:page=1;9:page=4;10:page=5;11:page=9;12:page=10;13:page=11;endcase
   hide=(f==1||f==3||f==5||f==7);
   cfg={7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b1,1'b0,4'(page),2'd0,1'b0,1'(hide),7'd30,7'd80,3'd0,1'b1};
   if(f==5)begin cfg[0]=0;cfg[21]=1;end // Hidden preview must suppress offline and manual-K text too.
   for(y=0;y<600;y=y+1)begin
    width=full_row(y,f)?1024:1;
    for(x=0;x<width;x=x+1)begin
     // Alternate separate VS and coincident first-pixel VS across complete frames.
     if(x==0&&y==0&&f%2==0)begin v=1;de=0;repeat(3)@(negedge clk);v=0;repeat(3)@(negedge clk);end
     v=(f%2==1&&x==0&&y==0);de=1;rgb=scene(x,y);@(negedge clk);
     // Adversarial mailbox edit must not change any pixel in this frame.
     if(y==200&&x==0)cfg[18]=!hide;
    end
    de=0;v=0;h=1;repeat(3)@(negedge clk);h=0;
   end
   repeat(8)@(negedge clk);
  end
  if(checks<50000||returns<5000||hidden<30000||awb<1000||menus<100||reset_button<2000)$fatal(1,"insufficient independent probes");
  $display("PASS UI layering and bar frame config: %0d output pixels, %0d independent exact probes, %0d return rectangle pixels across y64, %0d hidden bar pixels including offline/manual text, %0d AWB removed-button pixels, %0d tint reset pixels crossing y548, all menu pages, first-pixel VS/sync latency and mid-frame no tearing",pixels,checks,returns,hidden,awb,reset_button);
  $finish;
 end
 initial begin #15000000;$fatal(1,"UI layering watchdog");end
endmodule
