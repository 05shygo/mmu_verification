// =============================================================================
// mmu_l2tlb_rrpv_sva.sv — bind module mmu_l2tlb
// 验证意图: RRPV/替换路径前的时钟域健康；后续可接 skew-bank/RRPV 更新不变式。
// =============================================================================
`ifndef MMU_L2TLB_RRPV_SVA_SV
`define MMU_L2TLB_RRPV_SVA_SV
module mmu_l2tlb_rrpv_sva(
  input logic forever_cpuclk,
  input logic cpurst_b
);
  a_l2clk: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    !$isunknown(forever_cpuclk));
endmodule
`endif
