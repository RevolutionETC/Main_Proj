`timescale 1ns/1ps
module awb_guard_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,v=0,u=0,l=0,bad=0;reg [95:0] rgb=0;
 wire [11:0] gr,gb;wire stats_ok;
 wb_balance_96 #(.MIN_SAMPLES(16),.FRAME_BEATS(128),.FRAME_LINES(8)) dut(
 .I_clk(clk),.I_rst_n(rst),.I_mode(2'd0),.I_kelvin_index(7'd30),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),
 .I_ready(1'b1),.I_previous_bad(bad),.O_data(),.O_valid(),.O_user(),.O_last(),.O_ready(),.O_gain_r(gr),.O_gain_b(gb),.O_statistics_ok(stats_ok));
 task frame(input integer n,period,input [23:0] color,input bit reject,input integer usable);
 integer j;begin
 u=1;v=0;bad=0;@(negedge clk);u=0;
 for(j=0;j<n;j=j+1)begin v=1;l=((j+1)%period)==0;rgb={4{j<usable?color:24'd0}};@(negedge clk);end
 v=0;l=0;repeat(100)@(negedge clk);
 u=1;bad=reject;@(negedge clk);u=0;repeat(100)@(negedge clk);
 end endtask
 integer a,b;
 task unchanged;begin if(stats_ok)$fatal(1,"Rejected frame reported as usable");if(dut.auto_r!=a||dut.auto_b!=b)$fatal(1,"Rejected frame changed AWB %d %d",dut.auto_r,dut.auto_b);end endtask
 initial begin repeat(4)@(negedge clk);rst=1;
 frame(128,16,24'h5078a0,0,128);if(!stats_ok||dut.auto_r!=1032||dut.auto_b!=1016)$fatal(1,"Per-frame slew bound");a=dut.auto_r;b=dut.auto_b;
 frame(127,16,24'h5078a0,0,128);unchanged();
 frame(128,32,24'h5078a0,0,128);unchanged();
 frame(128,16,24'h5078a0,1,128);unchanged();
 frame(128,16,24'h5078a0,0,15);unchanged();
 frame(128,16,24'hffffff,0,128);unchanged();
 frame(128,16,24'h000000,0,128);unchanged();
 frame(128,16,24'h64c8c8,0,128);unchanged();
 frame(128,16,24'h5078a0,0,128);unchanged();
 frame(128,16,24'h5078a0,0,128);
 if(dut.auto_r!=1040||dut.auto_b!=1008)$fatal(1,"Stable-frame recovery");
 $display("PASS AWB complete beat/line count, receiver verdict, minimum sample proportion, dark/clipped rejection, luminance-jump hold, maximum Q10 step8 and stable-frame recovery");$finish;end
 initial begin #500000;$fatal(1,"AWB guard watchdog");end
endmodule
