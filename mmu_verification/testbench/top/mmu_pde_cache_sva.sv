// =============================================================================
// PTW PDE cache SVA - Stage 6
// Bind target: PDE_cache
// =============================================================================
`timescale 1ns/1ps

module mmu_pde_cache_sva #(
    parameter int VPN_WIDTH        = 27,
    parameter int PPN_WIDTH        = 28,
    parameter int PTE_LEVEL        = 3,
    parameter int ID_WIDTH         = 7,
    parameter int TYPE_WIDTH       = 3,
    parameter int L1PDE_ENTRY_NUM  = 8,
    parameter int L2PDE_ENTRY_NUM  = 16
) (
    input logic                                      pde_cache_clk,
    input logic                                      cpurst_b,
    input logic                                      regs_ptw_clr,
    input logic                                      tlboper_ptw_abort,
    input logic                                      ptw_abort_drain,
    input logic                                      ptw_lsu_bus_error_rsp,
    input logic                                      ptw_writeback_req_any,
    input logic                                      ptw_writeback_grant_any,
    input logic                                      pmp_regs_update,
    input logic                                      pde_cache_clear,
    input logic                                      xbar_pde_ready,
    input logic                                      pde_cache_ready,
    input logic                                      mbuf_cache_upd,
    input logic [PTE_LEVEL-2:0]                      mbuf_cache_upd_lvl,
    input logic [PPN_WIDTH-1:0]                      mbuf_cache_upd_ppn,
    input logic [VPN_WIDTH-1:0]                      mbuf_cache_upd_vpn,
    input logic [3:0]                                mbuf_cache_upd_l1pmpflg,
    input logic [3:0]                                mbuf_cache_upd_l2pmpflg,
    input logic [1:0]                                cp0_yy_priv_mode,
    input logic [1:0]                                cp0_priv_mode,
    input logic                                      ptw_req,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_upd,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_upd,
    input logic [L1PDE_ENTRY_NUM-1:0]                plru_L1PDE_ref_num,
    input logic [L2PDE_ENTRY_NUM-1:0]                plru_L2PDE_ref_num,
    input logic                                      L1PDE_plru_refill_vld,
    input logic                                      L2PDE_plru_refill_vld,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_vld,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_vld,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_hit_idx,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_hit_idx,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_tag_hit,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_tag_hit,
    input logic [L1PDE_ENTRY_NUM-1:0][3:0]           L1PDE_l1pmpflg,
    input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l1pmpflg,
    input logic [L2PDE_ENTRY_NUM-1:0][3:0]           L2PDE_l2pmpflg,
    input logic [L1PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L1PDE_entry_ppn,
    input logic [L2PDE_ENTRY_NUM-1:0][PPN_WIDTH-1:0] L2PDE_entry_ppn,
    input logic [L1PDE_ENTRY_NUM-1:0]                L1PDE_entry_before_upd_hit,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_before_upd_hit,
    input logic                                      L1PDE_entry_hit_vld,
    input logic                                      L2PDE_entry_hit_vld,
    input logic [PPN_WIDTH-1:0]                      L1PDE_cache_hit_ppn,
    input logic [PPN_WIDTH-1:0]                      L2PDE_cache_hit_ppn,
    input logic [PPN_WIDTH-1:0]                      PDE_cache_fin_ppn,
    input logic                                      L1PDE_plru_read_hit_vld,
    input logic                                      L2PDE_plru_read_hit_vld,
    input logic [L2PDE_ENTRY_NUM-1:0]                L2PDE_entry_acc_err,
    input logic                                      L2PDE_xbar_hit_vld,
    input logic                                      L1PDE_xbar_hit_vld,
    input logic [PPN_WIDTH-1:0]                      PDE_xbar_ppn,
    input logic [VPN_WIDTH-1:0]                      PDE_xbar_vpn,
    input logic [TYPE_WIDTH-1:0]                     PDE_xbar_type,
    input logic [ID_WIDTH-1:0]                       PDE_xbar_id,
    input logic                                      PDE_xbar_req,
    input logic                                      PDE_cache_acc_err_vld,
    input logic [TYPE_WIDTH-1:0]                     PDE_cache_acc_err_type,
    input logic [ID_WIDTH-1:0]                       PDE_cache_acc_err_id,
    input logic                                      PDE_cache_acc_err_grant,
    input logic [VPN_WIDTH-1:0]                      ptw_vpn,
    input logic [TYPE_WIDTH-1:0]                     ptw_type,
    input logic [ID_WIDTH-1:0]                       ptw_id
);

  localparam logic [2:0] PTW_TYPE_LOAD  = 3'b010;
  localparam logic [2:0] PTW_TYPE_FETCH = 3'b011;
  localparam logic [2:0] PTW_TYPE_PREF  = 3'b100;
  localparam logic [2:0] PTW_TYPE_STORE = 3'b110;

  int unsigned cp_pde_clear_hits;
  int unsigned cp_pde_abort_update_clear_hits;
  int unsigned cp_pde_double_hit_l2_wins_hits;
  int unsigned cp_pde_hit_level_hits;
  int unsigned cp_pde_ppn_match_hits;
  int unsigned cp_pde_update_level_hits;
  int unsigned cp_pde_old_state_lookup_hits;
  int unsigned cp_pde_ready_hits;
  int unsigned cp_pde_l1_pmp_hit_hits;
  int unsigned cp_pde_l2_pmp_hit_hits;
  int unsigned cp_pde_l2_deny_direct_accerr_hits;
  int unsigned cp_pde_accerr_valid_gate_hits;
  int unsigned cp_pde_update_pmpflg_hits;
  int unsigned cp_pde_tag_deny_no_plru_hits;
  int unsigned cp_pde_accerr_pending_hits;
  int unsigned cp_pde_consecutive_refill_hits;
  int unsigned cp_pde_l1_consecutive_advance_hits;
  int unsigned cp_pde_l2_consecutive_advance_hits;
  int unsigned cp_pde_l1_plru_refill_hits;
  int unsigned cp_pde_l2_plru_refill_hits;
  int unsigned cp_pde_update_mutual_exclusive_hits;
  int unsigned cp_pde_abort_drain_no_update_hits;
  int unsigned cp_pde_bus_error_no_update_hits;

  logic pde_past_valid;
  logic [L1PDE_ENTRY_NUM-1:0] l1_allow_vec;
  logic [L1PDE_ENTRY_NUM-1:0] l1_expected_hit_vec;
  logic [L1PDE_ENTRY_NUM-1:0] l1_deny_vec;
  logic [L2PDE_ENTRY_NUM-1:0] l2_l1_allow_vec;
  logic [L2PDE_ENTRY_NUM-1:0] l2_l2_allow_vec;
  logic [L2PDE_ENTRY_NUM-1:0] l2_expected_hit_vec;
  logic [L2PDE_ENTRY_NUM-1:0] l2_deny_vec;

  function automatic logic pde_pmp_type_allow(
    input logic [TYPE_WIDTH-1:0] req_type,
    input logic [3:0]            pmpflg
  );
    case (req_type)
      PTW_TYPE_LOAD,
      PTW_TYPE_PREF:  pde_pmp_type_allow = pmpflg[0];
      PTW_TYPE_STORE: pde_pmp_type_allow = pmpflg[1];
      PTW_TYPE_FETCH: pde_pmp_type_allow = pmpflg[2];
      default:        pde_pmp_type_allow = 1'b0;
    endcase
  endfunction

  function automatic logic pde_effective_m(
    input logic [TYPE_WIDTH-1:0] req_type
  );
    pde_effective_m = (req_type == PTW_TYPE_FETCH)
                    ? (cp0_yy_priv_mode == 2'b11)
                    : (cp0_priv_mode == 2'b11);
  endfunction

  function automatic logic pde_pmp_allow(
    input logic [TYPE_WIDTH-1:0] req_type,
    input logic [3:0]            pmpflg
  );
    pde_pmp_allow = pde_pmp_type_allow(req_type, pmpflg)
                 || (pde_effective_m(req_type) && !pmpflg[3]);
  endfunction

  always_comb begin
    for (int i = 0; i < L1PDE_ENTRY_NUM; i++) begin
      l1_allow_vec[i] = pde_pmp_allow(ptw_type, L1PDE_l1pmpflg[i]);
      l1_expected_hit_vec[i] = L1PDE_entry_vld[i] && L1PDE_tag_hit[i] && l1_allow_vec[i];
      l1_deny_vec[i] = L1PDE_entry_vld[i] && L1PDE_tag_hit[i] && !l1_allow_vec[i];
    end

    for (int i = 0; i < L2PDE_ENTRY_NUM; i++) begin
      l2_l1_allow_vec[i] = pde_pmp_allow(ptw_type, L2PDE_l1pmpflg[i]);
      l2_l2_allow_vec[i] = pde_pmp_allow(ptw_type, L2PDE_l2pmpflg[i]);
      l2_expected_hit_vec[i] = L2PDE_entry_vld[i] && L2PDE_tag_hit[i]
                            && l2_l1_allow_vec[i] && l2_l2_allow_vec[i];
      l2_deny_vec[i] = L2PDE_entry_vld[i] && L2PDE_tag_hit[i]
                    && !(l2_l1_allow_vec[i] && l2_l2_allow_vec[i]);
    end
  end

  always_ff @(posedge pde_cache_clk or negedge cpurst_b) begin
    if (!cpurst_b)
      pde_past_valid <= 1'b0;
    else
      pde_past_valid <= 1'b1;
  end

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

  // PTW-SVA-PDE-003/004/005: L2 wins on permission-qualified double hit and hit-level output is encoded.
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

  a_pde_hit_level_uses_qualified_hits: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (L1PDE_entry_hit_idx == l1_expected_hit_vec)
    && (L2PDE_entry_hit_idx == l2_expected_hit_vec)
    && (L1PDE_entry_hit_vld == (|l1_expected_hit_vec))
    && (L2PDE_entry_hit_vld == (|l2_expected_hit_vec)));

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

  // PTW-SVA-PDE-UPD-020/024: back-to-back refill updates remain known, onehot, and single-level.
  a_pde_consecutive_refill_update_onehot_known: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || !pde_past_valid)
    mbuf_cache_upd && $past(mbuf_cache_upd) && (L1PDE_plru_refill_vld || L2PDE_plru_refill_vld)
    |-> (!$isunknown({L1PDE_entry_upd, L2PDE_entry_upd})
      && $onehot({L1PDE_entry_upd, L2PDE_entry_upd})));

  a_pde_update_vectors_mutually_exclusive_phase9: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    mbuf_cache_upd |-> !(|L1PDE_entry_upd && |L2PDE_entry_upd));

  cp_pde_consecutive_refill: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || !pde_past_valid)
    mbuf_cache_upd && $past(mbuf_cache_upd) && (L1PDE_plru_refill_vld || L2PDE_plru_refill_vld)) begin
    cp_pde_consecutive_refill_hits++;
  end

  cp_pde_update_mutual_exclusive: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    mbuf_cache_upd && !(|L1PDE_entry_upd && |L2PDE_entry_upd)
    && ((|L1PDE_entry_upd) || (|L2PDE_entry_upd))) begin
    cp_pde_update_mutual_exclusive_hits++;
  end

  // PTW-SVA-PDE-UPD-021: while invalid ways remain, consecutive refill cannot reuse the previous way.
  a_pde_l1_consecutive_refill_no_reuse_when_invalid: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || !pde_past_valid)
    mbuf_cache_upd && L1PDE_plru_refill_vld && !(&L1PDE_entry_vld)
    && $past(mbuf_cache_upd && L1PDE_plru_refill_vld && !(&L1PDE_entry_vld))
    |-> ((L1PDE_entry_upd & $past(L1PDE_entry_upd)) == '0));

  a_pde_l2_consecutive_refill_no_reuse_when_invalid: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || !pde_past_valid)
    mbuf_cache_upd && L2PDE_plru_refill_vld && !(&L2PDE_entry_vld)
    && $past(mbuf_cache_upd && L2PDE_plru_refill_vld && !(&L2PDE_entry_vld))
    |-> ((L2PDE_entry_upd & $past(L2PDE_entry_upd)) == '0));

  cp_pde_l1_consecutive_advance: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || !pde_past_valid)
    mbuf_cache_upd && L1PDE_plru_refill_vld && !(&L1PDE_entry_vld)
    && $past(mbuf_cache_upd && L1PDE_plru_refill_vld && !(&L1PDE_entry_vld))
    && ((L1PDE_entry_upd & $past(L1PDE_entry_upd)) == '0)) begin
    cp_pde_l1_consecutive_advance_hits++;
  end

  cp_pde_l2_consecutive_advance: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || !pde_past_valid)
    mbuf_cache_upd && L2PDE_plru_refill_vld && !(&L2PDE_entry_vld)
    && $past(mbuf_cache_upd && L2PDE_plru_refill_vld && !(&L2PDE_entry_vld))
    && ((L2PDE_entry_upd & $past(L2PDE_entry_upd)) == '0)) begin
    cp_pde_l2_consecutive_advance_hits++;
  end

  // PTW-SVA-PDE-UPD-022/023: entry write enables use the same-cycle PLRU refill vector.
  a_pde_l1_entry_upd_matches_plru_refill: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L1PDE_entry_upd == (plru_L1PDE_ref_num & {L1PDE_ENTRY_NUM{L1PDE_plru_refill_vld}}));

  a_pde_l2_entry_upd_matches_plru_refill: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L2PDE_entry_upd == (plru_L2PDE_ref_num & {L2PDE_ENTRY_NUM{L2PDE_plru_refill_vld}}));

  a_pde_l1_refill_vec_known_onehot: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L1PDE_plru_refill_vld |-> (!$isunknown(plru_L1PDE_ref_num) && $onehot(plru_L1PDE_ref_num)
                            && $onehot(L1PDE_entry_upd)));

  a_pde_l2_refill_vec_known_onehot: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L2PDE_plru_refill_vld |-> (!$isunknown(plru_L2PDE_ref_num) && $onehot(plru_L2PDE_ref_num)
                            && $onehot(L2PDE_entry_upd)));

  cp_pde_l1_plru_refill: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L1PDE_plru_refill_vld && (L1PDE_entry_upd == plru_L1PDE_ref_num)) begin
    cp_pde_l1_plru_refill_hits++;
  end

  cp_pde_l2_plru_refill: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L2PDE_plru_refill_vld && (L2PDE_entry_upd == plru_L2PDE_ref_num)) begin
    cp_pde_l2_plru_refill_hits++;
  end

  // PTW-SVA-PDE-UPD-025/026: abort drain and isolated bus-error responses must
  // not create PDE cache refill updates.
  a_pde_abort_drain_no_cache_update_phase9: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    ptw_abort_drain |-> !mbuf_cache_upd);

  a_pde_bus_error_no_cache_update_same_cycle: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || !pde_past_valid)
    ptw_lsu_bus_error_rsp
    && !ptw_writeback_req_any
    && !ptw_writeback_grant_any
    && !$past(ptw_writeback_grant_any)
    |-> !mbuf_cache_upd);

  a_pde_bus_error_no_cache_update_next_cycle: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || !pde_past_valid)
    ptw_lsu_bus_error_rsp
    && !ptw_writeback_req_any
    && !ptw_writeback_grant_any
    |=> !mbuf_cache_upd);

  cp_pde_abort_drain_no_update: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    ptw_abort_drain && !mbuf_cache_upd) begin
    cp_pde_abort_drain_no_update_hits++;
  end

  cp_pde_bus_error_no_update: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || !pde_past_valid)
    ptw_lsu_bus_error_rsp
    && !ptw_writeback_req_any
    && !ptw_writeback_grant_any
    && !$past(ptw_writeback_grant_any)
    && !mbuf_cache_upd
    ##1 !mbuf_cache_upd) begin
    cp_pde_bus_error_no_update_hits++;
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

  // PTW-SVA-PDE-011: L1 hit is permission-qualified; tag hit deny is a miss.
  a_pde_l1_hit_iff_valid_tag_allow: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L1PDE_entry_hit_idx == l1_expected_hit_vec);

  a_pde_l1_tag_deny_not_hit: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (l1_deny_vec & L1PDE_entry_hit_idx) == '0);

  cp_pde_l1_pmp_hit: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (|l1_expected_hit_vec) || (|l1_deny_vec)) begin
    cp_pde_l1_pmp_hit_hits++;
  end

  // PTW-SVA-PDE-012: L2 hit is permission-qualified by both cached PMP flags.
  a_pde_l2_hit_iff_valid_tag_allow: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L2PDE_entry_hit_idx == l2_expected_hit_vec);

  cp_pde_l2_pmp_hit: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (|l2_expected_hit_vec) || (|l2_deny_vec)) begin
    cp_pde_l2_pmp_hit_hits++;
  end

  // PTW-SVA-PDE-013/014: L2 tag hit deny suppresses xbar request and creates direct accerr.
  // Hit sidebands may still reflect combinational cache lookup state while the
  // request valid is blocked by direct accerr arbitration.
  a_pde_l2_tag_deny_no_xbar_req: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    ptw_req && (|l2_deny_vec) |-> !PDE_xbar_req);

  a_pde_l2_tag_deny_direct_accerr: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    ptw_req && (|l2_deny_vec)
    |=> (PDE_cache_acc_err_vld
      && (PDE_cache_acc_err_type == $past(ptw_type))
      && (PDE_cache_acc_err_id == $past(ptw_id))));

  a_pde_direct_accerr_valid_gate: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L2PDE_entry_acc_err == ({L2PDE_ENTRY_NUM{ptw_req}} & l2_deny_vec));

  a_pde_direct_accerr_rise_from_valid_lookup: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (PDE_cache_acc_err_vld && !$past(PDE_cache_acc_err_vld))
    |-> $past(ptw_req && (|l2_deny_vec)));

  cp_pde_l2_deny_direct_accerr: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    ptw_req && (|l2_deny_vec) ##1 PDE_cache_acc_err_vld) begin
    cp_pde_l2_deny_direct_accerr_hits++;
  end

  cp_pde_accerr_valid_gate: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    L2PDE_entry_acc_err != '0) begin
    cp_pde_accerr_valid_gate_hits++;
  end

  // PTW-SVA-PDE-015: update payload carries L1/L2 page-table PMP evidence.
  a_pde_fst_update_payload_l2_zero: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    mbuf_cache_upd && mbuf_cache_upd_lvl[1] |-> (mbuf_cache_upd_l2pmpflg == 4'h0));

  a_pde_thd_update_does_not_allocate: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    mbuf_cache_upd && (mbuf_cache_upd_lvl == '0) |-> (!(|L1PDE_entry_upd) && !(|L2PDE_entry_upd)));

  generate
    for (genvar l1_i = 0; l1_i < L1PDE_ENTRY_NUM; l1_i++) begin : gen_l1_update_pmp_sva
      a_pde_l1_update_saves_l1pmpflg: assert property (@(posedge pde_cache_clk)
        disable iff (!cpurst_b)
        L1PDE_entry_upd[l1_i] |=> (L1PDE_l1pmpflg[l1_i] == $past(mbuf_cache_upd_l1pmpflg)));
    end

    for (genvar l2_i = 0; l2_i < L2PDE_ENTRY_NUM; l2_i++) begin : gen_l2_update_pmp_sva
      a_pde_l2_update_saves_l1pmpflg: assert property (@(posedge pde_cache_clk)
        disable iff (!cpurst_b)
        L2PDE_entry_upd[l2_i] |=> (L2PDE_l1pmpflg[l2_i] == $past(mbuf_cache_upd_l1pmpflg)));

      a_pde_l2_update_saves_l2pmpflg: assert property (@(posedge pde_cache_clk)
        disable iff (!cpurst_b)
        L2PDE_entry_upd[l2_i] |=> (L2PDE_l2pmpflg[l2_i] == $past(mbuf_cache_upd_l2pmpflg)));
    end
  endgenerate

  cp_pde_update_pmpflg: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    mbuf_cache_upd && (mbuf_cache_upd_lvl[1] || mbuf_cache_upd_lvl[0] || (mbuf_cache_upd_lvl == '0))) begin
    cp_pde_update_pmpflg_hits++;
  end

  // PTW-SVA-PDE-016: tag-hit deny must not update PLRU/read-hit state.
  a_pde_plru_uses_qualified_hit: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (L1PDE_plru_read_hit_vld == (|l1_expected_hit_vec))
    && (L2PDE_plru_read_hit_vld == (|l2_expected_hit_vec)));

  a_pde_tag_deny_no_plru_read_hit: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (((|l1_deny_vec) && !(|l1_expected_hit_vec)) |-> !L1PDE_plru_read_hit_vld)
    and (((|l2_deny_vec) && !(|l2_expected_hit_vec)) |-> !L2PDE_plru_read_hit_vld));

  cp_pde_tag_deny_no_plru: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    (((|l1_deny_vec) && !L1PDE_plru_read_hit_vld)
     || ((|l2_deny_vec) && !L2PDE_plru_read_hit_vld))) begin
    cp_pde_tag_deny_no_plru_hits++;
  end

  // PTW-SVA-PDE-017: direct accerr pending payload is stable until grant and clears after grant.
  a_pde_accerr_pending_type_id_stable: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    PDE_cache_acc_err_vld && !PDE_cache_acc_err_grant
    |=> (PDE_cache_acc_err_vld
      && $stable(PDE_cache_acc_err_type)
      && $stable(PDE_cache_acc_err_id)));

  a_pde_accerr_grant_clears_pending: assert property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    PDE_cache_acc_err_vld && PDE_cache_acc_err_grant && !(|L2PDE_entry_acc_err)
    |=> !PDE_cache_acc_err_vld);

  cp_pde_accerr_pending: cover property (@(posedge pde_cache_clk)
    disable iff (!cpurst_b)
    PDE_cache_acc_err_vld && PDE_cache_acc_err_grant) begin
    cp_pde_accerr_pending_hits++;
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
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_l1_pmp_hit req=PTW-SVA-PDE-011 hits=%0d", cp_pde_l1_pmp_hit_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_l2_pmp_hit req=PTW-SVA-PDE-012 hits=%0d", cp_pde_l2_pmp_hit_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_l2_deny_direct_accerr req=PTW-SVA-PDE-013 hits=%0d", cp_pde_l2_deny_direct_accerr_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_accerr_valid_gate req=PTW-SVA-PDE-014 hits=%0d", cp_pde_accerr_valid_gate_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_update_pmpflg req=PTW-SVA-PDE-015 hits=%0d", cp_pde_update_pmpflg_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_tag_deny_no_plru req=PTW-SVA-PDE-016 hits=%0d", cp_pde_tag_deny_no_plru_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_accerr_pending req=PTW-SVA-PDE-017 hits=%0d", cp_pde_accerr_pending_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_consecutive_refill req=PTW-SVA-PDE-UPD-020 hits=%0d", cp_pde_consecutive_refill_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_l1_consecutive_advance req=PTW-SVA-PDE-UPD-021 hits=%0d", cp_pde_l1_consecutive_advance_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_l2_consecutive_advance req=PTW-SVA-PDE-UPD-021 hits=%0d", cp_pde_l2_consecutive_advance_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_l1_plru_refill req=PTW-SVA-PDE-UPD-022 hits=%0d", cp_pde_l1_plru_refill_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_l2_plru_refill req=PTW-SVA-PDE-UPD-023 hits=%0d", cp_pde_l2_plru_refill_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_update_mutual_exclusive req=PTW-SVA-PDE-UPD-024 hits=%0d", cp_pde_update_mutual_exclusive_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_abort_drain_no_update req=PTW-SVA-PDE-UPD-025 hits=%0d", cp_pde_abort_drain_no_update_hits);
    $display("PTW_SVA_COVER module=mmu_pde_cache_sva name=cp_pde_bus_error_no_update req=PTW-SVA-PDE-UPD-026 hits=%0d", cp_pde_bus_error_no_update_hits);
  end

endmodule
