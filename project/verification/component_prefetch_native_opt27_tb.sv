`timescale 1ns/1ps
module component_prefetch_native_opt27_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,en=1,de=0,busy=0;reg [10:0] x=0,y=0;reg [1:0] color=0;
 wire start,bank,limit;wire [12:0] runs;wire [31:0] drops;
 wire new_start,new_bank,new_limit;wire [12:0] new_runs;wire [31:0] new_drops;
 reg read_bank=0;reg [11:0] address=0;
 wire [39:0] data,new_data;wire [1:0] label_color,new_label_color;wire [6:0] root,new_root;
 reference_color_components_opt27 old(.I_clk(clk),.I_rst_n(rst),.I_frame_start(fs),.I_enable(en),.I_de(de),.I_x(x),.I_y(y),.I_color(color),
  .I_analyzer_busy(busy),.O_start(start),.O_bank(bank),.O_runs(runs),.O_limit(limit),.O_dropped(drops),
  .I_read_bank(read_bank),.I_read_addr(address),.O_read_data(data),.I_label(data[6:0]),.O_root(root),.I_color_label(root),.O_label_color(label_color));
 color_components optimized(.I_clk(clk),.I_rst_n(rst),.I_frame_start(fs),.I_enable(en),.I_de(de),.I_x(x),.I_y(y),.I_color(color),
  .I_analyzer_busy(busy),.O_start(new_start),.O_bank(new_bank),.O_runs(new_runs),.O_limit(new_limit),.O_dropped(new_drops),
  .I_read_bank(read_bank),.I_read_addr(address),.O_read_data(new_data),.I_label(new_data[6:0]),.O_root(new_root),.I_color_label(new_root),.O_label_color(new_label_color));
 integer cycles=0,consumed=0,commits=0,frame,xx,yy,j,blank;
 reg [12:0] saved_runs;reg saved_bank;
 always @(posedge clk)if(rst)begin
  #2;cycles=cycles+1;
  if({start,bank,limit,runs,drops}!=={new_start,new_bank,new_limit,new_runs,new_drops})
   $fatal(1,"Native component metadata mismatch cycle%0d",cycles);
  if(old.state!==optimized.state||old.run_count!==optimized.run_count||old.engine_bad!==optimized.engine_bad||old.cur_root!==optimized.cur_root)
   $fatal(1,"Native engine mismatch cycle%0d",cycles);
  if(old.state==2&&old.cur_index<old.cur_count)begin
   if(old.cap_record!==optimized.cap_record)$fatal(1,"Native capture prefetch mismatch");
   consumed=consumed+1;
  end
  if(old.state==3&&old.scan_index<old.prev_count)begin
   if(old.prev_record!==optimized.prev_record)$fatal(1,"Native row prefetch mismatch");
   consumed=consumed+1;
  end
  if({data,root,label_color}!=={new_data,new_root,new_label_color})$fatal(1,"Native immutable RAM mismatch");
  if(start)begin commits=commits+1;saved_runs=runs;saved_bank=bank;end
 end
 task sof;begin de=0;fs=1;@(negedge clk);fs=0;repeat(200)@(negedge clk);end endtask
 task picture(input integer pattern);begin
  for(yy=0;yy<600;yy=yy+1)begin
   for(xx=0;xx<1024;xx=xx+1)begin
    x=xx;y=yy;de=1;
    case(pattern)
     0:color=(yy<64&&xx%8==1&&xx<512)?2'((xx/8)%3+1):0;
     1:color=(yy<65&&xx%8==1&&xx<512)?2'((xx/8)%3+1):0;
     2:color=(xx>=200&&xx<500&&yy>=100&&yy<500)?3:0;
     3:color=(xx%16==2&&yy%2==0)?2'((xx/16+yy/2)%3+1):0;
     default:color=0;
    endcase
    @(negedge clk);
   end
   de=0;color=0;
   blank=(pattern==3)?16:1024;
   repeat(blank)@(negedge clk);
  end
  repeat(4096)@(negedge clk);
 end endtask
 initial begin
  repeat(4)@(negedge clk);rst=1;
  sof();picture(0);sof();
  if(commits!=1||saved_runs!=4096||limit)$fatal(1,"Full4096 native capacity changed runs%0d commits%0d limit%b",saved_runs,commits,limit);
  read_bank=saved_bank;
  for(j=0;j<4096;j=j+1)begin address=j;repeat(2)@(negedge clk);end
  picture(1);sof();if(commits!=1||!limit)$fatal(1,"4097+ run rejection changed");
  picture(2);sof();if(commits!=2||saved_runs!=400||limit)$fatal(1,"Post-overflow recovery changed");
  busy=1;picture(2);sof();if(commits!=2)$fatal(1,"Analyzer busy immutability changed");busy=0;
  picture(3);sof();if(!limit)$fatal(1,"Short blank/label overflow rejection changed");
  en=0;picture(4);sof();if(commits!=2)$fatal(1,"Disabled capture changed");
  $display("PASS native synchronous component buffers: %0d exact-cycle checks, %0d consumed lookahead records, full1024x600 frames, complete4096 run handoff/readback, overflow/recovery/busy/shortblank/disable",cycles,consumed);
  $finish;
 end
 initial begin #100000000;$fatal(1,"Native component watchdog");end
endmodule
