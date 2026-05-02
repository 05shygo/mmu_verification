// =============================================================================
// PMP / TWU SVA - Phase 13
// Bind target: twu
// Focus: PMP serialization, deny handling, and PTW PMP port constraints.
// =============================================================================
`timescale 1ns/1ps

module mmu_pmp_twu_sva (
    input logic        twu_clk,
    input logic        cpurst_b,
    input logic        tlboper_ptw_abort,
    input logic        twu_mask,
    input logic        fst_pmp_wait,
    input logic        scd_pmp_wait,
    input logic        thd_pmp_wait,
    input logic        fst_pmp_vld,
    input logic        scd_pmp_vld,
    input logic        thd_pmp_vld,
    input logic        fst_pmp_grant,
    input logic        scd_pmp_grant,
    input logic        thd_pmp_grant,
    input logic        fst_pmp_deny,
    input logic        scd_pmp_deny,
    input logic        thd_pmp_deny,
    input logic        fst_pmp_mbuf_req,
    input logic        scd_pmp_mbuf_req,
    input logic        thd_pmp_mbuf_req,
    input logic [2:0]  pmp_grant,
    input logic [3:0]  pmp_mmu_flg,
    input logic        cp0_mmu_mprv,
    input logic [1:0]  cp0_mmu_mpp,
    input logic [1:0]  cp0_yy_priv_mode,
    input logic [2:0]  fst_pmp_type,
    input logic [2:0]  scd_pmp_type,
    input logic [2:0]  thd_pmp_type,
    input logic [5:0]  fst_pmp_id,
    input logic [5:0]  scd_pmp_id,
    input logic [5:0]  thd_pmp_id,
    input logic        mmu_pmp_fecth,
    input logic        twu_mbuf_req,
    input logic        twu_arb_ref_req,
    input logic [2:0]  twu_arb_ref_type,
    input logic [5:0]  twu_arb_ref_id,
    input logic        twu_l2tlb_ref_acc_err
);

  logic pmp_wait_any;
  logic pmp_deny_accept;
  logic pmp_wait_for_grant;
  logic pmp_allowed_grant;
  logic pmp_stage_mbuf_req;
  logic pmp_stage_wait_no_mbuf_req;
  logic pmp_deny_refill_same_txn;
  logic pmp_selected_stage_active;
  logic pmp_selected_deny;
  logic [2:0] pmp_selected_type;
  logic pmp_selected_fetch_type;
  logic pmp_selected_load_type;
  logic pmp_selected_store_type;
  logic pmp_selected_pref_type;
  logic pmp_selected_perm_deny;
  logic pmp_selected_mach_mode;
  logic pmp_selected_deny_expected;
  logic [1:0] pmp_effective_priv_mode;

  int unsigned cp_pmp_check_before_lsu_req_hits;
  int unsigned cp_pmp_wait_implies_mask_hits;
  int unsigned cp_pmp_deny_no_refill_hits;
  int unsigned cp_pmp_deny_acc_fault_hits;
  int unsigned cp_pmp_grant_onehot_hits;
  int unsigned cp_no_lsu_req_during_pmp_wait_hits;
  int unsigned cp_pmp_fetch_matches_grant_stage_hits;
  int unsigned cp_pmp_fetch_high_hits;
  int unsigned cp_pmp_fetch_uses_x_perm_hits;
  int unsigned cp_pmp_load_pref_uses_r_perm_hits;
  int unsigned cp_pmp_store_uses_w_perm_hits;
  int unsigned cp_pmp_mmode_l0_bypass_hits;
  int unsigned cp_pmp_deny_no_lsu_req_hits;

  localparam logic [2:0] TWU_REQ_TYPE_LOAD  = 3'b010;
  localparam logic [2:0] TWU_REQ_TYPE_FETCH = 3'b011;
  localparam logic [2:0] TWU_REQ_TYPE_PREF  = 3'b100;
  localparam logic [2:0] TWU_REQ_TYPE_STORE = 3'b110;

  assign pmp_wait_any = fst_pmp_wait || scd_pmp_wait || thd_pmp_wait;

  assign pmp_deny_accept =
      (fst_pmp_vld && fst_pmp_grant && fst_pmp_deny)
   || (scd_pmp_vld && scd_pmp_grant && scd_pmp_deny)
   || (thd_pmp_vld && thd_pmp_grant && thd_pmp_deny);

  assign pmp_wait_for_grant =
      (fst_pmp_vld && !fst_pmp_grant)
   || (scd_pmp_vld && !scd_pmp_grant)
   || (thd_pmp_vld && !thd_pmp_grant);

  assign pmp_allowed_grant =
      (fst_pmp_vld && fst_pmp_grant && !fst_pmp_deny)
   || (scd_pmp_vld && scd_pmp_grant && !scd_pmp_deny)
   || (thd_pmp_vld && thd_pmp_grant && !thd_pmp_deny);

  assign pmp_stage_mbuf_req = fst_pmp_mbuf_req || scd_pmp_mbuf_req || thd_pmp_mbuf_req;

  assign pmp_stage_wait_no_mbuf_req =
      (fst_pmp_vld && !fst_pmp_mbuf_req)
   || (scd_pmp_vld && !scd_pmp_mbuf_req)
   || (thd_pmp_vld && !thd_pmp_mbuf_req);

  assign pmp_deny_refill_same_txn =
      (fst_pmp_vld && fst_pmp_deny && twu_arb_ref_req
       && (twu_arb_ref_type == fst_pmp_type) && (twu_arb_ref_id == fst_pmp_id))
   || (scd_pmp_vld && scd_pmp_deny && twu_arb_ref_req
       && (twu_arb_ref_type == scd_pmp_type) && (twu_arb_ref_id == scd_pmp_id))
   || (thd_pmp_vld && thd_pmp_deny && twu_arb_ref_req
       && (twu_arb_ref_type == thd_pmp_type) && (twu_arb_ref_id == thd_pmp_id));

  assign pmp_selected_stage_active =
      ((pmp_grant == 3'b100) && fst_pmp_vld)
   || ((pmp_grant == 3'b010) && scd_pmp_vld)
   || ((pmp_grant == 3'b001) && thd_pmp_vld);

  assign pmp_selected_type =
      (pmp_grant == 3'b100) ? fst_pmp_type
    : (pmp_grant == 3'b010) ? scd_pmp_type
    : (pmp_grant == 3'b001) ? thd_pmp_type
    : 3'b000;

  assign pmp_selected_deny =
      (pmp_grant == 3'b100) ? fst_pmp_deny
    : (pmp_grant == 3'b010) ? scd_pmp_deny
    : (pmp_grant == 3'b001) ? thd_pmp_deny
    : 1'b0;

  assign pmp_selected_fetch_type = (pmp_selected_type == TWU_REQ_TYPE_FETCH);
  assign pmp_selected_load_type  = (pmp_selected_type == TWU_REQ_TYPE_LOAD);
  assign pmp_selected_store_type = (pmp_selected_type == TWU_REQ_TYPE_STORE);
  assign pmp_selected_pref_type  = (pmp_selected_type == TWU_REQ_TYPE_PREF);

  assign pmp_selected_perm_deny =
       (pmp_selected_fetch_type && !pmp_mmu_flg[2])
    || (pmp_selected_load_type  && !pmp_mmu_flg[0])
    || (pmp_selected_store_type && !pmp_mmu_flg[1])
    || (pmp_selected_pref_type  && !pmp_mmu_flg[0]);

  assign pmp_effective_priv_mode =
      cp0_mmu_mprv ? cp0_mmu_mpp : cp0_yy_priv_mode;

  // Fetch-originated walks use current privilege for PMP; non-fetch walks use
  // the MPRV-adjusted effective privilege, matching the TWU RTL.
  assign pmp_selected_mach_mode =
      pmp_selected_fetch_type ? (cp0_yy_priv_mode == 2'b11)
                              : (pmp_effective_priv_mode == 2'b11);

  assign pmp_selected_deny_expected =
      pmp_selected_perm_deny && !(pmp_selected_mach_mode && !pmp_mmu_flg[3]);

  // Verification intent: MBUF/PTE read requests are issued only after a PMP
  // stage grants an allowed access.
  sva_pmp_check_before_lsu_req: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    twu_mbuf_req |-> (pmp_allowed_grant && pmp_stage_mbuf_req));

  cp_pmp_check_before_lsu_req: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    twu_mbuf_req && pmp_allowed_grant) begin
    cp_pmp_check_before_lsu_req_hits++;
  end

  // Verification intent: any PMP-driven self-stall must contribute to twu_mask.
  sva_pmp_wait_implies_mask: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_wait_any |-> twu_mask);

  cp_pmp_wait_implies_mask: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_wait_any && twu_mask) begin
    cp_pmp_wait_implies_mask_hits++;
  end

  // Verification intent: a PMP-denied transaction must not create a refill for
  // the same request id/type.
  sva_pmp_deny_no_refill: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept |-> !pmp_deny_refill_same_txn);

  cp_pmp_deny_no_refill: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept && !pmp_deny_refill_same_txn) begin
    cp_pmp_deny_no_refill_hits++;
  end

  // Verification intent: accepted PMP denies are converted into TWU access-fault
  // indication on the following TWU clock.
  sva_pmp_deny_acc_fault: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept |=> twu_l2tlb_ref_acc_err);

  cp_pmp_deny_acc_fault: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept ##1 twu_l2tlb_ref_acc_err) begin
    cp_pmp_deny_acc_fault_hits++;
  end

  // Verification intent: the three TWU PMP stages must serialize access to the
  // shared PMP port.
  sva_pmp_grant_onehot: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    $onehot0(pmp_grant));

  cp_pmp_grant_onehot: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    $onehot(pmp_grant)) begin
    cp_pmp_grant_onehot_hits++;
  end

  // Verification intent: while a valid PMP stage is waiting for grant, no PTW
  // memory request may be launched from that same stage.
  sva_no_lsu_req_during_pmp_wait: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    ((fst_pmp_vld && !fst_pmp_grant) |-> !fst_pmp_mbuf_req)
    and ((scd_pmp_vld && !scd_pmp_grant) |-> !scd_pmp_mbuf_req)
    and ((thd_pmp_vld && !thd_pmp_grant) |-> !thd_pmp_mbuf_req));

  cp_no_lsu_req_during_pmp_wait: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_stage_wait_no_mbuf_req && !twu_mbuf_req) begin
    cp_no_lsu_req_during_pmp_wait_hits++;
  end

  // Verification intent: mmu_pmp_fecth is the original miss fetch sideband,
  // not the PTW PTE bus-read type. It must reflect the selected PMP stage.
  sva_pmp_fetch_matches_grant_stage: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (pmp_grant != 3'b000) |-> (mmu_pmp_fecth == pmp_selected_fetch_type));

  cp_pmp_fetch_matches_grant_stage: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (pmp_grant != 3'b000) && (mmu_pmp_fecth == pmp_selected_fetch_type)) begin
    cp_pmp_fetch_matches_grant_stage_hits++;
  end

  cp_pmp_fetch_high: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (pmp_grant != 3'b000) && pmp_selected_fetch_type && mmu_pmp_fecth) begin
    cp_pmp_fetch_high_hits++;
  end

  // Verification intent: PMP deny must use the original access type carried by
  // the walk: fetch->X, load/prefetch->R, store->W, with M-mode L=0 bypass.
  sva_pmp_deny_uses_original_type_perm: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_selected_stage_active |-> (pmp_selected_deny == pmp_selected_deny_expected));

  cp_pmp_fetch_uses_x_perm: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_selected_stage_active && pmp_selected_fetch_type && !pmp_mmu_flg[2]
    && (pmp_selected_deny == pmp_selected_deny_expected)) begin
    cp_pmp_fetch_uses_x_perm_hits++;
  end

  cp_pmp_load_pref_uses_r_perm: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_selected_stage_active
    && (pmp_selected_load_type || pmp_selected_pref_type) && !pmp_mmu_flg[0]
    && pmp_selected_deny) begin
    cp_pmp_load_pref_uses_r_perm_hits++;
  end

  cp_pmp_store_uses_w_perm: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_selected_stage_active && pmp_selected_store_type && !pmp_mmu_flg[1]
    && (pmp_selected_deny == pmp_selected_deny_expected)) begin
    cp_pmp_store_uses_w_perm_hits++;
  end

  cp_pmp_mmode_l0_bypass: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_selected_stage_active && pmp_selected_perm_deny
    && pmp_selected_mach_mode && !pmp_mmu_flg[3]
    && !pmp_selected_deny_expected && !pmp_selected_deny) begin
    cp_pmp_mmode_l0_bypass_hits++;
  end

  // Verification intent: denied PMP stages must not request PTE memory access.
  sva_pmp_deny_no_lsu_req: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept |-> !twu_mbuf_req);

  cp_pmp_deny_no_lsu_req: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept && !twu_mbuf_req) begin
    cp_pmp_deny_no_lsu_req_hits++;
  end

  final begin
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_check_before_lsu_req hits=%0d", cp_pmp_check_before_lsu_req_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_wait_implies_mask hits=%0d", cp_pmp_wait_implies_mask_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_deny_no_refill hits=%0d", cp_pmp_deny_no_refill_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_deny_acc_fault hits=%0d", cp_pmp_deny_acc_fault_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_grant_onehot hits=%0d", cp_pmp_grant_onehot_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_no_lsu_req_during_pmp_wait hits=%0d", cp_no_lsu_req_during_pmp_wait_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_fetch_matches_grant_stage hits=%0d", cp_pmp_fetch_matches_grant_stage_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_fetch_high hits=%0d", cp_pmp_fetch_high_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_fetch_uses_x_perm hits=%0d", cp_pmp_fetch_uses_x_perm_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_load_pref_uses_r_perm hits=%0d", cp_pmp_load_pref_uses_r_perm_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_store_uses_w_perm hits=%0d", cp_pmp_store_uses_w_perm_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_mmode_l0_bypass hits=%0d", cp_pmp_mmode_l0_bypass_hits);
    $display("PHASE13_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_deny_no_lsu_req hits=%0d", cp_pmp_deny_no_lsu_req_hits);
  end

endmodule
