`timescale 1ns/1ps
module hud_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,h=0,de=0;reg [35:0] cfg=0;reg [51:0] info=0;
 wire ov,oh,od;wire [23:0] rgb;
 wb_ui_overlay #(.HUD_ENABLE(1),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) dut(.I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_telemetry({1'b1,12'd1024,12'd1024,12'd1024}),.I_target_info(info),.I_vsync(v),.I_hsync(h),.I_de(de),.I_data(24'h123456),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(rgb));
 integer f,x,y,ox=0,oy=0,seen=0,field,dx,pos,row,col,fd=0;reg old_v=0;reg [1:0] pv=0,ph=0,pd=0;
 reg [127:0] expected_status,expected_fps,expected_det,expected_lat,text;
 reg [7:0] expected_char;wire [34:0] glyph;reg [23:0] expected,status_color;reg on,bit_on;
 target_ascii_font oracle(.I_char(expected_char),.I_row(3'd0),.O_bits(),.O_glyph(glyph));
 always @(posedge clk)begin
  pv={pv[0],v};ph={ph[0],h};pd={pd[0],de};#1;
  if(rst)begin
   if({ov,oh,od}!=={pv[1],ph[1],pd[1]})$fatal(1,"HUD changed UI video latency");
   if(ov&&!old_v)begin ox=0;oy=0;end old_v=ov;
   if(od)begin
    if(^rgb===1'bx)$fatal(1,"Unknown HUD pixel");
    if(oy>=552&&oy<566&&ox<560)begin
     on=0;dx=0;text=0;field=0;
     if(ox>=16&&ox<136)begin on=1;dx=ox-16;text=expected_status;field=0;end
     else if(ox>=152&&ox<236)begin on=1;dx=ox-152;text=expected_fps;field=1;end
     else if(ox>=260&&ox<344)begin on=1;dx=ox-260;text=expected_det;field=2;end
     else if(ox>=368&&ox<512)begin on=1;dx=ox-368;text=expected_lat;field=3;end
     pos=dx/12;row=(oy-552)/2;col=(dx/2)%6;expected_char=text>>((15-pos)*8);#0;
     expected=24'h040d15;bit_on=on&&col<5&&glyph[(6-row)*5+4-col];
     if(bit_on)expected=field==0?status_color:24'hf3f6fa;
     if(rgb!==expected)$fatal(1,"Footer glyph/frame snapshot mismatch f=%0d pixel=%0d,%0d got=%h expected=%h char=%h",f,ox,oy,rgb,expected,expected_char);
     seen=seen+1;
    end
    if(f==1&&oy==530&&ox==458&&rgb!==24'h123456)$fatal(1,"Status outside bottom information bar");
    if(f<3)$fwrite(fd,"%c%c%c",rgb[23:16],rgb[15:8],rgb[7:0]);
    if(ox==1023)begin ox=0;oy=oy+1;end else ox=ox+1;
   end
  end
 end
 initial begin
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<5;f=f+1)begin
   cfg={2'd0,1'b0,5'd0,5'd0,1'b1,3'(f==1?2:f==2?6:0),2'd0,2'd0,7'd30,7'd80,1'b1};
   case(f)
    0:begin info={3'd4,4'd8,12'h060,12'h030,1'b1,20'h01234};expected_status="RUN:8           ";expected_fps="FPS: 60         ";expected_det="DET: 30         ";expected_lat="LAT: 12.34ms    ";status_color=24'h50df90;end
    1:begin info={3'd3,4'd0,12'h059,12'h025,1'b1,20'h02005};expected_status="NO TARGET       ";expected_fps="FPS: 59         ";expected_det="DET: 25         ";expected_lat="LAT: 20.05ms    ";status_color=24'hff6060;end
    2:begin info={3'd2,4'd8,12'h060,12'h020,1'b1,20'h10203};expected_status="LIMIT           ";expected_fps="FPS: 60         ";expected_det="DET: 20         ";expected_lat="LAT:102.03ms    ";status_color=24'hffb43c;end
    3:begin info={3'd1,4'd0,12'h000,12'h000,1'b0,20'h00000};expected_status="WAIT            ";expected_fps="FPS:  0         ";expected_det="DET:  0         ";expected_lat="LAT:---.--ms    ";status_color=24'hb6c6d8;end
    4:begin info={3'd0,4'd0,12'h060,12'h000,1'b0,20'h00000};expected_status="OFF             ";expected_fps="FPS: 60         ";expected_det="DET:  0         ";expected_lat="LAT:---.--ms    ";status_color=24'hb6c6d8;end
   endcase
   if(f<3)begin fd=$fopen($sformatf("hud_state_%0d.ppm",f),"wb");if(fd==0)$fatal(1,"HUD preview open");$fwrite(fd,"P6\n1024 600\n255\n");end
   v=1;repeat(4)@(negedge clk);v=0;repeat(4)@(negedge clk);
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin
     de=1;if(y==200&&x==500)info=52'hfffffffffffff;@(negedge clk);
    end
    de=0;h=1;repeat(3)@(negedge clk);h=0;
   end
   repeat(5)@(negedge clk);if(f<3)$fclose(fd);
  end
  if(seen!=5*560*14)$fatal(1,"HUD pixel coverage");
  $display("PASS information bar: 39200 exact output pixels across RUN/NO TARGET/LIMIT/WAIT/OFF, display FPS/detection FPS/0.01ms latency strings, preview/auto/tint pages, frame-latched metadata under mid-frame edits, status inside footer and unchanged two-cycle UI video");$finish;
 end
 initial begin #60000000;$fatal(1,"HUD watchdog");end
endmodule
