// =============================================================================
// PTW TWU CHK SVA - twu_reconstruct Phase 3 (rewritten)
// Bind target: twu  (unified chk_unit + scalar twu_data_ready)
// Replaces old fst/scd/thd_chk_* 3-stage SVA with unified chk_unit_* checks.
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"
`include "l2tlb_negative_sva_guard.svh"

module mmu_twu_chk_sva #(
    parameter int VPN_WIDTH  = 27,
    parameter int DATA_WIDTH = 64,
    parameter int TYPE_WIDTH = 3,
    parameter int ID_WIDTH   = 7
) (
    input logic                  twu_clk,
    input logic                  cpurst_b,
    input logic                  tlboper_ptw_abort,
    input logic                  cp0_mmu_maee,
    input logic                  cp0_mmu_mxr,
    input logic                  cp0_mmu_sum,
    input logic [1:0]            cp0_mmu_mpp,
    input logic                  cp0_mmu_mprv,
    input logic [1:0]            cp0_yy_priv_mode,
    // ── twu_reconstruct: unified CHK unit ports ──────────────────────────
    input logic                  chk_unit_vld,
    input logic [VPN_WIDTH-1:0]  chk_unit_vpn,
    input logic [TYPE_WIDTH-1:0] chk_unit_type,
    input logic [ID_WIDTH-1:0]   chk_unit_id,
    input logic [DATA_WIDTH-1:0] chk_unit_data,
    input logic [8:0]            chk_unit_flg,
    input logic [2:0]            chk_unit_lvl,        // one-hot: [2]=FST [1]=SCD [0]=THD
    input logic                  chk_unit_leaf_vld,
    input logic                  chk_unit_page_flt,
    input logic                  chk_unit_refill_req,
    input logic                  chk_unit_csr_req,
    input logic                  chk_unit_wait,
    input logic                  chk_unit_fetch_type,
    input logic                  chk_unit_load_type,
    input logic                  chk_unit_store_type,
    input logic                  chk_unit_cp0_user_mode,
    input logic                  chk_unit_cp0_supv_mode,
    // ── twu_reconstruct: scalar ready ────────────────────────────────────
    input logic                  twu_data_ready,
    // ── Grant / outcome signals ──────────────────────────────────────────
    input logic                  pgflt_chk_unit_grant,
    input logic                  refill_chk_unit_grant,
    input logic                  chk_unit_csr_grant,
    input logic                  twu_l2tlb_ref_pgflt,
    input logic                  twu_arb_ref_req
);

  localparam logic [2:0] PTW_TYPE_FETCH = 3'b011;
  localparam logic [2:0] PTW_TYPE_PREF  = 3'b100;

  // Level decode helpers from one-hot chk_unit_lvl
  function automatic bit is_fst(); return chk_unit_lvl[2]; endfunction
  function automatic bit is_scd(); return chk_unit_lvl[1]; endfunction
  function automatic bit is_thd(); return chk_unit_lvl[0]; endfunction

  function automatic logic [8:0] decode_flg(input logic [DATA_WIDTH-1:0] data);
    decode_flg = {data[9:6], data[4:0]};
  endfunction

  function automatic bit leaf_from_flg(input logic [8:0] flg);
    leaf_from_flg = flg[0] && (flg[1] || flg[3]);
  endfunction

  function automatic bit write_only_fault(input logic [8:0] flg, input logic mxr);
    write_only_fault = flg[2] && !(flg[1] || (mxr && flg[3]));
  endfunction

  function automatic bit huge1g_misaligned(input logic [DATA_WIDTH-1:0] data);
    huge1g_misaligned = (data[27:10] != 18'b0);
  endfunction

  function automatic bit huge2m_misaligned(input logic [DATA_WIDTH-1:0] data);
    huge2m_misaligned = (data[18:10] != 9'b0);
  endfunction

  // ── Cover hit counters ──────────────────────────────────────────────────
  int unsigned cp_chk_unit_level;
  int unsigned cp_chk_leaf_write_only;
  int unsigned cp_chk_nonleaf_level;
  int unsigned cp_chk_fetch;
  int unsigned cp_chk_load;
  int unsigned cp_chk_store;
  int unsigned cp_chk_pfu;
  int unsigned cp_chk_us_sum;
  int unsigned cp_chk_huge_align;
  int unsigned cp_chk_no_side_effect;
  int unsigned cp_chk_wait_hold;
  int unsigned cp_chk_rsw_reserved;
  int unsigned cp_chk_csr_refill_mutex;
  int unsigned cp_chk_pgflt_no_next;

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-001: FLG decode matches raw data @ chk_unit_vld
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_flg_decode: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld |-> (chk_unit_flg == decode_flg(chk_unit_data)));

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-002: leaf decode from PTE flags
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_leaf_decode: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld |-> (chk_unit_leaf_vld == leaf_from_flg(chk_unit_flg)));

  cp_chk_unit_level_cover: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    chk_unit_vld && (is_fst() || is_scd() || is_thd())) begin
    cp_chk_unit_level++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-003: write-only leaf → page fault at all levels
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_write_only_fault: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_leaf_vld && write_only_fault(chk_unit_flg, cp0_mmu_mxr)
    |-> chk_unit_page_flt);

  cp_chk_leaf_write_only_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_leaf_vld && write_only_fault(chk_unit_flg, cp0_mmu_mxr)) begin
    cp_chk_leaf_write_only++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-004: non-leaf pointer check — FST/SCD no page fault for pointer
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_nonleaf_pointer_not_fault: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_flg[0] && !chk_unit_flg[1]
    && !chk_unit_flg[2] && !chk_unit_flg[3] && !is_thd()
    |-> (!chk_unit_leaf_vld && !chk_unit_page_flt));

  // THD non-leaf must page fault
  a_chk_thd_nonleaf_fault: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_flg[0] && !chk_unit_flg[1] && !chk_unit_flg[3] && is_thd()
    |-> chk_unit_page_flt);

  cp_chk_nonleaf_level_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    (chk_unit_vld && !chk_unit_leaf_vld && !chk_unit_page_flt && !is_thd())
    || (chk_unit_vld && is_thd() && chk_unit_page_flt)) begin
    cp_chk_nonleaf_level++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-005: permission checks — fetch needs X, load needs R, store needs W+D
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_fetch_needs_x: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_leaf_vld && chk_unit_fetch_type && !chk_unit_flg[3]
    |-> chk_unit_page_flt);

  a_chk_load_needs_r_or_mxr_x: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_leaf_vld && chk_unit_load_type
    && !chk_unit_flg[1] && !(cp0_mmu_mxr && chk_unit_flg[3])
    |-> chk_unit_page_flt);

  a_chk_store_needs_w_d: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_leaf_vld && chk_unit_store_type
    && (!chk_unit_flg[2] || !chk_unit_flg[6])
    |-> chk_unit_page_flt);

  cp_chk_fetch_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_fetch_type) begin cp_chk_fetch++; end

  cp_chk_load_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_load_type) begin cp_chk_load++; end

  cp_chk_store_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_store_type) begin cp_chk_store++; end

  cp_chk_pfu_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && (chk_unit_type == PTW_TYPE_PREF)) begin cp_chk_pfu++; end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-006: U/S page permission rules
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_user_supervisor_rules: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_leaf_vld
    && ((chk_unit_flg[4] && chk_unit_cp0_supv_mode && !cp0_mmu_sum)
        || (!chk_unit_flg[4] && chk_unit_cp0_user_mode))
    |-> chk_unit_page_flt);

  cp_chk_us_sum_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_page_flt) begin cp_chk_us_sum++; end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-007: huge page alignment fault → page fault, no refill/CSR
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_huge_align_fault: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_leaf_vld
    && ((is_fst() && huge1g_misaligned(chk_unit_data))
        || (is_scd() && huge2m_misaligned(chk_unit_data)))
    |-> (chk_unit_page_flt && !chk_unit_refill_req && !chk_unit_csr_req));

  cp_chk_huge_align_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_leaf_vld
    && ((is_fst() && huge1g_misaligned(chk_unit_data))
        || (is_scd() && huge2m_misaligned(chk_unit_data)))) begin
    cp_chk_huge_align++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-008: page fault → no refill, no CSR, no next walk side-effect
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_page_fault_no_side_effect: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_page_flt
    |-> (!chk_unit_refill_req && !chk_unit_csr_req));

  cp_chk_no_side_effect_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && chk_unit_page_flt && !chk_unit_refill_req && !chk_unit_csr_req) begin
    cp_chk_no_side_effect++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-009: wait holds CHK payload stable
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_wait_holds_payload: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    chk_unit_wait && !tlboper_ptw_abort
    |=> (tlboper_ptw_abort
      || (chk_unit_vld && $stable(chk_unit_vpn) && $stable(chk_unit_type)
          && $stable(chk_unit_id) && $stable(chk_unit_data))));

  cp_chk_wait_hold_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    chk_unit_wait && !tlboper_ptw_abort) begin cp_chk_wait_hold++; end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-010: CSR/refill mutual exclusion
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_csr_refill_mutex: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    !(chk_unit_csr_req && chk_unit_refill_req));

  cp_chk_csr_refill_mutex_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_csr_req ^ chk_unit_refill_req) begin cp_chk_csr_refill_mutex++; end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-011: page fault accepted → no subsequent next-level PMP/refill
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_pgflt_no_next_walk: assert property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    pgflt_chk_unit_grant |-> (!chk_unit_refill_req && !chk_unit_csr_req
                              && twu_l2tlb_ref_pgflt && !twu_arb_ref_req));

  cp_chk_pgflt_no_next_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    pgflt_chk_unit_grant && !chk_unit_refill_req && !chk_unit_csr_req) begin
    cp_chk_pgflt_no_next++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW-SVA-CHK-012: RSW/high-reserved field observation (provisional)
  // ══════════════════════════════════════════════════════════════════════════
  cp_chk_rsw_reserved_p: cover property (@(posedge twu_clk)
    disable iff (`L2TLB_NEG_DISABLE || tlboper_ptw_abort)
    chk_unit_vld && (|chk_unit_data[63:38] || |chk_unit_data[9:8])) begin
    cp_chk_rsw_reserved++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW_SVA_COVER report
  // ══════════════════════════════════════════════════════════════════════════
  final begin
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_unit_level req=PTW-SVA-CHK-001,PTW-RECON-SVA-CHK-UNIT hits=%0d", cp_chk_unit_level);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_leaf_write_only req=PTW-SVA-CHK-003 hits=%0d", cp_chk_leaf_write_only);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_nonleaf_level req=PTW-SVA-CHK-002,PTW-SVA-CHK-004 hits=%0d", cp_chk_nonleaf_level);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_fetch req=PTW-SVA-CHK-005 hits=%0d", cp_chk_fetch);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_load req=PTW-SVA-CHK-005 hits=%0d", cp_chk_load);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_store req=PTW-SVA-CHK-005 hits=%0d", cp_chk_store);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_pfu req=PTW-SVA-CHK-005 hits=%0d", cp_chk_pfu);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_us_sum req=PTW-SVA-CHK-006 hits=%0d", cp_chk_us_sum);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_huge_align req=PTW-SVA-CHK-007 hits=%0d", cp_chk_huge_align);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_no_side_effect req=PTW-SVA-CHK-008 hits=%0d", cp_chk_no_side_effect);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_wait_hold req=PTW-SVA-CHK-009 hits=%0d", cp_chk_wait_hold);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_rsw_reserved req=PTW-SVA-CHK-012 hits=%0d provisional=1", cp_chk_rsw_reserved);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_csr_refill_mutex req=PTW-SVA-CHK-010 hits=%0d", cp_chk_csr_refill_mutex);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_pgflt_no_next req=PTW-SVA-CHK-011 hits=%0d", cp_chk_pgflt_no_next);
  end

endmodule
