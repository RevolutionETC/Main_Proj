// RGB888 overlay for the already aligned example-1 display stream.
// All syncs and RGB are delayed by the same two register stages.
module dsi_osd_overlay #(
    parameter OSD_ENABLE = 1,
    parameter LOGO_X = 0,
    parameter LOGO_Y = 0,
    parameter TEXT_X = 375,
    parameter TEXT_Y = 120,
    parameter [23:0] TEXT_COLOR = 24'hfff200,
    parameter LOGO_INIT_FILE = "../../../user_source/hdl_source/osd/anlogic_logo.hex"
)(
    input wire I_clk,
    input wire I_rst_n,
    input wire I_enable,
    input wire I_vsync, I_hsync, I_de,
    input wire [23:0] I_data,
    output reg O_vsync, O_hsync, O_de,
    output reg [23:0] O_data
);
    reg vs_d, de_d;
    reg [11:0] x, y;
    reg [3:0] digit0, digit1, digit2, digit3, digit4, digit5;
    wire frame_start = I_vsync && !vs_d;

    // A level VSYNC lasts many clocks; only its rising edge counts a frame.
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            vs_d <= 0; de_d <= 0; x <= 0; y <= 0;
            digit0 <= 0; digit1 <= 0; digit2 <= 0;
            digit3 <= 0; digit4 <= 0; digit5 <= 0;
        end else begin
            vs_d <= I_vsync;
            de_d <= I_de;
            if (frame_start) begin x <= 0; y <= 0; end
            else begin
                if (I_de) x <= x + 1'b1;
                else x <= 0;
                if (de_d && !I_de) y <= y + 1'b1;
            end
            if (frame_start) begin
                if (digit0 != 9) digit0 <= digit0 + 1'b1;
                else begin
                    digit0 <= 0;
                    if (digit1 != 9) digit1 <= digit1 + 1'b1;
                    else begin
                        digit1 <= 0;
                        if (digit2 != 9) digit2 <= digit2 + 1'b1;
                        else begin
                            digit2 <= 0;
                            if (digit3 != 9) digit3 <= digit3 + 1'b1;
                            else begin
                                digit3 <= 0;
                                if (digit4 != 9) digit4 <= digit4 + 1'b1;
                                else begin
                                    digit4 <= 0;
                                    if (digit5 != 9) digit5 <= digit5 + 1'b1;
                                    else digit5 <= 0;
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    // floor(value*16/24), equivalent to the original example-3 scaling.
    function [3:0] scale24;
        input [4:0] value;
        begin
            case(value)
                0,1: scale24=0; 2: scale24=1;
                3,4: scale24=2; 5: scale24=3;
                6,7: scale24=4; 8: scale24=5;
                9,10: scale24=6; 11: scale24=7;
                12,13: scale24=8; 14: scale24=9;
                15,16: scale24=10; 17: scale24=11;
                18,19: scale24=12; 20: scale24=13;
                21,22: scale24=14; 23: scale24=15;
                default: scale24=0;
            endcase
        end
    endfunction

    reg logo_region;
    reg [14:0] logo_addr;
    reg [11:0] lx, ly, tx, ty;
    reg text_region;
    reg [7:0] char_code;
    reg [3:0] char_row, char_col;
    reg [3:0] dec_digit;
    reg [4:0] local_x, local_y;
    wire [15:0] char_bits;
    wire [24:0] logo_pixel;
    osd_char_lib u_font(.I_char(char_code), .I_row(char_row), .O_row_bits(char_bits));
    osd_logo_rom #(.INIT_FILE(LOGO_INIT_FILE)) u_logo(
        .I_clk(I_clk), .I_addr(logo_addr), .O_pixel(logo_pixel));

    // Address selection is separate from the ROM/font output mux to avoid
    // combinational feedback through an external character-ROM module.
    always @(*) begin
        logo_region=0; logo_addr=0; lx=0; ly=0;
        text_region=0; tx=0; ty=0;
        char_code=0; char_row=0; char_col=0;
        dec_digit=0; local_x=0; local_y=0;
        if (OSD_ENABLE && I_de) begin
            if (x>=LOGO_X && x<LOGO_X+160 && y>=LOGO_Y && y<LOGO_Y+160) begin
                logo_region=1;
                lx=x-LOGO_X; ly=y-LOGO_Y;
                logo_addr=ly*15'd160+lx;
            end
            if (x>=TEXT_X && x<TEXT_X+200 && y>=TEXT_Y && y<TEXT_Y+24) begin
                tx=x-TEXT_X; ty=y-TEXT_Y;
                local_y=ty[4:0];
                if (tx<48) begin
                    char_code=(tx<24) ? 8'h80 : 8'h81; // 安 路
                    local_x=(tx<24) ? tx : tx-24;
                    if (ty>=2) begin
                        local_y=ty-2;
                        text_region=1;
                        char_col=scale24(local_x);
                        char_row=scale24(local_y);
                    end
                end else if (tx>=52 && tx<108 && ty>=4 && ty<20) begin
                    text_region=1;
                    if (tx<68) begin char_code="C"; local_x=tx-52; end
                    else if (tx<84) begin char_code="N"; local_x=tx-68; end
                    else if (tx<100) begin char_code="T"; local_x=tx-84; end
                    else begin char_code=":"; local_x=(tx-100)*2; end
                    char_col=local_x[3:0];
                    local_y=ty-4;
                    char_row=local_y[3:0];
                end else if (tx>=110) begin
                    text_region=1;
                    if (tx<125) begin dec_digit=digit5; local_x=tx-110; end
                    else if (tx<140) begin dec_digit=digit4; local_x=tx-125; end
                    else if (tx<155) begin dec_digit=digit3; local_x=tx-140; end
                    else if (tx<170) begin dec_digit=digit2; local_x=tx-155; end
                    else if (tx<185) begin dec_digit=digit1; local_x=tx-170; end
                    else begin dec_digit=digit0; local_x=tx-185; end
                    char_code=8'h30+dec_digit;
                    // floor(value*16/15)==value for value in 0..14.
                    char_col=local_x[3:0];
                    char_row=scale24(local_y);
                end
            end
        end
    end

    reg s1_vs, s1_hs, s1_de;
    reg [23:0] s1_rgb;
    reg s1_logo, s1_text;
    reg [23:0] s2_rgb;
    reg s2_logo,s2_text;
    always @(posedge I_clk or negedge I_rst_n) begin
        if (!I_rst_n) begin
            s1_vs<=0; s1_hs<=0; s1_de<=0; s1_rgb<=0;
            s1_logo<=0; s1_text<=0;
            O_vsync<=0; O_hsync<=0; O_de<=0;
            s2_rgb<=0;s2_logo<=0;s2_text<=0;
        end else begin
            s1_vs<=I_vsync; s1_hs<=I_hsync; s1_de<=I_de; s1_rgb<=I_data;
            s1_logo<=logo_region && I_enable;
            s1_text<=text_region && char_bits[15-char_col] && I_enable;
            O_vsync<=s1_vs; O_hsync<=s1_hs; O_de<=s1_de;
            s2_rgb<=s1_rgb;s2_logo<=s1_logo;s2_text<=s1_text;
        end
    end
    // The second ROM stage is the existing second video stage. A final small
    // combinational mux preserves exactly two clocks of overlay latency.
    always @(*)begin
        if(!O_de)O_data=0;
        else if(s2_logo&&logo_pixel[24])O_data=logo_pixel[23:0];
        else if(s2_text)O_data=TEXT_COLOR;
        else O_data=s2_rgb;
    end
endmodule
