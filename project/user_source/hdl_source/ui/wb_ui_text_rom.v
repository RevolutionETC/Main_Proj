module wb_ui_text_rom #(parameter TEXT_FILE="../../../user_source/hdl_source/ui/wb_ui_text.hex")(
 input wire I_clk,input wire [10:0] I_addr,output reg [7:0] O_glyph);
 (* ram_style="block" *) reg [7:0] text[0:2047];
 initial $readmemh(TEXT_FILE,text);
 always @(posedge I_clk)O_glyph<=text[I_addr];
endmodule
