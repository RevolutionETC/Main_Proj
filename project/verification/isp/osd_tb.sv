`timescale 1ns/1ps
module osd_tb;
    reg clk=0; always #5 clk=~clk;
    reg rst=0, vs=0, hs=0, de=0, enable=1;
    reg [23:0] rgb=0;
    wire [2:0] ovs, ohs, ode;
    wire [23:0] out0,out1,out2;
    dsi_osd_overlay #(.LOGO_INIT_FILE("../../user_source/hdl_source/osd/anlogic_logo.hex")) dut(
        .I_clk(clk),.I_rst_n(rst),.I_enable(enable),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),
        .O_vsync(ovs[0]),.O_hsync(ohs[0]),.O_de(ode[0]),.O_data(out0));
    dsi_osd_overlay #(.OSD_ENABLE(0),
        .LOGO_INIT_FILE("../../user_source/hdl_source/osd/anlogic_logo.hex")) disabled(
        .I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),
        .O_vsync(ovs[1]),.O_hsync(ohs[1]),.O_de(ode[1]),.O_data(out1));
    dsi_osd_overlay #(.LOGO_X(250),.LOGO_Y(200),.TEXT_X(10),.TEXT_Y(10),
        .TEXT_COLOR(24'h00ff99),
        .LOGO_INIT_FILE("../../user_source/hdl_source/osd/anlogic_logo.hex")) moved(
        .I_clk(clk),.I_rst_n(rst),.I_enable(1'b1),.I_vsync(vs),.I_hsync(hs),.I_de(de),.I_data(rgb),
        .O_vsync(ovs[2]),.O_hsync(ohs[2]),.O_de(ode[2]),.O_data(out2));

    // Golden data comes from the supplied sparse logo and font, not DUT state.
    reg [24:0] logo[0:25599];
    reg [15:0] font[0:4095];
    initial begin
        $readmemh("../../user_source/hdl_source/osd/anlogic_logo.hex",logo);
        $readmemh("../reference_font.hex",font);
    end
    integer mx=0,my=0,frame_count=0;
    integer checked=0, active=0, logo_hits=0, text_hits=0, transparent=0;
    function [23:0] reference_pixel(input integer mode,xx,yy,count,input [23:0] background);
        integer lx,ly,tx,ty,c,row,col,digit,dx,i,number;
        reg [15:0] bits;
        reg [24:0] p;
        reg hit;
        begin
            reference_pixel=background;
            if (mode!=1) begin
                lx=xx-((mode==2)?250:0); ly=yy-((mode==2)?200:0);
                p=0;
                if (lx>=0 && lx<160 && ly>=0 && ly<160) p=logo[ly*160+lx];
                tx=xx-((mode==2)?10:375); ty=yy-((mode==2)?10:120);
                hit=0; c=0;row=0;col=0;
                if(tx>=0 && tx<200 && ty>=0 && ty<24) begin
                    if(tx<48 && ty>=2) begin
                        c=(tx<24)?128:129;
                        col=((tx%24)*16)/24;
                        row=((ty-2)*16)/24;
                        hit=1;
                    end else if(tx>=52 && tx<100 && ty>=4 && ty<20) begin
                        c=(tx<68)?67:((tx<84)?78:84);
                        col=(tx-52)%16;row=ty-4;hit=1;
                    end else if(tx>=100 && tx<108 && ty>=4 && ty<20) begin
                        c=58;col=(tx-100)*16/8;row=ty-4;hit=1;
                    end else if(tx>=110) begin
                        dx=(tx-110)/15;
                        number=count%1000000;
                        for(i=0;i<5-dx;i=i+1) number=number/10;
                        digit=number%10;
                        c=48+digit;col=((tx-110)%15)*16/15;row=ty*16/24;hit=1;
                    end
                    bits=font[c*16+row];
                    hit=hit && bits[15-col];
                end
                if(p[24]) reference_pixel=p[23:0];
                else if(hit) reference_pixel=(mode==2)?24'h00ff99:24'hfff200;
            end
        end
    endfunction

    reg pvs=0,phs=0,pde=0;
    reg [23:0] exp0=0,exp1=0,exp2=0;
    reg [23:0] q0,q1,q2;
    reg qvs,qhs,qde;
    integer count_actual;
    integer capture_fd=0,capture_pixels=0;
    reg capture=0, prev_capture=0;
    always @(posedge clk) begin
        if(!rst) begin
            exp0=0;exp1=0;exp2=0;pvs=0;phs=0;pde=0;prev_capture=0;
            #1;
            if({ovs,ohs,ode,out0,out1,out2}!==0) $fatal(1,"reset did not blank output");
        end else begin
            q0=exp0;q1=exp1;q2=exp2;qvs=pvs;qhs=phs;qde=pde;
            exp0=de?(enable?reference_pixel(0,mx,my,frame_count,rgb):rgb):0;
            exp1=de?rgb:0;
            exp2=de?reference_pixel(2,mx,my,frame_count,rgb):0;
            pvs=vs;phs=hs;pde=de;
            #1;
            if(ovs!=={3{qvs}} || ohs!=={3{qhs}} || ode!=={3{qde}})
                $fatal(1,"sync/DE pipeline mismatch at input %0d,%0d",mx,my);
            if(out0!==q0 || out1!==q1 || out2!==q2)
                $fatal(1,"RGB mismatch at input %0d,%0d: %h/%h %h/%h %h/%h",mx,my,out0,q0,out1,q1,out2,q2);
            count_actual=dut.digit5*100000+dut.digit4*10000+dut.digit3*1000+
                dut.digit2*100+dut.digit1*10+dut.digit0;
            if(count_actual!==frame_count%1000000) $fatal(1,"BCD mismatch %d != %d",count_actual,frame_count%1000000);
            if(ode[0]) begin
                active=active+1;
                if(out0!=out1) begin
                    if(out0==24'hfff200) text_hits=text_hits+1;
                    else logo_hits=logo_hits+1;
                end else transparent=transparent+1;
            end
            if(prev_capture && ode[0]) begin
                $fwrite(capture_fd,"%c%c%c",out0[23:16],out0[15:8],out0[7:0]);
                capture_pixels=capture_pixels+1;
            end
            prev_capture=capture;
            checked=checked+1;
        end
    end

    task tick(input bit v,h,d,input integer xx,yy,input [23:0] value);
        begin
            @(negedge clk);
            if(rst && v && !vs) frame_count=frame_count+1;
            vs=v;hs=h;de=d;mx=xx;my=yy;rgb=value;
            @(posedge clk);#2;
        end
    endtask
    task new_frame(input integer width);
        integer j;
        begin
            for(j=0;j<width;j=j+1) tick(1,0,0,0,0,0);
            repeat(4) tick(0,0,0,0,0,0);
        end
    endtask
    function [23:0] camera_pattern(input integer xx,yy,seed);
        reg [7:0] r,g,b;
        begin r=xx+seed*17;g=yy+seed*31;b=(xx^yy)+seed*7;camera_pattern={r,g,b};end
    endfunction
    task video_frame(input integer seed,height,full_timing);
        integer a,b,j;
        begin
            for(b=0;b<height;b=b+1) begin
                for(a=0;a<1024;a=a+1) tick(0,0,1,a,b,camera_pattern(a,b,seed));
                for(j=0;j<(full_timing?320:3);j=j+1) tick(0,(j<24),0,0,0,24'hffffff);
            end
            repeat(4) tick(0,0,0,0,0,0);
        end
    endtask
    integer k;
    initial begin
        repeat(4) tick(0,0,0,0,0,0);
        @(negedge clk);rst=1;
        new_frame(24);
        capture_fd=$fopen("osd_preview.ppm","wb");
        $fwrite(capture_fd,"P6\n1024 600\n255\n");capture=1;
        video_frame(1,600,1);capture=0;$fclose(capture_fd);
        if(capture_pixels!=614400) $fatal(1,"preview pixel count %d",capture_pixels);
        enable=0;new_frame(1);video_frame(2,600,0);enable=1;
        new_frame(2);video_frame(3,87,0);
        // Mid-frame reset, then a long VSYNC and a new complete frame.
        @(negedge clk);rst=0;frame_count=0;
        repeat(3) tick(0,0,0,0,0,0);
        @(negedge clk);rst=1;
        new_frame(64);video_frame(4,600,1);
        // Exercise every decimal carry and wrap at 999999 -> 000000.
        for(k=0;k<1000000;k=k+1) begin
            tick(1,0,0,0,0,0);
            tick(0,0,0,0,0,0);
        end
        new_frame(3);video_frame(5,600,0);
        repeat(5) tick(0,0,0,0,0,0);
        if(logo_hits<20000 || text_hits<1000 || transparent<2000000) $fatal(1,"insufficient overlay coverage");
        $display("PASS OSD: %0d cycles, %0d active pixels, three parameter modes, logo=%0d text=%0d unchanged=%0d; all BCD carries and wrap; reset recovery.",checked,active,logo_hits,text_hits,transparent);
        $finish;
    end
endmodule
