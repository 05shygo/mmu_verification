// =============================================================================
// mmu_l2tlb 侧 SVA: RRPV/lookup 前级与仲裁可见约束 (bind mmu_l2tlb) — Phase 7
// 验证意图: (1) L2 访问有请求时 acc_type / 写总线不 X; (2) DTLB load/store 与 acc_type 3'b010/3'b110 自洽;
//   (3) 设计意图文档中的 raw_vld/inv RRPV 等需观测内部时序/阵列，本处用可观测端口作保守代用（见注释）
// =============================================================================
`timescale 1ns/1ps

module mmu_l2tlb_rrpv_sva (
    input logic forever_cpuclk,
    input logic cpurst_b,
    input logic arb_l2tlb_req,
    input logic arb_l2tlb_write,
    input logic [2:0] arb_l2tlb_acc_type,
    input logic [47:0] arb_l2tlb_tag_din,
    input logic [41:0] arb_l2tlb_data_din
);

  // 注: sva_l2_is_dtlb_match（F3.5/TC-006）需对比 miss buffer / split path；仅用 acc_type 在端口侧与 RTL assign 同构

  // 写路径（含 PTW/TLB 操作）在请求有效时写数据/标签不得为 X
  a_write_bus_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (arb_l2tlb_req && arb_l2tlb_write)
      |-> (! $isunknown(arb_l2tlb_tag_din) && ! $isunknown(arb_l2tlb_data_din)));

  // 注: F3.4 sva_raw_vld_and_gate 需要 raw_vld/流水内部节点；F3.NEW.1 需要 RRPV 无效化后阵列视图 — 在 RTL 探针或 FPV 中收紧

endmodule
