// =============================================================================
// L2TLB miss-buffer SVA (bind mmu_l2tlb_mb).
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"

module mmu_l2tlb_mb_sva #(
    parameter int DTLB_DEPTH     = 8,
    parameter int VPN_WIDTH      = 27,
    parameter int L1EID_WIDTH    = 3,
    parameter int L2EID_WIDTH    = 4,
    parameter int PTW_TYPE_WIDTH = 3,
    parameter int QUE_ID_WIDTH   = 3,
    parameter int ACC_TYPE_WIDTH = 3,
    parameter int TOTAL_DEPTH    = 1 + DTLB_DEPTH,
    parameter int ID_WIDTH       = $clog2(TOTAL_DEPTH)
) (
    input logic reqq_clk,
    input logic cpurst_b,
    input logic tlboper_ptw_abort,
    input logic req_valid,
    input logic [VPN_WIDTH-1:0] req_vpn,
    input logic [L1EID_WIDTH-1:0] req_l1eid,
    input logic [ACC_TYPE_WIDTH-1:0] req_acc_type,
    input logic req_is_dtlb,
    input logic req_alloc_valid,
    input logic issue_req,
    input logic [L1EID_WIDTH+L2EID_WIDTH-1:0] issue_eid,
    input logic issue_is_dtlb,
    input logic [VPN_WIDTH-1:0] issue_vpn,
    input logic [PTW_TYPE_WIDTH-1:0] issue_type,
    input logic ptw_ready,
    input logic fb_valid,
    input logic [L2EID_WIDTH-1:0] fb_trans_id,
    input logic fb_hit,
    input logic [DTLB_DEPTH-1:0] dtlb_alloc_oh,
    input logic [TOTAL_DEPTH-1:0] alloc_en_vec,
    input logic [TOTAL_DEPTH-1:0] entry_vld_vec,
    input logic [TOTAL_DEPTH-1:0] entry_rdy_vec,
    input logic [TOTAL_DEPTH-1:0] entry_dealloc_vec,
    input logic [TOTAL_DEPTH-1:0] ffr_oh,
    input logic [TOTAL_DEPTH-1:0] entry_grant_vec,
    input logic [TOTAL_DEPTH-1:0] bypass_grant_vec,
    input logic [VPN_WIDTH-1:0] entry_out_vpn [TOTAL_DEPTH-1:0],
    input logic [L1EID_WIDTH-1:0] entry_out_l1eid [TOTAL_DEPTH-1:0],
    input logic [PTW_TYPE_WIDTH-1:0] entry_out_type [TOTAL_DEPTH-1:0]
);

  function automatic logic is_reqq_or_pfu_type(input logic [ACC_TYPE_WIDTH-1:0] acc_type);
    is_reqq_or_pfu_type = (acc_type == 3'b010) || (acc_type == 3'b110) ||
                          (acc_type == 3'b011) || (acc_type == 3'b100);
  endfunction

  function automatic logic id_in_range(input logic [L2EID_WIDTH-1:0] id);
    id_in_range = !$isunknown(id) && (id < TOTAL_DEPTH[L2EID_WIDTH-1:0]);
  endfunction

  // L2TLB_SVA_001/009: reset and allocation partitioning.
  a_reset_clears_mb_visible_state: assert property (@(posedge reqq_clk)
    !cpurst_b |-> (entry_vld_vec == '0 && entry_rdy_vec == '0
                && entry_dealloc_vec == '0 && !issue_req));

  a_req_payload_known: assert property (@(posedge reqq_clk) disable iff (`L2TLB_NEG_DISABLE)
    req_valid |-> (!$isunknown(req_vpn) && !$isunknown(req_l1eid)
                && !$isunknown(req_acc_type) && !$isunknown(req_is_dtlb)
                && is_reqq_or_pfu_type(req_acc_type)));

  a_itlb_alloc_entry0_only: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (req_valid && !req_is_dtlb && !entry_vld_vec[0])
      |-> (alloc_en_vec[0] && !(|alloc_en_vec[TOTAL_DEPTH-1:1])));

  a_itlb_full_no_overwrite: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (req_valid && !req_is_dtlb && entry_vld_vec[0])
      |-> (!req_alloc_valid && !alloc_en_vec[0]));

  a_dtlb_alloc_partition: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (req_valid && req_is_dtlb && !(&entry_vld_vec[TOTAL_DEPTH-1:1]))
      |-> (!alloc_en_vec[0] && $onehot(alloc_en_vec[TOTAL_DEPTH-1:1])));

  a_dtlb_full_no_overwrite: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (req_valid && req_is_dtlb && (&entry_vld_vec[TOTAL_DEPTH-1:1]))
      |-> (!req_alloc_valid && (alloc_en_vec[TOTAL_DEPTH-1:1] == '0)));

  a_dtlb_alloc_onehot0: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    $onehot0(dtlb_alloc_oh));

  // L2TLB_SVA_010/013: issue and completion accounting by MB id.
  a_ffr_onehot0: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    $onehot0(ffr_oh));

  a_entry_grant_onehot0: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    $onehot0(entry_grant_vec));

  a_bypass_grant_onehot0: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    $onehot0(bypass_grant_vec));

  a_issue_payload_known: assert property (@(posedge reqq_clk) disable iff (`L2TLB_NEG_DISABLE)
    issue_req |-> (!$isunknown(issue_eid) && !$isunknown(issue_is_dtlb)
                && !$isunknown(issue_vpn) && !$isunknown(issue_type)
                && id_in_range(issue_eid[L1EID_WIDTH+L2EID_WIDTH-1:L1EID_WIDTH])));

  a_issue_id_matches_partition: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    issue_req |-> (issue_is_dtlb ==
      (issue_eid[L1EID_WIDTH+L2EID_WIDTH-1:L1EID_WIDTH] != '0)));

  a_issue_payload_matches_ready_entry: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (issue_req && (|entry_rdy_vec))
      |-> (issue_vpn == entry_out_vpn[issue_eid[L1EID_WIDTH+L2EID_WIDTH-1:L1EID_WIDTH]]
        && issue_type == entry_out_type[issue_eid[L1EID_WIDTH+L2EID_WIDTH-1:L1EID_WIDTH]]));

  a_ptw_ready_backpressure_payload_stable: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
      (issue_req && !ptw_ready)
        |=> (issue_req && $stable(issue_eid) && $stable(issue_vpn)
          && $stable(issue_type) && $stable(issue_is_dtlb)));

  a_feedback_id_known_and_in_range: assert property (@(posedge reqq_clk) disable iff (`L2TLB_NEG_DISABLE)
    fb_valid |-> (id_in_range(fb_trans_id) && !$isunknown(fb_hit)));

  a_feedback_id_outstanding: assert property (@(posedge reqq_clk) disable iff (`L2TLB_NEG_DISABLE)
    (fb_valid && id_in_range(fb_trans_id)) |-> entry_vld_vec[fb_trans_id]);

  a_feedback_deallocates_matching_entry: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (fb_valid && fb_hit && id_in_range(fb_trans_id))
      |=> !entry_vld_vec[$past(fb_trans_id)]);

  // L2TLB_SVA_016: abort clears sent state and must not drop outstanding entry
  // ownership, except entries that legally complete in the abort cycle.
  a_abort_keeps_outstanding_entries_valid: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (tlboper_ptw_abort && (entry_vld_vec != '0))
      |=> ((entry_vld_vec & ($past(entry_vld_vec) & ~$past(entry_dealloc_vec)))
        == ($past(entry_vld_vec) & ~$past(entry_dealloc_vec))));

  c_mb_itlb_alloc: cover property (@(posedge reqq_clk) disable iff (!cpurst_b)
    req_valid && !req_is_dtlb && req_alloc_valid);

  c_mb_dtlb_alloc: cover property (@(posedge reqq_clk) disable iff (!cpurst_b)
    req_valid && req_is_dtlb && req_alloc_valid);

  c_mb_ptw_backpressure: cover property (@(posedge reqq_clk) disable iff (!cpurst_b)
      issue_req && !ptw_ready ##1 issue_req && ptw_ready);

  c_mb_abort_outstanding: cover property (@(posedge reqq_clk) disable iff (!cpurst_b)
    tlboper_ptw_abort && (entry_vld_vec != '0));

endmodule
