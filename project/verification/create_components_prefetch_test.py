from pathlib import Path
root=Path(__file__).resolve().parent.parent
text=(root/'verification/rgb/component_tb.sv').read_text(encoding='utf8')
text=text.replace('module component_tb;','module component_prefetch_opt27_tb;',1)
text='`include "../prototypes/prefetch_color_components_opt27.sv"\n'+text
anchor=' reg [127:0] masks[0:47];'
assert anchor in text
extra=''' wire new_start,new_bank,new_limit;wire [12:0] new_runs;wire [31:0] new_drops;
 wire [39:0] new_data;wire [1:0] new_label_color;wire [6:0] new_root;
 prefetch_color_components_opt27 #(.WIDTH(64),.HEIGHT(48)) optimized(
  .I_clk(clk),.I_rst_n(rst),.I_frame_start(fs),.I_enable(1'b1),.I_de(de),.I_x(x),.I_y(y),.I_color(color),
  .I_analyzer_busy(busy),.O_start(new_start),.O_bank(new_bank),.O_runs(new_runs),.O_limit(new_limit),.O_dropped(new_drops),
  .I_read_bank(read_bank),.I_read_addr(address),.O_read_data(new_data),.I_label(new_data[6:0]),.O_root(new_root),
  .I_color_label(new_root),.O_label_color(new_label_color));
 integer comparisons=0;
 always @(posedge clk)if(rst)begin
  #2;comparisons=comparisons+1;
  if({start,bank,limit,runs,drops}!=={new_start,new_bank,new_limit,new_runs,new_drops})
   $fatal(1,"Component metadata cycle mismatch %0d oldstate%0d newstate%0d",comparisons,dut.state,optimized.state);
  if(dut.state!==optimized.state||dut.run_count!==optimized.run_count||dut.engine_bad!==optimized.engine_bad||dut.cur_root!==optimized.cur_root)
   $fatal(1,"Component engine timing mismatch cycle%0d oldstate%0d newstate%0d",comparisons,dut.state,optimized.state);
  if(dut.state==2&&dut.cur_index<dut.cur_count&&dut.cap_record!==optimized.cap_record)
   $fatal(1,"Capture prefetch mismatch cycle%0d index%0d",comparisons,dut.cur_index);
  if(dut.state==3&&dut.scan_index<dut.prev_count&&dut.prev_record!==optimized.prev_record)
   $fatal(1,"Row prefetch mismatch cycle%0d index%0d",comparisons,dut.scan_index);
  if({data,root,label_color}!=={new_data,new_root,new_label_color})
   $fatal(1,"Component returned immutable records mismatch cycle%0d",comparisons);
 end
'''
text=text.replace(anchor,extra+anchor,1)
text=text.replace('$display("PASS full-resolution components:', '$display("PASS synchronous buffer prefetch exact-cycle components:')
(root/'verification/component_prefetch_opt27_tb.sv').write_text(text,encoding='utf8')
print('Created inactive component prefetch test')
