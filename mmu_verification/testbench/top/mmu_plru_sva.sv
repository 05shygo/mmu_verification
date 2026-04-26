// =============================================================================
// mmu_plru_sva.sv — bind module mmu_l1itlb
// 验证意图: L1 ITLB（PLRU）侧时钟/复位可观测，占位为后续 16-entry PLRU 不变式留接口。
// =============================================================================
`ifndef MMU_PLRU_SVA_SV
`define MMU_PLRU_SVA_SV
module mmu_plru_sva(
  input logic forever_cpuclk,
  input logic cpurst_b
);
  a_iclkb: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    !$isunknown(forever_cpuclk));
endmodule
`endif
