`timescale 1ns/1ps
module csi_packet_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,hs=0,lane=0;reg [15:0] hd=0;
 wire fs,fe,cv,le,bad;wire [31:0] count;
 csi_unpacket_2lane decode(.I_clk(clk),.I_rst_n(rst),.I_hs_valid(hs),.I_hs_data(hd),
 .O_csi_frame_start(fs),.O_csi_frame_end(fe),.O_csi_valid(cv),.O_csi_hs(),.O_csi_line_end(le),.O_csi_data());
 camera_frame_check #(.LINE_WORDS(8),.LINES(4)) check_frame(.I_clk(clk),.I_rst_n(rst),.I_sof(fs),.I_eof(fe),.I_valid(cv),
 .I_line_end(le),.I_lane_error(lane),.O_previous_bad(bad),.O_frame_toggle(),.O_bad_frames(count));
 task packet(input [7:0] dt,input integer bytes,input bit fault);
 integer j;begin
 // Alignment indications outside active payload must not reject a good frame.
 lane=1;repeat(6)@(negedge clk);lane=0;
 hs=1;hd={dt,8'(bytes)};@(negedge clk);hd={8'(bytes>>8),8'd0};
 for(j=0;j<bytes/2;j=j+1)begin @(negedge clk);hd=16'h8080;lane=fault&&j>=4&&j<=8;end
 lane=0;@(negedge clk);hd=0;@(negedge clk);hs=0;repeat(10)@(negedge clk);
 end endtask
 task frame(input integer lines,bytes,input bit fault);
 integer y;begin packet(0,0,0);for(y=0;y<lines;y=y+1)begin packet(2,0,0);packet(8'h2b,bytes,fault&&y==1);packet(3,0,0);end
 packet(1,0,0);repeat(8)@(negedge clk);end endtask
 initial begin repeat(12)@(negedge clk);rst=1;
 frame(4,32,0);if(bad)$fatal(1,"Alternate CSI/short LS LE packets rejected");
 frame(3,32,0);if(!bad)$fatal(1,"Missing image line accepted");
 frame(4,36,0);if(!bad)$fatal(1,"Extra payload word accepted");
 frame(4,32,1);if(!bad)$fatal(1,"Active payload lane fault accepted");
 frame(4,32,0);if(bad||count!=3)$fatal(1,"Recovery/alignment-noise filtering %d",count);
 $display("PASS real CSI packet boundaries: alternate valid, RAW10 payload end, short FS/FE/LS/LE ignored as image lines, bad width/height/payload error rejection, idle alignment-error immunity and recovery");$finish;end
 initial begin #200000;$fatal(1,"CSI packets watchdog");end
endmodule
