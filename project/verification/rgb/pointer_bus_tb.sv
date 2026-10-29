`timescale 1ns/1ps
module pointer_bus_tb;
 reg clk=0;always #500 clk=~clk;
 reg rst=0,nack=0,slave_low=0,fail_clear=0;
 reg [15:0] fail_reg=16'hffff;
 tri1 scl,sda,int_pin;
 assign sda=slave_low?1'b0:1'bz;
 wire reset_n,online,report;
 wire [3:0] contacts;wire [15:0] x,y,width,height,errors;
 gt911_pointer #(.CLK_HZ(1000000)) dut(.I_clk(clk),.I_rst_n(rst),.IO_scl(scl),.IO_sda(sda),.IO_int(int_pin),
 .O_reset_n(reset_n),.O_online(online),.O_report(report),.O_contacts(contacts),.O_x(x),.O_y(y),.O_width(width),.O_height(height),.O_errors(errors));
 reg [7:0] status=0;
 integer reports=0,clears=0,reads=0;
 always @(posedge clk)if(report)begin
  reports=reports+1;
  if(contacts==1&&(x!=400||y!=240))$fatal(1,"Incoherent first-contact coordinates");
 end
 function [7:0] register_value(input [15:0] address);
  begin case(address)
   16'h8048:register_value=8'h20;16'h8049:register_value=8'h03;
   16'h804a:register_value=8'he0;16'h804b:register_value=8'h01;
   16'h814e:register_value=status;
   16'h8150:register_value=8'h90;16'h8151:register_value=8'h01;
   16'h8152:register_value=8'hf0;16'h8153:register_value=8'h00;
   default:begin register_value=0;$fatal(1,"Unexpected GT911 read %h",address);end
  endcase end
 endfunction
    task automatic start_condition;
        begin
            @(negedge sda);
            while(scl!==1'b1) @(negedge sda);
        end
    endtask
    task automatic recv_byte(output reg [7:0] value);
        integer i;
        begin
            for(i=7;i>=0;i=i-1) begin @(posedge scl); value[i]=sda; end
            @(negedge scl); slave_low=!nack;
            @(posedge scl);
            @(negedge scl); slave_low=0;
        end
    endtask
    task automatic send_byte(input reg [7:0] value);
        integer i;
        begin
            for(i=7;i>=0;i=i-1) begin
                slave_low=!value[i]; @(posedge scl); @(negedge scl);
            end
            slave_low=0; @(posedge scl);
            if(sda!==1'b1) $fatal(1,"Master did not NACK last read byte");
            @(negedge scl);
        end
    endtask

 reg [7:0] address,hi,lo,value;
 reg [15:0] pointer;
 integer j;
 initial forever begin
  nack=0;start_condition();recv_byte(address);
  if(address!==8'hba)$fatal(1,"GT911 unexpected address");
  recv_byte(hi);recv_byte(lo);pointer={hi,lo};
  @(posedge scl);
  if(sda===1'b1)begin
   start_condition();nack=(pointer==fail_reg);recv_byte(address);
   if(address!==8'hbb)$fatal(1,"Missing repeated START");
   if(!nack)begin value=register_value(pointer);send_byte(value);reads=reads+1;end
  end else begin
   value[7]=sda;
   for(j=6;j>=0;j=j-1)begin @(posedge scl);value[j]=sda;end
   @(negedge scl);slave_low=!fail_clear;
   @(posedge scl);@(negedge scl);slave_low=0;
   if(pointer!=16'h814e||value!=0)$fatal(1,"Configuration must not be written");
   if(!fail_clear)begin status=0;clears=clears+1;end
  end
 end
 integer old_reports,old_errors;
 initial begin
  #10000;rst=1;wait(online);wait(width==800&&height==480);#10000000;
  old_reports=reports;status=8'h81;wait(reports>old_reports);
  if(x!=400||y!=240)$fatal(1,"Contact decode");
  old_reports=reports;old_errors=errors;fail_reg=16'h8152;status=8'h81;
  wait(errors>old_errors);#15000000;
  if(reports!=old_reports)$fatal(1,"Coordinate NACK fabricated report");
  fail_reg=16'hffff;wait(reports>old_reports);
  old_reports=reports;old_errors=errors;fail_clear=1;status=8'h81;
  wait(errors>old_errors);#15000000;
  if(reports!=old_reports)$fatal(1,"Failed clear committed report");
  fail_clear=0;wait(reports>old_reports);
  old_reports=reports;status=8'h80;wait(reports>old_reports);if(contacts!=0)$fatal(1,"Release report");
  old_reports=reports;status=8'h82;wait(reports>old_reports);if(contacts!=2)$fatal(1,"Multi-touch report");
  old_reports=reports;status=8'h86;#30000000;if(reports!=old_reports)$fatal(1,"Malformed count report");
  $display("PASS GT911 serial resolution/coordinate reads, little-endian first contact, repeated START/NACK, status-clear ACK commit, coordinate/clear failure retry, release/multi-touch, no configuration writes; reads=%0d clears=%0d",reads,clears);$finish;
 end
 initial begin #1000000000;$fatal(1,"Pointer bus watchdog");end
endmodule
