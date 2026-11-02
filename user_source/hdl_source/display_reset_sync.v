 
 
module display_reset_sync (
    input wire I_clk,
    input wire I_async_reset_n,
    output wire O_reset_n
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] S_release;
    always @(posedge I_clk or negedge I_async_reset_n) begin
        if (!I_async_reset_n) S_release <= 2'b00;
        else S_release <= {S_release[0], 1'b1};
    end
    assign O_reset_n = S_release[1];
endmodule
