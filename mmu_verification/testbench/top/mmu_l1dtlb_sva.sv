// =============================================================================
// L1DTLB focused SVA for chapter-3 audit points.
//
// The assertions are split by RTL module so the 3.9 matrix is checked close to
// the logic that owns the behavior.  Some matrix rows are still scoreboard or
// formal/equivalence items; see the traceability document for residual gaps.
// =============================================================================
`timescale 1ns/1ps

module mmu_l1dtlb_sva #(
    parameter int MB_DEPTH    = 8,
    parameter int NUM_ENTRY   = 16,
    parameter int VPN_WIDTH   = 27,
    parameter int PPN_WIDTH   = 28,
    parameter int IID_WIDTH   = 7,
    parameter int FLG_WIDTH   = 14,
    parameter int CREDIT_MAX  = 8
) (
    input logic forever_cpuclk,
    input logic cpurst_b,

    input logic regs_utlb_clr,
    input logic rtu_yy_xx_flush,
    input logic tlboper_utlb_clr,
    input logic tlboper_utlb_inv_va_req,
    input logic [VPN_WIDTH-1:0] lsu_mmu_tlb_va,

    input logic lsu_mmu_va0_vld,
    input logic [63:0] lsu_mmu_va0,
    input logic [IID_WIDTH-1:0] lsu_mmu_id0,
    input logic lsu_mmu_st_inst0,
    input logic [27:0] lsu_mmu_vabuf0,
    input logic lsu_mmu_abort0,
    input logic mmu_lsu_pa0_vld,
    input logic [PPN_WIDTH-1:0] mmu_lsu_pa0,
    input logic mmu_lsu_access_fault0,
    input logic mmu_lsu_page_fault0,

    input logic lsu_mmu_va1_vld,
    input logic [63:0] lsu_mmu_va1,
    input logic [IID_WIDTH-1:0] lsu_mmu_id1,
    input logic lsu_mmu_st_inst1,
    input logic [27:0] lsu_mmu_vabuf1,
    input logic lsu_mmu_abort1,
    input logic mmu_lsu_pa1_vld,
    input logic [PPN_WIDTH-1:0] mmu_lsu_pa1,
    input logic mmu_lsu_access_fault1,
    input logic mmu_lsu_page_fault1,

    input logic lsu_mmu_stamo_vld,
    input logic mmu_hpcp_dutlb_miss,
    input logic mmu_lsu_tlb_busy,
    input logic [11:0] mmu_lsu_tlb_wakeup,

    input logic [MB_DEPTH-1:0]                 mb_entry_vld,
    input logic [MB_DEPTH-1:0][2:0]            mb_entry_state,
    input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0]  mb_entry_vpn,
    input logic [MB_DEPTH-1:0][IID_WIDTH-1:0]  mb_entry_iid,
    input logic [MB_DEPTH-1:0]                 mb_entry_issued,
    input logic [MB_DEPTH-1:0]                 mb_entry_ready,
    input logic [MB_DEPTH-1:0]                 mb_entry_wfc,
    input logic [MB_DEPTH-1:0]                 mb_entry_wfi,
    input logic [MB_DEPTH-1:0]                 mb_entry_store,

    input logic [NUM_ENTRY-1:0]                entry_vld,
    input logic [NUM_ENTRY-1:0][VPN_WIDTH-1:0] l1dtlb_ent_vpn,
    input logic [NUM_ENTRY-1:0][PPN_WIDTH-1:0] entry_ppn,
    input logic [NUM_ENTRY-1:0][2:0]           l1dtlb_ent_pgs,
    input logic [NUM_ENTRY-1:0]                entry_hit0,
    input logic [NUM_ENTRY-1:0]                entry_hit1,

    input logic dutlb_miss_vld0,
    input logic dutlb_miss_vld1,
    input logic dutlb_miss_vld_short0,
    input logic dutlb_miss_vld_short1,
    input logic miss0_vld_q,
    input logic miss1_vld_q,
    input logic [VPN_WIDTH-1:0] miss0_vpn_q,
    input logic [VPN_WIDTH-1:0] miss1_vpn_q,
    input logic miss0_abort_q,
    input logic miss1_abort_q,
    input logic mb_hit0,
    input logic mb_hit1,
    input logic same_4k_miss01,
    input logic alloc_gnt0,
    input logic alloc_gnt1,
    input logic [2:0] alloc_sel0,
    input logic [2:0] alloc_sel1,
    input logic [MB_DEPTH-1:0] mb_alloc_we,
    input logic dutlb_acc_flt0,
    input logic dutlb_acc_flt1,
    input logic expt_match0,
    input logic expt_match1,
    input logic dutlb_off_hit,

    input logic dutlb_l2tlb_req_vld,
    input logic [VPN_WIDTH-1:0] dutlb_l2tlb_req_vpn,
    input logic [2:0] dutlb_l2tlb_req_eid,
    input logic dutlb_l2tlb_req_is_load,

    input logic ptw_l1dtlb_ref_pavld,
    input logic ptw_l1dtlb_ref_cmplt,
    input logic [2:0] ptw_l1dtlb_ref_id,
    input logic [2:0] ptw_l1tlb_ref_pgs,
    input logic ptw_l1tlb_acc_err,
    input logic ptw_l1tlb_pgflt,
    input logic jtlb_dutlb_ref_pavld,
    input logic jtlb_dutlb_ref_cmplt,
    input logic [2:0] jtlb_dutlb_ref_id,
    input logic jtlb_dutlb_pgflt,

    input logic utlb_refill_vld,
    input logic [3:0] utlb_refill_idx,
    input logic [VPN_WIDTH-1:0] utlb_refill_vpn,
    input logic [PPN_WIDTH-1:0] utlb_refill_ppn,
    input logic [2:0] utlb_refill_pgs,
    input logic [NUM_ENTRY-1:0] entry_upd,
    input logic plru_refill_updt,
    input logic [NUM_ENTRY-1:0] plru_refill_way,
    input logic [11:0] install_wakeup,
    input logic [11:0] expt_wakeup,

    input logic expt_wr0_vld,
    input logic [2:0] expt_wr0_eid,
    input logic [IID_WIDTH-1:0] expt_wr0_iid,
    input logic [VPN_WIDTH-1:0] expt_wr0_vpn,
    input logic expt_wr0_pgflt,
    input logic expt_wr0_acflt,
    input logic expt_wr1_vld,
    input logic [2:0] expt_wr1_eid,
    input logic [IID_WIDTH-1:0] expt_wr1_iid,
    input logic [VPN_WIDTH-1:0] expt_wr1_vpn,
    input logic expt_wr1_pgflt,
    input logic expt_wr1_acflt
);

  localparam logic [2:0] MB_STATE_IDLE = 3'b000;
  localparam logic [2:0] MB_STATE_WFG  = 3'b001;
  localparam logic [2:0] MB_STATE_WFC  = 3'b010;
  localparam logic [2:0] MB_STATE_ABT  = 3'b101;
  localparam logic [2:0] MB_STATE_WFI  = 3'b110;

  int unsigned cp_l1d_ptw_consumer_install_hits;
  int unsigned cp_l1d_ptw_consumer_fault_hits;

  function automatic logic [NUM_ENTRY-1:0] onehot_entry(input logic [3:0] idx);
    onehot_entry = '0;
    if (idx < NUM_ENTRY)
      onehot_entry[idx] = 1'b1;
  endfunction

  function automatic bit legal_pgs(input logic [2:0] pgs);
    legal_pgs = (pgs == 3'b001) || (pgs == 3'b010) || (pgs == 3'b100);
  endfunction

  function automatic logic [NUM_ENTRY-1:0] va8_match_vec(input logic [7:0] vpn8);
    va8_match_vec = '0;
    for (int i = 0; i < NUM_ENTRY; i++) begin
      va8_match_vec[i] = (l1dtlb_ent_vpn[i][7:0] == vpn8);
    end
  endfunction

  // A001/A061: reset and full-entry clear visible state.
  a_reset_clears_visible_state: assert property (@(posedge forever_cpuclk)
    !cpurst_b |=> (entry_vld == '0
                && mb_entry_vld == '0
                && mmu_lsu_tlb_busy == 1'b0
                && mmu_lsu_tlb_wakeup == 12'h000
                && mmu_lsu_pa0_vld == 1'b0
                && mmu_lsu_pa1_vld == 1'b0
                && mmu_lsu_page_fault0 == 1'b0
                && mmu_lsu_page_fault1 == 1'b0
                && mmu_lsu_access_fault0 == 1'b0
                && mmu_lsu_access_fault1 == 1'b0));

  a_regs_utlb_clr_clears_entries: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    regs_utlb_clr |=> (entry_vld == '0));

  a_tlboper_utlb_clr_clears_entries: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    tlboper_utlb_clr |=> (entry_vld == '0));

  // A004/A005: STAMO is a pipe1 bypass path and must not create pipe0 side effects.
  a_stamo_no_pipe0_bypass: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_stamo_vld && !lsu_mmu_va0_vld) |-> !mmu_lsu_pa0_vld);

  a_stamo_no_new_miss_side_effect: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_stamo_vld && !lsu_mmu_va0_vld && !lsu_mmu_va1_vld)
    |-> (!dutlb_miss_vld0 && !dutlb_miss_vld1));

  // A008/A020/A037/A038/A070: abort, CAM-hit, and no-response paths do not allocate.
  a_abort0_not_miss: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va0_vld && lsu_mmu_abort0) |-> !dutlb_miss_vld0);

  a_abort1_not_miss: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va1_vld && lsu_mmu_abort1) |-> !dutlb_miss_vld1);

  a_abort0_no_expt_consume_top: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va0_vld && lsu_mmu_abort0) |-> !expt_match0);

  a_abort1_no_expt_consume_top: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va1_vld && lsu_mmu_abort1) |-> !expt_match1);

  a_expt_replay0_not_new_miss: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va0_vld && expt_match0) |-> (!dutlb_miss_vld0 && !dutlb_miss_vld_short0));

  a_expt_replay1_not_new_miss: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va1_vld && expt_match1) |-> (!dutlb_miss_vld1 && !dutlb_miss_vld_short1));

  // A011/A012/A014/A015: externally visible terminal/fault shape.
  a_pipe0_page_fault_has_pa_vld: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    mmu_lsu_page_fault0 |-> mmu_lsu_pa0_vld);

  a_pipe1_page_fault_has_pa_vld: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    mmu_lsu_page_fault1 |-> mmu_lsu_pa1_vld);

  a_expt_replay0_has_terminal_response: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va0_vld && expt_match0) |-> mmu_lsu_pa0_vld);

  a_expt_replay1_has_terminal_response: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va1_vld && expt_match1) |-> mmu_lsu_pa1_vld);

  // A016/A017/A018: wakeup/busy event-level contract.
  a_wakeup_is_broadcast: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (mmu_lsu_tlb_wakeup == 12'h000) || (mmu_lsu_tlb_wakeup == 12'hfff));

  a_wakeup_has_known_source: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (mmu_lsu_tlb_wakeup == 12'hfff) |-> ((install_wakeup == 12'hfff) || (expt_wakeup == 12'hfff)));

  a_busy_mirrors_mb_valid: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    mmu_lsu_tlb_busy == (|mb_entry_vld));

  // A021/A022/A068: hit responses are independent per pipe.
  a_pipe0_hit_returns_t0: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va0_vld && (|entry_hit0) && !mmu_lsu_page_fault0) |-> mmu_lsu_pa0_vld);

  a_pipe1_hit_returns_t0: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va1_vld && (|entry_hit1) && !mmu_lsu_page_fault1) |-> mmu_lsu_pa1_vld);

  a_dual_hit_returns_both: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va0_vld && lsu_mmu_va1_vld && (|entry_hit0) && (|entry_hit1)
     && !mmu_lsu_page_fault0 && !mmu_lsu_page_fault1)
    |-> (mmu_lsu_pa0_vld && mmu_lsu_pa1_vld));

  // A023/A037/A039: top-level T1 miss allocation gating before allocator.
  a_same_4k_miss_dedup_top: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (same_4k_miss01 && !(mb_hit0 || mb_hit1) && !(&mb_entry_vld))
    |-> (alloc_gnt0 && !alloc_gnt1 && $countones(mb_alloc_we) == 1));

  a_mb_cam_hit_no_alloc0: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (miss0_vld_q && !miss0_abort_q && mb_hit0) |-> !alloc_gnt0);

  a_mb_cam_hit_no_alloc1: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (miss1_vld_q && !miss1_abort_q && mb_hit1) |-> !alloc_gnt1);

  a_mb_full_no_alloc_top: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    ((miss0_vld_q || miss1_vld_q) && (&mb_entry_vld)) |-> (!alloc_gnt0 && !alloc_gnt1 && mb_alloc_we == '0));

  a_one_free_dual_diff_at_most_one_alloc_top: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (miss0_vld_q && miss1_vld_q && (miss0_vpn_q != miss1_vpn_q) && ($countones(mb_entry_vld) == MB_DEPTH-1))
    |-> ($countones(mb_alloc_we) <= 1 && !(alloc_gnt0 && alloc_gnt1)));

  a_direct_map_no_new_miss_top: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    ((lsu_mmu_va0_vld || lsu_mmu_va1_vld) && dutlb_off_hit)
    |-> (!dutlb_miss_vld0 && !dutlb_miss_vld1));

  a_legal_no_response_no_t0_terminal_top: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (((lsu_mmu_va0_vld && !lsu_mmu_abort0 && !dutlb_off_hit && !expt_match0 && mb_hit0 && !(|entry_hit0))
      || (lsu_mmu_va0_vld && !lsu_mmu_abort0 && !dutlb_off_hit && !expt_match0 && dutlb_miss_vld0 && (&mb_entry_vld) && !mb_hit0 && !(|entry_hit0)))
     |-> (!mmu_lsu_pa0_vld && !mmu_lsu_page_fault0)));

  a_legal_no_response_no_t0_terminal_top_p1: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (((lsu_mmu_va1_vld && !lsu_mmu_abort1 && !dutlb_off_hit && !expt_match1 && mb_hit1 && !(|entry_hit1))
      || (lsu_mmu_va1_vld && !lsu_mmu_abort1 && !dutlb_off_hit && !expt_match1 && dutlb_miss_vld1 && (&mb_entry_vld) && !mb_hit1 && !(|entry_hit1)))
     |-> (!mmu_lsu_pa1_vld && !mmu_lsu_page_fault1)));

  // A028/A029/A030/A066: entry/PLRU structural invariants.
  genvar ent_i;
  generate
    for (ent_i = 0; ent_i < NUM_ENTRY; ent_i++) begin : gen_l1dtlb_entry_sva
      a_valid_entry_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
        entry_vld[ent_i] |-> (!$isunknown(entry_ppn[ent_i])
                           && !$isunknown(l1dtlb_ent_vpn[ent_i])
                           && !$isunknown(l1dtlb_ent_pgs[ent_i])
                           && legal_pgs(l1dtlb_ent_pgs[ent_i])));

      a_va8_inv_clears_matching_entry: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
        (tlboper_utlb_inv_va_req
         && entry_vld[ent_i]
         && (l1dtlb_ent_vpn[ent_i][7:0] == lsu_mmu_tlb_va[7:0]))
        |=> !entry_vld[ent_i]);

      a_va8_inv_preserves_nonmatching_entry: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
        (tlboper_utlb_inv_va_req
         && entry_vld[ent_i]
         && (l1dtlb_ent_vpn[ent_i][7:0] != lsu_mmu_tlb_va[7:0])
         && !regs_utlb_clr
         && !tlboper_utlb_clr
         && !entry_upd[ent_i])
        |=> entry_vld[ent_i]);

      a_clear_wins_install_same_entry: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
        (((regs_utlb_clr || tlboper_utlb_clr)
          || (tlboper_utlb_inv_va_req
              && entry_vld[ent_i]
              && (l1dtlb_ent_vpn[ent_i][7:0] == lsu_mmu_tlb_va[7:0])))
         && entry_upd[ent_i])
        |=> !entry_vld[ent_i]);
    end
  endgenerate

  a_refill_entry_update_onehot: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    utlb_refill_vld |-> ($onehot(entry_upd)
                      && (utlb_refill_idx < NUM_ENTRY)
                      && (entry_upd == onehot_entry(utlb_refill_idx))));

  a_refill_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    utlb_refill_vld |-> (!$isunknown(utlb_refill_vpn)
                      && !$isunknown(utlb_refill_ppn)
                      && !$isunknown(utlb_refill_pgs)
                      && legal_pgs(utlb_refill_pgs)));

  a_plru_refill_way_onehot: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    plru_refill_updt |-> ($onehot(plru_refill_way) && !$isunknown(plru_refill_way)));

  // A040/A041: MB aggregate state-derived signals.
  genvar mb_i;
  generate
    for (mb_i = 0; mb_i < MB_DEPTH; mb_i++) begin : gen_l1dtlb_mb_sva
      a_mb_vld_matches_state: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
        mb_entry_vld[mb_i] == (mb_entry_state[mb_i] != MB_STATE_IDLE));

      a_mb_ready_only_wfg: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
        mb_entry_ready[mb_i] |-> (mb_entry_state[mb_i] == MB_STATE_WFG));

      a_mb_wfc_matches_state: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
        mb_entry_wfc[mb_i] == ((mb_entry_state[mb_i] == MB_STATE_WFC)
                            || (mb_entry_state[mb_i] == MB_STATE_ABT)));

      a_mb_wfi_matches_state: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
        mb_entry_wfi[mb_i] == (mb_entry_state[mb_i] == MB_STATE_WFI));

      a_valid_mb_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
        mb_entry_vld[mb_i] |-> (!$isunknown(mb_entry_vpn[mb_i])
                             && !$isunknown(mb_entry_iid[mb_i])
                             && !$isunknown(mb_entry_store[mb_i])));
    end
  endgenerate

  // A047/A052/A053/A054: L2/fault refill payload and stale/flush side effects.
  a_l2_req_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    dutlb_l2tlb_req_vld |-> (!$isunknown(dutlb_l2tlb_req_vpn)
                          && !$isunknown(dutlb_l2tlb_req_eid)
                          && !$isunknown(dutlb_l2tlb_req_is_load)));

  a_l2_req_eid_in_range: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    dutlb_l2tlb_req_vld |-> (dutlb_l2tlb_req_eid < MB_DEPTH));

  a_l2_req_matches_mb_payload: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (dutlb_l2tlb_req_vld && mb_entry_vld[dutlb_l2tlb_req_eid])
    |-> (dutlb_l2tlb_req_vpn == mb_entry_vpn[dutlb_l2tlb_req_eid]
      && dutlb_l2tlb_req_is_load == !mb_entry_store[dutlb_l2tlb_req_eid]));

  a_expt_wr0_fault_exclusive: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr0_vld |-> !(expt_wr0_pgflt && expt_wr0_acflt));

  a_expt_wr1_fault_exclusive: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr1_vld |-> !(expt_wr1_pgflt && expt_wr1_acflt));

  a_expt_wr0_has_fault_class: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr0_vld |-> (expt_wr0_pgflt ^ expt_wr0_acflt));

  a_expt_wr1_has_fault_class: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr1_vld |-> (expt_wr1_pgflt ^ expt_wr1_acflt));

  a_expt_wr0_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr0_vld |-> (!$isunknown(expt_wr0_eid)
                   && !$isunknown(expt_wr0_iid)
                   && !$isunknown(expt_wr0_vpn)));

  a_expt_wr1_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr1_vld |-> (!$isunknown(expt_wr1_eid)
                   && !$isunknown(expt_wr1_iid)
                   && !$isunknown(expt_wr1_vpn)));

  a_expt_wr0_id_in_range: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr0_vld |-> (expt_wr0_eid < MB_DEPTH));

  a_expt_wr1_id_in_range: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr1_vld |-> (expt_wr1_eid < MB_DEPTH));

  a_l2_fault_is_page_fault_only: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr1_vld |-> (expt_wr1_pgflt && !expt_wr1_acflt));

  a_ptw_fault_requires_wfc_entry: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr0_vld |-> (mb_entry_vld[expt_wr0_eid]
                   && mb_entry_state[expt_wr0_eid] == MB_STATE_WFC));

  a_l2_fault_requires_wfc_entry: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr1_vld |-> (mb_entry_vld[expt_wr1_eid]
                   && mb_entry_state[expt_wr1_eid] == MB_STATE_WFC));

  // RTU flush suppresses new fault side effects.  Same-cycle refill/install
  // wakeup is legal and is checked by the per-MB flush/refill assertions below.
  a_flush_blocks_new_side_effects: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    rtu_yy_xx_flush |-> (!expt_wr0_vld && !expt_wr1_vld));

  // A071: event-level miss counter guard.
  a_hpc_miss_only_on_real_miss: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    mmu_hpcp_dutlb_miss |-> (dutlb_miss_vld0 || dutlb_miss_vld1));

  // C001-C027 representative cover points.  Several complex rows are also
  // measured in the whitebox covergroup and traceability matrix.
  cp_l1dtlb_c001_reset_then_miss: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    $rose(cpurst_b) ##[1:64] (dutlb_miss_vld0 || dutlb_miss_vld1));

  cp_l1dtlb_c002_dual_hit: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    lsu_mmu_va0_vld && lsu_mmu_va1_vld && (|entry_hit0) && (|entry_hit1));

  cp_l1dtlb_c003_hit_miss: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    lsu_mmu_va0_vld && lsu_mmu_va1_vld
    && (((|entry_hit0) && dutlb_miss_vld1) || ((|entry_hit1) && dutlb_miss_vld0)));

  cp_l1dtlb_c007_mb_full: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (&mb_entry_vld) && (dutlb_miss_vld0 || dutlb_miss_vld1));

  cp_l1dtlb_c004_same_vpn_dedup_top: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    same_4k_miss01 && alloc_gnt0 && !alloc_gnt1);

  cp_l1dtlb_c008_hit_under_miss: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    mmu_lsu_tlb_busy && (mmu_lsu_pa0_vld || mmu_lsu_pa1_vld));

  cp_l1dtlb_c006_one_free_dual_diff_top: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    miss0_vld_q && miss1_vld_q && (miss0_vpn_q != miss1_vpn_q)
    && ($countones(mb_entry_vld) == MB_DEPTH-1));

  cp_l1dtlb_c011_direct_map_no_miss_top: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    ((lsu_mmu_va0_vld || lsu_mmu_va1_vld) && dutlb_off_hit
     && !dutlb_miss_vld0 && !dutlb_miss_vld1));

  cp_l1dtlb_c009_abort: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va0_vld && lsu_mmu_abort0) || (lsu_mmu_va1_vld && lsu_mmu_abort1));

  cp_l1dtlb_c009_abort_hit: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va0_vld && lsu_mmu_abort0 && (|entry_hit0))
    || (lsu_mmu_va1_vld && lsu_mmu_abort1 && (|entry_hit1)));

  cp_l1dtlb_c009_abort_miss_attempt: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va0_vld && lsu_mmu_abort0 && !(|entry_hit0) && !dutlb_off_hit && !expt_match0)
    || (lsu_mmu_va1_vld && lsu_mmu_abort1 && !(|entry_hit1) && !dutlb_off_hit && !expt_match1));

  cp_l1dtlb_c012_stamo: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    lsu_mmu_stamo_vld);

  cp_l1dtlb_c014_l2_req: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    dutlb_l2tlb_req_vld);

  cp_l1dtlb_c015_wfi_install: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (|mb_entry_wfi) ##[0:16] utlb_refill_vld);

  cp_l1dtlb_c016_fault_write: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr0_vld || expt_wr1_vld);

  cp_l1dtlb_c016_dual_fault_write: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_wr0_vld && expt_wr1_vld && (expt_wr0_eid != expt_wr1_eid));

  cp_l1dtlb_c019_expt_replay: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    expt_match0 || expt_match1);

  cp_l1dtlb_c020_clear: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    regs_utlb_clr || tlboper_utlb_clr || tlboper_utlb_inv_va_req || rtu_yy_xx_flush);

  cp_l1dtlb_c020_va8_alias_clear: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    tlboper_utlb_inv_va_req
    && (|entry_vld)
    && (|(entry_vld & va8_match_vec(lsu_mmu_tlb_va[7:0]))));

  cp_l1dtlb_c020_inv_install_same_entry: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (|entry_upd)
    && ((tlboper_utlb_inv_va_req && (|(entry_upd & entry_vld & va8_match_vec(lsu_mmu_tlb_va[7:0]))))
        || regs_utlb_clr || tlboper_utlb_clr));

  cp_l1dtlb_c021_t1_t0_overlap: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (mmu_lsu_access_fault0 && (mmu_lsu_pa0_vld || mmu_lsu_page_fault0))
    || (mmu_lsu_access_fault1 && (mmu_lsu_pa1_vld || mmu_lsu_page_fault1)));

  cp_l1dtlb_c022_page_size_4k: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    utlb_refill_vld && utlb_refill_pgs == 3'b001);

  cp_l1dtlb_c022_page_size_2m: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    utlb_refill_vld && utlb_refill_pgs == 3'b010);

  cp_l1dtlb_c022_page_size_1g: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    utlb_refill_vld && utlb_refill_pgs == 3'b100);

  cp_l1dtlb_c023_multi_hit_diag: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    ($countones(entry_hit0) > 1) || ($countones(entry_hit1) > 1));

  cp_l1dtlb_c024_plru_refill: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    plru_refill_updt);

  cp_l1dtlb_c025_hpc_miss_event: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    mmu_hpcp_dutlb_miss);

  cp_l1dtlb_c026_vabuf_change: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    lsu_mmu_va0_vld && $changed(lsu_mmu_vabuf0));

  // Consumer-only PTW routing evidence. PTW source-side closure remains in
  // ptw_source_sb and PTW-bound SVA.
  a_l1d_ptw_success_has_install_payload: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    (ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt)
    |-> (!ptw_l1tlb_pgflt && !ptw_l1tlb_acc_err && legal_pgs(ptw_l1tlb_ref_pgs)));

  cp_l1d_ptw_consumer_install: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt
    && !ptw_l1tlb_pgflt && !ptw_l1tlb_acc_err) begin
    cp_l1d_ptw_consumer_install_hits++;
  end

  a_l1d_ptw_fault_class_mutex: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    ptw_l1dtlb_ref_cmplt |-> !(ptw_l1tlb_pgflt && ptw_l1tlb_acc_err));

  cp_l1d_ptw_consumer_fault: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    ptw_l1dtlb_ref_cmplt && (ptw_l1tlb_pgflt || ptw_l1tlb_acc_err)) begin
    cp_l1d_ptw_consumer_fault_hits++;
  end

  final begin
    $display("PTW_SVA_COVER module=mmu_l1dtlb_sva name=cp_l1d_ptw_consumer_install req=L1D-SVA-PTW-001 hits=%0d consumer_only=1", cp_l1d_ptw_consumer_install_hits);
    $display("PTW_SVA_COVER module=mmu_l1dtlb_sva name=cp_l1d_ptw_consumer_fault req=L1D-SVA-PTW-003 hits=%0d consumer_only=1", cp_l1d_ptw_consumer_fault_hits);
  end

endmodule

module mmu_l1dtlb_allocator_sva #(
    parameter int MB_DEPTH  = 8,
    parameter int VPN_WIDTH = 27,
    parameter int IID_WIDTH = 7
) (
    input logic forever_cpuclk,
    input logic cpurst_b,
    input logic req0_vld,
    input logic [VPN_WIDTH-1:0] req0_vpn,
    input logic [IID_WIDTH-1:0] req0_iid,
    input logic req1_vld,
    input logic [VPN_WIDTH-1:0] req1_vpn,
    input logic [IID_WIDTH-1:0] req1_iid,
    input logic [MB_DEPTH-1:0] mb_vld,
    input logic gnt0,
    input logic gnt1,
    input logic [$clog2(MB_DEPTH)-1:0] sel0,
    input logic [$clog2(MB_DEPTH)-1:0] sel1,
    input logic [MB_DEPTH-1:0] alloc_we
);

  function automatic logic [$clog2(MB_DEPTH+1)-1:0] free_count(input logic [MB_DEPTH-1:0] v);
    free_count = $countones(~v);
  endfunction

  // A023/A024/A025/A039: allocation count, same-4K dedup, and full behavior.
  a_alloc_we_matches_grants: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    $countones(alloc_we) == ((gnt0 ? 1 : 0) + (gnt1 ? 1 : 0)));

  a_alloc_we_at_most_two: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    $countones(alloc_we) <= 2);

  a_no_free_no_grant: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (&mb_vld) |-> (!gnt0 && !gnt1 && alloc_we == '0));

  a_same_4k_dual_miss_dedup: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (req0_vld && req1_vld && (req0_vpn == req1_vpn) && (free_count(mb_vld) != 0))
    |-> (gnt0 && !gnt1 && $countones(alloc_we) == 1));

  a_two_free_dual_diff_allocates_both: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (req0_vld && req1_vld && (req0_vpn != req1_vpn) && (free_count(mb_vld) >= 2))
    |-> (gnt0 && gnt1 && sel0 != sel1 && $countones(alloc_we) == 2));

  a_single_req0_allocates_when_free: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (req0_vld && !req1_vld && (free_count(mb_vld) != 0)) |-> gnt0);

  a_single_req1_allocates_when_free: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (!req0_vld && req1_vld && (free_count(mb_vld) != 0)) |-> gnt1);

  cp_l1dtlb_c004_same_vpn_dedup: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    req0_vld && req1_vld && (req0_vpn == req1_vpn) && gnt0 && !gnt1);

  cp_l1dtlb_c005_dual_diff_two_free: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    req0_vld && req1_vld && (req0_vpn != req1_vpn) && gnt0 && gnt1);

  cp_l1dtlb_c006_dual_diff_one_free: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    req0_vld && req1_vld && (req0_vpn != req1_vpn) && (free_count(mb_vld) == 1));

  cp_l1dtlb_c006_one_free_port0_wins: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    req0_vld && req1_vld && (req0_vpn != req1_vpn) && (free_count(mb_vld) == 1)
    && gnt0 && !gnt1);

  cp_l1dtlb_c006_one_free_port1_wins: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    req0_vld && req1_vld && (req0_vpn != req1_vpn) && (free_count(mb_vld) == 1)
    && !gnt0 && gnt1);

endmodule

module mmu_l1dtlb_mb_entry_sva #(
    parameter int VPN_WIDTH = 27,
    parameter int PPN_WIDTH = 28,
    parameter int FLG_WIDTH = 14,
    parameter int IID_WIDTH = 7
) (
    input logic cpurst_b,
    input logic mb_clk,
    input logic alloc_vld,
    input logic [VPN_WIDTH-1:0] alloc_vpn,
    input logic [IID_WIDTH-1:0] alloc_iid,
    input logic alloc_store,
    input logic issue_sel,
    input logic issue_grant,
    input logic refill_vld,
    input logic refill_gnt,
    input logic refill_pgflt,
    input logic refill_acflt,
    input logic [PPN_WIDTH-1:0] refill_ppn,
    input logic [FLG_WIDTH-1:0] refill_flg,
    input logic [2:0] refill_pgs,
    input logic expt_hit,
    input logic rtu_yy_xx_flush,
    input logic entry_vld,
    input logic [2:0] entry_state,
    input logic [VPN_WIDTH-1:0] entry_vpn,
    input logic [PPN_WIDTH-1:0] entry_ppn,
    input logic [FLG_WIDTH-1:0] entry_flg,
    input logic [IID_WIDTH-1:0] entry_iid,
    input logic [2:0] entry_pgs,
    input logic entry_store,
    input logic entry_issued,
    input logic entry_ready,
    input logic entry_wfc,
    input logic entry_wfi
);

  localparam logic [2:0] STATE_IDLE  = 3'b000;
  localparam logic [2:0] STATE_WFG   = 3'b001;
  localparam logic [2:0] STATE_WFC   = 3'b010;
  localparam logic [2:0] STATE_PGFLT = 3'b011;
  localparam logic [2:0] STATE_ACFLT = 3'b100;
  localparam logic [2:0] STATE_ABT   = 3'b101;
  localparam logic [2:0] STATE_WFI   = 3'b110;

  function automatic bit legal_pgs(input logic [2:0] pgs);
    legal_pgs = (pgs == 3'b001) || (pgs == 3'b010) || (pgs == 3'b100);
  endfunction

  // A040/A041/A042/A051/A065: MB FSM and latched data behavior.
  a_entry_vld_state_decode: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    entry_vld == (entry_state != STATE_IDLE));

  a_entry_ready_state_decode: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    entry_ready == (entry_state == STATE_WFG));

  a_entry_wfc_state_decode: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    entry_wfc == ((entry_state == STATE_WFC) || (entry_state == STATE_ABT)));

  a_entry_wfi_state_decode: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    entry_wfi == (entry_state == STATE_WFI));

	  a_alloc_latches_payload: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
	    (alloc_vld && !rtu_yy_xx_flush && entry_state == STATE_IDLE)
	    |=> (entry_vpn == $past(alloc_vpn)
	      && entry_iid == $past(alloc_iid)
	      && entry_store == $past(alloc_store)));

	  a_idle_flush_blocks_alloc: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
	    (alloc_vld && rtu_yy_xx_flush && entry_state == STATE_IDLE)
	    |=> entry_state == STATE_IDLE);

  a_wfi_data_stable_without_grant: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    (entry_state == STATE_WFI && !refill_gnt && !rtu_yy_xx_flush)
    |=> (entry_state == STATE_WFI
      && entry_vpn == $past(entry_vpn)
      && entry_ppn == $past(entry_ppn)
      && entry_flg == $past(entry_flg)
      && entry_pgs == $past(entry_pgs)));

  a_fault_state_holds_until_replay_or_flush: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    ((entry_state == STATE_PGFLT) || (entry_state == STATE_ACFLT)) && !expt_hit && !rtu_yy_xx_flush
    |=> ((entry_state == STATE_PGFLT) || (entry_state == STATE_ACFLT)));

  a_refill_fault_exclusive: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    refill_vld |-> !(refill_pgflt && refill_acflt));

  a_refill_success_payload_legal: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    (entry_state == STATE_WFC && refill_vld && !refill_pgflt && !refill_acflt)
    |-> (!$isunknown(refill_ppn) && !$isunknown(refill_flg) && legal_pgs(refill_pgs)));

  a_wfg_flush_no_grant_to_idle: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    (entry_state == STATE_WFG && rtu_yy_xx_flush && !(issue_sel && issue_grant)) |=> entry_state == STATE_IDLE);

  a_wfg_flush_with_grant_to_abt: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    (entry_state == STATE_WFG && rtu_yy_xx_flush && issue_sel && issue_grant) |=> entry_state == STATE_ABT);

  cp_l1dtlb_wfg_flush_no_grant: cover property (@(posedge mb_clk) disable iff (!cpurst_b)
    entry_state == STATE_WFG && rtu_yy_xx_flush && !(issue_sel && issue_grant));

  cp_l1dtlb_wfg_flush_with_grant: cover property (@(posedge mb_clk) disable iff (!cpurst_b)
    entry_state == STATE_WFG && rtu_yy_xx_flush && issue_sel && issue_grant);

  a_wfc_flush_no_refill_to_abt: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    (entry_state == STATE_WFC && rtu_yy_xx_flush && !refill_vld) |=> entry_state == STATE_ABT);

  a_wfc_flush_refill_to_idle: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    (entry_state == STATE_WFC && rtu_yy_xx_flush && refill_vld) |=> entry_state == STATE_IDLE);

  a_wfi_flush_to_idle: assert property (@(posedge mb_clk) disable iff (!cpurst_b)
    (entry_state == STATE_WFI && rtu_yy_xx_flush) |=> entry_state == STATE_IDLE);

  cp_l1dtlb_c017_stale_or_abt_refill: cover property (@(posedge mb_clk) disable iff (!cpurst_b)
    (entry_state inside {STATE_IDLE, STATE_PGFLT, STATE_ACFLT, STATE_ABT}) && refill_vld);

  cp_l1dtlb_c015_wfi_hold: cover property (@(posedge mb_clk) disable iff (!cpurst_b)
    (entry_state == STATE_WFI) && refill_gnt);

  cp_l1dtlb_c020_flush_race: cover property (@(posedge mb_clk) disable iff (!cpurst_b)
    rtu_yy_xx_flush && (entry_state != STATE_IDLE));

endmodule

module mmu_l1dtlb_scheduler_sva #(
    parameter int MB_DEPTH   = 8,
    parameter int VPN_WIDTH  = 27,
    parameter int IID_WIDTH  = 7,
    parameter int CREDIT_MAX = 8
) (
    input logic sched_clk,
    input logic cpurst_b,
    input logic [MB_DEPTH-1:0] mb_entry_vld,
    input logic [MB_DEPTH-1:0] mb_entry_ready,
    input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
    input logic [MB_DEPTH-1:0][IID_WIDTH-1:0] mb_entry_iid,
    input logic [MB_DEPTH-1:0] mb_entry_store,
    input logic alloc_gnt0,
    input logic [$clog2(MB_DEPTH)-1:0] alloc_sel0,
    input logic [VPN_WIDTH-1:0] alloc_vpn0,
    input logic [IID_WIDTH-1:0] alloc_iid0,
    input logic alloc_store0,
    input logic alloc_gnt1,
    input logic [$clog2(MB_DEPTH)-1:0] alloc_sel1,
    input logic [VPN_WIDTH-1:0] alloc_vpn1,
    input logic [IID_WIDTH-1:0] alloc_iid1,
    input logic alloc_store1,
    input logic l2tlb_credit_ret,
    input logic dutlb_arb_req,
    input logic [VPN_WIDTH-1:0] dutlb_arb_vpn,
    input logic [$clog2(MB_DEPTH)-1:0] dutlb_arb_id,
    input logic dutlb_arb_store,
    input logic [MB_DEPTH-1:0] issue_sel,
    input logic issue_grant_out,
    input logic [$clog2(CREDIT_MAX+1):0] credit_cnt
);

  function automatic logic [$clog2(MB_DEPTH)-1:0] first_ready(input logic [MB_DEPTH-1:0] v);
    first_ready = '0;
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (v[i]) begin
        first_ready = i[$clog2(MB_DEPTH)-1:0];
        break;
      end
    end
  endfunction

  logic [$clog2(MB_DEPTH)-1:0] old_ready_id;
  assign old_ready_id = first_ready(mb_entry_ready);

  // A002/A043/A044/A045/A046/A047: scheduler credit and request ownership.
  a_credit_in_range: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    credit_cnt <= CREDIT_MAX);

  a_reset_credit_max: assert property (@(posedge sched_clk)
    !cpurst_b |=> credit_cnt == CREDIT_MAX);

  a_no_req_without_credit_or_return: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    (credit_cnt == 0 && !l2tlb_credit_ret) |-> !dutlb_arb_req);

  a_no_req_at_zero_credit_even_with_return: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    credit_cnt == 0 |-> !dutlb_arb_req);

  a_credit_decrement_on_req_only: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    (dutlb_arb_req && !l2tlb_credit_ret) |=> credit_cnt == $past(credit_cnt) - 1'b1);

  a_credit_increment_on_return_only: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    (!dutlb_arb_req && l2tlb_credit_ret && (credit_cnt < CREDIT_MAX))
    |=> credit_cnt == $past(credit_cnt) + 1'b1);

  a_credit_hold_on_req_and_return: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    (dutlb_arb_req && l2tlb_credit_ret) |=> credit_cnt == $past(credit_cnt));

  a_req_payload_known: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    dutlb_arb_req |-> (!$isunknown(dutlb_arb_vpn)
                    && !$isunknown(dutlb_arb_id)
                    && !$isunknown(dutlb_arb_store)));

  a_req_id_in_range: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    dutlb_arb_req |-> (dutlb_arb_id < MB_DEPTH));

  a_issue_sel_onehot0: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    $onehot0(issue_sel));

  a_req_matches_issue_grant: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    dutlb_arb_req == issue_grant_out);

  a_old_mb_priority_over_bypass: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    ((|mb_entry_ready) && (alloc_gnt0 || alloc_gnt1) && (credit_cnt != 0))
    |-> (dutlb_arb_req
      && dutlb_arb_id == old_ready_id
      && issue_sel == ({{(MB_DEPTH-1){1'b0}}, 1'b1} << old_ready_id)));

  a_mb_req_payload_matches_entry: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    (dutlb_arb_req && (|mb_entry_ready))
    |-> (dutlb_arb_vpn == mb_entry_vpn[dutlb_arb_id]
      && dutlb_arb_store == mb_entry_store[dutlb_arb_id]));

  a_bypass0_req_matches_alloc: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    (dutlb_arb_req && !(|mb_entry_ready) && alloc_gnt0)
    |-> (dutlb_arb_id == alloc_sel0
      && dutlb_arb_vpn == alloc_vpn0
      && dutlb_arb_store == alloc_store0));

  a_bypass1_req_matches_alloc: assert property (@(posedge sched_clk) disable iff (!cpurst_b)
    (dutlb_arb_req && !(|mb_entry_ready) && !alloc_gnt0 && alloc_gnt1)
    |-> (dutlb_arb_id == alloc_sel1
      && dutlb_arb_vpn == alloc_vpn1
      && dutlb_arb_store == alloc_store1));

  cp_l1dtlb_c014_credit_empty: cover property (@(posedge sched_clk) disable iff (!cpurst_b)
    credit_cnt == 0);

  cp_l1dtlb_c014_credit_req: cover property (@(posedge sched_clk) disable iff (!cpurst_b)
    dutlb_arb_req);

  cp_l1dtlb_c014_credit_return: cover property (@(posedge sched_clk) disable iff (!cpurst_b)
    l2tlb_credit_ret);

  cp_l1dtlb_c014_req_and_return: cover property (@(posedge sched_clk) disable iff (!cpurst_b)
    dutlb_arb_req && l2tlb_credit_ret);

  cp_l1dtlb_c014_zero_credit_return: cover property (@(posedge sched_clk) disable iff (!cpurst_b)
    (credit_cnt == 0) && l2tlb_credit_ret && !dutlb_arb_req);

  cp_l1dtlb_c014_old_mb_priority: cover property (@(posedge sched_clk) disable iff (!cpurst_b)
    (|mb_entry_ready) && (alloc_gnt0 || alloc_gnt1) && dutlb_arb_req);

  cp_l1dtlb_c014_bypass_issue: cover property (@(posedge sched_clk) disable iff (!cpurst_b)
    !(|mb_entry_ready) && (alloc_gnt0 || alloc_gnt1) && dutlb_arb_req);

endmodule

module mmu_l1dtlb_install_sva #(
    parameter int MB_DEPTH  = 8,
    parameter int VPN_WIDTH = 27,
    parameter int PPN_WIDTH = 28,
    parameter int FLG_WIDTH = 14,
    parameter int IID_WIDTH = 7
) (
    input logic cpurst_b,
    input logic install_clk,
    input logic [MB_DEPTH-1:0] mb_entry_vld,
    input logic [MB_DEPTH-1:0][2:0] mb_entry_state,
    input logic [MB_DEPTH-1:0][VPN_WIDTH-1:0] mb_entry_vpn,
    input logic [MB_DEPTH-1:0][PPN_WIDTH-1:0] mb_entry_ppn,
    input logic [MB_DEPTH-1:0][FLG_WIDTH-1:0] mb_entry_flg,
    input logic [MB_DEPTH-1:0][2:0] mb_entry_pgs,
    input logic [MB_DEPTH-1:0] mb_entry_wfi,
    input logic [MB_DEPTH-1:0] mb_refill_gnt_bus,
    input logic jtlb_dutlb_ref_pavld,
    input logic jtlb_dutlb_ref_cmplt,
    input logic [2:0] jtlb_dutlb_ref_id,
    input logic [VPN_WIDTH-1:0] jtlb_utlb_ref_vpn,
    input logic [PPN_WIDTH-1:0] jtlb_utlb_ref_ppn,
    input logic [FLG_WIDTH-1:0] jtlb_utlb_ref_flg,
    input logic jtlb_dutlb_pgflt,
    input logic [2:0] l2tlb_l1dtlb_ref_pgs,
    input logic ptw_l1dtlb_ref_pavld,
    input logic ptw_l1dtlb_ref_cmplt,
    input logic [2:0] ptw_l1dtlb_ref_id,
    input logic [VPN_WIDTH-1:0] ptw_l1tlb_ref_vpn,
    input logic [PPN_WIDTH-1:0] ptw_l1tlb_ref_ppn,
    input logic ptw_l1tlb_acc_err,
    input logic ptw_l1tlb_pgflt,
    input logic [FLG_WIDTH-1:0] ptw_l1tlb_ref_flg,
    input logic [2:0] ptw_l1dtlb_ref_pgs,
    input logic utlb_refill_vld,
    input logic [3:0] utlb_refill_idx,
    input logic [VPN_WIDTH-1:0] utlb_refill_vpn,
    input logic [PPN_WIDTH-1:0] utlb_refill_ppn,
    input logic [FLG_WIDTH-1:0] utlb_refill_flg,
    input logic [2:0] utlb_refill_pgs,
    input logic plru_refill_updt,
    input logic [15:0] plru_refill_way,
    input logic [11:0] mmu_lsu_tlb_wakeup
);

  localparam logic [2:0] STATE_WFC = 3'b010;
  localparam logic [2:0] STATE_ABT = 3'b101;

  function automatic logic [$clog2(MB_DEPTH)-1:0] first_wfi(input logic [MB_DEPTH-1:0] v);
    first_wfi = '0;
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (v[i]) begin
        first_wfi = i[$clog2(MB_DEPTH)-1:0];
        break;
      end
    end
  endfunction

  function automatic bit legal_pgs(input logic [2:0] pgs);
    legal_pgs = (pgs == 3'b001) || (pgs == 3'b010) || (pgs == 3'b100);
  endfunction

  logic [$clog2(MB_DEPTH)-1:0] wfi_id;
  assign wfi_id = first_wfi(mb_entry_wfi);

  // A016/A048/A049/A050/A051/A066: install arbitration and update payload.
  a_install_wakeup_shape: assert property (@(posedge install_clk) disable iff (!cpurst_b)
    (mmu_lsu_tlb_wakeup == 12'h000) || (mmu_lsu_tlb_wakeup == 12'hfff));

  a_install_wakeup_on_install: assert property (@(posedge install_clk) disable iff (!cpurst_b)
    utlb_refill_vld |-> (mmu_lsu_tlb_wakeup == 12'hfff));

  a_no_install_on_fault_refill_only: assert property (@(posedge install_clk) disable iff (!cpurst_b)
    (!(|mb_entry_wfi)
     && ((ptw_l1dtlb_ref_cmplt && (ptw_l1tlb_pgflt || ptw_l1tlb_acc_err))
      || (jtlb_dutlb_ref_cmplt && jtlb_dutlb_pgflt))
     && !(ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt
          && mb_entry_vld[ptw_l1dtlb_ref_id]
          && mb_entry_state[ptw_l1dtlb_ref_id] == STATE_WFC
          && !(ptw_l1tlb_pgflt || ptw_l1tlb_acc_err))
     && !(jtlb_dutlb_ref_pavld && jtlb_dutlb_ref_cmplt
          && mb_entry_vld[jtlb_dutlb_ref_id]
          && mb_entry_state[jtlb_dutlb_ref_id] == STATE_WFC
          && !jtlb_dutlb_pgflt))
    |-> !utlb_refill_vld);

  a_grant_bus_onehot0: assert property (@(posedge install_clk) disable iff (!cpurst_b)
    $onehot0(mb_refill_gnt_bus));

  a_plru_way_onehot_on_refill: assert property (@(posedge install_clk) disable iff (!cpurst_b)
    utlb_refill_vld |-> (plru_refill_updt && $onehot(plru_refill_way)));

  a_wfi_priority_over_ptw_l2: assert property (@(posedge install_clk) disable iff (!cpurst_b)
    (|mb_entry_wfi) |-> (utlb_refill_vld
                      && mb_refill_gnt_bus[wfi_id]
                      && utlb_refill_vpn == mb_entry_vpn[wfi_id]
                      && utlb_refill_ppn == mb_entry_ppn[wfi_id]
                      && utlb_refill_flg == mb_entry_flg[wfi_id]
                      && utlb_refill_pgs == mb_entry_pgs[wfi_id]));

  a_ptw_priority_over_l2: assert property (@(posedge install_clk) disable iff (!cpurst_b)
    (!(|mb_entry_wfi)
     && ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt
     && mb_entry_vld[ptw_l1dtlb_ref_id]
     && mb_entry_state[ptw_l1dtlb_ref_id] == STATE_WFC
     && !(ptw_l1tlb_pgflt || ptw_l1tlb_acc_err)
     && jtlb_dutlb_ref_pavld && jtlb_dutlb_ref_cmplt
     && mb_entry_vld[jtlb_dutlb_ref_id]
     && mb_entry_state[jtlb_dutlb_ref_id] == STATE_WFC
     && !jtlb_dutlb_pgflt)
    |-> (utlb_refill_vld
      && mb_refill_gnt_bus[ptw_l1dtlb_ref_id]
      && utlb_refill_vpn == ptw_l1tlb_ref_vpn
      && utlb_refill_ppn == ptw_l1tlb_ref_ppn
      && utlb_refill_flg == ptw_l1tlb_ref_flg
      && utlb_refill_pgs == ptw_l1dtlb_ref_pgs));

  a_l2_selected_when_no_wfi_ptw: assert property (@(posedge install_clk) disable iff (!cpurst_b)
    (!(|mb_entry_wfi)
     && !(ptw_l1dtlb_ref_pavld && ptw_l1dtlb_ref_cmplt
          && mb_entry_vld[ptw_l1dtlb_ref_id]
          && mb_entry_state[ptw_l1dtlb_ref_id] == STATE_WFC
          && !(ptw_l1tlb_pgflt || ptw_l1tlb_acc_err))
     && jtlb_dutlb_ref_pavld && jtlb_dutlb_ref_cmplt
     && mb_entry_vld[jtlb_dutlb_ref_id]
     && mb_entry_state[jtlb_dutlb_ref_id] == STATE_WFC
     && !jtlb_dutlb_pgflt)
    |-> (utlb_refill_vld
      && mb_refill_gnt_bus[jtlb_dutlb_ref_id]
      && utlb_refill_vpn == jtlb_utlb_ref_vpn
      && utlb_refill_ppn == jtlb_utlb_ref_ppn
      && utlb_refill_flg == jtlb_utlb_ref_flg
      && utlb_refill_pgs == l2tlb_l1dtlb_ref_pgs));

  a_install_payload_known_legal: assert property (@(posedge install_clk) disable iff (!cpurst_b)
    utlb_refill_vld |-> (!$isunknown(utlb_refill_idx)
                      && !$isunknown(utlb_refill_vpn)
                      && !$isunknown(utlb_refill_ppn)
                      && !$isunknown(utlb_refill_flg)
                      && !$isunknown(utlb_refill_pgs)
                      && legal_pgs(utlb_refill_pgs)));

  cp_l1dtlb_c015_wfi_priority: cover property (@(posedge install_clk) disable iff (!cpurst_b)
    (|mb_entry_wfi) && utlb_refill_vld);

  cp_l1dtlb_c015_ptw_l2_collision: cover property (@(posedge install_clk) disable iff (!cpurst_b)
    ptw_l1dtlb_ref_cmplt && jtlb_dutlb_ref_cmplt && utlb_refill_vld);

  cp_l1dtlb_c018_install_release: cover property (@(posedge install_clk) disable iff (!cpurst_b)
    utlb_refill_vld && (|mb_refill_gnt_bus));

endmodule

module mmu_l1dtlb_expt_cam_sva #(
    parameter int CAM_DEPTH = 8,
    parameter int IID_WIDTH = 7,
    parameter int VPN_WIDTH = 27
) (
    input logic clk,
    input logic rst_b,
    input logic rtu_yy_xx_flush,
    input logic expt_wr0_vld,
    input logic [$clog2(CAM_DEPTH)-1:0] expt_wr0_eid,
    input logic [IID_WIDTH-1:0] expt_wr0_iid,
    input logic [VPN_WIDTH-1:0] expt_wr0_vpn,
    input logic expt_wr0_pgflt,
    input logic expt_wr0_acflt,
    input logic expt_wr1_vld,
    input logic [$clog2(CAM_DEPTH)-1:0] expt_wr1_eid,
    input logic [IID_WIDTH-1:0] expt_wr1_iid,
    input logic [VPN_WIDTH-1:0] expt_wr1_vpn,
    input logic expt_wr1_pgflt,
    input logic expt_wr1_acflt,
    input logic lsu_mmu_va0_vld,
    input logic lsu_mmu_abort0,
    input logic [IID_WIDTH-1:0] lsu_mmu_id0,
    input logic [VPN_WIDTH-1:0] lsu_mmu_vpn0,
    input logic lsu_mmu_va1_vld,
    input logic lsu_mmu_abort1,
    input logic [IID_WIDTH-1:0] lsu_mmu_id1,
    input logic [VPN_WIDTH-1:0] lsu_mmu_vpn1,
    input logic expt_match0,
    input logic expt_pgflt0,
    input logic expt_acflt0,
    input logic expt_match1,
    input logic expt_pgflt1,
    input logic expt_acflt1,
    input logic [CAM_DEPTH-1:0] expt_hit_vec
);

  // A009/A014/A027/A052/A056/A057/A058/A060: exception CAM contract.
  a_expt_write0_fault_exclusive: assert property (@(posedge clk) disable iff (!rst_b)
    expt_wr0_vld |-> !(expt_wr0_pgflt && expt_wr0_acflt));

  a_expt_write1_fault_exclusive: assert property (@(posedge clk) disable iff (!rst_b)
    expt_wr1_vld |-> !(expt_wr1_pgflt && expt_wr1_acflt));

  a_expt_write_payload_known: assert property (@(posedge clk) disable iff (!rst_b)
    (expt_wr0_vld || expt_wr1_vld) |-> (!$isunknown({expt_wr0_vld, expt_wr1_vld})
                                      && (!$isunknown({expt_wr0_eid, expt_wr0_iid, expt_wr0_vpn})
                                          || !expt_wr0_vld)
                                      && (!$isunknown({expt_wr1_eid, expt_wr1_iid, expt_wr1_vpn})
                                          || !expt_wr1_vld)));

  a_no_dual_write_same_eid: assert property (@(posedge clk) disable iff (!rst_b)
    (expt_wr0_vld && expt_wr1_vld) |-> (expt_wr0_eid != expt_wr1_eid));

  // Dual LSU ports may replay two independent exception entries in the same
  // cycle.  The spec scoreboard enforces the same two-entry upper bound.
  a_expt_consume_at_most_two_entries: assert property (@(posedge clk) disable iff (!rst_b)
    !$isunknown(expt_hit_vec) |-> ($countones(expt_hit_vec) <= 2));

  a_abort_does_not_consume0: assert property (@(posedge clk) disable iff (!rst_b)
    (lsu_mmu_va0_vld && lsu_mmu_abort0) |-> !expt_match0);

  a_abort_does_not_consume1: assert property (@(posedge clk) disable iff (!rst_b)
    (lsu_mmu_va1_vld && lsu_mmu_abort1) |-> !expt_match1);

  a_match0_has_fault_class: assert property (@(posedge clk) disable iff (!rst_b)
    expt_match0 |-> (expt_pgflt0 ^ expt_acflt0));

  a_match1_has_fault_class: assert property (@(posedge clk) disable iff (!rst_b)
    expt_match1 |-> (expt_pgflt1 ^ expt_acflt1));

  a_match0_key_uses_iid_vpn: assert property (@(posedge clk) disable iff (!rst_b)
    expt_match0 |-> (lsu_mmu_va0_vld && !$isunknown({lsu_mmu_id0, lsu_mmu_vpn0})));

  a_match1_key_uses_iid_vpn: assert property (@(posedge clk) disable iff (!rst_b)
    expt_match1 |-> (lsu_mmu_va1_vld && !$isunknown({lsu_mmu_id1, lsu_mmu_vpn1})));

  cp_l1dtlb_c016_dual_expt_write: cover property (@(posedge clk) disable iff (!rst_b)
    expt_wr0_vld && expt_wr1_vld);

  cp_l1dtlb_c019_expt_page_replay: cover property (@(posedge clk) disable iff (!rst_b)
    (expt_match0 && expt_pgflt0) || (expt_match1 && expt_pgflt1));

  cp_l1dtlb_c019_expt_access_replay: cover property (@(posedge clk) disable iff (!rst_b)
    (expt_match0 && expt_acflt0) || (expt_match1 && expt_acflt1));

endmodule

module mmu_l1dtlb_hit_rd_sva #(
    parameter int VPN_WIDTH = 27,
    parameter int PPN_WIDTH = 28,
    parameter int FLG_WIDTH = 14,
    parameter int NUM_ENTRY = 16
) (
    input logic cpurst_b,
    input logic dutlb_clk,
    input logic cp0_mach_mode,
    input logic cp0_mmu_mxr,
    input logic cp0_mmu_sum,
    input logic cp0_supv_mode,
    input logic cp0_user_mode,
    input logic [NUM_ENTRY-1:0] entry_vld_vec,
    input logic [NUM_ENTRY*FLG_WIDTH-1:0] entry_flg_vec,
    input logic [NUM_ENTRY-1:0] entry_hit_vec,
    input logic [NUM_ENTRY*PPN_WIDTH-1:0] entry_ppn_vec,
    input logic expt_match_x,
    input logic expt_pgflt_x,
    input logic expt_acflt_x,
    input logic dutlb_off_hit,
    input logic dutlb_ori_read_x,
    input logic dutlb_read_type_x,
    input logic lsu_mmu_va_vld_x,
    input logic [6:0] lsu_mmu_id_x,
    input logic [63:0] lsu_mmu_va_x,
    input logic [27:0] lsu_mmu_vabuf_x,
    input logic lsu_mmu_abort_x,
    input logic lsu_mmu_stamo_vld_x,
    input logic [27:0] lsu_mmu_stamo_pa_x,
    input logic mmu_lsu_pa_vld_x,
    input logic [27:0] mmu_lsu_pa_x,
    input logic mmu_lsu_buf_x,
    input logic mmu_lsu_ca_x,
    input logic mmu_lsu_sh_x,
    input logic mmu_lsu_so_x,
    input logic mmu_lsu_stall_x,
    input logic mmu_lsu_sec_x,
    input logic mmu_lsu_access_fault_x,
    input logic mmu_lsu_page_fault_x,
    input logic dutlb_acc_flt_x,
    input logic dutlb_miss_vld_short_x,
    input logic dutlb_miss_vld_x,
    input logic dutlb_plru_read_hit_vld_x,
    input logic [NUM_ENTRY-1:0] dutlb_plru_read_hit_x,
    input logic dutlb_va_chg_x,
    input logic [27:0] mmu_pmp_pa_x,
    input logic [27:0] mmu_sysmap_pa_x,
    input logic [VPN_WIDTH-1:0] utlb_req_vpn_x
);

  // A004/A011/A012/A014/A015/A019/A031-A035/A059/A068/A069.
  a_hit_response_t0: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    (lsu_mmu_va_vld_x && (|entry_hit_vec) && !mmu_lsu_page_fault_x)
    |-> mmu_lsu_pa_vld_x);

  a_page_fault_has_pa_vld: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    mmu_lsu_page_fault_x |-> mmu_lsu_pa_vld_x);

  a_direct_map_terminal_response: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    (lsu_mmu_va_vld_x && dutlb_off_hit && !lsu_mmu_abort_x)
    |-> (mmu_lsu_pa_vld_x && !dutlb_miss_vld_x && !dutlb_miss_vld_short_x));

  a_expt_replay_not_new_miss: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    (lsu_mmu_va_vld_x && expt_match_x) |-> (!dutlb_miss_vld_x && !dutlb_miss_vld_short_x));

  a_expt_replay_has_fault_class: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    (lsu_mmu_va_vld_x && expt_match_x) |-> (expt_pgflt_x ^ expt_acflt_x));

  // RTL gives exception-CAM replay priority via dutlb_pre_sel.  A replay may
  // coincide with a stale/independent TLB entry hit for the same VPN; the
  // required behavior is that the request is completed as the replayed fault
  // and does not allocate a new miss or source stale entry PA.
  a_expt_entry_overlap_is_terminal_replay: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    (lsu_mmu_va_vld_x && (|entry_hit_vec) && expt_match_x)
    |-> (mmu_lsu_pa_vld_x && !dutlb_miss_vld_x && !dutlb_miss_vld_short_x
         && (mmu_lsu_pa_x == mmu_sysmap_pa_x)));

  cp_l1dtlb_expt_entry_overlap_replay: cover property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    lsu_mmu_va_vld_x && (|entry_hit_vec) && expt_match_x);

  a_abort_blocks_miss: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    (lsu_mmu_va_vld_x && lsu_mmu_abort_x) |-> !dutlb_miss_vld_x);

  // STAMO itself is not a DTLB miss source.  A concurrent VA retry on pipe1 can
  // still miss, so keep this assertion scoped to pure STAMO cycles.
  a_stamo_bypass_not_miss: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    (lsu_mmu_stamo_vld_x && !lsu_mmu_va_vld_x)
    |-> (!dutlb_miss_vld_x && !dutlb_miss_vld_short_x));

  // RTL (mmu_l1dtlb_hit_rd.sv:267): dutlb_stamo_pre_sel = lsu_mmu_stamo_vld_x & !dutlb_expt_match.
  // When expt_match=1, STAMO path is disabled and PA comes from exception handler.
  // Assertion must exclude expt_match case to avoid false failure.
  a_stamo_pa_source: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    (lsu_mmu_stamo_vld_x && mmu_lsu_pa_vld_x && !expt_match_x) |-> (mmu_lsu_pa_x == lsu_mmu_stamo_pa_x));

  a_access_fault_known_payload: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    mmu_lsu_access_fault_x |-> !$isunknown({mmu_lsu_pa_x, mmu_pmp_pa_x}));

  a_plru_hit_sample_known: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    dutlb_plru_read_hit_vld_x |-> !$isunknown(dutlb_plru_read_hit_x));

  a_valid_hit_only_from_valid_entry: assert property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    (entry_hit_vec & ~entry_vld_vec) == '0);

  cp_l1dtlb_c002_single_hit: cover property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    lsu_mmu_va_vld_x && (|entry_hit_vec));

  cp_l1dtlb_c010_page_fault: cover property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    mmu_lsu_page_fault_x);

  cp_l1dtlb_c011_direct_map: cover property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    lsu_mmu_va_vld_x && dutlb_off_hit && mmu_lsu_pa_vld_x);

  cp_l1dtlb_c012_stamo_bypass: cover property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    lsu_mmu_stamo_vld_x && mmu_lsu_pa_vld_x);

  cp_l1dtlb_c012_stamo_pipe_negative: cover property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    !lsu_mmu_stamo_vld_x && lsu_mmu_va_vld_x && (|entry_hit_vec) && mmu_lsu_pa_vld_x);

  cp_l1dtlb_c021_access_fault: cover property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    mmu_lsu_access_fault_x);

  cp_l1dtlb_c026_vabuf_changes: cover property (@(posedge dutlb_clk) disable iff (!cpurst_b)
    lsu_mmu_va_vld_x && $changed(lsu_mmu_vabuf_x));

endmodule
