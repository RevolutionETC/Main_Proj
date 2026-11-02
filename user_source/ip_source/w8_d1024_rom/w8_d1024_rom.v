







`timescale 1 ns / 1 ps
module w8_d1024_rom
(
  output  [7:0]                 doa,
  input   [9:0]                 addra,
  input                         clka
);

  rom_c370f19e17c7
  #(
      .DATA_WIDTH_A(8),
      .ADDR_WIDTH_A(10),
      .DATA_DEPTH_A(1024),
      .INIT_FILE("../../w8_d1024_rom/config_data_panel7.mif.dat"),
      .FILL_ALL("NONE")
  )rom_c370f19e17c7_Inst
  (
      .doa(doa),
      .addra(addra),
      .clka(clka)
  );
endmodule
