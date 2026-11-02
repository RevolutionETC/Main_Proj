 
 
module gt911_pointer #(
 parameter CLK_HZ=25000000,I2C_HZ=100000,POLL_MS=5,
 parameter RESET_LOW_MS=20,ADDRESS_HOLD_MS=6,INT_SYNC_MS=55,STARTUP_MS=50
)(
 input wire I_clk,I_rst_n,inout wire IO_scl,IO_sda,IO_int,
 output wire O_reset_n,output reg O_online,O_report,
 output reg [3:0] O_contacts,output reg [15:0] O_x,O_y,O_width,O_height,O_errors
);
 localparam RESET=0,HOLD=1,SYNC=2,STARTUP=3,WAIT=4,ISSUE=5,DONE=6;
 reg [2:0] state;
 reg [1:0] kind,index;
 reg [31:0] timer;
 reg start,read_op;reg [15:0] addr;
 reg [7:0] status,xlo,xhi,ylo,cfglo;
 wire busy,done,error;wire [7:0] data;
 assign IO_int=(state<=SYNC)?1'b0:1'bz;
 assign O_reset_n=I_rst_n&&(state!=RESET);
 i2c_reg16_byte #(.CLK_HZ(CLK_HZ),.I2C_HZ(I2C_HZ)) bus(
  .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(start),.I_read(read_op),.I_addr(7'h5d),
  .I_reg(addr),.I_wdata(8'd0),.IO_scl(IO_scl),.IO_sda(IO_sda),
  .O_busy(busy),.O_done(done),.O_error(error),.O_rdata(data));
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin
  state<=RESET;kind<=0;index<=0;timer<=0;start<=0;read_op<=1;addr<=16'h8048;
  status<=0;xlo<=0;xhi<=0;ylo<=0;cfglo<=0;
  O_online<=0;O_report<=0;O_contacts<=0;O_x<=0;O_y<=0;O_width<=1024;O_height<=600;O_errors<=0;
 end else begin
  start<=0;O_report<=0;
  case(state)
   RESET:if(timer>=(CLK_HZ/1000)*RESET_LOW_MS-1)begin timer<=0;state<=HOLD;end else timer<=timer+1'b1;
   HOLD:if(timer>=(CLK_HZ/1000)*ADDRESS_HOLD_MS-1)begin timer<=0;state<=SYNC;end else timer<=timer+1'b1;
   SYNC:if(timer>=(CLK_HZ/1000)*INT_SYNC_MS-1)begin timer<=0;state<=STARTUP;end else timer<=timer+1'b1;
   STARTUP:if(timer>=(CLK_HZ/1000)*STARTUP_MS-1)begin timer<=0;state<=ISSUE;end else timer<=timer+1'b1;
   WAIT:if(timer>=(CLK_HZ/1000)*POLL_MS-1)begin timer<=0;state<=ISSUE;end else timer<=timer+1'b1;
   ISSUE:if(!busy)begin start<=1;state<=DONE;end
   DONE:if(done)begin
    if(error)begin
     O_online<=0;if(O_errors!=16'hffff)O_errors<=O_errors+1'b1;
      
     if(kind!=0)begin kind<=1;addr<=16'h814e;read_op<=1;end
     timer<=0;state<=WAIT;
    end else begin
     O_online<=1;
     case(kind)
      0:begin
       if(index==0||index==2)cfglo<=data;
       if(index==1)O_width<={data,cfglo};
       if(index==3)begin O_height<={data,cfglo};kind<=1;addr<=16'h814e;index<=0;end
       else begin index<=index+1'b1;addr<=addr+1'b1;end
       state<=ISSUE;
      end
      1:begin
       status<=data;
       if(!data[7])begin timer<=0;state<=WAIT;end
       else begin
        if(data[3:0]==1)begin kind<=2;index<=0;addr<=16'h8150;end
        else begin kind<=3;addr<=16'h814e;read_op<=0;end
        state<=ISSUE;
       end
      end
      2:begin
       case(index)0:xlo<=data;1:xhi<=data;2:ylo<=data;3:O_y<={data,ylo};endcase
       if(index==3)begin O_x<={xhi,xlo};kind<=3;addr<=16'h814e;read_op<=0;end
       else begin index<=index+1'b1;addr<=addr+1'b1;end
       state<=ISSUE;
      end
      3:begin
       if(status[3:0]<=5)begin O_contacts<=status[3:0];O_report<=1;end
       kind<=1;addr<=16'h814e;read_op<=1;timer<=0;state<=WAIT;
      end
     endcase
    end
   end
   default:state<=RESET;
  endcase
 end
endmodule
