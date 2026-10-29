`timescale 1ps/1ps
module buffer_identity_tb;
  reg clk=0, apb_clk=0, rst_n=1;
  always #3750 clk=~clk;
  always #5000 apb_clk=~apb_clk;
  reg [17:0] sample_gate=0, sample_rdqsn=0;
  integer n;
  ph1p_ddrphy_fast_init_wrapper #(.DX_NUM(2)) dut (
    .clk(clk), .rst_n(rst_n), .apb_pclk(apb_clk), .apb_prst_n(rst_n),
    .apb_psel(1'b0), .apb_penable(1'b0), .apb_pwrite(1'b0),
    .apb_paddr(8'd0), .apb_pwdata(32'd0), .dcp_rdy(2'd0),
    .dly_cur_gate(18'd0), .dly_cur_wdqs(18'd0), .dly_cur_wdq(18'd0),
    .dly_cur_rdqsp(18'd0), .dly_cur_rdqsn(18'd0),
    .wsl_i(8'd0), .rsl_i(8'd0), .gate_status(4'd0),
    .lb_en(1'b0), .mdl_ui(18'd0), .start(1'b0)
  );
  original_fast_init_wrapper #(.DX_NUM(2)) original_dut (
    .clk(clk), .rst_n(rst_n), .apb_pclk(apb_clk), .apb_prst_n(rst_n),
    .apb_psel(1'b0), .apb_penable(1'b0), .apb_pwrite(1'b0),
    .apb_paddr(8'd0), .apb_pwdata(32'd0), .dcp_rdy(2'd0),
    .dly_cur_gate(18'd0), .dly_cur_wdqs(18'd0), .dly_cur_wdq(18'd0),
    .dly_cur_rdqsp(18'd0), .dly_cur_rdqsn(18'd0),
    .wsl_i(8'd0), .rsl_i(8'd0), .gate_status(4'd0),
    .lb_en(1'b0), .mdl_ui(18'd0), .start(1'b0)
  );
  initial begin
    force dut.init_gate=sample_gate;
    force original_dut.init_gate=sample_gate;
      force dut.init_rdqsn=sample_rdqsn;
      force original_dut.init_rdqsn=sample_rdqsn;
    #1 rst_n=0;
    #1;
    if(dut.init_gate_r !== 18'd0 || original_dut.init_gate_r !== 18'd0 ||
       dut.init_rdqsn_r !== 18'd0 || original_dut.init_rdqsn_r !== 18'd0)
      $fatal(1,"reset values differ");
    #1000 rst_n=1;
    for(n=0;n<262144;n=n+1) begin
      @(negedge clk);
      sample_gate=n;
      sample_rdqsn=(~n)&18'h3ffff;
      // Reapply each vector: Icarus evaluates a widened force RHS once.
      force dut.init_gate=sample_gate;
      force original_dut.init_gate=sample_gate;
      force dut.init_rdqsn=sample_rdqsn;
      force original_dut.init_rdqsn=sample_rdqsn;
      #1;
      if(dut.init_gate_capture !== sample_gate || dut.init_rdqsn_capture !== sample_rdqsn)
        $fatal(1,"combinational identity failed vector %0d",n);
      @(posedge clk);
      #1;
      if(dut.init_gate_r !== sample_gate || dut.init_gate_r !== original_dut.init_gate_r ||
         dut.init_rdqsn_r !== sample_rdqsn || dut.init_rdqsn_r !== original_dut.init_rdqsn_r)
        $fatal(1,"capture cycle mismatch vector %0d new=%h old=%h",n,dut.init_gate_r,original_dut.init_gate_r);
    end
    @(negedge clk); rst_n=0;
    #1;
    if(dut.init_gate_r !== 18'd0 || original_dut.init_gate_r !== 18'd0 ||
       dut.init_rdqsn_r !== 18'd0 || original_dut.init_rdqsn_r !== 18'd0)
      $fatal(1,"asynchronous reset values differ");
    $display("PASS buffer_identity_tb: both buses each cover all 262144 18-bit payloads, zero added capture cycles, unchanged asynchronous reset");
    $finish;
  end
endmodule
