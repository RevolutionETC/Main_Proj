 
 
module sepia_core #(
    parameter W=1280,H=720,GRAIN=1,VIGNETTE=1
)(input wire clk,rst_n,input wire [95:0] data_i,
  input wire valid_i,sof_i,eol_i,input wire [31:0] luma_i,
  output wire [95:0] data_o,output wire valid_o,sof_o,eol_o);
    reg [11:0] xpos,ypos;
    reg sof_d;
    reg [15:0] rng,frame_count;
    reg [3:0] vp,sp,lp;
    wire fs=sof_i&&!sof_d;
    wire [11:0] ax=fs?12'd0:xpos;
    wire [11:0] ay=fs?12'd0:ypos;
    wire [15:0] seed=16'h1ace ^ {frame_count[14:0],1'b1};
    wire [15:0] r0=fs?seed:rng;
    wire [15:0] r1,r2,r3,r4;
    function [15:0] advance;
        input [15:0] r;
        begin advance={r[14:0],r[15]^r[13]^r[12]^r[10]};end
    endfunction
    assign r1=advance(r0);assign r2=advance(r1);
    assign r3=advance(r2);assign r4=advance(r3);
    always @(posedge clk or negedge rst_n) begin
        if(!rst_n)begin
            xpos<=0;ypos<=0;sof_d<=0;rng<=16'h1ace;frame_count<=0;
            vp<=0;sp<=0;lp<=0;
        end else begin
            sof_d<=sof_i;
            vp<={vp[2:0],valid_i};sp<={sp[2:0],sof_i};lp<={lp[2:0],eol_i};
            if(fs)begin xpos<=0;ypos<=0;rng<=seed;frame_count<=frame_count+1'b1;end
            if(valid_i)begin
                rng<=r4;
                if(ax==W-4)begin xpos<=0;ypos<=(ay==H-1)?12'd0:ay+1'b1;end
                else begin xpos<=ax+12'd4;ypos<=ay;end
            end
        end
    end
    assign valid_o=vp[3];assign sof_o=sp[3];assign eol_o=lp[3];
    genvar p;
    generate for(p=0;p<4;p=p+1)begin:PIXEL
        wire [15:0] rr=(p==0)?r1:((p==1)?r2:((p==2)?r3:r4));
        wire [11:0] pixel_x=ax+p;
        sepia_pixel #(.W(W),.H(H),.GRAIN(GRAIN),.VIGNETTE(VIGNETTE)) u_pixel(
            .clk(clk),.rst_n(rst_n),.rgb_i(data_i[(3-p)*24 +:24]),
            .luma_i(luma_i[(3-p)*8+:8]),.x_i(pixel_x),.y_i(ay),.noise_i(rr[7:6]),.rgb_o(data_o[(3-p)*24 +:24]));
    end endgenerate
endmodule

module sepia_pixel #(
    parameter W=1280,H=720,GRAIN=1,VIGNETTE=1
)(input wire clk,rst_n,input wire [23:0] rgb_i,
  input wire [11:0] x_i,y_i,input wire [1:0] noise_i,input wire [7:0] luma_i,
  output reg [23:0] rgb_o);
     
    function [5:0] penalty;
        input [5:0] q;
        begin
            case(q)
                0,1,2:penalty=0;3,4:penalty=1;5,6:penalty=2;
                7:penalty=3;8:penalty=4;9:penalty=5;10:penalty=6;
                11:penalty=8;12:penalty=9;13:penalty=11;14:penalty=12;
                15:penalty=14;16:penalty=16;17:penalty=18;18:penalty=20;
                19:penalty=23;20:penalty=25;21:penalty=28;22:penalty=30;
                23:penalty=33;24:penalty=36;25:penalty=39;26:penalty=42;
                27:penalty=46;28:penalty=49;29:penalty=53;30:penalty=56;
                default:penalty=60;
            endcase
        end
    endfunction
    function [7:0] sat;
        input signed [10:0] v;
        begin if(v<0)sat=0;else if(v>255)sat=255;else sat=v[7:0];end
    endfunction
    wire [11:0] dx=(x_i<W/2)?W/2-x_i:x_i-W/2;
    wire [11:0] dy=(y_i<H/2)?H/2-y_i:y_i-H/2;
    wire [5:0] px=penalty(dx[10:5]);
    wire [5:0] py=penalty(dy[9:4])>>1;
    wire [8:0] gain=(VIGNETTE==0)?9'd256:9'd256-{3'd0,px}-{3'd0,py};
    reg [7:0] gray1;
    reg [8:0] gain1,gain2;
    reg signed [3:0] grain1,grain2,grain3;
    wire [23:0] color2;
    reg [16:0] red3,green3,blue3;
    sepia_lut u_curve(.clk(clk),.y_i(gray1),.rgb_o(color2));
    wire signed [10:0] red4=$signed({3'd0,red3[15:8]})+grain3;
    wire signed [10:0] green4=$signed({3'd0,green3[15:8]})+grain3;
    wire signed [10:0] blue4=$signed({3'd0,blue3[15:8]})+grain3;
    wire [16:0] rp,gp,bp;
    unsigned_gain_product #(.GAIN_BITS(9)) R(.pixel(color2[23:16]),.gain(gain2),.product(rp));
    unsigned_gain_product #(.GAIN_BITS(9)) G(.pixel(color2[15:8]),.gain(gain2),.product(gp));
    unsigned_gain_product #(.GAIN_BITS(9)) B(.pixel(color2[7:0]),.gain(gain2),.product(bp));
    always @(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            gray1<=0;gain1<=256;gain2<=256;
            grain1<=0;grain2<=0;grain3<=0;red3<=0;green3<=0;blue3<=0;rgb_o<=0;
        end else begin
            gray1<=luma_i;gain1<=gain;
            case(noise_i)
                0:grain1<=-GRAIN;
                3:grain1<=GRAIN;
                default:grain1<=0;
            endcase
            gain2<=gain1;grain2<=grain1;
            red3<=rp+17'd128;
            green3<=gp+17'd128;
            blue3<=bp+17'd128;
            grain3<=grain2;
            rgb_o<={sat(red4),sat(green4),sat(blue4)};
        end
    end
endmodule
