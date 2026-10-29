// Legacy module name retained for the stable top-level connection.
// Red connected components -> affine moment shapes -> stable red annotations.
module reference_red_target_video #(
 parameter WIDTH=1024,HEIGHT=600,R_MIN=80,RG_MARGIN=32,RB_MARGIN=24,
 parameter MIN_PIXELS=1200,MIN_WIDTH=32,MIN_HEIGHT=32,MAX_OBJECTS=8,BOX_THICKNESS=3
)(
 input wire I_clk,I_rst_n,I_enable,input wire [2:0] I_page,input wire [1:0] I_effect,
 input wire I_vsync,I_hsync,I_de,input wire [23:0] I_data,
 output reg O_vsync,O_hsync,O_de,output reg [23:0] O_data
);
 reg vs_d,de_d,enabled;reg [2:0] page;reg [10:0] xc,yc;
 wire fs=I_vsync&&!vs_d;
 wire en=fs?I_enable:enabled;wire [2:0] pg=fs?I_page:page;
 wire [10:0] x=fs?11'd0:xc,y=fs?11'd0:yc;
 wire [9:0] r={2'd0,I_data[23:16]},g={2'd0,I_data[15:8]},b={2'd0,I_data[7:0]};
 wire red=r>=R_MIN&&r>=g+RG_MARGIN&&r>=b+RB_MARGIN&&(r<<1)>=g+(g<<1)&&(r<<1)>=b+(b<<1)&&g<=b+48;
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
  v1<=I_vsync;h1<=I_hsync;d1<=I_de;fs1<=fs;en1<=en;pg1<=pg;color1<=red?2'd1:2'd0;x1<=x;y1<=y;rgb1<=I_data;
  v2<=v1;h2<=h1;d2<=d1;en2<=en1;pg2<=pg1;x2<=x1;y2<=y1;rgb2<=rgb1;
 end
 wire capture_start,capture_bank,capture_limit,ana_busy,ana_done,read_bank,ana_limit,stable_busy,mask_busy;
 wire [12:0] capture_runs;wire [11:0] read_addr;wire [39:0] run_data;wire [6:0] root;
 wire [31:0] dropped;
 reg [15:0] frame_id,capture_id,paint_id;
 wire [15:0] result_age=frame_id+16'd1-capture_id;
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin frame_id<=0;capture_id<=0;paint_id<=0;end
 else begin
  if(fs)frame_id<=frame_id+1'b1;
  if(capture_start)capture_id<=frame_id-1'b1;
  if(ana_done)begin paint_id<=frame_id+1'b1;end
 end
 reference_color_components #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_LINE_RUNS(32)) components(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_frame_start(fs1),.I_enable(en1),.I_de(d1),.I_x(x1),.I_y(y1),.I_color(color1),
  .I_analyzer_busy(ana_busy||stable_busy||mask_busy),.O_start(capture_start),.O_bank(capture_bank),.O_runs(capture_runs),
  .O_limit(capture_limit),.O_dropped(dropped),.I_read_bank(read_bank),.I_read_addr(read_addr),.O_read_data(run_data),.I_label(run_data[6:0]),.O_root(root));
 wire [MAX_OBJECTS*48-1:0] ana_objects;wire [3:0] ana_count;
 reference_multi_shape_analyzer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_OBJECTS(MAX_OBJECTS),.MIN_PIXELS(MIN_PIXELS),.MIN_WIDTH(MIN_WIDTH),.MIN_HEIGHT(MIN_HEIGHT)) analyzer(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(capture_start),.I_cancel(fs1&&!en1),.I_bank(capture_bank),.I_runs(capture_runs),
  .O_busy(ana_busy),.O_done(ana_done),.O_read_bank(read_bank),.O_read_addr(read_addr),.I_read_data(run_data),.I_root(root),
  .O_objects(ana_objects),.O_count(ana_count),.O_limit(ana_limit));
 wire stable_done,stable_limit;wire [MAX_OBJECTS*48-1:0] stable_objects;wire [3:0] stable_count;
 reference_target_shape_stabilizer #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_OBJECTS(MAX_OBJECTS)) stabilizer(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(ana_done),.I_cancel(fs1&&(!en1||capture_limit)),
  .I_frame_id(capture_id),.I_age(result_age>3?4'd0:result_age[3:0]),
  .I_objects(ana_objects),.I_count(ana_count),.I_limit(ana_limit),.O_busy(stable_busy),.O_done(stable_done),
  .O_objects(stable_objects),.O_count(stable_count),.O_limit(stable_limit));
 reg front,pending_bank,pending_valid,front_valid;
 reg [15:0] pending_id;wire mask_done,mask_ink;
 wire swap=fs&&pending_valid&&pending_id==frame_id+1'b1;
 wire read_bank_now=swap?pending_bank:front;
 wire annotations_valid=swap?1'b1:front_valid;
 reference_target_mask #(.WIDTH(WIDTH),.HEIGHT(HEIGHT),.MAX_OBJECTS(MAX_OBJECTS)) painter(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(stable_done),.I_cancel(fs&&!en),.I_write_bank(!front),
  .I_objects(stable_objects),.I_limit(stable_limit),.O_busy(mask_busy),.O_done(mask_done),
  .I_read_bank(read_bank_now),.I_x(x),.I_y(y),.O_ink(mask_ink));
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin front<=0;pending_bank<=0;pending_valid<=0;front_valid<=0;pending_id<=0;end
 else begin
  if(mask_done)begin pending_bank<=!front;pending_id<=paint_id;pending_valid<=1;end
  if(fs)begin
   if(!en)begin front_valid<=0;pending_valid<=0;end
   else if(swap)begin front<=pending_bank;front_valid<=1;pending_valid<=0;end
   else begin front_valid<=0;if(pending_valid)pending_valid<=0;end
  end
 end
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
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin effect<=0;effect1<=0;mask_valid1<=0;gray1<=0;left_gray<=0;left1<=0;upper_left<=0;display2<=0;end
 else begin
  if(fs)effect<=I_effect;
  effect1<=fs?I_effect:effect;mask_valid1<=en&&annotations_valid;
  gray1<=gray;left1<=x==0?gray:left_gray;if(I_de)left_gray<=gray;
  if(d1)upper_left<=upper;
  display2<=mask_valid1&&mask_ink&&(pg1==0||x1<560)?24'hff2020:
   effect1==1?{edge_level,edge_level,edge_level}:effect1==2?enhanced:rgb1;
 end
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin O_vsync<=0;O_hsync<=0;O_de<=0;O_data<=0;end
 else begin O_vsync<=v2;O_hsync<=h2;O_de<=d2;O_data<=d2?display2:24'd0;end
endmodule
