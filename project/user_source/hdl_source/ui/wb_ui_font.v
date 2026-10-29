module wb_ui_font #(parameter FONT_FILE="../../../user_source/hdl_source/ui/wb_ui_font.hex")(
 input wire I_clk,input wire [12:0] I_addr,output reg [23:0] O_bits);
 (* ram_style="block" *) reg [23:0] font[0:5823];
 initial $readmemh(FONT_FILE,font);
 always @(posedge I_clk)O_bits<=font[I_addr];
endmodule
