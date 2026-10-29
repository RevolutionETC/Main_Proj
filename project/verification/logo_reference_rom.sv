// Exact original logo, lossless cropped palette representation, two RAM stages.
module logo_reference_rom #(
    parameter INIT_FILE = "../../../user_source/hdl_source/osd/anlogic_logo.hex"
)(
    input wire I_clk,
    input wire [14:0] I_addr,
    output reg [24:0] O_pixel
);
    (* ram_style="bram" *) reg [24:0] palette[0:579]; //synthesis force_ram
    initial begin
        $readmemh({INIT_FILE,".palette"},palette);
    end
    wire [7:0] x=I_addr%160,y=I_addr/160;
    wire in_bounds=x>=7&&x<153&&y>=34&&y<128;
    wire [13:0] addr=(y-8'd34)*14'd146+x-8'd7;
    wire [9:0] index;
`ifdef __ICARUS__
    reg [9:0] indices[0:13723];
    reg [9:0] index_q;
    initial $readmemb({INIT_FILE,".index.dat"},indices);
    always @(posedge I_clk)index_q<=indices[in_bounds?addr:14'd0];
    assign index=index_q;
`else
    // Explicit vendor memory prevents ROM-to-LUT expansion of the index image.
    // SP/NOREG has exactly one synchronous read cycle, matching the RTL model.
    PH1P_LOGIC_ERAM #(
        .DATA_WIDTH_A(10),.ADDR_WIDTH_A(14),.DATA_DEPTH_A(13724),
        .DATA_WIDTH_B(10),.ADDR_WIDTH_B(14),.DATA_DEPTH_B(13724),
        .MODE("SP"),.REGMODE_A("NOREG"),.IMPLEMENT("20K"),
        .DEBUGGABLE("NO"),.PACKABLE("NO"),
        .INIT_FILE({INIT_FILE,".index.dat"}),.FILL_ALL("NONE")
    ) index_rom (
        .dia(10'd0),.dib(10'd0),.addra(in_bounds?addr:14'd0),.addrb(14'd0),
        .cea(1'b1),.ceb(1'b0),.ocea(1'b0),.oceb(1'b0),
        .clka(I_clk),.clkb(1'b0),.wea(1'b0),.web(1'b0),
        .bea(1'b0),.beb(1'b0),.rsta(1'b0),.rstb(1'b0),.doa(index),.dob()
    );
`endif
    reg in_bounds_d;
    always @(posedge I_clk)begin
        in_bounds_d<=in_bounds;
        O_pixel<=in_bounds_d?palette[index]:25'd0;
    end
endmodule
