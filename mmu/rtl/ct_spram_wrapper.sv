module ct_spsram_wrapper #(
  parameter DATA_WIDTH = 48,
  parameter ADDR_WIDTH = 8
)(
  input  [ADDR_WIDTH-1:0]  A,
  input                    CEN,  // Active Low
  input                    CLK,
  input  [DATA_WIDTH-1:0]  D,
  input                    GWEN, // Active Low
  input  [DATA_WIDTH-1:0]  WEN,  // Active Low bitmask (unused in simple fpga_ram)
  output [DATA_WIDTH-1:0]  Q
);

// For FPGA target, we directly use the behavioral fpga_ram module.
// Note: In T-Head code, GWEN and CEN logic controls the write enable.
wire write_en = !CEN && !GWEN;

mmu_fpga_ram #(DATA_WIDTH, ADDR_WIDTH) x_fpga_ram (
  .PortAClk         (CLK),
  .PortAAddr        (A),
  .PortADataIn      (D),
  .PortAWriteEnable (write_en),
  .PortADataOut     (Q)
);

endmodule
