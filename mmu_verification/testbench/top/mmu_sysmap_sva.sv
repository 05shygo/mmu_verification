// =============================================================================
// SysMap / TWU SVA - Phase 13
// Bind target: twu
// Focus: SysMap flag substitution, cross-boundary degrade, and PA alignment.
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"
`include "l2tlb_negative_sva_guard.svh"

module mmu_sysmap_sva (
    input logic        twu_clk,
    input logic        cpurst_b,
    input logic        tlboper_ptw_abort,
    input logic        cp0_mmu_maee,
    input logic [4:0]  sysmap_mmu_flg,
    input logic [7:0]  sysmap_mmu_hitx1,
    input logic [7:0]  sysmap_mmu_hitx2,
    input logic        twu_crs_1g,
    input logic        twu_crs_2m,
    input logic        twu_crs_chk,
    input logic        twu_csr_cross,
    input logic [2:0]  csr_refill_pgs,
    input logic        csr_refill_req,
    input logic [41:0] csr_refill_data,
    input logic [27:0] mmu_sysmap_pax1,
    input logic [27:0] mmu_sysmap_pax2,
    input logic [39:0] twu_sysmap_adderx1,
    input logic [39:0] twu_sysmap_adderx2
);

  logic csr_refill_from_sysmap;
  logic sysmap_cross_1g;
  logic sysmap_cross_2m;
  logic sysmap_cross_1g_d;
  logic sysmap_cross_2m_d;

  int unsigned cp_csr_refill_flg_matches_sysmap_hits;
  int unsigned cp_sysmap_cross_degrade_hits;
  int unsigned cp_sysmap_no_cross_no_degrade_hits;
  int unsigned cp_sysmap_pa_align_hits;

  assign csr_refill_from_sysmap = csr_refill_req && !cp0_mmu_maee;
  assign sysmap_cross_1g       = twu_crs_1g && twu_csr_cross;
  assign sysmap_cross_2m       = twu_crs_2m && twu_csr_cross;

  always_ff @(posedge twu_clk or negedge cpurst_b) begin
    if (!cpurst_b || tlboper_ptw_abort) begin
      sysmap_cross_1g_d <= 1'b0;
      sysmap_cross_2m_d <= 1'b0;
    end else begin
      sysmap_cross_1g_d <= sysmap_cross_1g;
      sysmap_cross_2m_d <= sysmap_cross_2m;
    end
  end

  // Verification intent: MAEE=0 CSR refill data must carry the current SysMap
  // attribute bits at the refill encoding point.
  sva_csr_refill_flg_matches_sysmap: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    csr_refill_from_sysmap |-> (csr_refill_data[13:9] == sysmap_mmu_flg));

  cp_csr_refill_flg_matches_sysmap: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    csr_refill_from_sysmap && (csr_refill_data[13:9] == sysmap_mmu_flg)) begin
    cp_csr_refill_flg_matches_sysmap_hits++;
  end

  // Verification intent: when a SysMap hit vector changes across a large-page
  // boundary probe, TWU must degrade page size before CSR refill.
  sva_sysmap_cross_degrade: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    sysmap_cross_1g |=> (csr_refill_pgs == 3'b010));

  sva_sysmap_cross_degrade_2m: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    sysmap_cross_2m |=> (csr_refill_pgs == 3'b001));

  cp_sysmap_cross_degrade: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    (sysmap_cross_1g_d && (csr_refill_pgs == 3'b010))
    || (sysmap_cross_2m_d && (csr_refill_pgs == 3'b001))) begin
    cp_sysmap_cross_degrade_hits++;
  end

  // Verification intent: without a SysMap boundary change, the CSR refill page
  // size must keep the original 1G/2M grant-derived size.
  sva_sysmap_no_cross_no_degrade: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    (twu_crs_chk && !twu_csr_cross) |=> (csr_refill_pgs != 3'b001));

  cp_sysmap_no_cross_no_degrade: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    (twu_crs_chk && !twu_csr_cross) ##1 (csr_refill_pgs != 3'b001)) begin
    cp_sysmap_no_cross_no_degrade_hits++;
  end

  // Verification intent: TWU sends SysMap a page-aligned PA/PPN view.
  sva_sysmap_pax1_align: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    (|sysmap_mmu_hitx1) |-> (mmu_sysmap_pax1 == twu_sysmap_adderx1[39:12]));

  sva_sysmap_pax2_align: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    (|sysmap_mmu_hitx2) |-> (mmu_sysmap_pax2 == twu_sysmap_adderx2[39:12]));

  cp_sysmap_pa_align: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    ((|sysmap_mmu_hitx1) && (mmu_sysmap_pax1 == twu_sysmap_adderx1[39:12]))
    || ((|sysmap_mmu_hitx2) && (mmu_sysmap_pax2 == twu_sysmap_adderx2[39:12]))) begin
    cp_sysmap_pa_align_hits++;
  end

  final begin
    $display("PHASE13_SVA_COVER module=mmu_sysmap_sva name=cp_csr_refill_flg_matches_sysmap hits=%0d", cp_csr_refill_flg_matches_sysmap_hits);
    $display("PHASE13_SVA_COVER module=mmu_sysmap_sva name=cp_sysmap_cross_degrade hits=%0d", cp_sysmap_cross_degrade_hits);
    $display("PHASE13_SVA_COVER module=mmu_sysmap_sva name=cp_sysmap_no_cross_no_degrade hits=%0d", cp_sysmap_no_cross_no_degrade_hits);
    $display("PHASE13_SVA_COVER module=mmu_sysmap_sva name=cp_sysmap_pa_align hits=%0d", cp_sysmap_pa_align_hits);
    $display("PTW_SVA_COVER module=mmu_sysmap_sva name=cp_csr_refill_flg_matches_sysmap req=PTW-SVA-MAEE-004 hits=%0d", cp_csr_refill_flg_matches_sysmap_hits);
    $display("PTW_SVA_COVER module=mmu_sysmap_sva name=cp_sysmap_cross_degrade req=PTW-SVA-MAEE-005 hits=%0d", cp_sysmap_cross_degrade_hits);
    $display("PTW_SVA_COVER module=mmu_sysmap_sva name=cp_sysmap_no_cross_no_degrade req=PTW-SVA-MAEE-006 hits=%0d", cp_sysmap_no_cross_no_degrade_hits);
    $display("PTW_SVA_COVER module=mmu_sysmap_sva name=cp_sysmap_pa_align req=PTW-SVA-MAEE-010 hits=%0d", cp_sysmap_pa_align_hits);
  end

endmodule
