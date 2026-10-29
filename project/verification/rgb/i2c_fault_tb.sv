`timescale 1ns/1ps
module i2c_fault_tb;
    reg clk=0;always #500 clk=~clk;
    reg rst=0,start=0,stretch=0,stuck=0;
    tri1 scl,sda;
    assign scl=stretch?1'b0:1'bz;
    assign sda=stuck?1'b0:1'bz;
    wire busy,done,error;
    wire [7:0] value;
    i2c_reg16_byte #(.CLK_HZ(1000000)) dut (
      .I_clk(clk),.I_rst_n(rst),.I_start(start),.I_read(1'b1),
      .I_addr(7'h5d),.I_reg(16'h814e),.I_wdata(8'h00),
      .IO_scl(scl),.IO_sda(sda),.O_busy(busy),.O_done(done),.O_error(error),.O_rdata(value));
    task launch;
        begin @(negedge clk);start=1;@(negedge clk);start=0;end
    endtask
    integer clocks=0;
    always @(posedge scl) if(stuck)clocks=clocks+1;
    initial begin
        #10000;rst=1;#10000;
        stretch=1;#10000;launch();wait(done);#1;
        if(!error||busy) $fatal(1,"Stuck SCL did not terminate with error");
        stretch=0;#10000;
        launch();wait(done);#1;
        if(!error||scl!==1||sda!==1) $fatal(1,"NACK did not STOP and release bus");
        stuck=1;#10000;launch();wait(done);#1;
        if(!error||clocks<9||busy) $fatal(1,"Missing nine-clock SDA recovery");
        stuck=0;#10000;launch();wait(done);#1;
        if(!error||scl!==1||sda!==1) $fatal(1,"Master did not recover after bus fault");
        $display("PASS I2C stuck-SCL timeout, NACK STOP, stuck-SDA recovery clocks and retry after fault");$finish;
    end
    initial begin #50000000;$fatal(1,"Fault test watchdog");end
endmodule
