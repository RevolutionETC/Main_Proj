`timescale 1ns/1ps
module filter_bank_tb #(parameter W=64,H=24,F=16,PREFIX="filters")();
 localparam N=W*H*F/4;
 reg clk=0,rst=0,v=0,u=0,l=0;always #5 clk=~clk;
 reg [95:0] rgb=0;reg [2:0] mode=0;
 wire [95:0] out;wire ov,ou,ol;wire [2:0] om;
 image_filter_bank_96 #(.IMG_WIDTH(W),.IMG_HEIGHT(H)) dut(
  .I_clk(clk),.I_rst_n(rst),.I_mode(mode),.I_data(rgb),.I_valid(v),.I_user(u),.I_last(l),.I_ready(1'b1),
  .O_data(out),.O_valid(ov),.O_user(ou),.O_last(ol),.O_ready(),.O_frame_mode(om));
 reg [95:0] source[0:N-1],expected[0:N-1];
 integer put=0,take=0,frames=0,lines=0,f,y,x,selected;
 function integer selected_mode(input integer n);
  begin selected_mode=(F==2)?n+6:((n<8)?n:15-n);end
 endfunction
 always @(posedge clk)if(rst)begin
  #1;
  if(ou)frames=frames+1;
  if(ov)begin
   if(take>=N||out!==expected[take])$fatal(1,"Filter pixel beat=%0d frame=%0d xy=(%0d,%0d) mode=%0d got=%h expected=%h",take,take/(W*H/4),4*(take%(W/4)),(take/(W/4))%H,om,out,expected[take]);
   if(om!==((selected_mode(take/(W*H/4))==1||selected_mode(take/(W*H/4))==3)?0:selected_mode(take/(W*H/4))))$fatal(1,"Frame tag changed mid-frame");
   if(ol!==(take%(W/4)==W/4-1))$fatal(1,"EOL misaligned at beat %0d",take);
   if(ol)lines=lines+1;
   take=take+1;
  end else if(ol)$fatal(1,"EOL without valid");
 end
 initial begin
  $readmemh({PREFIX,"_input.hex"},source);$readmemh({PREFIX,"_expected.hex"},expected);
  repeat(5)@(negedge clk);rst=1;
  for(f=0;f<F;f=f+1)begin
   selected=selected_mode(f);mode=selected;u=1;
   // Alternate SOF in blanking and SOF coincident with the first pixel.
   if(f%2==0)begin @(negedge clk);u=0;repeat(3)@(negedge clk);end
   for(y=0;y<H;y=y+1)begin
    for(x=0;x<W/4;x=x+1)begin
     if((x+3*y)%7==3)begin v=0;l=0;@(negedge clk);end
     rgb=source[put];put=put+1;v=1;l=(x==W/4-1);
     @(negedge clk);u=0;
     // Requests change during a frame but may only apply at its next SOF.
     mode=(selected+3)%8;
    end
    v=0;l=0;repeat(5)@(negedge clk);
   end
   repeat(W/2+80)@(negedge clk);
   if(take!=(f+1)*W*H/4)$fatal(1,"Incomplete spatial tail frame=%0d beats=%0d",f,take);
  end
  repeat(8)@(negedge clk);
  if(take!=N||frames!=F||lines!=F*H)$fatal(1,"Filter coverage %0d %0d %0d",take,frames,lines);
  $display("PASS six-filter and retired-code bypass oracle %0dx%0d: %0d pixels, %0d frames, exact pixels/SOF/EOL/tags, blank/coincident SOF, bubbles and mid-frame requests",W,H,N*4,F);$finish;
 end
 initial begin #100000000;$fatal(1,"Filter watchdog");end
endmodule

module filter_720p_tb;
 filter_bank_tb #(.W(1280),.H(720),.F(2),.PREFIX("filters720")) run();
endmodule
