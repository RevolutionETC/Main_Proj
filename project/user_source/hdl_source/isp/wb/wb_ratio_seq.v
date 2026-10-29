// Restoring unsigned division, one bit/clock. Q10 gain is clamped to .5..3.
module wb_ratio_seq(
 input wire I_clk,I_rst_n,I_start,
 input wire [25:0] I_g,I_channel,
 output reg O_busy,O_done,output reg [11:0] O_gain
);
 reg [35:0] quotient;
 reg [26:0] remainder;
 reg [25:0] divisor;
 reg [5:0] count;
 wire [26:0] trial={remainder[25:0],quotient[35]};
 wire ge=trial>={1'b0,divisor};
 wire [35:0] next_q={quotient[34:0],ge};
 always @(posedge I_clk or negedge I_rst_n)
 if(!I_rst_n)begin O_busy<=0;O_done<=0;O_gain<=1024;quotient<=0;remainder<=0;divisor<=1;count<=0;end
 else begin
  O_done<=0;
  if(I_start&&!O_busy)begin
   if(I_channel==0)begin O_gain<=1024;O_done<=1;end
   else begin O_busy<=1;quotient<={I_g,10'b0};remainder<=0;divisor<=I_channel;count<=35;end
  end else if(O_busy)begin
   remainder<=ge ? trial-{1'b0,divisor} : trial;quotient<=next_q;
   if(count==0)begin
    O_busy<=0;O_done<=1;
    O_gain<=(next_q<512)?12'd512:(next_q>3072)?12'd3072:next_q[11:0];
   end else count<=count-1'b1;
  end
 end
endmodule
