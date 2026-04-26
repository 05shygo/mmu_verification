// =============================================================================
// mmu_sva.sv — Phase 7 TaskDivision: bind ct_mmu_top
// 验证意图: 主时钟在复位释放后无 X，避免 TB/RTL 断连；后续可替换为 M/S/X 时序规约。
// =============================================================================
`ifndef MMU_SVA_SV
`define MMU_SVA_SV
module mmu_sva(
  input logic forever_cpuclk,
  input logic cpurst_b
);
  a_clk_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    !$isunknown(forever_cpuclk))
  else $error("mmu_sva: forever_cpuclk is X/Z after reset deassertion");
endmodule
`endif
