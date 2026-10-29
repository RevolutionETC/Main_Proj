`timescale 1ns/1ps
module histogram_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,u=0,l=0,previous_bad=0,hready=1;
 reg [8:0] cfg=9'd434,model_cfg=9'd434;reg [95:0] rgb=0;reg [2:0] mode=0;
 wire [95:0] out;wire ov,ou,ol,hw,hp;wire [2:0] om;wire [5:0] ha;wire [7:0] hv;
 histogram_equalizer_96 #(.FRAME_BEATS(512),.FRAME_LINES(32),.LINE_BEATS(16),
  .VIEW_X(2),.VIEW_Y(8),.VIEW_BEATS(12),.VIEW_LINES(16)) dut(
  .I_clk(clk),.I_rst_n(rst),.I_config(cfg),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),
  .I_previous_bad(previous_bad),.I_frame_mode(mode),.O_data(out),.O_valid(ov),.O_user(ou),.O_last(ol),.O_frame_mode(om),
  .I_hist_ready(hready),.O_hist_we(hw),.O_hist_publish(hp),.O_hist_addr(ha),.O_hist_height(hv));
 integer counts[0:63],last_counts[0:63],delta[0:63];
 reg [95:0] expected[0:20000];reg [2:0] tags[0:20000];
 integer put=0,take=0,frames=0,hist_writes=0,publishes=0;
 integer f,x,y,j,b,pk,n,cumulative,first,total,level,mag,d,rr,gg,bb,grey;
 integer prior_fault=0,current_fault=0,prior_strength=100,current_strength=100;
 bit map_valid=0,prior_ready=1;reg [5:0] controls=0;
 function [23:0] source_pixel(input integer frame,xx,yy,lane);
  integer value,r,g,b;
  begin
   case(frame%5)
    0:begin value=(xx*17+yy*11+lane*31)%256;r=value;g=(value*3+17)%256;b=255-value;end
    1:begin value=80+(xx+yy+lane)%32;r=value;g=value;b=value;end
    2:begin r=80;g=80;b=80;end
    3:begin value=((xx+yy+lane)%2)?8:248;r=value;g=value;b=value;end
    default:begin r=255;g=255;b=255;end
   endcase
   source_pixel={8'(r),8'(g),8'(b)};
  end
 endfunction
 function integer clamp(input integer value);clamp=value<0?0:value>255?255:value;endfunction
 task prepare_map;
  integer k,c,minimum,denom,raw,absraw;bit found;
  begin
   c=0;minimum=0;found=0;
   for(k=0;k<64;k=k+1)if(!found&&last_counts[k]!=0)begin minimum=last_counts[k];found=1;end
   denom=192-minimum;
   for(k=0;k<64;k=k+1)begin
    c=c+last_counts[k];
    if(denom==0)delta[k]=0;
    else begin
     raw=((c>minimum?c-minimum:0)*255+denom/2)/denom-(4*k+2);
     absraw=raw<0?-raw:raw;
     delta[k]=(absraw*prior_strength+50)/100;if(raw<0)delta[k]=-delta[k];
    end
   end
  end
 endtask
 always @(posedge clk)if(rst)begin
  if(v)begin
   expected[put]=rgb;tags[put]=mode;
   if(model_cfg[8]&&(model_cfg[7]||model_cfg[6:0]!=0)&&map_valid)begin
    for(j=0;j<4;j=j+1)begin
     rr=rgb[j*24+16+:8];gg=rgb[j*24+8+:8];bb=rgb[j*24+:8];grey=(rr+2*gg+bb)/4;
     d=delta[grey/4];expected[put][j*24+:24]={8'(clamp(rr+d)),8'(clamp(gg+d)),8'(clamp(bb+d))};
    end
   end
   put=put+1;
  end
  #1;
  if(hw&&!hready)$fatal(1,"Histogram wrote while display bank was pending");
  if({ov,ou,ol,om}!==controls)$fatal(1,"HE control/tag latency");
  controls={v,u,l,mode};
  if(ov)begin
   if(take>=put||out!==expected[take]||om!==tags[take])$fatal(1,"HE pixel frame=%0d beat=%0d got=%h expected=%h",f,take,out,expected[take]);
   take=take+1;
  end
  if(hw&&current_fault==0)begin
   pk=0;for(n=0;n<64;n=n+1)if(counts[n]>pk)pk=counts[n];
   level=(counts[ha]*128+pk/2)/pk;
   if(hv!==8'(level))$fatal(1,"Histogram height bin=%0d got=%0d expected=%0d",ha,hv,level);
   hist_writes=hist_writes+1;
  end
  if(hp)publishes=publishes+1;
 end
 initial begin
  for(rr=0;rr<256;rr=rr+1)for(d=-255;d<=255;d=d+1)
   if(dut.saturated(8'(rr),9'(d))!==8'(clamp(rr+d)))$fatal(1,"Saturation exhaustive oracle");
  for(b=0;b<64;b=b+1)begin counts[b]=0;last_counts[b]=0;delta[b]=0;end
  repeat(5)@(negedge clk);rst=1;repeat(80)@(negedge clk);
  for(f=0;f<18;f=f+1)begin
   if(f!=0&&prior_fault==0)begin prepare_map();map_valid=1;end
   current_fault=f==6?1:f==8?2:0;
   current_strength=f==3?0:(f==4||f==5||f==6)?50:f==10?1:f==11?99:100;
   cfg={1'(f!=13),1'(current_strength==100),7'(current_strength)};
   model_cfg=cfg;
   hready=f!=12;previous_bad=prior_fault==1;mode=f%8;
   for(b=0;b<64;b=b+1)counts[b]=0;
   // Half of the frames use coincident SOF and first valid data.
   u=1;v=f%2;l=0;rgb=0;
   if(v)for(j=0;j<4;j=j+1)rgb[j*24+:24]=source_pixel(f,0,0,j);
   @(negedge clk);u=0;v=0;
   for(y=0;y<32;y=y+1)begin
    for(x=(y==0&&f%2?1:0);x<16;x=x+1)begin
     if(f==5&&y==16&&x==6)cfg=9'd228;
     for(j=0;j<4;j=j+1)rgb[j*24+:24]=source_pixel(f,x,y,j);
     if(x>=2&&x<14&&y>=8&&y<24)begin
      grey=(rgb[95:88]+2*int'(rgb[87:80])+rgb[79:72])/4;counts[grey/4]=counts[grey/4]+1;
     end
     v=1;l=x==15;if(current_fault==2&&y==5&&x==14)l=1;
     @(negedge clk);v=0;l=0;
     if((x+y)%7==0)repeat(2)@(negedge clk);
    end
    if(y==23)repeat(9000)@(negedge clk);
   end
   repeat(10000)@(negedge clk);
   for(b=0;b<64;b=b+1)last_counts[b]=counts[b];
   prior_fault=current_fault;prior_strength=current_strength;prior_ready=hready;
  end
  repeat(5)@(negedge clk);
  if(take!=18*512||put!=take||hist_writes<64*10||publishes<10)$fatal(1,"HE coverage/count mismatch");
  $display("PASS independent 64-bin CDF/minimum/rounding/blend RGB oracle: 18 complete four-lane frames, 0/1/50/99/100 strength, flat/white/clipped colours, exact bypass, bad-CSI/malformed-frame freeze/recovery, plot heights and control tags");$finish;
 end
 initial begin #10000000;$fatal(1,"HE watchdog");end
endmodule

module histogram_snapshot_tb;
 reg w=0,r=0,rst=0,we=0,pub=0,fs=0;always #5 w=~w;always #7 r=~r;
 reg [5:0] a=0,ra=0;reg [7:0] value=0;wire ready,valid;wire [7:0] height;
 histogram_snapshot dut(.I_wclk(w),.I_rclk(r),.I_rst_n(rst),.I_we(we),.I_publish(pub),
  .I_addr(a),.I_height(value),.O_ready(ready),.I_frame_start(fs),.I_read_addr(ra),.O_height(height),.O_valid(valid));
 task send(input integer base);
  integer i;begin for(i=0;i<64;i=i+1)begin @(negedge w);we=1;a=i;value=base+i;end
   @(negedge w);we=0;pub=1;@(negedge w);pub=0;end
 endtask
 task boundary;begin @(negedge r);fs=1;@(negedge r);fs=0;end endtask
 task check(input integer base);
  integer i;begin for(i=0;i<64;i=i+1)begin @(negedge r);ra=i;@(negedge r);
   if(!valid||height!==8'(base+i))$fatal(1,"Torn histogram bank bin %0d got %0d",i,height);end end
 endtask
 initial begin
  repeat(4)@(negedge w);rst=1;
  send(0);repeat(10)@(negedge r);if(valid||ready)$fatal(1,"Snapshot visible/ACK before display boundary");
  boundary();repeat(8)@(negedge w);if(!ready)$fatal(1,"No snapshot ACK");check(0);
  send(64);repeat(10)@(negedge r);check(0);
  boundary();check(64);repeat(8)@(negedge w);
  send(0);repeat(10)@(negedge r);boundary();check(0);
  $display("PASS async ERAM histogram snapshots: all 64 bars, pending publish held until VS, old bank immutable, bank reuse/ACK and no tearing");$finish;
 end
 initial begin #100000;$fatal(1,"Snapshot watchdog");end
endmodule
