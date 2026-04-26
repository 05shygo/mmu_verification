// =============================================================================
// credit_sva.sv — bind mmu_l2tlb_reqq
// 验证意图: reqq 时钟在复位释放后有效；后续替换为 entry_vld 深度 <= TOTAL_DEPTH 的契约。
// =============================================================================
`ifndef CREDIT_SVA_SV
`define CREDIT_SVA_SV
module credit_sva(
  input logic reqq_clk,
  input logic cpurst_b
);
  a_reqqclk: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    !$isunknown(reqq_clk));
endmodule
`endif
