module mmu_fpga_ram(
  PortAClk,
  PortAAddr,
  PortADataIn,
  PortAWriteEnable,
//  PortAChipEnable,
  PortADataOut
);

parameter  DATAWIDTH = 2;
parameter  ADDRWIDTH = 2;

input                     PortAClk;
input   [(ADDRWIDTH-1):0] PortAAddr;
input   [(DATAWIDTH-1):0] PortADataIn;
input                     PortAWriteEnable;
//input                     PortAChipEnable;
output  [(DATAWIDTH-1):0] PortADataOut; 

parameter  MEMDEPTH = 2**(ADDRWIDTH);

reg [(DATAWIDTH-1):0] mem [(MEMDEPTH-1):0] /* synthesis syn_ramstyle = "no_rw_check" */;
reg [(DATAWIDTH-1):0] PortADataOut;

// -------------------------------------------------------------------------
// [FIXED by IC1] Initialize memory to 0 to avoid X-propagation in simulation
// -------------------------------------------------------------------------
initial begin
  integer i;
  for (i = 0; i < MEMDEPTH; i = i + 1) begin
    mem[i] = {DATAWIDTH{1'b0}};
  end
end
// -------------------------------------------------------------------------

always @(posedge PortAClk)
begin
  if(PortAWriteEnable)
  begin
    mem[PortAAddr]  <= PortADataIn;
    PortADataOut    <= PortADataIn;
  end
  else
  begin
    PortADataOut    <= mem[PortAAddr];
  end
end

endmodule
