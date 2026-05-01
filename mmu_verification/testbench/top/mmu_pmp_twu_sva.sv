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
  logic pmp_deny_refill_same_txn;

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

  assign pmp_deny_refill_same_txn =
      (fst_pmp_vld && fst_pmp_deny && twu_arb_ref_req
       && (twu_arb_ref_type == fst_pmp_type) && (twu_arb_ref_id == fst_pmp_id))
   || (scd_pmp_vld && scd_pmp_deny && twu_arb_ref_req
       && (twu_arb_ref_type == scd_pmp_type) && (twu_arb_ref_id == scd_pmp_id))
   || (thd_pmp_vld && thd_pmp_deny && twu_arb_ref_req
       && (twu_arb_ref_type == thd_pmp_type) && (twu_arb_ref_id == thd_pmp_id));

  // Verification intent: MBUF/PTE read requests are issued only after a PMP
  // stage grants an allowed access.
  sva_pmp_check_before_lsu_req: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    twu_mbuf_req |-> (pmp_allowed_grant && pmp_stage_mbuf_req));

  cp_pmp_check_before_lsu_req: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    twu_mbuf_req && pmp_allowed_grant);

  // Verification intent: any PMP-driven self-stall must contribute to twu_mask.
  sva_pmp_wait_implies_mask: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_wait_any |-> twu_mask);

  cp_pmp_wait_implies_mask: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_wait_any && twu_mask);

  // Verification intent: a PMP-denied transaction must not create a refill for
  // the same request id/type.
  sva_pmp_deny_no_refill: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept |-> !pmp_deny_refill_same_txn);

  cp_pmp_deny_no_refill: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept && !pmp_deny_refill_same_txn);

  // Verification intent: accepted PMP denies are converted into TWU access-fault
  // indication on the following TWU clock.
  sva_pmp_deny_acc_fault: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept |=> twu_l2tlb_ref_acc_err);

  cp_pmp_deny_acc_fault: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept ##1 twu_l2tlb_ref_acc_err);

  // Verification intent: the three TWU PMP stages must serialize access to the
  // shared PMP port.
  sva_pmp_grant_onehot: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    $onehot0(pmp_grant));

  cp_pmp_grant_onehot: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    $onehot(pmp_grant));

  // Verification intent: while a valid PMP stage is waiting for grant, no PTW
  // memory request may be launched from that same stage.
  sva_no_lsu_req_during_pmp_wait: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    ((fst_pmp_vld && !fst_pmp_grant) |-> !fst_pmp_mbuf_req)
    and ((scd_pmp_vld && !scd_pmp_grant) |-> !scd_pmp_mbuf_req)
    and ((thd_pmp_vld && !thd_pmp_grant) |-> !thd_pmp_mbuf_req));

  cp_no_lsu_req_during_pmp_wait: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_wait_for_grant
    && !(fst_pmp_mbuf_req || scd_pmp_mbuf_req || thd_pmp_mbuf_req));

  // Verification intent: PTW PMP checks are PTE reads, not instruction fetches.
  sva_ptw_pmp_fetch_zero: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (pmp_grant != 3'b000) |-> !mmu_pmp_fecth);

  cp_ptw_pmp_fetch_zero: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (pmp_grant != 3'b000) && !mmu_pmp_fecth);

  // Verification intent: denied PMP stages must not request PTE memory access.
  sva_pmp_deny_no_lsu_req: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept |-> !twu_mbuf_req);

  cp_pmp_deny_no_lsu_req: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_deny_accept && !twu_mbuf_req);

endmodule
