 
 
module i2c_reg16_byte #(
    parameter CLK_HZ = 25000000,
    parameter I2C_HZ = 100000,
    parameter TIMEOUT_CYCLES = CLK_HZ/100
)(
    input wire I_clk, I_rst_n, I_start, I_read,
    input wire [6:0] I_addr,
    input wire [15:0] I_reg,
    input wire [7:0] I_wdata,
    inout wire IO_scl, IO_sda,
    output reg O_busy, O_done, O_error,
    output reg [7:0] O_rdata
);
    localparam DIV = (CLK_HZ + 4*I2C_HZ-1)/(4*I2C_HZ);
    localparam IDLE=0, START0=1, START1=2, START2=3,
      TX0=4, TX1=5, TX2=6, TX3=7,
      ACK0=8, ACK1=9, ACK2=10, ACK3=11,
      REP0=12, REP1=13, REP2=14, REP3=15,
      RX0=16, RX1=17, RX2=18, RX3=19,
      NACK0=20, NACK1=21, NACK2=22, NACK3=23,
      STOP0=24, STOP1=25, STOP2=26, FINISH=27,
      REC0=28, REC1=29, REC2=30, REC3=31;
    reg [5:0] state;
    reg scl_low, sda_low;
    (* async_reg="true" *) reg [1:0] scl_sync, sda_sync;
    reg [31:0] div_count, timeout_count;
    reg [7:0] tx, rx, wdata;
    reg [15:0] reg_addr;
    reg [6:0] dev_addr;
    reg is_read;
    reg [2:0] bitno, byte_index;
    reg [3:0] recovery_count;
    assign IO_scl = scl_low ? 1'b0 : 1'bz;
    assign IO_sda = sda_low ? 1'b0 : 1'bz;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin scl_sync<=3; sda_sync<=3; end
        else begin scl_sync<={scl_sync[0],IO_scl}; sda_sync<={sda_sync[0],IO_sda}; end
    end
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            state<=IDLE; scl_low<=0; sda_low<=0;
            O_busy<=0; O_done<=0; O_error<=0; O_rdata<=0;
            div_count<=0; timeout_count<=0;
            tx<=0; rx<=0; dev_addr<=0; reg_addr<=0; wdata<=0;
            is_read<=0; bitno<=7; byte_index<=0; recovery_count<=0;
        end else begin
            O_done<=0;
            if (!O_busy) begin
                div_count<=0; timeout_count<=0;
                if (I_start) begin
                    O_busy<=1; O_error<=0;
                    dev_addr<=I_addr; reg_addr<=I_reg; wdata<=I_wdata;
                    is_read<=I_read; tx<={I_addr,1'b0};
                    bitno<=7; byte_index<=0; recovery_count<=0;
                    scl_low<=0; sda_low<=0; state<=START0;
                end
            end else if (timeout_count == TIMEOUT_CYCLES-1) begin
                 
                scl_low<=0; sda_low<=0; O_busy<=0; O_done<=1;
                O_error<=1; state<=IDLE; div_count<=0; timeout_count<=0;
            end else begin
                timeout_count<=timeout_count+1'b1;
                if (div_count == DIV-1) begin
                    div_count<=0;
                    case(state)
                    START0: if (scl_sync[1]) begin
                        if (sda_sync[1]) state<=START1;
                        else state<=REC0;
                    end
                    START1: begin sda_low<=1; state<=START2; end
                    START2: begin scl_low<=1; state<=TX0; end
                    TX0: begin sda_low<=!tx[bitno]; state<=TX1; end
                    TX1: begin scl_low<=0; if(scl_sync[1]) state<=TX2; end
                    TX2: state<=TX3;
                    TX3: begin
                        scl_low<=1;
                        if(bitno==0) state<=ACK0;
                        else begin bitno<=bitno-1'b1; state<=TX0; end
                    end
                    ACK0: begin sda_low<=0; state<=ACK1; end
                    ACK1: begin scl_low<=0; if(scl_sync[1]) state<=ACK2; end
                    ACK2: begin
                        if(sda_sync[1]) O_error<=1;
                        state<=ACK3;
                    end
                    ACK3: begin
                        scl_low<=1; bitno<=7;
                        if(O_error) state<=STOP0;
                        else case(byte_index)
                        0: begin tx<=reg_addr[15:8]; byte_index<=1; state<=TX0; end
                        1: begin tx<=reg_addr[7:0]; byte_index<=2; state<=TX0; end
                        2: if(is_read) state<=REP0;
                           else begin tx<=wdata; byte_index<=3; state<=TX0; end
                        3: state<=STOP0;
                        4: begin rx<=0; state<=RX0; end
                        default: state<=STOP0;
                        endcase
                    end
                    REP0: begin sda_low<=0; state<=REP1; end
                    REP1: begin scl_low<=0; if(scl_sync[1]) state<=REP2; end
                    REP2: begin sda_low<=1; state<=REP3; end
                    REP3: begin
                        scl_low<=1; tx<={dev_addr,1'b1}; byte_index<=4; state<=TX0;
                    end
                    RX0: begin sda_low<=0; state<=RX1; end
                    RX1: begin scl_low<=0; if(scl_sync[1]) state<=RX2; end
                    RX2: begin rx[bitno]<=sda_sync[1]; state<=RX3; end
                    RX3: begin
                        scl_low<=1;
                        if(bitno==0) begin O_rdata<=rx; state<=NACK0; end
                        else begin bitno<=bitno-1'b1; state<=RX0; end
                    end
                    NACK0: begin sda_low<=0; state<=NACK1; end
                    NACK1: begin scl_low<=0; if(scl_sync[1]) state<=NACK2; end
                    NACK2: state<=NACK3;
                    NACK3: begin scl_low<=1; state<=STOP0; end
                    STOP0: begin scl_low<=1; sda_low<=1; state<=STOP1; end
                    STOP1: begin scl_low<=0; if(scl_sync[1]) state<=STOP2; end
                    STOP2: begin sda_low<=0; state<=FINISH; end
                    FINISH: begin
                        if(!sda_sync[1]) O_error<=1;
                        O_done<=1; O_busy<=0; state<=IDLE;
                    end
                     
                    REC0: begin scl_low<=1; sda_low<=0; state<=REC1; end
                    REC1: begin scl_low<=0; if(scl_sync[1]) state<=REC2; end
                    REC2: state<=REC3;
                    REC3: begin
                        scl_low<=1;
                        if(recovery_count==8) begin O_error<=1; state<=STOP0; end
                        else begin recovery_count<=recovery_count+1'b1; state<=REC0; end
                    end
                    default: state<=STOP0;
                    endcase
                end else div_count<=div_count+1'b1;
            end
        end
    end
endmodule
