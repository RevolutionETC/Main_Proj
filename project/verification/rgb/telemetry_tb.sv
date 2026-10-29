`timescale 1ns/1ps
module telemetry_tb;
 reg src=0,dst=0;always #7 src=~src;always #11 dst=~dst;
 reg rst=0;reg [36:0] data={1'b0,12'd1024,12'd1024,12'd1024};wire [36:0] received;
 config_mailbox #(.WIDTH(37),.RESET_VALUE({1'b0,12'd1024,12'd1024,12'd1024})) link(
 .I_src_clk(src),.I_dst_clk(dst),.I_rst_n(rst),.I_data(data),.O_data(received));
 reg [36:0] sent[0:511];integer count=1,j,n;reg match;
 initial sent[0]={1'b0,12'd1024,12'd1024,12'd1024};
 always @(posedge src)if(rst&&link.request==link.ack_sync[1]&&data!=link.payload)begin sent[count]=data;count=count+1;end
 always @(posedge dst)if(rst)begin
  #1;match=0;for(j=0;j<count;j=j+1)if(received===sent[j])match=1;
  if(!match)$fatal(1,"Torn RGB/status telemetry");
 end
 reg vs=0,de=0;wire [23:0] out;
 wb_ui_overlay #(.FONT_FILE("../../user_source/hdl_source/ui/wb_ui_font.hex")) ui(.I_clk(dst),.I_rst_n(rst),
 .I_config({11'd0,1'b0,3'd2,2'd0,2'd0,7'd30,7'd80,1'b1}),.I_telemetry(received),
 .I_vsync(vs),.I_hsync(1'b0),.I_de(de),.I_data(24'h123456),.O_vsync(),.O_hsync(),.O_de(),.O_data(out));
 task new_frame;begin @(negedge dst);de=0;vs=1;repeat(3)@(negedge dst);vs=0;repeat(3)@(negedge dst);de=1;repeat(3)@(negedge dst);end endtask
 reg [36:0] held;
 initial begin
 repeat(4)@(negedge src);rst=1;
 for(n=0;n<120;n=n+1)begin @(negedge src);data={$random,$random};repeat(n%6)@(negedge src);end
 data={1'b1,12'd1536,12'd1024,12'd768};repeat(40)@(negedge dst);new_frame();held=ui.telemetry_cfg;
 if(held!==data||ui.tr100!=150||ui.tg100!=100||ui.tb100!=75)$fatal(1,"Live gain numeric conversion");
 @(negedge src);data={1'b0,12'd3072,12'd1024,12'd512};repeat(60)@(negedge dst);
 if(received!==data||ui.telemetry_cfg!==held||ui.tr100!=150)$fatal(1,"Display telemetry changed mid-frame");
 new_frame();if(ui.telemetry_cfg!==data||ui.tr100!=300||ui.tg100!=100||ui.tb100!=50||ui.telemetry[36])$fatal(1,"Next-frame gain/status refresh");
 $display("PASS live AWB 37-bit RGB/status mailbox, asynchronous rapid updates, no torn telemetry, actual Q10-to-multiplier readouts, display-frame snapshot and next-frame refresh");$finish;
 end
 initial begin #1000000;$fatal(1,"Telemetry watchdog");end
endmodule
