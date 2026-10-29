`timescale 1ns/1ps
module logo_address_equivalence_tb;
 reg clk=0;always #5 clk=~clk;
 reg [14:0] address=0;
 wire [24:0] pixel,reference_pixel;
 osd_logo_rom #(.INIT_FILE("../../user_source/hdl_source/osd/anlogic_logo.hex")) dut(
  .I_clk(clk),.I_addr(address),.O_pixel(pixel));
 logo_reference_rom #(.INIT_FILE("../../user_source/hdl_source/osd/anlogic_logo.hex")) reference_rom(
  .I_clk(clk),.I_addr(address),.O_pixel(reference_pixel));
 reg [24:0] original[0:25599];
 initial $readmemh("../../user_source/hdl_source/osd/anlogic_logo.hex",original);
 integer i,x,y,cropped,previous=0,checks=0,active_checks=0;
 reg primed=0;reg [31:0] random_state=32'h98b26c57;
 reg [24:0] expected;
 task tick(input integer next_address);
 begin
  @(negedge clk);address=next_address[14:0];#1;
  x=next_address%160;y=next_address/160;
  cropped=((y-34)*146+x-7)&16383;
  if(dut.x!==x[7:0]||dut.y!==y[7:0]||dut.addr!==cropped[13:0] ||
     {dut.in_bounds,dut.x,dut.y,dut.addr}!==
     {reference_rom.in_bounds,reference_rom.x,reference_rom.y,reference_rom.addr})
   $fatal(1,"address mismatch input=%0d xy=%0d,%0d crop=%0d",next_address,dut.x,dut.y,dut.addr);
  @(posedge clk);#1;
  if(primed)begin
   expected=previous<25600?original[previous]:25'd0;
   if(pixel!==reference_pixel||pixel!==expected)
    $fatal(1,"pixel/latency mismatch previous=%0d new=%h old=%h expected=%h",previous,pixel,reference_pixel,expected);
   checks=checks+1;
   if(expected[24])active_checks=active_checks+1;
  end
  previous=next_address;primed=1;
 end endtask
 initial begin
  // All possible addresses, including 7168 addresses outside the source image.
  for(i=0;i<32768;i=i+1)tick(i);
  for(i=32767;i>=0;i=i-1)tick(i);
  // Abrupt row/border changes verify exactly the original two RAM stages.
  for(i=0;i<32768;i=i+1)begin
   random_state={random_state[30:0],random_state[31]^random_state[21]^random_state[1]^random_state[0]};
   tick(random_state[14:0]);
  end
  tick(0);
  if(checks!=98304||active_checks<10000)$fatal(1,"insufficient address/pixel coverage checks=%0d active=%0d",checks,active_checks);
  $display("PASS logo address optimization: all32768 addresses forward/reverse plus32768 jumps, %0d exact original RGBA outputs, original two-RAM latency, transparent borders and out-of-image blanking; %0d active pixels",checks,active_checks);
  $finish;
 end
 initial begin #1500000;$fatal(1,"logo address equivalence watchdog");end
endmodule
