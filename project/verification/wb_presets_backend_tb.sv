`timescale 1ns/1ps
module wb_presets_backend_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,v=0,u=0,l=0,ready=1,bad=0;
 reg [1:0] mode=0;reg [6:0] index=30;reg [95:0] rgb=0;
 wire [95:0] data,original_data,qualified_data;
 wire ov,ou,ol,ordy,os;wire [11:0] gr,gb;
 wire rv,ru,rl,rrdy,rs;wire [11:0] rgr,rgbgain;
 wire qv,qu,ql,qrdy,qs;wire [11:0] qgr,qgb;
 wb_balance_96 #(.MIN_SAMPLES(16),.FRAME_BEATS(128),.FRAME_LINES(8)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_mode(mode),.I_kelvin_index(index),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),
 .I_ready(ready),.I_previous_bad(bad),.O_data(data),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(ordy),.O_gain_r(gr),.O_gain_b(gb),.O_statistics_ok(os));
 wb_balance_original_restore_ref #(.MIN_SAMPLES(16),.FRAME_BEATS(128),.FRAME_LINES(8)) original(
 .I_clk(clk),.I_rst_n(rst),.I_mode(mode),.I_kelvin_index(index),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),
 .I_ready(ready),.I_previous_bad(bad),.O_data(original_data),.O_valid(rv),.O_user(ru),.O_last(rl),.O_ready(rrdy),.O_gain_r(rgr),.O_gain_b(rgbgain),.O_statistics_ok(rs));
 // Preset 1 uses exactly the existing qualified manual 2 arithmetic. Auto 0 and manual 2 inputs are unchanged.
 wire [1:0] qualified_mode=(mode==1)?2'd2:mode;
 wb_balance_qualified_restore_ref #(.MIN_SAMPLES(16),.FRAME_BEATS(128),.FRAME_LINES(8)) qualified(
 .I_clk(clk),.I_rst_n(rst),.I_mode(qualified_mode),.I_kelvin_index(index),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),
 .I_ready(ready),.I_previous_bad(bad),.O_data(qualified_data),.O_valid(qv),.O_user(qu),.O_last(ql),.O_ready(qrdy),.O_gain_r(qgr),.O_gain_b(qgb),.O_statistics_ok(qs));
 integer tr[0:75],tb[0:75],fd,k,a,b,n,scan,idx,p,c,checked=0,cycles=0;
 integer active_r=1024,active_b=1024,rval,bval,ix;
 reg prev_u=0,pv=0,pu=0,pl=0;
 reg [95:0] expect_pipe=0,expect_now;
 function automatic [7:0] scaled(input integer color,gain);
 integer q;begin q=(color*gain+512)/1024;scaled=q>255?255:q;end endfunction
 always @(posedge clk) if(rst)begin
  if(u&&!prev_u)begin
   ix=index>75?75:index;
   if(mode==1||mode==2)begin active_r=tr[ix];active_b=tb[ix];end
   else begin active_r=dut.auto_r;active_b=dut.auto_b;end
  end
  prev_u=u;
  for(p=0;p<4;p=p+1) expect_now[p*24+:24]={scaled(rgb[p*24+16+:8],active_r),rgb[p*24+8+:8],scaled(rgb[p*24+:8],active_b)};
  #1;
  if({data,ov,ou,ol,ordy,gr,gb,os}!=={original_data,rv,ru,rl,rrdy,rgr,rgbgain,rs})$fatal(1,"Original WB mismatch at cycle %0d mode %0d",cycles,mode);
  if({data,ov,ou,ol,ordy,gr,gb,os}!=={qualified_data,qv,qu,ql,qrdy,qgr,qgb,qs})$fatal(1,"Qualified retained path mismatch at cycle %0d mode %0d",cycles,mode);
  if({ov,ou,ol,ordy}!=={pv,pu,pl,ready})$fatal(1,"WB pipeline controls");
  if(gr!==active_r||gb!==active_b)$fatal(1,"WB gains not frame atomic");
  if(pv)begin if(data!==expect_pipe)$fatal(1,"Four-lane Kelvin pixel oracle actual=%h expected=%h",data,expect_pipe);checked=checked+4;end
  else if(data!==0)$fatal(1,"WB invalid pixels not blank");
  if(mode!=0 && u && os)$fatal(1,"Preset/manual asserted AWB statistics valid");
  expect_pipe=expect_now;pv=v;pu=u;pl=l;cycles=cycles+1;
 end
 task frame(input integer new_mode,new_index,beats,input bit mutate,constant_color);
 integer j;begin
  mode=new_mode;index=new_index;u=1;v=1;l=0;rgb={24'hff00ff,24'h018001,24'h7f407f,24'h000000};@(negedge clk);u=0;
  for(j=1;j<beats;j=j+1)begin
   v=1;l=(j%16)==15;
   case(j%8)
    0:rgb={24'hffffff,24'h010101,24'h808080,24'h000000};
    1:rgb={24'hff0000,24'h00ff00,24'h0000ff,24'hffffff};
    default:rgb=constant_color?{4{24'h5078a0}}:{$random,$random,$random};
   endcase
   if(mutate && j==8)begin mode=(new_mode+1)%3;index=(new_index+33)%76;end
   ready=(j%7)!=0;@(negedge clk);
  end
  v=0;l=0;ready=1;repeat(100)@(negedge clk);
 end endtask
 initial begin
  fd=$fopen("../../user_source/hdl_source/wb/kelvin_gains_demo.csv","r");if(!fd)$fatal(1,"Kelvin oracle CSV missing");
  begin reg [1023:0] line;scan=$fgets(line,fd);end
  for(idx=0;idx<76;idx=idx+1)begin scan=$fscanf(fd,"%d,%d,%d\n",k,a,b);if(scan!=3)$fatal(1,"Kelvin CSV row");tr[idx]=a;tb[idx]=b;end
  $fclose(fd);repeat(4)@(negedge clk);rst=1;
  for(idx=0;idx<76;idx=idx+1)begin frame(1,idx,48,0,0);frame(2,idx,48,0,0);end
  frame(1,5,128,0,1);frame(1,30,128,0,1);frame(1,40,128,0,1);frame(1,50,128,0,1);
  frame(1,127,48,0,0);frame(2,127,48,0,0);
  for(idx=0;idx<76;idx=idx+1)begin frame(1,idx,32,1,0);frame(2,idx,32,1,0);end
  for(idx=0;idx<30;idx=idx+1)begin frame(0,idx,128,0,1);frame(2,idx,128,0,1);end
  v=0;u=0;repeat(5)@(negedge clk);
  if(checked<70000)$fatal(1,"Insufficient WB pixel coverage %0d",checked);
  $display("PASS restored WB presets: all 76 Kelvin values plus clamp, four preset indices 5/30/40/50, %0d four-lane oracle pixels, rounding/saturation, mid-frame atomicity, original all-mode equivalence and qualified auto/manual path equivalence (%0d cycles)",checked,cycles);$finish;
 end
 initial begin #10000000;$fatal(1,"Restored WB watchdog");end
endmodule
