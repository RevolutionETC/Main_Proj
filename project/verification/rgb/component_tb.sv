`timescale 1ns/1ps
module component_tb;
 reg clk=0;always #5 clk=~clk;
 reg rst=0,fs=0,de=0,busy=0;reg [10:0] x=0,y=0;reg [1:0] color=0;
 wire start,bank,limit;wire [12:0] runs;wire [31:0] drops;
 reg read_bank=0;reg [11:0] address=0;wire [39:0] data;wire [1:0] label_color;wire [6:0] root;
 color_components #(.WIDTH(64),.HEIGHT(48)) dut(.I_clk(clk),.I_rst_n(rst),.I_frame_start(fs),.I_enable(1'b1),.I_de(de),.I_x(x),.I_y(y),.I_color(color),
 .I_analyzer_busy(busy),.O_start(start),.O_bank(bank),.O_runs(runs),.O_limit(limit),.O_dropped(drops),.I_read_bank(read_bank),.I_read_addr(address),.O_read_data(data),.I_label(data[6:0]),.O_root(root),.I_color_label(root),.O_label_color(label_color));
 reg [127:0] masks[0:47];reg [15:0] expected[0:3071],counts[0:7];
 integer map_root[0:127],map_expected[0:3072],seen[0:3071];
 integer starts=0,old_starts,case_id,xx,yy,i,k,idx,comp,found_components;
 reg saved_bank;integer saved_runs;
 always @(posedge clk)if(rst)begin #1;if(start)begin starts=starts+1;saved_bank=bank;saved_runs=runs;end end
 task sof;begin de=0;fs=1;@(negedge clk);fs=0;repeat(200)@(negedge clk);end endtask
 task image;
  begin
   for(yy=0;yy<48;yy=yy+1)begin
    for(xx=0;xx<64;xx=xx+1)begin de=1;x=xx;y=yy;color=masks[yy][127-2*xx-:2];@(negedge clk);end
    de=0;color=0;repeat(1280)@(negedge clk);
   end
   repeat(2000)@(negedge clk);
  end
 endtask
 initial begin
  $readmemh("../fixtures/small_counts.hex",counts);repeat(4)@(negedge clk);rst=1;
  for(case_id=0;case_id<8;case_id=case_id+1)begin
   $readmemh($sformatf("../fixtures/small_%0d.hex",case_id),masks);$readmemh($sformatf("../fixtures/small_expected_%0d.hex",case_id),expected);
   old_starts=starts;sof();image();sof();
   if(case_id==5)begin if(starts!=old_starts||!limit)$fatal(1,"Provisional-label overflow must reject the frame");end
   else begin
    if(starts!=old_starts+1||limit)$fatal(1,"Frame handoff case=%0d state=%0d bad=%b cap=%b",case_id,dut.state,dut.engine_bad,dut.cap_bad);
    read_bank=saved_bank;
    for(i=0;i<128;i=i+1)map_root[i]=0;
    for(i=0;i<3073;i=i+1)map_expected[i]=0;
    for(i=0;i<3072;i=i+1)seen[i]=0;
    found_components=0;
    for(i=0;i<saved_runs;i=i+1)begin
     address=i;repeat(3)@(negedge clk);
     if(root==0||^root===1'bx)$fatal(1,"Invalid canonical root");
     for(k=data[28:18];k<=data[17:7];k=k+1)begin
      idx=data[38:29]*64+k;comp=expected[idx];
      if(comp==0||seen[idx]!=0)$fatal(1,"Run pixel background/duplicate");seen[idx]=1;
      if(map_root[root]==0)begin map_root[root]=comp;found_components=found_components+1;end
      if(map_root[root]!=comp)$fatal(1,"Disconnected regions merged, case=%0d",case_id);
      if(map_expected[comp]==0)map_expected[comp]=root;
      if(map_expected[comp]!=root)$fatal(1,"Union equivalence split, case=%0d",case_id);
      if(label_color!==masks[data[38:29]][127-2*k-:2])$fatal(1,"Run color");
     end
    end
    for(i=0;i<3072;i=i+1)if(seen[i]!=(expected[i]!=0))$fatal(1,"Exact pixel coverage");
    if(found_components!=counts[case_id])$fatal(1,"Component count");
   end
  end
  $display("PASS full-resolution components: independent 4-connected pixel oracle, one-pixel gap, late bridge union, touching red/blue/green, true green labels, diagonal-only separation, empty frame, overflow rejection and immutable bank handoff");$finish;
 end
 initial begin #10000000;$fatal(1,"Component watchdog");end
endmodule
