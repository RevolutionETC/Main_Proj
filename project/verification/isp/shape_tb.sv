`timescale 1ns/1ps
module shape_classify_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,valid=0,red=0;reg [10:0] x=0,y=0;
 wire found,ready;wire [1:0] shape;wire [10:0] l,r,t,b,cx,cy;
 red_target_detect #(.CONFIRM_FRAMES(1)) dut(.I_clk(clk),.I_rst_n(rst),.I_frame_start(fs),.I_enable(1'b1),
  .I_valid(valid),.I_red(red),.I_x(x),.I_y(y),.O_found(found),.O_left(l),.O_right(r),.O_top(t),.O_bottom(b),.O_cx(cx),.O_cy(cy),.O_shape(shape),.O_shape_ready(ready));
 reg [1023:0] mask_rows[0:599];reg [95:0] metadata[0:22];reg [95:0] meta;
 integer i,xx,yy,cycles,max_cycles=0;
 task sof;begin fs=1;valid=0;@(negedge clk);fs=0;repeat(3)@(negedge clk);end endtask
 initial begin
  $readmemh("../fixtures/metadata.hex",metadata);
  repeat(4)@(negedge clk);rst=1;
  for(i=0;i<23;i=i+1)begin
   $readmemh($sformatf("../fixtures/%02d.hex",i),mask_rows);meta=metadata[i];sof();
   for(yy=0;yy<600;yy=yy+1)begin
    for(xx=0;xx<1024;xx=xx+1)begin
     x=xx;y=yy;valid=1;red=mask_rows[yy][1023-xx]&&meta[72:69]<2;@(negedge clk);
    end
    valid=0;repeat(3)@(negedge clk);
   end
   sof();cycles=0;
   while(!ready&&cycles<20000)begin @(negedge clk);cycles=cycles+1;end
   if(cycles>max_cycles)max_cycles=cycles;
   if(!ready)$fatal(1,"Classifier timeout case=%0d",i);
   if(found!==meta[2])$fatal(1,"Presence case=%0d",i);
   if(found&&{l,r,t,b,cx,cy}!=={meta[13:3],meta[24:14],meta[35:25],meta[46:36],meta[57:47],meta[68:58]})$fatal(1,"Shape bbox/center case=%0d",i);
   if(shape!==meta[1:0])begin
    $display("DEBUG case=%d shape=%d expect=%d state=%d rounderr=%d area=%d spans=%d roundok=%b concave=%b lp=%d pieces=%d caps=%d",i,shape,meta[1:0],dut.shape_classifier.state,dut.shape_classifier.round_error,dut.shape_classifier.box_area,dut.shape_classifier.spans,dut.shape_classifier.round_ok,dut.shape_classifier.concave,dut.shape_classifier.left_pieces,dut.shape_classifier.pieces,dut.shape_classifier.caps);
    $fatal(1,"Shape class case=%0d",i);
   end
   $display("CASE %0d class=%0d blank_cycles=%0d",i,shape,cycles);
  end
  // The descriptor memory has no effect if the new frame arrives too soon.
  $readmemh("../fixtures/00.hex",mask_rows);sof();
  for(yy=0;yy<600;yy=yy+1)begin
   for(xx=0;xx<1024;xx=xx+1)begin x=xx;y=yy;valid=1;red=mask_rows[yy][1023-xx];@(negedge clk);end
   valid=0;repeat(2)@(negedge clk);
  end
  sof();x=0;y=0;valid=1;red=0;@(negedge clk);valid=0;
  if(shape!=0||!ready)$fatal(1,"Short blanking must fail closed");
  $display("PASS shape classifier: 23 independent sphere/projected-3D-cube/triangle/negative fixtures, highlights/shadow, rotation/perspective, exact bbox/center, clipped/small/empty rejection, short-blank abort; max_blank_cycles=%0d",max_cycles);$finish;
 end
 initial begin #180000000;$fatal(1,"Shape classifier watchdog");end
endmodule

module shape_video_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,en=1,v=0,h=0,de=0;reg [2:0] page=0;reg [23:0] rgb=0;
 wire ov,oh,od;wire [23:0] data;
 red_target_video dut(.I_clk(clk),.I_rst_n(rst),.I_enable(en),.I_page(page),.I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),
  .O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(data));
 reg [38:0] c1=0,c2=0,c3=0,frame_cfg=0;reg vsd=0;
 wire [38:0] cfg={1'b0,5'd0,5'd0,en,1'b0,{1'b0,page},2'd0,2'd0,7'd30,7'd80,3'd0,1'b1};
 always @(posedge clk)begin
  vsd<=v;if(v&&!vsd)frame_cfg<=cfg;
  c1<=(v&&!vsd)?cfg:frame_cfg;c2<=c1;c3<=c2;
 end
 wire uv,uh,ud;wire [23:0] ui_data;
 wb_ui_overlay #(.TEXT_FILE("../../user_source/hdl_source/ui/wb_ui_text.hex"),.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) ui(
 .I_clk(clk),.I_rst_n(rst),.I_config(c3),.I_telemetry({1'b1,12'd1536,12'd1024,12'd768}),
 .I_vsync(ov),.I_hsync(oh),.I_de(od),.I_data(data),.O_vsync(uv),.O_hsync(uh),.O_de(ud),.O_data(ui_data));
 reg [1023:0] mask_rows[0:599];reg [95:0] metadata[0:22];reg [95:0] meta;
 integer item,case_id,frame_no,xx,yy,fd=0,ui_fd=0,count=0,total=0;
 reg dv0=0,dh0=0,dd0=0,dv1=0,dh1=0,dd1=0;
 always @(posedge clk)if(rst)begin
  #1;
  if({ov,oh,od}!=={dv1,dh1,dd1})$fatal(1,"Shape video latency");
  dv1=dv0;dh1=dh0;dd1=dd0;dv0=v;dh0=h;dd0=de;
  if(od)begin
   if(^data===1'bx)$fatal(1,"Unknown shape video pixel");
   if(fd)begin $fwrite(fd,"%c%c%c",data[23:16],data[15:8],data[7:0]);count=count+1;end
   total=total+1;
  end
  if(ud&&ui_fd)$fwrite(ui_fd,"%c%c%c",ui_data[23:16],ui_data[15:8],ui_data[7:0]);
 end
 task start_frame;
  begin v=1;de=0;repeat(4)@(negedge clk);v=0;repeat(22000)@(negedge clk);end
 endtask
 task image;
  begin
   for(yy=0;yy<600;yy=yy+1)begin
    for(xx=0;xx<1024;xx=xx+1)begin
     de=1;rgb=mask_rows[yy][1023-xx]?((meta[72:69]==2)?24'h20d028:24'hc82428):24'he0e0e0;
     @(negedge clk);
    end
    de=0;h=1;repeat(3)@(negedge clk);h=0;
   end
   repeat(12)@(negedge clk);
  end
 endtask
 initial begin
  $readmemh("../fixtures/metadata.hex",metadata);repeat(4)@(negedge clk);rst=1;
  for(item=0;item<6;item=item+1)begin
   case(item)0:case_id=0;1:case_id=7;2:case_id=11;3:case_id=12;4:case_id=22;5:case_id=7;endcase
   page=(item==5)?2:0;
   $readmemh($sformatf("../fixtures/%02d.hex",case_id),mask_rows);meta=metadata[case_id];
   // Explicitly disable between scenes so confirmations cannot cross objects.
   en=0;start_frame();image();en=1;
   for(frame_no=0;frame_no<3;frame_no=frame_no+1)begin
    start_frame();
    if(frame_no==2)begin
     if(dut.found!==meta[2]||dut.raw_shape!==meta[1:0])$fatal(1,"Video class/presence scene=%0d",item);
     if(dut.label_x+252>((page==0)?1024:560)||dut.label_y<64||dut.label_y+24>548)$fatal(1,"Label bounds");
     if(dut.found&&dut.label_y<dut.top&&dut.label_y+24>dut.top)$fatal(1,"Above-box label overlap");
     fd=$fopen($sformatf("shape_scene_%0d.ppm",item),"wb");$fwrite(fd,"P6\n1024 600\n255\n");count=0;
     ui_fd=$fopen($sformatf("shape_ui_%0d.ppm",item),"wb");$fwrite(ui_fd,"P6\n1024 600\n255\n");
    end
    image();
    if(frame_no==2)begin
     $fclose(fd);$fclose(ui_fd);fd=0;ui_fd=0;
     if(count!=614400)$fatal(1,"Shape screenshot count");
     if(dut.render_shape!==meta[1:0])$fatal(1,"Frame-frozen class label");
    end
   end
  end
  $display("PASS shape video/UI chain: default two-frame confirmation, BALL/CUBE/UNKNOWN/NO TARGET, target-anchored bounded label, auto-page target switch, full 1024x600 RGB output and three-cycle video controls; pixels=%0d",total);$finish;
 end
 initial begin #180000000;$fatal(1,"Shape video watchdog");end
endmodule
