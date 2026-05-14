// =============================================================================
// PTW PDE cache SVA - Stage 5
// Bind target: PDE_cache
// =============================================================================
`timescale 1ns/1ps

module mmu_pde_cache_sva #(
    parameter int VPN_WIDTH        = 27,
    parameter int PPN_WIDTH        = 28,
    parameter int PTE_LEVEL        = 3,
    parameter int ID_WIDTH         = 6,
    parameter int TYPE_WIDTH       = 3,
    parameter int L1PDE_ENTRY_NUM  = 16,
    parameter int L2PDE_ENTRY_NUM  = 16
) (
    input logic                                      pde_cache_clk,
    input logic                                      cpurst_b,
    input logic                                      regs_ptw_clr,
    input logic                                      tlboper_ptw_abort,
    input logic                                      pmp_regs_update,
    input logic                                      pde_cache_clear,
    input logic                                      xbar_pde_ready,
    input logic                                      pde_cache_ready,
    input logic                                      mbuf_cache_upd,
    input logic [PTE_LEVEL-2:0]                      mbuf_cache_upd_lvl,
    input logic [PPN_WIDTH-1:0]                      mbuf_cache_upd_ppn,
    input logic [VPN_WIDTH-1:0]                      mbuf_cache_upd_vpn,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_upd,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_upd,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_vld,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_vld,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit_idx,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit_idx,
    input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,
    input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_before_upd_hit,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_before_upd_hit,
    input logic                                      L1PDE_entry_hit_vld,
    input logic                                      L2PDE_entry_hit_vld,
    input logic [PPN_WIDTH-1:0]                      L1PDE_cache_hit_ppn,
    input logic [PPN_WIDTH-1:0]                      L2PDE_cache_hit_ppn,
    input logic [PPN_WIDTH-1:0]                      PDE_cache_fin_ppn,
    input logic                                      L2PDE_xbar_hit_vld,
    input logic                                      L1PDE_xbar_hit_vld,
    input logic [PPN_WIDTH-1:0]                      PDE_xbar_ppn,
    input logic [VPN_WIDTH-1:0]                      PDE_xbar_vpn,
    input logic [TYPE_WIDTH-1:0]                     PDE_xbar_type,
    input logic [ID_WIDTH-1:0]                       PDE_xbar_id,
    input logic                                      PDE_xbar_req,
    input logic [VPN_WIDTH-1:0]                      ptw_vpn,
    input logic [TYPE_WIDTH-1:0]                     ptw_type,
    input logic [ID_WIDTH-1:0]                       ptw_id
);

  int unsigned cp_pde_clear_hits;
  int unsigned cp_pde_abort_update_clear_hits;
  int unsigned cp_pde_double_hit_l2_wins_hits;
  int unsigned cp_pde_hit_level_hits;
  int unsigned cp_pde_ppn_match_hits;
  int unsigned cp_pde_update_level_hits;
  int unsigned cp_pde_old_state_lookup_hits;
  int unsigned cp_pde_ready_hits;

  // PTW-SVA-PDE-001/002: reset, satp/PMP clear, and abort clear all valid entries.
  a_pde_clear_drops_all_valid: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    pde_cache_clear |=> ((L1PDE_entry_vld == '0) && (L2PDE_entry_vld == '0)));

  cp_pde_clear: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (regs_ptw_clr || pmp_regs_update || tlboper_ptw_abort)
    ##1 ((L1PDE_entry_vld == '0) && (L2PDE_entry_vld == '0))) begin
    cp_pde_clear_hits++;
  end

  cp_pde_abort_update_clear: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    tlboper_ptw_abort && mbuf_cache_upd
    ##1 ((L1PDE_entry_vld == '0) && (L2PDE_entry_vld == '0))) begin
    cp_pde_abort_update_clear_hits++;
  end

  // PTW-SVA-PDE-003/004/005: L2 wins on double hit and hit-level output is encoded.
  a_pde_double_hit_l2_wins: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (L1PDE_entry_hit_vld && L2PDE_entry_hit_vld)
    |-> (L2PDE_xbar_hit_vld && !L1PDE_xbar_hit_vld
      && (PDE_xbar_ppn == L2PDE_cache_hit_ppn)));

  cp_pde_double_hit_l2_wins: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L1PDE_entry_hit_vld && L2PDE_entry_hit_vld && L2PDE_xbar_hit_vld && !L1PDE_xbar_hit_vld) begin
    cp_pde_double_hit_l2_wins_hits++;
  end

  a_pde_hit_level_outputs: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (L2PDE_xbar_hit_vld == L2PDE_entry_hit_vld)
    && (L1PDE_xbar_hit_vld == (L1PDE_entry_hit_vld && !L2PDE_entry_hit_vld)));

  cp_pde_hit_level: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (!L1PDE_xbar_hit_vld && !L2PDE_xbar_hit_vld)
    || (L1PDE_xbar_hit_vld && !L2PDE_xbar_hit_vld)
    || L2PDE_xbar_hit_vld) begin
    cp_pde_hit_level_hits++;
  end

  a_pde_hit_ppn_matches_selected_entry: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (L2PDE_entry_hit_vld |-> (PDE_xbar_ppn == L2PDE_cache_hit_ppn))
    and ((!L2PDE_entry_hit_vld && L1PDE_entry_hit_vld) |-> (PDE_xbar_ppn == L1PDE_cache_hit_ppn)));

  cp_pde_ppn_match: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (L2PDE_entry_hit_vld && (PDE_xbar_ppn == L2PDE_cache_hit_ppn))
    || (!L2PDE_entry_hit_vld && L1PDE_entry_hit_vld && (PDE_xbar_ppn == L1PDE_cache_hit_ppn))) begin
    cp_pde_ppn_match_hits++;
  end

  // PTW-SVA-PDE-006/008: update level is onehot0 and refill only allocates on old-state miss.
  a_pde_update_level_onehot0: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    mbuf_cache_upd |-> ($onehot0(L1PDE_entry_upd)
                     && $onehot0(L2PDE_entry_upd)
                     && !(|L1PDE_entry_upd && |L2PDE_entry_upd)));

  a_pde_update_matches_level: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    mbuf_cache_upd |-> (((|L1PDE_entry_upd) == (mbuf_cache_upd_lvl[1] && !(|L1PDE_entry_before_upd_hit)))
                     && ((|L2PDE_entry_upd) == (mbuf_cache_upd_lvl[0] && !(|L2PDE_entry_before_upd_hit)))));

  cp_pde_update_level: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    mbuf_cache_upd && ((|L1PDE_entry_upd) || (|L2PDE_entry_upd))) begin
    cp_pde_update_level_hits++;
  end

  cp_pde_old_state_lookup: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    mbuf_cache_upd
    && ((mbuf_cache_upd_lvl[1] && |L1PDE_entry_before_upd_hit && !(|L1PDE_entry_upd))
     || (mbuf_cache_upd_lvl[0] && |L2PDE_entry_before_upd_hit && !(|L2PDE_entry_upd)))) begin
    cp_pde_old_state_lookup_hits++;
  end

  a_pde_output_payload_matches_registered_req: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    PDE_xbar_req |-> (PDE_xbar_vpn == ptw_vpn
                   && PDE_xbar_type == ptw_type
                   && PDE_xbar_id == ptw_id));

  a_pde_ready_mirrors_xbar_ready: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    pde_cache_ready == xbar_pde_ready);

  cp_pde_ready: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    PDE_xbar_req && xbar_pde_ready) begin
    cp_pde_ready_hits++;
  end

  final begin
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_clear req=PTW-SVA-PDE-001 hits=%0d", cp_pde_clear_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_abort_update_clear req=PTW-SVA-PDE-002 hits=%0d", cp_pde_abort_update_clear_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_double_hit_l2_wins req=PTW-SVA-PDE-003 hits=%0d", cp_pde_double_hit_l2_wins_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_hit_level req=PTW-SVA-PDE-004 hits=%0d", cp_pde_hit_level_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_ppn_match req=PTW-SVA-PDE-005 hits=%0d", cp_pde_ppn_match_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_update_level req=PTW-SVA-PDE-006 hits=%0d", cp_pde_update_level_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_old_state_lookup req=PTW-SVA-PDE-008 hits=%0d", cp_pde_old_state_lookup_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_ready req=PTW-SVA-PDE-004 hits=%0d", cp_pde_ready_hits);
  end

endmodule
