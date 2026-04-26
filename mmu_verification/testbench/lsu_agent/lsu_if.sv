// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_if.sv
// Phase 2: LSU <=> MMU interface
// Subgroups: pipe0 / pipe1 / pipe2(prefetch) / stamo / inv(SFENCE.VMA)
//            + L1DTLB→LSU broadcast (tlb_status, v7.3: moved from ptw_mem_if)
// DUT port group: lsu_mmu_* / mmu_lsu_* (ct_mmu_top.v lines ~68-150)
// =============================================================================
`ifndef LSU_IF_SV
`define LSU_IF_SV

interface lsu_if (
  input bit clk_i,
  input bit rst_ni
);

  // =========================================================================
  // Pipe 0
  // =========================================================================
  logic        lsu_mmu_va0_vld;
  logic [6:0]  lsu_mmu_id0;
  logic [63:0] lsu_mmu_va0;
  logic        lsu_mmu_st_inst0;
  logic        lsu_mmu_abort0;
  logic [27:0] lsu_mmu_vabuf0;

  logic        mmu_lsu_pa0_vld;
  logic [27:0] mmu_lsu_pa0;
  logic        mmu_lsu_page_fault0;
  logic        mmu_lsu_access_fault0;
  logic        mmu_lsu_stall0;
  logic        mmu_lsu_sec0;
  logic        mmu_lsu_sh0;
  logic        mmu_lsu_so0;
  logic        mmu_lsu_buf0;
  logic        mmu_lsu_ca0;

  // =========================================================================
  // Pipe 1
  // =========================================================================
  logic        lsu_mmu_va1_vld;
  logic [6:0]  lsu_mmu_id1;
  logic [63:0] lsu_mmu_va1;
  logic        lsu_mmu_st_inst1;
  logic        lsu_mmu_abort1;
  logic [27:0] lsu_mmu_vabuf1;

  logic        mmu_lsu_pa1_vld;
  logic [27:0] mmu_lsu_pa1;
  logic        mmu_lsu_page_fault1;
  logic        mmu_lsu_access_fault1;
  logic        mmu_lsu_stall1;
  logic        mmu_lsu_sec1;
  logic        mmu_lsu_sh1;
  logic        mmu_lsu_so1;
  logic        mmu_lsu_buf1;
  logic        mmu_lsu_ca1;

  // =========================================================================
  // Pipe 2 — Prefetch
  // =========================================================================
  logic        lsu_mmu_va2_vld;
  logic [27:0] lsu_mmu_va2;

  logic        mmu_lsu_pa2_vld;
  logic [27:0] mmu_lsu_pa2;
  logic        mmu_lsu_sec2;
  logic        mmu_lsu_pa2_err;
  logic        mmu_lsu_share2;

  // =========================================================================
  // STAMO — Store-Atomic Physical Address Check
  // =========================================================================
  logic        lsu_mmu_stamo_vld;
  logic [27:0] lsu_mmu_stamo_pa;

  // =========================================================================
  // TLB Invalidation — SFENCE.VMA (4 modes)
  // =========================================================================
  logic        lsu_mmu_tlb_va_all_inv;   // SFENCE.VMA va, all_asid
  logic        lsu_mmu_tlb_all_inv;      // SFENCE.VMA all_va, all_asid
  logic        lsu_mmu_tlb_va_asid_inv;  // SFENCE.VMA va, specific_asid
  logic        lsu_mmu_tlb_asid_all_inv; // SFENCE.VMA all_va, specific_asid
  logic [26:0] lsu_mmu_tlb_va;
  logic [15:0] lsu_mmu_tlb_asid;
  logic        mmu_lsu_tlb_inv_done;

  // =========================================================================
  // L1DTLB -> LSU Broadcast Subgroup (v7.3: moved from ptw_mem_if)
  //   Source: mmu_l1dtlb.sv / mmu_l1dtlb_install.sv / ct_mmu_regs.v
  // =========================================================================
  // mmu_lsu_tlb_busy:
  //   |mb_entry_vld.  Any in-flight L1DTLB miss/refill tells LSU/IDU LSIQ to
  //   use the TLB-busy restart path instead of immediate retry.
  // mmu_lsu_tlb_wakeup:
  //   Completion/replay release vector.  Broadcast completion events release
  //   LSIQ tlb_busy latches; exception CAM wakeups may also make LSU retry so
  //   the request can hit the replay CAM.
  // mmu_lsu_mmu_en:
  //   MMU enable broadcast (SATP.mode != 0).
  logic        mmu_lsu_tlb_busy;
  logic [11:0] mmu_lsu_tlb_wakeup;
  logic        mmu_lsu_mmu_en;

  // Testbench: hierarchical assign from mmu_l1dtlb (expt CAM consumer).
  // Not a DUT top-level port; used by lsu_monitor + mmu_translation_sb.
  logic        mmu_lsu_dtlb_expt_match0;
  logic        mmu_lsu_dtlb_expt_match1;

  // =========================================================================
  // Clocking Block — Active Driver
  // =========================================================================
  clocking driver_cb @(posedge clk_i);
    default input #1step output #1step;
    // pipe0 drive
    output lsu_mmu_va0_vld, lsu_mmu_id0, lsu_mmu_va0;
    output lsu_mmu_st_inst0, lsu_mmu_abort0, lsu_mmu_vabuf0;
    // pipe1 drive
    output lsu_mmu_va1_vld, lsu_mmu_id1, lsu_mmu_va1;
    output lsu_mmu_st_inst1, lsu_mmu_abort1, lsu_mmu_vabuf1;
    // pipe2 drive
    output lsu_mmu_va2_vld, lsu_mmu_va2;
    // stamo drive
    output lsu_mmu_stamo_vld, lsu_mmu_stamo_pa;
    // inv drive
    output lsu_mmu_tlb_va_all_inv, lsu_mmu_tlb_all_inv;
    output lsu_mmu_tlb_va_asid_inv, lsu_mmu_tlb_asid_all_inv;
    output lsu_mmu_tlb_va, lsu_mmu_tlb_asid;
    // DUT responses (sample)
    input  mmu_lsu_pa0_vld, mmu_lsu_pa0;
    input  mmu_lsu_page_fault0, mmu_lsu_access_fault0, mmu_lsu_stall0;
    input  mmu_lsu_sec0, mmu_lsu_sh0, mmu_lsu_so0, mmu_lsu_buf0, mmu_lsu_ca0;
    input  mmu_lsu_pa1_vld, mmu_lsu_pa1;
    input  mmu_lsu_page_fault1, mmu_lsu_access_fault1, mmu_lsu_stall1;
    input  mmu_lsu_sec1, mmu_lsu_sh1, mmu_lsu_so1, mmu_lsu_buf1, mmu_lsu_ca1;
    input  mmu_lsu_pa2_vld, mmu_lsu_pa2, mmu_lsu_sec2, mmu_lsu_pa2_err, mmu_lsu_share2;
    input  mmu_lsu_tlb_inv_done;
    input  mmu_lsu_tlb_busy, mmu_lsu_tlb_wakeup, mmu_lsu_mmu_en;
  endclocking

  // =========================================================================
  // Clocking Block — Monitor
  // =========================================================================
  clocking monitor_cb @(posedge clk_i);
    default input #1step;
    input lsu_mmu_va0_vld, lsu_mmu_id0, lsu_mmu_va0;
    input lsu_mmu_st_inst0, lsu_mmu_abort0, lsu_mmu_vabuf0;
    input lsu_mmu_va1_vld, lsu_mmu_id1, lsu_mmu_va1;
    input lsu_mmu_st_inst1, lsu_mmu_abort1, lsu_mmu_vabuf1;
    input lsu_mmu_va2_vld, lsu_mmu_va2;
    input lsu_mmu_stamo_vld, lsu_mmu_stamo_pa;
    input lsu_mmu_tlb_va_all_inv, lsu_mmu_tlb_all_inv;
    input lsu_mmu_tlb_va_asid_inv, lsu_mmu_tlb_asid_all_inv;
    input lsu_mmu_tlb_va, lsu_mmu_tlb_asid;
    input mmu_lsu_pa0_vld, mmu_lsu_pa0;
    input mmu_lsu_page_fault0, mmu_lsu_access_fault0, mmu_lsu_stall0;
    input mmu_lsu_sec0, mmu_lsu_sh0, mmu_lsu_so0, mmu_lsu_buf0, mmu_lsu_ca0;
    input mmu_lsu_pa1_vld, mmu_lsu_pa1;
    input mmu_lsu_page_fault1, mmu_lsu_access_fault1, mmu_lsu_stall1;
    input mmu_lsu_sec1, mmu_lsu_sh1, mmu_lsu_so1, mmu_lsu_buf1, mmu_lsu_ca1;
    input mmu_lsu_pa2_vld, mmu_lsu_pa2, mmu_lsu_sec2, mmu_lsu_pa2_err, mmu_lsu_share2;
    input mmu_lsu_tlb_inv_done;
    input mmu_lsu_tlb_busy, mmu_lsu_tlb_wakeup, mmu_lsu_mmu_en;
    input mmu_lsu_dtlb_expt_match0, mmu_lsu_dtlb_expt_match1;
  endclocking

endinterface : lsu_if

`endif // LSU_IF_SV
