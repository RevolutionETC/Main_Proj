`timescale 1ns/1ps
module color_video_tb;
 parameter NOISY_BACKGROUND=0;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,h=0,de=0;reg [23:0] rgb=0;
 wire [51:0] info;wire ov,oh,od;wire [23:0] out;
 red_target_video dut(.I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_page(3'd0),.I_effect(2'd0),.I_vsync(v),.I_hsync(h),.I_de(de),.I_data(rgb),.O_info(info),.O_vsync(ov),.O_hsync(oh),.O_de(od),.O_data(out));
 reg [2047:0] scene0[0:599],scene1[0:599];reg [49:0] meta[0:7];
 reg [2:0] pv=0,ph=0,pd=0;reg old_ov=0;integer outframe=-1,ox=0,oy=0,fd=0,frame_pixels=0;
 integer red_ink=0,blue_ink=0,green_ink=0,info_fd;
 integer f,x,y,i,j,n,expected_l,found,reds,blues,greens;reg [1:0] color;reg [49:0] rec;
 function [23:0] palette(input [1:0] col,input integer ff);begin
  case(col)
   1:palette=24'hd02020;
   2:palette=ff%3==0?24'h181860:ff%3==1?24'h2020d0:24'h6078c0;
   3:palette=ff%3==0?24'h186018:ff%3==1?24'h20d020:24'h78c060;
   default:palette=24'hb0b0b0;
  endcase
 end endfunction
 always @(posedge clk)begin
  pv={pv[1:0],v};ph={ph[1:0],h};pd={pd[1:0],de};#1;
  if(rst)begin
   if({ov,oh,od}!=={pv[2],ph[2],pd[2]})$fatal(1,"Color video changed latency");
   if(ov&&!old_ov)begin outframe=outframe+1;ox=0;oy=0;frame_pixels=0;red_ink=0;blue_ink=0;green_ink=0;
    if(outframe==5)begin
     if(NOISY_BACKGROUND)fd=$fopen("three_color_noise_preview.ppm","wb");
     else fd=$fopen("three_color_preview.ppm","wb");
     if(fd==0)$fatal(1,"Unable to open actual RTL preview output");
     $fwrite(fd,"P6\n1024 600\n255\n");
     if(NOISY_BACKGROUND)info_fd=$fopen("three_color_noise_info.hex","w");else info_fd=$fopen("three_color_info.hex","w");
     if(info_fd==0)$fatal(1,"Unable to open actual RTL metadata output");$fwrite(info_fd,"%013h\n",info);$fclose(info_fd);
    end
   end
   old_ov=ov;
   if(od)begin
    if(^out===1'bx)$fatal(1,"Unknown color display");
    if(out==24'hff2020)red_ink=red_ink+1;
    if(out==24'h2860ff)blue_ink=blue_ink+1;
    if(out==24'h20c040)green_ink=green_ink+1;
    if(outframe==5)begin
     $fwrite(fd,"%c%c%c",out[23:16],out[15:8],out[7:0]);
     if(ox==100&&oy==180&&out!==24'hff2020)$fatal(1,"Red moving box color/position");
     if(ox==820&&oy==180&&out!==24'h2860ff)$fatal(1,"Blue moving box color/position");
     if(ox==580&&oy==410&&out!==24'h20c040)$fatal(1,"Green moving box color/position");
     if(ox==100&&oy==106&&out!==24'hff2020)$fatal(1,"Red type glyph");
     if(ox==796&&oy==106&&out!==24'h2860ff)$fatal(1,"Blue type glyph");
     if(ox==580&&oy==336&&out!==24'h20c040)$fatal(1,"Green type glyph");
    end
    if(outframe==17&&ox==458&&oy==530&&(out!==24'hb0b0b0||info[51:49]!=2))$fatal(1,"LIMIT must be footer metadata, without floating text");
    frame_pixels=frame_pixels+1;if(ox==1023)begin ox=0;oy=oy+1;end else ox=ox+1;
    if(frame_pixels==614400&&outframe==5)begin
     if(red_ink<1000||blue_ink<1000||green_ink<500)$fatal(1,"Missing color OSD");$fclose(fd);fd=0;
    end
   end
  end
 end
 initial begin
  $readmemh("../fixtures/color_scene_0.hex",scene0);$readmemh("../fixtures/color_scene_1.hex",scene1);$readmemh("../fixtures/color_scene_meta.hex",meta);
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<22;f=f+1)begin
   v=1;repeat(4)@(negedge clk);v=0;repeat(200)@(negedge clk);
   for(y=0;y<600;y=y+1)begin
    for(x=0;x<1024;x=x+1)begin
     color=0;
     if(f<19&&x>=4*f)color=f<6?scene0[y][2047-2*(x-4*f)-:2]:scene1[y][2047-2*(x-4*f)-:2];
     if(f>=14&&f<19&&x>=20+4*f&&x<=59+4*f&&y>=290&&y<=329)color=3;
     de=1;rgb=palette(color,f);
     if(NOISY_BACKGROUND&&color==0&&f<19&&y%7==0&&x%16<3)rgb=(x/16)%2==0?24'h5c707e:24'h708274;
     @(negedge clk);
    end
    de=0;h=1;repeat(160)@(negedge clk);h=0;
   end
   repeat(12000)@(negedge clk);
   if(frame_pixels!=614400)$fatal(1,"Color frame length");
   if(f>=2&&f<19)begin
    if(dut.ana_count!=8)$fatal(1,"Combined RGB target count %0d",dut.ana_count);
    reds=0;blues=0;greens=0;n=0;
    for(i=0;i<8;i=i+1)begin
     rec=dut.stable_objects[i*50+:50];if(!rec[47])$fatal(1,"Eight confirmed objects expected");
     case(rec[49:48])1:reds=reds+1;2:blues=blues+1;3:greens=greens+1;default:$fatal(1,"Object lost color");endcase
     found=0;
     for(j=0;j<8;j=j+1)begin
      expected_l=meta[j][44:34]+4*(f+1);
      if(rec[49:48]==meta[j][49:48]&&rec[44:34]==expected_l&&rec[22:12]==meta[j][22:12])begin
       found=found+1;
       if(j!=7||f<6)begin if(rec[46:45]!=meta[j][46:45])$fatal(1,"Color/shape class mismatch at %0d/%0d",f,j);end
       else if(f>=10&&rec[46:45]!=3)$fatal(1,"Green triangle never confirmed");
       if(rec[33:23]!=meta[j][33:23]+4*(f+1)||rec[11:1]!=meta[j][11:1])$fatal(1,"Exact projected box dimensions");
      end
     end
     if(found!=1)$fatal(1,"Unmatched/merged/projected geometry f=%0d obj=%h",f,rec);
    end
    if(reds!=3||blues!=3||greens!=2)$fatal(1,"Shared total limit violated %0d/%0d/%0d",reds,blues,greens);
   end
   if(f>=16&&f<19&&(!dut.ana_limit||dut.ana_count!=8))$fatal(1,"Ninth mixed-color target must not allocate a ninth slot");
   if(f==21)begin
    if(dut.ana_count!=0||dut.stable_objects!=0)$fatal(1,"Empty RGB frame ghosts");
    if(red_ink!=0||blue_ink!=0||green_ink!=0||info[51:49]!=3)$fatal(1,"Empty frame must export NO TARGET metadata without floating text");
   end
   if(dut.capture_limit||dut.dropped!=0)$fatal(1,"RGB processing exceeded budget");
  end
  $display("PASS 22 full 1024x600 RGB frames: all nine color/shape combinations, eight shared slots, tiny RGB rejection, brightness/saturation variation, exact moving RGB boxes and colored coordinate labels, confirmed shape change, ninth-target LIMIT/empty NO TARGET metadata and no floating status text");$finish;
 end
 initial begin #240000000;$fatal(1,"Color video watchdog");end
endmodule
