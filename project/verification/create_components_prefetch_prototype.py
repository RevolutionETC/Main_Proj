from pathlib import Path
root=Path(__file__).resolve().parent.parent
original=root.parent/'integration_20261026_info_swipe/ISP_RGB_SC500_INTEGRATED/user_source/hdl_source/target/color_components.v'
text=original.read_text(encoding='utf8')
def replace(before,after,count=1):
 global text
 assert text.count(before)==count,(before,text.count(before))
 text=text.replace(before,after)
replace('module color_components #(','module prefetch_color_components_opt27 #(')
replace('reg [23:0] cap0[0:MAX_LINE_RUNS-1],cap1[0:MAX_LINE_RUNS-1];',
 '(* ram_style="bram" *) reg [23:0] cap_records[0:MAX_LINE_RUNS*2-1];')
replace('reg [30:0] row0[0:MAX_LINE_RUNS-1],row1[0:MAX_LINE_RUNS-1];',
 '(* ram_style="bram" *) reg [30:0] row_records[0:MAX_LINE_RUNS*2-1];')
replace('wire [23:0] cap_record=source_bank?cap1[cur_index[5:0]]:cap0[cur_index[5:0]];\n wire [30:0] prev_record=prev_bank?row1[scan_index[5:0]]:row0[scan_index[5:0]];',
 '''// Prefetch at the same predecessor state that selects the next record.
 // Neither the state schedule nor the pixel capture interface gains a cycle.
 localparam [6:0] BUFFER_BASE=MAX_LINE_RUNS;
 wire [23:0] cap_record;wire [30:0] prev_record;
 reg [6:0] cap_read_addr,row_read_addr;
 reg [6:0] cap_registered_addr,row_registered_addr;
 always @(*)begin
  cap_read_addr=(source_bank?BUFFER_BASE:7'd0)+cur_index[5:0];
  if(state==IDLE&&line_ready)cap_read_addr=(line_bank?BUFFER_BASE:7'd0);
  else if(state==WRITE&&cur_index+1<cur_count)
   cap_read_addr=(source_bank?BUFFER_BASE:7'd0)+(cur_index[5:0]+6'd1);
  row_read_addr=(prev_bank?BUFFER_BASE:7'd0)+scan_index[5:0];
  if(state==CUR)row_read_addr=(prev_bank?BUFFER_BASE:7'd0)+prev_pointer[5:0];
  else if(state==MERGE||(state==SCAN&&scan_index<prev_count&&
   (prev_right<cur_left||(prev_left<=cur_right&&(prev_color!=cur_color||prev_label==0)))))
   row_read_addr=(prev_bank?BUFFER_BASE:7'd0)+(scan_index[5:0]+6'd1);
 end
 always @(posedge I_clk)begin
  cap_registered_addr<=cap_read_addr;
  row_registered_addr<=row_read_addr;
 end
 assign cap_record=cap_records[cap_registered_addr];
 assign prev_record=row_records[row_registered_addr];''')
replace('if(cap_bank)cap1[cap_count[5:0]]<={run_left,I_x-11\'d1,run_color};\n       else cap0[cap_count[5:0]]<={run_left,I_x-11\'d1,run_color};',
 'cap_records[(cap_bank?BUFFER_BASE:7\'d0)+cap_count[5:0]]<={run_left,I_x-11\'d1,run_color};')
replace('if(cap_bank)cap1[cap_count[5:0]]<={run_left,last_x,run_color};\n      else cap0[cap_count[5:0]]<={run_left,last_x,run_color};',
 'cap_records[(cap_bank?BUFFER_BASE:7\'d0)+cap_count[5:0]]<={run_left,last_x,run_color};')
replace('if(out_bank)row1[cur_index[5:0]]<={cur_left,cur_right,cur_color,assigned};\n    else row0[cur_index[5:0]]<={cur_left,cur_right,cur_color,assigned};',
 'row_records[(out_bank?BUFFER_BASE:7\'d0)+cur_index[5:0]]<={cur_left,cur_right,cur_color,assigned};')
folder=root/'verification/prototypes';folder.mkdir(exist_ok=True)
(folder/'prefetch_color_components_opt27.sv').write_text('`ifndef PREFETCH_COLOR_COMPONENTS_OPT27\n`define PREFETCH_COLOR_COMPONENTS_OPT27\n'+text+'\n`endif\n',encoding='utf8')
print('Created inactive prefetch component prototype')
