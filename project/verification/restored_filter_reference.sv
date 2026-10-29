// Shared scalar display filters. One centered 3x3 YCoCg window and one
// Sobel datapath serve edge and enhancement. No extra DDR pass is required.
module restored_filter_reference #(parameter WIDTH=1024,HEIGHT=600,HTOTAL=1344)(
 input wire clk,rst_n,input wire [2:0] mode_i,
 input wire vs_i,hs_i,de_i,input wire [23:0] rgb_i,
 output wire vs_o,hs_o,de_o,output wire [23:0] rgb_o
);
 reg vs_d;reg [2:0] mode;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin vs_d<=0;mode<=0;end
 else begin vs_d<=vs_i;if(vs_i&&!vs_d)mode<=(mode_i==4||mode_i==5||mode_i==6||mode_i==7)?mode_i:3'd0;end
 wire [233:0] win;wire wv;wire [10:0] wx,wy;
 restored_filter_window_reference #(.W(WIDTH),.H(HEIGHT),.HT(HTOTAL)) window(
  .clk(clk),.rst_n(rst_n),.vs(vs_i),.de(de_i),.rgb(rgb_i),
  .win(win),.valid(wv),.x(wx),.y(wy));
 wire [25:0] center=win[4*26+:26];
 wire signed [12:0] co=$signed(center[17:9]),cg=$signed(center[8:0]);
 wire signed [12:0] tt=$signed({5'd0,center[25:18]})-(cg>>>1);
 wire signed [12:0] bb=tt-(co>>>1),gg=cg+tt,rr=bb+co;
 wire [23:0] original={rr[7:0],gg[7:0],bb[7:0]};
 reg [23:0] raw_pipe[0:6];integer k;
 always @(posedge clk)begin
  raw_pipe[0]<=original;for(k=1;k<7;k=k+1)raw_pipe[k]<=raw_pipe[k-1];
 end
 wire [25:0] edge_yc,toned;wire [1:0] edge_level;wire [13:0] magnitude;
 style_sobel edges(.clk(clk),.win_i(win),.yc_o(edge_yc),.level_o(edge_level),.center_o(),.magnitude_o(magnitude));
 enhance_lut tone(.clk(clk),.y_i(edge_yc[25:18]),.y_o(toned[25:18]));
 reg [17:0] chroma;reg [1:0] l0,l1,l2;
 always @(posedge clk)begin chroma<=edge_yc[17:0];l0<=edge_level;l1<=l0;l2<=l1;end
 assign toned[17:0]=chroma;
 wire [23:0] quantized,enhanced;
 style_quantize_color quantize(.clk(clk),.yc_i(toned),.rgb_o(quantized));
 style_quantize_fuse fuse(.clk(clk),.rgb_i(quantized),.level_i(l2),.rgb_o(enhanced));
 reg [23:0] edge_pipe[0:4];integer e;
 always @(posedge clk)begin
  edge_pipe[0]<=(magnitude>=14'd80)?24'hffffff:24'h000000;
  for(e=1;e<5;e=e+1)edge_pipe[e]<=edge_pipe[e-1];
 end
 wire [15:0] weighted=({8'd0,original[23:16]}*16'd77)+({8'd0,original[15:8]}*16'd150)+({8'd0,original[7:0]}*16'd29)+16'd128;
 reg [15:0] noise;reg [23:0] retro_pipe[0:2];wire [23:0] retro;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)noise<=16'h1ace;
 else if(wv)noise<={noise[14:0],noise[15]^noise[13]^noise[12]^noise[10]};
 sepia_pixel #(.W(WIDTH),.H(HEIGHT)) sepia(.clk(clk),.rst_n(rst_n),.rgb_i(original),
  .x_i({1'b0,wx}),.y_i({1'b0,wy}),.noise_i(noise[7:6]),.luma_i(weighted[15:8]),.rgb_o(retro));
 always @(posedge clk)begin retro_pipe[0]<=retro;retro_pipe[1]<=retro_pipe[0];retro_pipe[2]<=retro_pipe[1];end
 (* ram_style="bram" *) reg [7:0] block_row[0:(WIDTH+7)/8-1];
 reg [7:0] block_q,held,sample;reg [10:0] px,py;reg pv;
 wire [7:0] sample_now={original[23:21],original[15:13],original[7:6]};
 always @(posedge clk)begin
  if(wv&&wy[2:0]==0&&wx[2:0]==0)block_row[wx>>3]<=sample_now;
  block_q<=block_row[wx>>3];sample<=sample_now;px<=wx;py<=wy;pv<=wv;
 end
 wire [7:0] block_color=py[2:0]==0?(px[2:0]==0?sample:held):block_q;
 wire [23:0] pixel_color={{block_color[7:5],block_color[7:5],block_color[7:6]},
   {block_color[4:2],block_color[4:2],block_color[4:3]},
   {block_color[1:0],block_color[1:0],block_color[1:0],block_color[1:0]}};
 reg [23:0] pixel_pipe[0:5];integer p;
 always @(posedge clk)begin
  if(pv&&py[2:0]==0&&px[2:0]==0)held<=sample;
  pixel_pipe[0]<=pixel_color;for(p=1;p<6;p=p+1)pixel_pipe[p]<=pixel_pipe[p-1];
 end
 // Read-before-write timing ring; reset only the pointer/valid guard.
 localparam DELAY=HTOTAL+10;
 (* ram_style="bram" *) reg [2:0] sync_ram[0:DELAY-1];
 localparam AW=$clog2(DELAY);reg [AW-1:0] ptr;reg [AW:0] filled;reg [2:0] sync_q;
 always @(posedge clk)begin sync_ram[ptr]<={vs_i,hs_i,de_i};sync_q<=sync_ram[ptr];end
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin ptr<=0;filled<=0;end
 else begin ptr<=(ptr==DELAY-1)?0:ptr+1'b1;if(filled<DELAY)filled<=filled+1'b1;end
 assign {vs_o,hs_o,de_o}=filled>=DELAY?sync_q:3'd0;
 assign rgb_o=!de_o?24'd0:mode==4?pixel_pipe[5]:mode==5?edge_pipe[4]:mode==6?retro_pipe[2]:mode==7?enhanced:raw_pipe[6];
endmodule

// Three rotating banks prevent read/write collisions. The last row is
// replicated during vertical blanking, at the same horizontal line period.
module restored_filter_window_reference #(parameter W=1024,H=600,HT=1344)(
 input wire clk,rst_n,vs,de,input wire [23:0] rgb,
 output reg [233:0] win,output reg valid,output reg [10:0] x,y
);
 reg vs_d,de_d,started,tail_done;reg [10:0] ix,iy,phase;reg [1:0] bank;
 wire fs=vs&&!vs_d;
 wire synth_row=started&&iy==H&&!tail_done&&phase<W;
 wire take=de||synth_row;
 wire [10:0] sx=de?ix:phase;
 wire [1:0] prev=bank==0?2'd2:bank-1'b1,next=bank==2?2'd0:bank+1'b1;
 wire [25:0] encoded;
 enhance_rgb_to_yc encode(.clk(clk),.rgb_i(rgb),.yc_o(encoded));
 reg take1,write1,drain1;reg [10:0] sx1,sy1;reg [1:0] bank1,top1,mid1;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin vs_d<=0;de_d<=0;started<=0;tail_done<=0;ix<=0;iy<=0;phase<=0;bank<=0;
  take1<=0;write1<=0;drain1<=0;sy1<=0;bank1<=0;top1<=0;mid1<=0;
 end else begin
  vs_d<=vs;de_d<=de;take1<=take&&!fs;write1<=de&&!fs;drain1<=synth_row;
  sy1<=iy;bank1<=bank;mid1<=prev;top1<=iy==1?prev:next;
  if(fs)begin started<=0;tail_done<=0;ix<=0;iy<=0;phase<=0;bank<=0;end
  else begin
   if(de)begin started<=1;ix<=ix+1'b1;end else ix<=0;
   if(de&&!de_d)phase<=1;else if(started)phase<=phase==HT-1?0:phase+1'b1;
   if(de_d&&!de)begin iy<=iy+1'b1;bank<=next;end
   if(synth_row&&phase==W-1)tail_done<=1;
  end
 end
 (* ram_style="bram" *) reg [25:0] row0[0:W-1],row1[0:W-1],row2[0:W-1];
 reg [25:0] q0,q1,q2,bottom;
 always @(posedge clk)sx1<=sx;
 always @(posedge clk)begin
  if(write1)case(bank1)0:row0[sx1]<=encoded;1:row1[sx1]<=encoded;2:row2[sx1]<=encoded;endcase
  q0<=row0[sx1];q1<=row1[sx1];q2<=row2[sx1];bottom<=encoded;
 end
 function [25:0] pick(input [1:0] b,input [25:0] a,c,d);begin case(b)0:pick=a;1:pick=c;default:pick=d;endcase end endfunction
 reg rv,drain_q,tail;reg [10:0] qx,qy,tail_y;reg [1:0] qt,qm;
 wire [25:0] top=pick(qt,q0,q1,q2),middle=pick(qm,q0,q1,q2),bot=drain_q?middle:bottom;
 reg [25:0] lt,lm,lb,ct,cm,cb;
 always @(posedge clk or negedge rst_n)
 if(!rst_n)begin rv<=0;tail<=0;qx<=0;qy<=0;drain_q<=0;qt<=0;qm<=0;tail_y<=0;valid<=0;x<=0;y<=0;end
 else begin
  rv<=take1&&sy1>0&&!fs;qx<=sx1;qy<=sy1-1'b1;drain_q<=drain1;qt<=top1;qm<=mid1;
  tail<=rv&&qx==W-1&&!fs;if(rv&&qx==W-1)tail_y<=qy;
  valid<=!fs&&((rv&&qx!=0)||tail);
  if(!fs)begin
   if(rv)begin
    ct<=top;cm<=middle;cb<=bot;
    lt<=qx==0?top:ct;lm<=qx==0?middle:cm;lb<=qx==0?bot:cb;
   end
   if((rv&&qx!=0)||tail)begin
    win<={lt,ct,tail?ct:top,lm,cm,tail?cm:middle,lb,cb,tail?cb:bot};
    x<=tail?W-1:qx-1'b1;y<=tail?tail_y:qy;
   end
  end
 end
endmodule
