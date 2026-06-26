// =============================================================================
// L1 PLRU / PPLRU 旁路 SVA (bind ct_mmu_iplru / ct_mmu_dplru) — Phase 7
// 验证意图: 回填/替换时 victim one-hot; F12.NEW.1(首次命中树更新) 需 p00 等内部点 — 在形式化或插桩后补
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"
`include "l2tlb_negative_sva_guard.svh"

// ITLB: 32 路 victim 向量
module mmu_plru_sva (
    input logic        cpurst_b,
    input logic        forever_cpuclk,
    input logic        utlb_plru_refill_vld,
    input logic [31:0] plru_iutlb_ref_num
);

  a_iutlb_ref_onehot0: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    utlb_plru_refill_vld |-> (! $isunknown(plru_iutlb_ref_num) && $onehot0(plru_iutlb_ref_num)));

endmodule

// DTLB: 16 路 victim 向量
module mmu_dplru_sva (
    input logic        cpurst_b,
    input logic        forever_cpuclk,
    input logic        utlb_plru_refill_vld,
    input logic [15:0] plru_dutlb_ref_num
);

  a_dutlb_ref_onehot0: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    utlb_plru_refill_vld |-> (! $isunknown(plru_dutlb_ref_num) && $onehot0(plru_dutlb_ref_num)));

endmodule
