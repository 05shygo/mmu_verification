// =============================================================================
// MMU top-level interface SVA (bind ct_mmu_top) — Phase 7
// 验证意图: IFU/LSU 发请路径 VA/abort 非 X；同 pipe 上 stall 与 PA 有效互斥；IFU abort 后一拍 IFU 不应再有效 pavld
// =============================================================================
`timescale 1ns/1ps

module mmu_sva (
    input logic forever_cpuclk,
    input logic cpurst_b,
    // IFU
    input logic        ifu_mmu_va_vld,
    input logic [62:0] ifu_mmu_va,
    input logic        ifu_mmu_abort,
    input logic        mmu_ifu_pavld,
    // LSU pipe0/1/2
    input logic         lsu_mmu_va0_vld,
    input logic [63:0]  lsu_mmu_va0,
    input logic         lsu_mmu_abort0,
    input logic         mmu_lsu_pa0_vld,
    input logic         mmu_lsu_stall0,
    input logic         lsu_mmu_va1_vld,
    input logic [63:0]  lsu_mmu_va1,
    input logic         lsu_mmu_abort1,
    input logic         mmu_lsu_pa1_vld,
    input logic         mmu_lsu_stall1,
    input logic         lsu_mmu_va2_vld,
    input logic [27:0]  lsu_mmu_va2,
    input logic         mmu_lsu_pa2_vld,
    input logic         mmu_lsu_stall2
);

  a_ifu_va_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    ifu_mmu_va_vld |-> (!$isunknown(ifu_mmu_va) && ! $isunknown(ifu_mmu_abort)));

  a_lsu0_va_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    lsu_mmu_va0_vld |-> (!$isunknown(lsu_mmu_va0) && ! $isunknown(lsu_mmu_abort0)));

  a_lsu1_va_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    lsu_mmu_va1_vld |-> (!$isunknown(lsu_mmu_va1) && ! $isunknown(lsu_mmu_abort1)));

  a_lsu2_va_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    lsu_mmu_va2_vld |-> !$isunknown(lsu_mmu_va2));

  // 验证意图: 协议级 — 同一周期不应同时声明 stall(背压) 与 PA 有效(完成) 在 pipe0/1/2
  a_lsu0_stall_excl_pavld: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    !(mmu_lsu_stall0 && mmu_lsu_pa0_vld));

  a_lsu1_stall_excl_pavld: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    !(mmu_lsu_stall1 && mmu_lsu_pa1_vld));

  a_lsu2_stall_excl_pavld: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    !(mmu_lsu_stall2 && mmu_lsu_pa2_vld));

  // 注: “abort 后 N 拍内 pavld 行为” 与流水线外射事务重叠强相关，本 Phase 仅保留不冲突检查；可配合定向 TC+波形收紧

endmodule
