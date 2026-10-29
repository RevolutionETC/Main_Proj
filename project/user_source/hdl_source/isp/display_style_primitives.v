module enhance_rgb_to_yc(input wire clk,input wire [23:0] rgb_i,output reg [25:0] yc_o);
 wire signed [10:0] r=$signed({3'd0,rgb_i[23:16]}),g=$signed({3'd0,rgb_i[15:8]}),b=$signed({3'd0,rgb_i[7:0]});
 wire signed [10:0] co=r-b,t=b+(co>>>1),cg=g-t,y=t+(cg>>>1);
 always @(posedge clk)yc_o<={y[7:0],co[8:0],cg[8:0]};
endmodule

module style_sobel(input wire clk,input wire [233:0] win_i,output reg [25:0] yc_o,output reg [1:0] level_o,
 output reg [25:0] center_o,output reg [13:0] magnitude_o);
 wire [7:0] a[0:8];wire signed [13:0] cy[0:8],cc[0:8],cg[0:8];genvar j;
 generate for(j=0;j<9;j=j+1)begin:Y
  assign a[j]=win_i[(8-j)*26+18+:8];
  assign cy[j]=$signed({6'd0,a[j]});
  assign cc[j]=$signed(win_i[(8-j)*26+9+:9]);
  assign cg[j]=$signed(win_i[(8-j)*26+:9]);
 end endgenerate
 wire signed [11:0] gx=$signed({4'd0,a[2]})+($signed({4'd0,a[5]})<<<1)+$signed({4'd0,a[8]})-$signed({4'd0,a[0]})-($signed({4'd0,a[3]})<<<1)-$signed({4'd0,a[6]});
 wire signed [11:0] gy=$signed({4'd0,a[6]})+($signed({4'd0,a[7]})<<<1)+$signed({4'd0,a[8]})-$signed({4'd0,a[0]})-($signed({4'd0,a[1]})<<<1)-$signed({4'd0,a[2]});
 wire signed [13:0] ysum=cy[0]+(cy[1]<<<1)+cy[2]+(cy[3]<<<1)+(cy[4]<<<2)+(cy[5]<<<1)+cy[6]+(cy[7]<<<1)+cy[8]+14'sd8;
 wire signed [13:0] csum=cc[0]+(cc[1]<<<1)+cc[2]+(cc[3]<<<1)+(cc[4]<<<2)+(cc[5]<<<1)+cc[6]+(cc[7]<<<1)+cc[8]+14'sd8;
 wire signed [13:0] gsum=cg[0]+(cg[1]<<<1)+cg[2]+(cg[3]<<<1)+(cg[4]<<<2)+(cg[5]<<<1)+cg[6]+(cg[7]<<<1)+cg[8]+14'sd8;
 reg signed [11:0] xreg,yreg;reg [25:0] color;
 reg signed [13:0] by,bc,bg;
 wire [11:0] ax=xreg[11]?-xreg:xreg,ay=yreg[11]?-yreg:yreg;
 wire [12:0] mag={1'b0,ax}+{1'b0,ay};
 wire signed [13:0] center_y=$signed({6'd0,color[25:18]}),center_c=$signed(color[17:9]),center_g=$signed(color[8:0]);
 wire signed [13:0] mixy=(center_y+by+14'sd1)>>>1,mixc=(center_c+bc+14'sd1)>>>1,mixg=(center_g+bg+14'sd1)>>>1;
 wire signed [13:0] fy=(mag>=384)?center_y:((mag>=192)?mixy:by);
 wire signed [13:0] fc=(mag>=384)?center_c:((mag>=192)?mixc:bc);
 wire signed [13:0] fg=(mag>=384)?center_g:((mag>=192)?mixg:bg);
 always @(posedge clk)begin
  xreg<=gx;yreg<=gy;color<=win_i[4*26+:26];
  by<=ysum>>>4;bc<=csum>>>4;bg<=gsum>>>4;
  yc_o<={fy[7:0],fc[8:0],fg[8:0]};center_o<=color;magnitude_o<={1'b0,mag};
  level_o<=(mag>=256)?2'd3:((mag>=128)?2'd2:((mag>=64)?2'd1:2'd0));
 end
endmodule

module style_quantize_color(input wire clk,input wire [25:0] yc_i,output reg [23:0] rgb_o);
 wire signed [13:0] co=$signed(yc_i[17:9]),cg=$signed(yc_i[8:0]);
 // Fine chroma palette; bypass chroma quantization below Y=32.
 wire signed [13:0] cq=co+14'sd2,gq=cg+14'sd2;
 reg signed [12:0] sc,sg;reg [7:0] y;
 wire signed [12:0] t=$signed({5'd0,y})-(sg>>>1);
 wire signed [12:0] green=sg+t,blue=t-(sc>>>1),red=blue+sc;
 function [7:0] clip;
  input signed [12:0] v;
  begin if(v<0)clip=0;else if(v>255)clip=255;else clip=v[7:0];end
 endfunction
 // Keep all 32 shadow codes; quantize mid/high luminance in 8-code steps.
 // A nonzero shadow is never mapped to black by the palette.
 function [7:0] quantize_y;
  input [7:0] v;reg [8:0] rounded;
  begin rounded={1'b0,v}+9'd4;
   if(v<32)quantize_y=v;else if(rounded>=256)quantize_y=255;
   else quantize_y={rounded[7:3],3'b000};
  end
 endfunction
 always @(posedge clk)begin
  y<=quantize_y(yc_i[25:18]);
  sc<=(yc_i[25:18]<32)?co:((cq>>>2)<<<2);
  sg<=(yc_i[25:18]<32)?cg:((gq>>>2)<<<2);
  rgb_o<={clip(red),clip(green),clip(blue)};
 end
endmodule

// Shadow lift uses one common RGB gain, so it preserves channel ratios.
// There is no black-offset subtraction or threefold saturation.
// Pipeline remains two cycles: gain -> bounded saturation and gentle edge fusion.
module style_quantize_fuse(input wire clk,input wire [23:0] rgb_i,input wire [1:0] level_i,output reg [23:0] rgb_o);
 wire [7:0] r=rgb_i[23:16],g=rgb_i[15:8],b=rgb_i[7:0];
 wire [7:0] maxrg=(r>g)?r:g,maxrgb=(maxrg>b)?maxrg:b;
 wire [9:0] gain;
 style_tone_gain T(.max_i(maxrgb),.gain_o(gain));
 wire [17:0] rp,gp,bp;
 unsigned_gain_product #(.GAIN_BITS(10)) R(.pixel(r),.gain(gain),.product(rp));
 unsigned_gain_product #(.GAIN_BITS(10)) G(.pixel(g),.gain(gain),.product(gp));
 unsigned_gain_product #(.GAIN_BITS(10)) B(.pixel(b),.gain(gain),.product(bp));
 function [7:0] tone;
  input [17:0] product;reg [18:0] rounded;
  begin rounded={1'b0,product}+19'd128;
   tone=(rounded>=19'd65536)?8'd255:rounded[15:8];
  end
 endfunction
 reg [23:0] vibrant;reg [1:0] edge_level;
 wire [7:0] vr=vibrant[23:16],vg=vibrant[15:8],vb=vibrant[7:0];
 wire [7:0] mxrg=(vr>vg)?vr:vg,mx=(mxrg>vb)?mxrg:vb;
 function [7:0] fuse;
  input [7:0] v,m;input [1:0] level;
  reg signed [10:0] z;reg [7:0] c;
  reg [12:0] s31;reg [11:0] s15;reg [10:0] s7;
  begin
   z=$signed({3'd0,v})-($signed({3'd0,m})-$signed({3'd0,v})+11'sd2)/11'sd4;
   c=(z<0)?8'd0:z[7:0];
   s31=({5'd0,c}<<5)-{5'd0,c};s15=({4'd0,c}<<4)-{4'd0,c};s7=({3'd0,c}<<3)-{3'd0,c};
   case(level)2'd1:fuse=s31[12:5];2'd2:fuse=s15[11:4];2'd3:fuse=s7[10:3];default:fuse=c;endcase
  end
 endfunction
 always @(posedge clk)begin
  vibrant<={tone(rp),tone(gp),tone(bp)};edge_level<=level_i;
  rgb_o<={fuse(vr,mx,edge_level),fuse(vg,mx,edge_level),fuse(vb,mx,edge_level)};
 end
endmodule
