 
 
module touch_press_once #(
    parameter CLK_HZ=25000000,
    parameter RELEASE_MS=30
)(
    input wire I_clk, I_rst_n, I_report_valid,
    input wire [3:0] I_contacts,
    output reg O_press,
    output reg O_held
);
    localparam RELEASE_CYCLES=(CLK_HZ/1000)*RELEASE_MS;
    reg released_seen;
    reg [31:0] release_age;
    always @(posedge I_clk or negedge I_rst_n) begin
        if(!I_rst_n) begin
            O_press<=0; O_held<=0; released_seen<=0; release_age<=0;
        end else begin
            O_press<=0;
            if(released_seen && release_age<RELEASE_CYCLES)
                release_age<=release_age+1'b1;
            if(I_report_valid) begin
                if(I_contacts!=0) begin
                     
                    if(!O_held || (released_seen && release_age>=RELEASE_CYCLES))
                        O_press<=1;
                    O_held<=1; released_seen<=0; release_age<=0;
                end else if(!released_seen) begin
                    released_seen<=1; release_age<=0;
                end
            end
        end
    end
endmodule
