// =============================================================================
// MAEE / TWU path SVA (bind twu) - twu_reconstruct Phase 3 (rewritten)
// Replaces old fst/scd/thd_chk_* SVA with unified chk_unit_lvl checks.
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"
`include "l2tlb_negative_sva_guard.svh"

module mmu_maee_twu_sva (
    input logic        twu_clk,
    input logic        cpurst_b,
    input logic        cp0_mmu_maee,
    // ── twu_reconstruct: unified CHK unit ports ────────────────────────────
    input logic        chk_unit_vld,
    input logic        chk_unit_leaf_vld,
    input logic        chk_unit_page_flt,
    input logic        chk_unit_refill_req,
    input logic        chk_unit_csr_req,
    input logic [2:0]  chk_unit_lvl,         // one-hot: [2]=FST(1G) [1]=SCD(2M) [0]=THD(4K)
    // 4K leaf behavior: THD level, MAEE=0, direct refill (no CSR path)
    input logic        chk_unit_thd_refill_no_maee  // asserted when MAEE=0 THD leaf → direct refill
);

  // Level decode from one-hot
  function automatic bit is_fst(); return chk_unit_lvl[2]; endfunction
  function automatic bit is_scd(); return chk_unit_lvl[1]; endfunction
  function automatic bit is_thd(); return chk_unit_lvl[0]; endfunction

  // Leaf non-fault
  logic fst_leaf_nonfault;
  logic scd_leaf_nonfault;
  logic thd_leaf_nonfault;

  assign fst_leaf_nonfault = is_fst() && chk_unit_vld && chk_unit_leaf_vld && !chk_unit_page_flt;
  assign scd_leaf_nonfault = is_scd() && chk_unit_vld && chk_unit_leaf_vld && !chk_unit_page_flt;
  assign thd_leaf_nonfault = is_thd() && chk_unit_vld && chk_unit_leaf_vld && !chk_unit_page_flt;

  // Cover counters
  int unsigned cp_maee_paths_mutex;
  int unsigned cp_maee0_csr;
  int unsigned cp_maee1_refill;
  int unsigned cp_maee0_thd_direct_refill;
  int unsigned cp_maee_level_1g;
  int unsigned cp_maee_level_2m;
  int unsigned cp_maee_level_4k;

  // ══════════════════════════════════════════════════════════════════════════
  // MAEE-SVA-001: CSR/refill mutual exclusion (all levels)
  // ══════════════════════════════════════════════════════════════════════════
  a_maee_csr_refill_mutex: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    !(chk_unit_csr_req && chk_unit_refill_req));

  cp_maee_paths_mutex_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    chk_unit_csr_req ^ chk_unit_refill_req) begin cp_maee_paths_mutex++; end

  // ══════════════════════════════════════════════════════════════════════════
  // MAEE-SVA-002: MAEE=0 → leaf enters CSR path (1G/2M); 4K → direct refill
  // ══════════════════════════════════════════════════════════════════════════
  a_maee0_csr_path: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    !cp0_mmu_maee |-> (
      (!fst_leaf_nonfault || (chk_unit_csr_req && !chk_unit_refill_req))
      && (!scd_leaf_nonfault || (chk_unit_csr_req && !chk_unit_refill_req))
    ));

  cp_maee0_csr_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    !cp0_mmu_maee && (
      (fst_leaf_nonfault && chk_unit_csr_req && !chk_unit_refill_req)
      || (scd_leaf_nonfault && chk_unit_csr_req && !chk_unit_refill_req)
    )) begin cp_maee0_csr++; end

  // ══════════════════════════════════════════════════════════════════════════
  // MAEE-SVA-003: MAEE=1 → leaf bypasses CSR FSM, direct refill (all levels)
  // ══════════════════════════════════════════════════════════════════════════
  a_maee1_direct_refill: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    cp0_mmu_maee |-> (
      (!fst_leaf_nonfault || (chk_unit_refill_req && !chk_unit_csr_req))
      && (!scd_leaf_nonfault || (chk_unit_refill_req && !chk_unit_csr_req))
      && (!thd_leaf_nonfault || chk_unit_refill_req)
    ));

  cp_maee1_refill_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    cp0_mmu_maee && (
      (fst_leaf_nonfault && chk_unit_refill_req && !chk_unit_csr_req)
      || (scd_leaf_nonfault && chk_unit_refill_req && !chk_unit_csr_req)
      || (thd_leaf_nonfault && chk_unit_refill_req)
    )) begin cp_maee1_refill++; end

  // ══════════════════════════════════════════════════════════════════════════
  // MAEE-SVA-004: MAEE=0 4K leaf → direct refill (no CSR for 4K; TWU RTL
  //               behavior: 4K always direct refill regardless of MAEE)
  // ══════════════════════════════════════════════════════════════════════════
  a_maee0_thd_direct_refill: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    !cp0_mmu_maee && thd_leaf_nonfault
    |-> (chk_unit_refill_req && !chk_unit_csr_req));

  cp_maee0_thd_direct_refill_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    !cp0_mmu_maee && thd_leaf_nonfault && chk_unit_refill_req && !chk_unit_csr_req) begin
    cp_maee0_thd_direct_refill++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // MAEE-SVA-005: level coverage — each page size can reach the MAEE path
  // ══════════════════════════════════════════════════════════════════════════
  cp_maee_level_1g_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    fst_leaf_nonfault && (chk_unit_refill_req || chk_unit_csr_req)) begin
    cp_maee_level_1g++;
  end

  cp_maee_level_2m_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    scd_leaf_nonfault && (chk_unit_refill_req || chk_unit_csr_req)) begin
    cp_maee_level_2m++;
  end

  cp_maee_level_4k_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    thd_leaf_nonfault && chk_unit_refill_req) begin
    cp_maee_level_4k++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW_SVA_COVER report
  // ══════════════════════════════════════════════════════════════════════════
  final begin
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_maee_paths_mutex req=PTW-RECON-SVA-MAEE-001 hits=%0d", cp_maee_paths_mutex);
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_maee0_csr req=PTW-RECON-SVA-MAEE-002 hits=%0d", cp_maee0_csr);
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_maee1_refill req=PTW-RECON-SVA-MAEE-003 hits=%0d", cp_maee1_refill);
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_maee0_thd_direct_refill req=PTW-RECON-SVA-MAEE-004 hits=%0d", cp_maee0_thd_direct_refill);
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_maee_level_1g req=PTW-RECON-SVA-MAEE-005 hits=%0d", cp_maee_level_1g);
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_maee_level_2m req=PTW-RECON-SVA-MAEE-005 hits=%0d", cp_maee_level_2m);
    $display("PTW_SVA_COVER module=mmu_maee_twu_sva name=cp_maee_level_4k req=PTW-RECON-SVA-MAEE-005 hits=%0d", cp_maee_level_4k);
  end

endmodule
