 
module rgb_luma_96(input wire [95:0] rgb,output wire [31:0] luma);
 genvar p;
 generate for(p=0;p<4;p=p+1)begin:P
  wire [15:0] r={8'd0,rgb[p*24+16+:8]},g={8'd0,rgb[p*24+8+:8]},b={8'd0,rgb[p*24+:8]};
  wire [15:0] s=(r<<6)+(r<<3)+(r<<2)+r+(g<<7)+(g<<4)+(g<<2)+(g<<1)+
      (b<<4)+(b<<3)+(b<<2)+b+16'd128;
  assign luma[p*8+:8]=s[15:8];
 end endgenerate
endmodule

 
 
module unsigned_gain_product #(parameter GAIN_BITS=10)(
 input wire [7:0] pixel,input wire [GAIN_BITS-1:0] gain,
 output wire [GAIN_BITS+7:0] product
);
  
  
 assign product=pixel*gain;
endmodule
