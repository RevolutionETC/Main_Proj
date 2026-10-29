// Legacy module name retained for the stable top-level connection.
// Successful red pipeline extended with conservative blue/green gates.
// Shape decisions, class hysteresis and motion rules remain the red baseline.
module red_target_video #(
 parameter USE_ISP_FILTERS=0,HTOTAL=1344,parameter CLOCK_HZ=52173913,WIDTH=1024,HEIGHT=600,R_MIN=80,RG_MARGIN=32,RB_MARGIN=24,
 parameter B_MIN=64,BG_MARGIN=20,BR_MARGIN=20,
 parameter G_MIN=64,GR_MARGIN=20,GB_MARGIN=20,
 parameter MIN_PIXELS=1200,MIN_WIDTH=32,MIN_HEIGHT=32,MAX_OBJECTS=8,BOX_THICKNESS=3
)(
 input wire I_clk,I_rst_n,I_enable,input wire [2:0] I_page,input wire [1:0] I_effect,
 input wire [2:0] I_image_mode,input wire I_vsync,I_hsync,I_de,input wire [23:0] I_data,
 output wire [51:0] O_info,
 output reg O_vsync,O_hsync,O_de,output reg [23:0] O_data
);
 reg vs_d,de_d,enabled;reg [2:0] page;reg [10:0] xc,yc;
 wire fs=I_vsync&&!vs_d;
 wire en=fs?I_enable:enabled;wire [2:0] pg=fs?I_page:page;
 wire [10:0] x=fs?11'd0:xc,y=fs?11'd0:yc;
 wire [9:0] r={2'd0,I_data[23:16]},g={2'd0,I_data[15:8]},b={2'd0,I_data[7:0]};
 wire red=r>=R_MIN&&r>=g+RG_MARGIN&&r>=b+RB_MARGIN&&(r<<1)>=g+(g<<1)&&(r<<1)>=b+(b<<1)&&g<=b+48;
 // Blue/green use clear dominant-channel differences and a 1.2x ratio.
 // The original red predicate above is unchanged; weak background casts fail.
 wire blue=b>=B_MIN&&b>=g+BG_MARGIN&&b>=r+BR_MARGIN&&({b,2'b0}+{2'b0,b})>=({g,2'b0}+{1'b0,g,1'b0})&&({b,2'b0}+{2'b0,b})>=({r,2'b0}+{1'b0,r,1'b0});
 wire green=g>=G_MIN&&g>=r+GR_MARGIN&&g>=b+GB_MARGIN&&({g,2'b0}+{2'b0,g})>=({r,2'b0}+{1'b0,r,1'b0})&&({g,2'b0}+{2'b0,g})>=({b,2'b0}+{1'b0,b,1'b0});
 reg v1,h1,d1,fs1,en1;reg [1:0] color1;reg [2:0] pg1;reg [10:0] x1,y1;reg [23:0] rgb1;
 reg v2,h2,d2,en2;reg [2:0] pg2;reg [10:0] x2,y2;reg [23:0] rgb2;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  vs_d<=0;de_d<=0;enabled<=0;page<=0;xc<=0;yc<=0;
  v1<=0;h1<=0;d1<=0;fs1<=0;en1<=0;color1<=0;pg1<=0;x1<=0;y1<=0;rgb1<=0;
  v2<=0;h2<=0;d2<=0;en2<=0;pg2<=0;x2<=0;y2<=0;rgb2<=0;
 end else begin
  vs_d<=I_vsync;de_d<=I_de;
  if(fs)begin enabled<=I_enable;page<=I_page;xc<=I_de?11'd1:11'd0;yc<=0;end
  else begin if(I_de)xc<=xc+1'b1;else xc<=0;if(de_d&&!I_de)yc<=yc+1'b1;end
  v1<=I_vsync;h1<=I_hsync;d1<=I_de;fs1<=fs;en1<=en;pg1<=pg;color1<=red?2'd1:blue?2'd2:green?2'd3:2'd0;x1<=x;y1<=y;rgb1<=I_data;
  v2<=v1;h2<=h1;d2<=d1;en2<=en1;pg2<=pg1;x2<=x1;y2<=y1;rgb2<=rgb1;
 end
 wire capture_start,capture_bank,capture_limit,ana_busy,ana_done,read_bank,ana_limit,stable_busy,mask_busy;
 wire [12:0] capture_runs;wire [11:0] read_addr;wire [39:0] run_data;wire [6:0] color_label;wire [1:0] label_color;wire [6:0] root;
 wire [31:0] dropped;
 reg [15:0] frame_id,capture_id;
 wire [15:0] result_age=frame_id+16'd1-capture_id;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin frame_id<=0;capture_id<=0;end
 else begin
  if(fs)frame_id<=frame_id+1'b1;
  if(capture_start)capture_id<=frame_id-1'b1;
 end
 color_components #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_LINE_RUNS(32)) components(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_frame_start(fs1),.I_enable(en1),.I_de(d1),.I_x(x1),.I_y(y1),.I_color(color1),
  .I_analyzer_busy(ana_busy||stable_busy||mask_busy),.O_start(capture_start),.O_bank(capture_bank),.O_runs(capture_runs),
  .O_limit(capture_limit),.O_dropped(dropped),.I_read_bank(read_bank),.I_read_addr(read_addr),.O_read_data(run_data),.I_label(run_data[6:0]),.O_root(root),.I_color_label(color_label),.O_label_color(label_color));
 wire [MAX_OBJECTS*48-1:0] ana_geometry;wire [MAX_OBJECTS*2-1:0] ana_colors;
 wire [MAX_OBJECTS*50-1:0] ana_objects;wire [3:0] ana_count;
 multi_shape_analyzer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_OBJECTS(MAX_OBJECTS),.MIN_PIXELS(MIN_PIXELS),.MIN_WIDTH(MIN_WIDTH),.MIN_HEIGHT(MIN_HEIGHT)) analyzer(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(capture_start),.I_cancel(fs1&&!en1),.I_bank(capture_bank),.I_runs(capture_runs),
  .O_busy(ana_busy),.O_done(ana_done),.O_read_bank(read_bank),.O_read_addr(read_addr),.I_read_data(run_data),.I_root(root),
  .O_objects(ana_geometry),.O_colors(ana_colors),.O_color_label(color_label),.I_label_color(label_color),.O_count(ana_count),.O_limit(ana_limit));
 wire stable_done,stable_limit;wire [MAX_OBJECTS*50-1:0] stable_objects;wire [MAX_OBJECTS*48-1:0] stable_geometry;wire [MAX_OBJECTS*2-1:0] stable_colors;wire [3:0] stable_count;
 target_shape_stabilizer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_OBJECTS(MAX_OBJECTS)) stabilizer(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(ana_done),.I_cancel(fs1&&(!en1||capture_limit)),
  .I_frame_id(capture_id),.I_age(result_age>3?4'd0:result_age[3:0]),
  .I_objects(ana_geometry),.I_colors(ana_colors),.I_count(ana_count),.I_limit(ana_limit),.O_busy(stable_busy),.O_done(stable_done),
  .O_objects(stable_geometry),.O_colors(stable_colors),.O_count(stable_count),.O_limit(stable_limit));
 // Debug descriptor views preserve the existing testbench interface only.
 // Hardware classification/tracking use the successful 48-bit geometry words.
 genvar object_i;
 generate for(object_i=0;object_i<MAX_OBJECTS;object_i=object_i+1)begin: descriptor_view
  assign ana_objects[object_i*50+:50]={ana_colors[object_i*2+:2],ana_geometry[object_i*48+:48]};
  assign stable_objects[object_i*50+:50]={stable_colors[object_i*2+:2],stable_geometry[object_i*48+:48]};
 end endgenerate
 wire [2:0] target_status;wire [3:0] target_count;
 wire draw_vs,draw_hs,draw_de;wire [23:0] draw_data;
 generate if(USE_ISP_FILTERS)begin: FILTERED
  display_filter #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.HTOTAL(HTOTAL)) filters(
   .clk(I_clk),.rst_n(I_rst_n),.mode_i(I_image_mode),
   .vs_i(I_vsync),.hs_i(I_hsync),.de_i(I_de),.rgb_i(I_data),
   .vs_o(draw_vs),.hs_o(draw_hs),.de_o(draw_de),.rgb_o(draw_data));
 end else begin: UNFILTERED
  assign draw_vs=I_vsync;assign draw_hs=I_hsync;assign draw_de=I_de;assign draw_data=I_data;
 end endgenerate
 reg draw_vs_d,draw_de_d;reg [10:0] draw_xc,draw_yc;
 wire draw_fs=draw_vs&&!draw_vs_d;
 wire [10:0] draw_x=draw_fs?11'd0:draw_xc,draw_y=draw_fs?11'd0:draw_yc;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin draw_vs_d<=0;draw_de_d<=0;draw_xc<=0;draw_yc<=0;end
 else begin
  draw_vs_d<=draw_vs;draw_de_d<=draw_de;
  if(draw_fs)begin draw_xc<=draw_de?11'd1:11'd0;draw_yc<=0;end
  else begin if(draw_de)draw_xc<=draw_xc+1'b1;else draw_xc<=0;if(draw_de_d&&!draw_de)draw_yc<=draw_yc+1'b1;end
 end
 wire mask_done,front_valid;wire [1:0] mask_color;
 target_mask #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_OBJECTS(MAX_OBJECTS)) painter(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(stable_done),.I_cancel(fs&&!en),
  .I_enable(en),.I_frame_start(fs),.I_objects(stable_geometry),.I_colors(stable_colors),
  .I_limit(stable_limit),.I_capture_limit(capture_limit),.O_busy(mask_busy),.O_done(mask_done),
  .I_x(draw_x),.I_y(draw_y),.O_valid(front_valid),.O_status(target_status),.O_count(target_count),.O_color(mask_color));
 wire [11:0] measured_fps,measured_detection_fps;wire [19:0] measured_latency;wire latency_valid;
 target_video_metrics #(.CLOCK_HZ(CLOCK_HZ)) metrics(.I_clk(I_clk),.I_rst_n(I_rst_n),.I_enable(en),
  .I_frame(fs),.I_start(capture_start),.I_done(mask_done),.O_fps(measured_fps),
  .O_detection_fps(measured_detection_fps),.O_latency(measured_latency),.O_latency_valid(latency_valid));
 assign O_info={target_status,target_count,measured_fps,measured_detection_fps,latency_valid,measured_latency};
 wire annotations_valid=front_valid;
 // Optional display effects are downstream of the red mask input, so edge
 // viewing never destroys the color information used by recognition.
 reg [1:0] effect,effect1;reg mask_valid1;
 wire [9:0] gray_sum={2'b0,I_data[23:16]}+{1'b0,I_data[15:8],1'b0}+{2'b0,I_data[7:0]};
 wire [7:0] gray=gray_sum[9:2];
 (* ram_style="bram" *) reg [7:0] line_gray[0:WIDTH-1];
 reg [7:0] upper,gray1,left_gray,left1,upper_left;
 always @(posedge I_clk)begin
  if(I_de&&x<WIDTH)line_gray[x]<=gray;
  upper<=line_gray[x<WIDTH?x:0];
 end
 function [7:0] contrast(input [7:0] v);
  reg [9:0] q;begin q={2'b0,v}+({2'b0,v}>>2);contrast=q<=32?0:q>=287?255:q-32;end
 endfunction
 wire [8:0] dga=gray1>=upper_left?gray1-upper_left:upper_left-gray1;
 wire [8:0] dgb=left1>=upper?left1-upper:upper-left1;
 wire [9:0] gradient=dga+dgb;
 wire [7:0] edge_level=(x1==0||y1==0||gradient<24)?8'd0:gradient>127?8'd255:{gradient[6:0],1'b0};
 wire [23:0] enhanced={contrast(rgb1[23:16]),contrast(rgb1[15:8]),contrast(rgb1[7:0])};
 reg [23:0] display2;
 reg draw_v1,draw_h1,draw_d1,draw_v2,draw_h2,draw_d2;reg [23:0] draw_rgb1;
 reg [10:0] draw_x1;reg [2:0] draw_pg1;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin draw_v1<=0;draw_h1<=0;draw_d1<=0;draw_v2<=0;draw_h2<=0;draw_d2<=0;draw_rgb1<=0;draw_x1<=0;draw_pg1<=0;end
 else begin
  draw_v1<=draw_vs;draw_h1<=draw_hs;draw_d1<=draw_de;draw_v2<=draw_v1;draw_h2<=draw_h1;draw_d2<=draw_d1;
  draw_rgb1<=draw_data;draw_x1<=draw_x;draw_pg1<=pg;
 end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin effect<=0;effect1<=0;mask_valid1<=0;gray1<=0;left_gray<=0;left1<=0;upper_left<=0;display2<=0;end
 else begin
  if(fs)effect<=I_effect;
  effect1<=fs?I_effect:effect;mask_valid1<=en&&annotations_valid;
  gray1<=gray;left1<=x==0?gray:left_gray;if(I_de)left_gray<=gray;
  if(d1)upper_left<=upper;
  display2<=mask_valid1&&mask_color!=0&&((USE_ISP_FILTERS?draw_pg1:pg1)==0||(USE_ISP_FILTERS?draw_x1:x1)<560)?
   (mask_color==1?24'hff2020:mask_color==2?24'h2860ff:24'h20c040):
   USE_ISP_FILTERS?draw_rgb1:effect1==1?{edge_level,edge_level,edge_level}:effect1==2?enhanced:rgb1;
 end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin O_vsync<=0;O_hsync<=0;O_de<=0;O_data<=0;end
 else begin O_vsync<=USE_ISP_FILTERS?draw_v2:v2;O_hsync<=USE_ISP_FILTERS?draw_h2:h2;O_de<=USE_ISP_FILTERS?draw_d2:d2;O_data<=(USE_ISP_FILTERS?draw_d2:d2)?display2:24'd0;end
endmodule

// Measured rates over one second and processing time in 0.01 ms units.
// CLOCK_HZ is the real display byte-clock frequency, not the testbench clock.
// Latency covers accepted-frame analysis through completed annotation prep;
// camera exposure/capture and waiting for the next display frame are excluded.
module target_video_metrics #(parameter CLOCK_HZ=52173913)(
 input wire I_clk,I_rst_n,I_enable,I_frame,I_start,I_done,
 output reg [11:0] O_fps,O_detection_fps,
 output reg [19:0] O_latency,output reg O_latency_valid
);
 reg [25:0] second_count,phase;
 reg [11:0] frame_count,detection_count;
 reg [19:0] elapsed;reg measuring;
 wire tick=phase>=CLOCK_HZ-100000;
 function [11:0] increment3(input [11:0] a);reg [11:0] q;begin
  q=a;if(a!=12'h999)begin
   if(a[3:0]!=9)q[3:0]=a[3:0]+1'b1;
   else begin q[3:0]=0;if(a[7:4]!=9)q[7:4]=a[7:4]+1'b1;else begin q[7:4]=0;q[11:8]=a[11:8]+1'b1;end end
  end increment3=q;end
 endfunction
 function [19:0] increment5(input [19:0] a);reg [19:0] q;integer k;reg carry;begin
  q=a;carry=1;if(a!=20'h99999)for(k=0;k<5;k=k+1)if(carry)begin
   if(a[k*4+:4]==9)q[k*4+:4]=0;else begin q[k*4+:4]=a[k*4+:4]+1'b1;carry=0;end
  end increment5=q;end
 endfunction
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  second_count<=0;phase<=0;frame_count<=0;detection_count<=0;O_fps<=0;O_detection_fps<=0;
  O_latency<=0;O_latency_valid<=0;elapsed<=0;measuring<=0;
 end else begin
  if(tick)phase<=phase+100000-CLOCK_HZ;else phase<=phase+100000;
  if(second_count==CLOCK_HZ-1)begin
   second_count<=0;O_fps<=I_frame?increment3(frame_count):frame_count;
   O_detection_fps<=I_enable?(I_done?increment3(detection_count):detection_count):12'd0;
   frame_count<=0;detection_count<=0;
  end else begin
   second_count<=second_count+1'b1;
   if(I_frame)frame_count<=increment3(frame_count);
   if(I_enable&&I_done)detection_count<=increment3(detection_count);
  end
  if(!I_enable)begin measuring<=0;elapsed<=0;O_latency<=0;O_latency_valid<=0;detection_count<=0;O_detection_fps<=0;end
  else begin
   if(I_start)begin elapsed<=0;measuring<=1;end
   else if(measuring&&tick)elapsed<=increment5(elapsed);
   if(I_done&&measuring)begin O_latency<=tick?increment5(elapsed):elapsed;O_latency_valid<=1;measuring<=0;end
  end
 end
endmodule
