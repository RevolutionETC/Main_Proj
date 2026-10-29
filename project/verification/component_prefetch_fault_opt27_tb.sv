`timescale 1ns/1ps
module component_prefetch_fault_opt27_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,en=1,de=0,busy=0;reg [10:0] x=0,y=0;reg [1:0] color=0;
 wire start,bank,limit;wire [12:0] runs;wire [31:0] drops;
 wire new_start,new_bank,new_limit;wire [12:0] new_runs;wire [31:0] new_drops;
 reg read_bank=0;reg [11:0] address=0;
 wire [39:0] data,new_data;wire [1:0] label_color,new_label_color;wire [6:0] root,new_root;
 reference_color_components_opt27 #(.WIDTH(128),.HEIGHT(48)) old(
  .I_clk(clk),.I_rst_n(rst),.I_frame_start(fs),.I_enable(en),.I_de(de),.I_x(x),.I_y(y),.I_color(color),
  .I_analyzer_busy(busy),.O_start(start),.O_bank(bank),.O_runs(runs),.O_limit(limit),.O_dropped(drops),
  .I_read_bank(read_bank),.I_read_addr(address),.O_read_data(data),.I_label(data[6:0]),.O_root(root),.I_color_label(root),.O_label_color(label_color));
 color_components #(.WIDTH(128),.HEIGHT(48)) optimized(
  .I_clk(clk),.I_rst_n(rst),.I_frame_start(fs),.I_enable(en),.I_de(de),.I_x(x),.I_y(y),.I_color(color),
  .I_analyzer_busy(busy),.O_start(new_start),.O_bank(new_bank),.O_runs(new_runs),.O_limit(new_limit),.O_dropped(new_drops),
  .I_read_bank(read_bank),.I_read_addr(address),.O_read_data(new_data),.I_label(new_data[6:0]),.O_root(new_root),.I_color_label(new_root),.O_label_color(new_label_color));
 integer cycles=0,commits=0,records=0,old_commits,xx,yy,j,scenario;
 reg saved_bank;reg [12:0] saved_runs;
 always @(posedge clk)if(rst)begin
  #2;cycles=cycles+1;
  if({start,bank,limit,runs,drops}!=={new_start,new_bank,new_limit,new_runs,new_drops})
   $fatal(1,"Fault observable cycle mismatch scenario%0d cycle%0d oldstate%0d newstate%0d oldbad%b newbad%b old%b new%b",scenario,cycles,old.state,optimized.state,old.engine_bad,optimized.engine_bad,{start,bank,limit,runs,drops},{new_start,new_bank,new_limit,new_runs,new_drops});
  if(start)begin commits=commits+1;saved_bank=bank;saved_runs=runs;end
 end
 task sof;begin de=0;fs=1;@(negedge clk);fs=0;repeat(200)@(negedge clk);end endtask
 task read_committed;integer index;begin
  read_bank=saved_bank;
  for(index=0;index<saved_runs;index=index+1)begin
   address=index;repeat(3)@(negedge clk);
   if({data,root,label_color}!=={new_data,new_root,new_label_color})
    $fatal(1,"Committed run/root/color differs scenario%0d index%0d",scenario,index);
   if(root==0||^root===1'bx)$fatal(1,"Committed root invalid");
   records=records+1;
  end
 end endtask
 task picture(input integer pattern,gap);begin
  for(yy=0;yy<48;yy=yy+1)begin
   for(xx=0;xx<128;xx=xx+1)begin
    x=xx;y=yy;de=1;
    case(pattern)
     0:color=(xx>=32&&xx<81&&yy>=8&&yy<40)?3:0;
     1,4,5,6:color=(xx%2==0)?2'(xx%3+1):0;
     2:color=2'(xx%3+1);
     3:color=2'($random);
     default:color=0;
    endcase
    // Restart during active processing of the preceding full64-run line.
    if(pattern==4&&yy==1&&xx==40)begin
     if(old.state==1)$fatal(1,"Early new-frame test did not reach busy engine");
     fs=1;
    end else fs=0;
    // Asynchronous reset is the component-level cancellation operation.
    if(pattern==5&&yy==1&&xx==40)rst=0;
    if(pattern==5&&yy==1&&xx==44)rst=1;
    if(pattern==6&&yy==1&&xx==40)en=0;
    @(negedge clk);
   end
   if(gap>0)begin de=0;color=0;repeat(gap)@(negedge clk);end
  end
  de=0;color=0;fs=0;repeat(4096)@(negedge clk);
 end endtask
 task recover;begin
  en=1;busy=0;sof();old_commits=commits;picture(0,1280);sof();
  if(commits!=old_commits+1||saved_runs!=32||limit)$fatal(1,"Valid recovery failed scenario%0d",scenario);
  read_committed();
 end endtask
 initial begin
  scenario=0;repeat(4)@(negedge clk);rst=1;recover();
  for(scenario=1;scenario<=9;scenario=scenario+1)begin
   old_commits=commits;
   case(scenario)
    1:picture(1,0);
    2:picture(1,1);
    3:picture(2,1);
    4:picture(3,1);
    5:picture(4,1);
    6:picture(5,1);
    7:picture(6,1);
    8:begin busy=1;picture(0,1280);end
    9:begin en=0;sof();picture(0,1280);end
   endcase
   sof();
   if(commits>old_commits)read_committed();
   recover();
  end
  $display("PASS component fault observables: %0d exact external cycle checks, %0d committed immutable run/root/color records; zero/one blank,64run overrun,128run overflow,random noise,early frame while busy,async reset/cancel,disable/analyzerbusy and valid recovery after each",cycles,records);
  $finish;
 end
 initial begin #100000000;$fatal(1,"Component fault watchdog");end
endmodule
