// =============================================================================
// mmu_arb_sva.sv — bind module mmu_arb
// 验证意图: L2 仲裁子模块时钟/复位可观测；与 BuildPlan 第9章 mmu_arb 约束对齐前的占位门控检查。
// =============================================================================
`ifndef MMU_ARB_SVA_SV
`define MMU_ARB_SVA_SV
module mmu_arb_sva(
  input logic forever_cpuclk,
  input logic cpurst_b
);
  a_clk_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    !$isunknown(forever_cpuclk));
endmodule
`endif
