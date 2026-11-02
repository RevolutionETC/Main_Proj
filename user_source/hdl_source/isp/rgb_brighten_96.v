 
 
 
module rgb_brighten_96 #(
    parameter ENABLE = 1'b1
)(
    input wire [95:0] I_data,
    output wire [95:0] O_data
);
    function [7:0] lift;
        input [7:0] value;
        reg [8:0] wide;
        begin
            if (value < 8'd64)
                wide = {1'b0,value} + {2'b0,value[7:1]};
            else if (value < 8'd192)
                wide = {1'b0,value} + 9'd32;
            else
                wide = {1'b0,value} + ((9'd255-{1'b0,value}) >> 1);
            lift = wide[7:0];
        end
    endfunction
    genvar channel;
    generate for(channel=0;channel<12;channel=channel+1) begin:g_channel
        assign O_data[channel*8 +:8] = ENABLE ? lift(I_data[channel*8 +:8]) : I_data[channel*8 +:8];
    end endgenerate
endmodule
