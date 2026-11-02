`timescale 1ns / 1ps































module uics500regAE
(  
input      [8 :0]  REG_INDEX,
output reg [31:0]  REG_DATA,
output     [8 :0]  REG_SIZE,
input      [15:0]  I_AE,
input      [15:0]  I_AG
);

 
 
assign REG_SIZE=9'd5;
always @(*)case(REG_INDEX)
 0:REG_DATA={16'h3800,8'h00};
 1:REG_DATA={16'h3e08,I_AG[15:8]};
 2:REG_DATA={16'h3e09,I_AG[7:0]};
 3:REG_DATA={16'h3800,8'h10};
 4:REG_DATA={16'h3800,8'h40};
 default:REG_DATA=0;
endcase
endmodule
