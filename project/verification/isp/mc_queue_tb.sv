`timescale 1ns/1ps
module w155_d512_fifo(input clk,rst,we,input [154:0] di,input re,output valid,output [154:0] dout,
 output afull,full_flag,empty_flag,aempty,output [8:0] wrusedw,rdusedw);
 reg [154:0] mem[0:511];reg [8:0] wp=0,rp=0;reg [9:0] count=0;
 assign dout=mem[rp];assign valid=re;assign full_flag=count==512;assign empty_flag=count==0;
 assign afull=count>=500;assign aempty=count<=2;assign wrusedw=count[8:0];assign rdusedw=count[8:0];
 always @(posedge clk)if(rst)begin wp<=0;rp<=0;count<=0;end
 else begin
  if(we)begin if(full_flag)$fatal(1,"Command full");mem[wp]<=di;wp<=wp+1'b1;end
  if(re)begin if(empty_flag)$fatal(1,"Command empty");rp<=rp+1'b1;end
  case({we,re})2'b10:count<=count+1'b1;2'b01:count<=count-1'b1;default:;endcase
 end
endmodule
module mc_queue_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,wr=0,rd=0,ar=0,dr=0;reg [24:0] addr=0;reg [127:0] data=0;
 wire ready,idle,en,wren;wire [24:0] outaddr;wire [2:0] cmd;wire [127:0] wd;
 mc_to_user_interface dut(.I_clk(clk),.I_rst_n(rst),.I_ddr_user_wr_en(wr),.I_ddr_user_rd_en(rd),.I_ddr_user_addr(addr),.I_ddr_user_wr_data(data),
 .O_ddr_user_ready(ready),.O_writes_idle(idle),.O_ddr_user_rd_valid(),.O_ddr_user_rd_data(),
 .O_mc_app_en(en),.O_mc_app_addr(outaddr),.O_mc_app_cmd(cmd),.I_mc_app_rdy(ar),.O_mc_app_wdf_wren(wren),.O_mc_app_wdf_data(wd),
 .O_mc_app_wdf_end(),.O_mc_app_wdf_mask(),.I_mc_app_wdf_rdy(dr),.I_mc_app_rd_data(128'd0),.I_mc_app_rd_data_end(1'b0),.I_mc_app_rd_data_valid(1'b0));
 integer sent=0,taken=0,writes=0,cycle=0,i;
 always @(posedge clk)if(rst)begin
  if(wr||rd)sent=sent+1;
  if(en)begin
   if(!ar||!dr||outaddr!=taken*8||cmd!=((taken%3)==0?1:0))$fatal(1,"Command order/handshake");
   if(cmd==0)begin if(!wren||wd!==128'(taken))$fatal(1,"Write payload");writes=writes+1;end
   taken=taken+1;
  end
 end
 initial begin repeat(5)@(negedge clk);rst=1;
 for(i=0;i<400;i=i+1)begin addr=i*8;data=i;rd=i%3==0;wr=!rd;@(negedge clk);end
 wr=0;rd=0;repeat(5)@(negedge clk);if(idle||taken!=0)$fatal(1,"Early completion before MC");
 ar=1;repeat(20)@(negedge clk);if(idle||taken!=0)$fatal(1,"Write-data backpressure ignored");
 for(i=0;i<700;i=i+1)begin ar=i%5!=0;dr=i%7!=0;@(negedge clk);end
 ar=1;dr=1;repeat(500)@(negedge clk);
 if(!idle||taken!=400||writes!=266||sent!=400)$fatal(1,"MC completion counters %d %d %d",taken,writes,sent);
 $display("PASS MC command FIFO: queued writes remain uncommitted through independent address/data stalls, 400 ordered mixed commands, exact write drain");$finish;end
endmodule
