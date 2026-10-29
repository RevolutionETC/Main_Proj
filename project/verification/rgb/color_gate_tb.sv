`timescale 1ns/1ps
module color_gate_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0;reg [23:0] rgb=0;integer i,n=0;
 red_target_video #(.WIDTH(64),.HEIGHT(48)) dut(.I_clk(clk),.I_rst_n(rst),.I_enable(1'b0),.I_page(3'd0),.I_effect(2'd0),.I_vsync(1'b0),.I_hsync(1'b0),.I_de(1'b0),.I_data(rgb),.O_vsync(),.O_hsync(),.O_de(),.O_data());
 task sample(input [23:0] value,input [1:0] color);begin rgb=value;@(negedge clk);if(dut.color1!==color)$fatal(1,"RGB gate %h got=%0d expected=%0d",value,dut.color1,color);n=n+1;end endtask
 initial begin repeat(4)@(negedge clk);rst=1;
  sample(24'hd02020,1);sample(24'h641010,1);sample(24'hdc8080,1);
  sample(24'h2020d0,2);sample(24'h181860,2);sample(24'h6078c0,2);
  sample(24'h20d020,3);sample(24'h186018,3);sample(24'h78c060,3);
  sample(24'h503035,1);sample(24'h353050,2);sample(24'h305035,3);
  sample(24'h503036,0);sample(24'h363050,2);sample(24'h305036,3);
  sample(24'h8c8cb4,2);sample(24'h8cb48c,3);sample(24'h101045,2);sample(24'h104510,3);
  // Weak paper casts accepted by the former broad gates must be rejected.
  sample(24'h5c707e,0);sample(24'h708274,0);sample(24'h969fb4,0);sample(24'h96b49f,0);
  sample(24'hffff00,0);sample(24'h00ffff,0);sample(24'hff00ff,0);
  sample(24'h10102f,0);sample(24'h102f10,0);
  for(i=0;i<256;i=i+1)sample({i[7:0],i[7:0],i[7:0]},0);
  // Dense channel permutations: symmetry and disjointness, including bright colors.
  for(i=80;i<256;i=i+7)begin
   sample({i[7:0],8'd24,8'd24},1);sample({8'd24,8'd24,i[7:0]},2);sample({8'd24,i[7:0],8'd24},3);
  end
  $display("PASS %0d RGB samples: unchanged red, symmetric blue/green, weak cast rejection, neutral grayscale and disjoint color gates",n);$finish;
 end
endmodule
