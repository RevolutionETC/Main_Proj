`timescale 1ns/1ps
module coordinates_tb;
 reg clk=0;always #5 clk=~clk;reg rst=0,start=0,fs=0,en=1,cancel=0;
 reg [383:0] objects=0;reg [15:0] colors=0;reg [10:0] x=0,y=0;
 wire busy,done,valid;wire [1:0] ink;wire [2:0] status;wire [3:0] count;
 target_mask dut(.I_clk(clk),.I_rst_n(rst),.I_start(start),.I_cancel(cancel),.I_enable(en),.I_frame_start(fs),
  .I_objects(objects),.I_colors(colors),.I_limit(1'b0),.I_capture_limit(1'b0),.O_busy(busy),.O_done(done),.O_valid(valid),.O_status(status),.O_count(count),.I_x(x),.I_y(y),.O_color(ink));
 reg [7:0] expected_char;wire [34:0] expected_glyph;
 target_ascii_font oracle(.I_char(expected_char),.I_row(3'd0),.O_bits(),.O_glyph(expected_glyph));
 task prepare;integer c;begin @(negedge clk);start=1;@(negedge clk);start=0;c=0;while(!done&&c<5000)begin @(negedge clk);c=c+1;end if(!done)$fatal(1,"Coordinate preparation deadline state=%0d busy=%0d index=%0d",dut.state,busy,dut.index);end endtask
 task commit;begin fs=1;@(negedge clk);fs=0;repeat(3)@(negedge clk);end endtask
 task sample(input integer xx,yy,col);begin x=xx;y=yy;repeat(2)@(negedge clk);if(ink!==col[1:0])$fatal(1,"Coordinate pixel %0d,%0d got=%0d exp=%0d",xx,yy,ink,col);end endtask
 task item(input integer slot,palette,kind,l,r,t,b);begin objects[slot*48+:48]={1'b1,2'(kind),11'(l),11'(r),11'(t),11'(b),1'b0};colors[slot*2+:2]=palette;end endtask
 task label_check(input integer slot,input [255:0] text,input integer length,palette,draw);
  integer c,row,col,px,py;reg [34:0] actual;begin
   if(dut.front_len[slot]!=length)$fatal(1,"Unexpected character count");
   for(c=0;c<length;c=c+1)begin
    expected_char=text>>((length-c-1)*8);#1;
    actual=dut.front_bank?dut.glyph1[slot*32+c]:dut.glyph0[slot*32+c];
    if(actual!==expected_glyph)$fatal(1,"Wrong coordinate/name character slot=%0d pos=%0d ascii=%h got=%h expected=%h",slot,c,expected_char,actual,expected_glyph);
    if(draw)for(row=0;row<7;row=row+1)for(col=0;col<6;col=col+1)begin
     px=2*(dut.front_x[slot]+c*6+col);py=2*(dut.front_y[slot]+row);
     sample(px,py,col<5&&expected_glyph[(6-row)*5+4-col]?palette:0);
    end
   end
  end
 endtask
 integer i;
 initial begin
  repeat(5)@(negedge clk);rst=1;
  item(0,1,2,101,180,121,210);prepare();commit();label_check(0,"RECTANGLE (140,165)",19,1,1);sample(100,160,1);
  objects=0;colors=0;item(0,2,1,901,1022,401,598);prepare();sample(100,160,1);commit();
  label_check(0,"CIRCLE (961,499)",16,2,1);if(dut.front_x[0]+16*6>512)$fatal(1,"Right edge label clipping");
  objects=0;colors=0;item(0,3,3,91,110,71,90);prepare();commit();label_check(0,"TRIANGLE (100,80)",17,3,1);
  // Integer boundaries and all eight slots, no leading zeros.
  objects=0;colors=0;
  item(0,1,1,0,0,0,0);item(1,2,1,9,9,9,9);item(2,3,1,10,10,10,10);item(3,1,1,99,99,99,99);
  item(4,2,1,100,100,100,100);item(5,3,1,999,999,599,599);item(6,1,1,1000,1000,0,0);item(7,2,1,1023,1023,599,599);
  prepare();commit();if(count!=8||status!=4)$fatal(1,"Eight coordinate slots/status");
  label_check(0,"CIRCLE (0,0)",12,1,0);label_check(1,"CIRCLE (9,9)",12,2,0);label_check(2,"CIRCLE (10,10)",14,3,0);label_check(3,"CIRCLE (99,99)",14,1,0);
  label_check(4,"CIRCLE (100,100)",16,2,0);label_check(5,"CIRCLE (999,599)",16,3,0);label_check(6,"CIRCLE (1000,0)",15,1,0);label_check(7,"CIRCLE (1023,599)",17,2,0);
  objects=0;colors=0;prepare();commit();if(status!=3||count!=0)$fatal(1,"Empty status metadata");sample(458,530,0);sample(466,530,0);
  en=0;cancel=1;@(negedge clk);if(status!=0)$fatal(1,"OFF status");
  $display("PASS coordinates: exact box-center floor, odd bounds, all RGB/classes, decimal 0/9/10/99/100/999/1000/1023 and 599, eight slots, pixel glyphs, right clamp, atomic glyph/geometry commit, metadata-only NO TARGET and disable");$finish;
 end
 initial begin #10000000;$fatal(1,"Coordinate watchdog");end
endmodule
