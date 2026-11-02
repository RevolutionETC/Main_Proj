 
 
module gt911_touch #(
    parameter CLK_HZ=25000000,
    parameter I2C_HZ=100000,
    parameter POLL_MS=5,
    parameter RESET_LOW_MS=20,
    parameter ADDRESS_HOLD_MS=6,
    parameter INT_SYNC_MS=55,
    parameter STARTUP_MS=50,
    parameter RELEASE_MS=30
)(
    input wire I_clk, I_rst_n,
    inout wire IO_scl, IO_sda, IO_int,
    output wire O_reset_n,
    output wire O_press, O_held,
    output reg O_online,
    output reg [15:0] O_error_count
);
    localparam RESET=0, HOLD_ADDR=1, SYNC_INT=2, STARTUP=3,
      POLL_WAIT=4, READ_START=5, READ_WAIT=6, CLEAR_START=7, CLEAR_WAIT=8;
    reg [3:0] state;
    reg [31:0] timer;
    reg start, read_op;
    reg [7:0] status;
    reg report_valid;
    wire busy, done, error;
    wire [7:0] rdata;
     
     
    assign IO_int=(state<=SYNC_INT) ? 1'b0 : 1'bz;
    assign O_reset_n=I_rst_n && (state!=RESET);
    i2c_reg16_byte #(.CLK_HZ(CLK_HZ),.I2C_HZ(I2C_HZ)) u_i2c (
      .I_clk(I_clk),.I_rst_n(I_rst_n),.I_start(start),.I_read(read_op),
      .I_addr(7'h5d),.I_reg(16'h814e),.I_wdata(8'h00),
      .IO_scl(IO_scl),.IO_sda(IO_sda),.O_busy(busy),.O_done(done),
      .O_error(error),.O_rdata(rdata));
    touch_press_once #(.CLK_HZ(CLK_HZ),.RELEASE_MS(RELEASE_MS)) u_press (
      .I_clk(I_clk),.I_rst_n(I_rst_n),.I_report_valid(report_valid),
      .I_contacts(status[3:0]),.O_press(O_press),.O_held(O_held));
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            state<=RESET; timer<=0; start<=0; read_op<=1;
            status<=0; report_valid<=0; O_online<=0; O_error_count<=0;
        end else begin
            start<=0; report_valid<=0;
            case(state)
            RESET: if(timer >= (CLK_HZ/1000)*RESET_LOW_MS-1) begin
                timer<=0; state<=HOLD_ADDR;
            end else timer<=timer+1'b1;
            HOLD_ADDR: if(timer >= (CLK_HZ/1000)*ADDRESS_HOLD_MS-1) begin
                timer<=0; state<=SYNC_INT;
            end else timer<=timer+1'b1;
            SYNC_INT: if(timer >= (CLK_HZ/1000)*INT_SYNC_MS-1) begin
                timer<=0; state<=STARTUP;
            end else timer<=timer+1'b1;
            STARTUP: if(timer >= (CLK_HZ/1000)*STARTUP_MS-1) begin
                timer<=0; state<=READ_START;
            end else timer<=timer+1'b1;
            POLL_WAIT: if(timer >= (CLK_HZ/1000)*POLL_MS-1) begin
                timer<=0; state<=READ_START;
            end else timer<=timer+1'b1;
            READ_START: if(!busy) begin start<=1; read_op<=1; state<=READ_WAIT; end
            READ_WAIT: if(done) begin
                if(error) begin
                    O_online<=0;
                    if(O_error_count!=16'hffff) O_error_count<=O_error_count+1'b1;
                    state<=POLL_WAIT; timer<=0;
                end else begin
                    O_online<=1; status<=rdata;
                    if(rdata[7]) state<=CLEAR_START;
                    else begin state<=POLL_WAIT; timer<=0; end
                end
            end
            CLEAR_START: if(!busy) begin start<=1; read_op<=0; state<=CLEAR_WAIT; end
            CLEAR_WAIT: if(done) begin
                 
                 
                if(error) begin
                    O_online<=0;
                    if(O_error_count!=16'hffff) O_error_count<=O_error_count+1'b1;
                end else if(status[3:0]<=5) report_valid<=1;
                timer<=0; state<=POLL_WAIT;
            end
            default: begin state<=RESET; timer<=0; end
            endcase
        end
    end
endmodule
