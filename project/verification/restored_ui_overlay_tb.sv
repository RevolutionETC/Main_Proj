`timescale 1ns/1ps
// Independent output oracle: literal Chinese masks are rendered by a standalone
// generator, with no production text ROM, glyph IDs or generated Verilog input.
module restored_ui_overlay_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,h=0,de=0;reg [51:0] cfg=0;
 localparam [23:0] VIDEO=24'h234567,INK=24'hf3f6fa;
 wire ov,oh,od;wire [23:0] out;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(
 .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_ae_telemetry(10'd80),.I_hist_height(8'd0),.I_hist_valid(1'b0),
 .I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),.I_target_info(52'd0),.I_latency(9'd0),.I_diagnostics(24'd0),.I_underflow(8'd0),
 .I_vsync(v),.I_hsync(h),.I_de(de),.I_data(VIDEO),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 reg [23:0] masks[0:8191];initial $readmemh("../restored_ui_literal_rows.hex",masks);
 function [23:0] half(input [23:0] a,b);integer r,g,c;begin r=(a[23:16]+b[23:16])/2;g=(a[15:8]+b[15:8])/2;c=(a[7:0]+b[7:0])/2;half={r[7:0],g[7:0],c[7:0]};end endfunction
 function fullrow(input integer y);begin fullrow=(y==120||y==200||y==280||y==360||(y>=132&&y<156)||(y>=212&&y<236)||(y>=292&&y<316)||(y>=372&&y<396)||(y>=464&&y<488));end endfunction
 integer f,x,y,width,page,mode,index,filter,k,xx,yy,row,col,selectmode,labelid,lx,ly,length;
 integer px[0:2],py[0:2],frameid[0:2];reg [2:0] pv=0,ph=0,pd=0;reg verify,ink;
 reg [23:0] expected,bg;integer pixels=0,checks=0,letters=0,selected=0;
 always @(posedge clk)begin
  pv={pv[1:0],v};ph={ph[1:0],h};pd={pd[1:0],de};
  for(k=2;k>0;k=k-1)begin px[k]=px[k-1];py[k]=py[k-1];frameid[k]=frameid[k-1];end
  px[0]=x;py[0]=y;frameid[0]=f;#1;
  if(rst)begin
   if({ov,oh,od}!=={pv[2],ph[2],pd[2]})$fatal(1,"restored UI control latency");
   if(od)begin
    pixels=pixels+1;xx=px[2];yy=py[2];verify=0;ink=0;labelid=-1;lx=0;ly=0;length=0;bg=24'h111e2c;
    // All menu rectangles remain 50% transparent. Independent literal masks
    // check every glyph pixel across all restored preset/filter selections.
    if(xx>=584&&xx<1000&&yy>=112&&yy<416)begin
     row=(yy-112)/80;col=xx>=800;selectmode=-1;
     if(page==1&&row<3)begin
      verify=1;selectmode=row;labelid=row;lx=620;ly=132+row*80;length=row==1?4:5;
      if(yy>=112+row*80&&yy<176+row*80)bg=(mode==selectmode)?24'h087f83:24'h26394d;
     end
     if(page==3)begin
      verify=1;selectmode=row==0?5:row==1?30:row==2?40:50;labelid=3+row;lx=620;ly=132+row*80;length=row==0?12:8;
      if(yy>=112+row*80&&yy<176+row*80)bg=(mode==1&&index==selectmode)?24'h087f83:24'h26394d;
     end
     if(page==7)begin
      verify=1;selectmode=row==0?(col?5:0):row==1?(col?6:4):row==2?(col?1:7):(col?3:2);
      labelid=7+row*2+col;lx=col?864:(row==1||row==2?636:648);ly=132+row*80;length=(row==1&&!col)?3:(row==2&&!col)?4:2;
      if(yy>=112+row*80&&yy<176+row*80&&((xx>=584&&xx<784)||(xx>=800&&xx<1000)))bg=(filter==selectmode)?24'h087f83:24'h26394d;
      if(xx>=784&&xx<800)begin labelid=-1;bg=24'h111e2c;end
     end
    end
    if(page==3&&xx>=600&&xx<744&&yy>=464&&yy<488)begin verify=1;labelid=15;lx=600;ly=464;length=6;bg=24'h111e2c;end
    if(verify)begin
     expected=half(bg,VIDEO);
     if(labelid>=0&&xx>=lx&&xx<lx+length*24&&yy>=ly&&yy<ly+24)begin
      ink=masks[labelid*512+((xx-lx)/24)*32+yy-ly][23-(xx-lx)%24];
      if(ink)begin expected=INK;letters=letters+1;end
     end
     if(bg==24'h087f83)selected=selected+1;
     checks=checks+1;if(out!==expected)$fatal(1,"restored UI literal/background f%0d p%0d mode%0d idx%0d filter%0d xy%0d,%0d got%h expected%h label%0d",frameid[2],page,mode,index,filter,xx,yy,out,expected,labelid);
    end
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<16;f=f+1)begin
   if(f<3)begin page=1;mode=f;index=30;filter=0;end
   else if(f<8)begin page=3;mode=f==7?2:1;index=f==3||f==7?5:f==4?30:f==5?40:50;filter=0;end
   else begin page=7;mode=0;index=30;filter=f-8;end
   cfg={7'd50,1'b1,1'b0,1'b0,2'd1,1'b1,1'b0,5'd0,5'd0,1'b0,1'b0,4'(page),2'(mode),1'b0,1'(f%2),7'(index),7'd80,3'(filter),1'b1};
   for(y=0;y<600;y=y+1)begin
    width=fullrow(y)?1024:1;
    for(x=0;x<width;x=x+1)begin v=x==0&&y==0;de=1;h=0;@(negedge clk);if(x==0&&y==250)cfg[21:4]=~cfg[21:4];end
    de=0;v=0;h=1;repeat(3)@(negedge clk);h=0;
   end
   repeat(8)@(negedge clk);
  end
  if(checks<500000||letters<50000||selected<40000)$fatal(1,"insufficient restored UI coverage %d %d %d",checks,letters,selected);
  $display("PASS restored UI independent literal raster: 16 frames, all three WB selected states, all four presets plus manual-no-highlight, eight filter selected states, %0d exact background/glyph probes including %0d foreground pixels, unchanged 50-percent blend, frame-atomic mode/index/filter and control latency",checks,letters);$finish;
 end
 initial begin #50000000;$fatal(1,"restored UI oracle watchdog");end
endmodule

