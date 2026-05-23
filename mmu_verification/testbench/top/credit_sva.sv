// =============================================================================
// L2 Reqq 信用/队列窗口 SVA (bind mmu_l2tlb_reqq) — Phase 7
// 验证意图: 发到 arb 的 issue 在 valid 时队列索引与类型/VA 不 X; 信用回送为单比特已知电平
// 注: ITLB(entry0) 与 DTLB(entry1..) 在 Reqq 上独立分配/回收，可并发有请求，互不排斥 — 不要断言
//     “同一周期仅一类 L1 TLB 可分配”。
// =============================================================================
`timescale 1ns/1ps

module credit_sva #(
    parameter int DTLB_DEPTH = 8,
    parameter int VPN_W = 27,
    parameter int EID_W = 3,
    parameter int TYPE_W = 3,
    parameter int ID_W  = 4,
    parameter int TOTAL_DEPTH = 1 + DTLB_DEPTH
) (
    input logic reqq_clk,
    input logic cpurst_b,
    input logic i_req_valid,
    input logic [VPN_W-1:0] i_req_vpn,
    input logic d_req_valid,
    input logic [VPN_W-1:0] d_req_vpn,
    input logic [EID_W-1:0] d_req_eid,
    input logic [TYPE_W-1:0] d_req_type,
    input logic issue_valid,
    input logic [ID_W-1:0] issue_queue_id,
    input logic [EID_W-1:0] issue_eid,
    input logic [TYPE_W-1:0] issue_type,
    input logic [VPN_W-1:0] issue_vpn,
    input logic issue_grant,
    input logic fb_valid,
    input logic [ID_W-1:0] fb_trans_id,
    input logic fb_hit,
    input logic fb_miss_alloc,
    input logic fb_miss_retry,
    input logic i_credit_return,
    input logic d_credit_return,
    input logic [DTLB_DEPTH-1:0] dtlb_alloc_oh,
    input logic [TOTAL_DEPTH-1:0] alloc_en_vec,
    input logic [TOTAL_DEPTH-1:0] entry_vld_vec,
    input logic [TOTAL_DEPTH-1:0] entry_rdy_vec,
    input logic [TOTAL_DEPTH-1:0] entry_dealloc_vec,
    input logic [TOTAL_DEPTH-1:0] ffr_oh,
    input logic [TOTAL_DEPTH-1:0] entry_grant_vec,
    input logic [TOTAL_DEPTH-1:0] bypass_grant_vec,
    input logic [VPN_W-1:0] entry_out_vpn [TOTAL_DEPTH-1:0],
    input logic [EID_W-1:0] entry_out_eid [TOTAL_DEPTH-1:0],
    input logic [TYPE_W-1:0] entry_out_type [TOTAL_DEPTH-1:0]
);

  function automatic logic is_dtlb_type(input logic [TYPE_W-1:0] req_type);
    is_dtlb_type = (req_type == 3'b010) || (req_type == 3'b110);
  endfunction

  function automatic logic id_in_range(input logic [ID_W-1:0] id);
    id_in_range = !$isunknown(id) && (id < TOTAL_DEPTH[ID_W-1:0]);
  endfunction

  // L2TLB_SVA_003: L1-to-L2 request valid is a one-cycle pulse.
  a_i_req_one_cycle_pulse: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    i_req_valid |=> !i_req_valid);

  a_d_req_one_cycle_pulse: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    d_req_valid |=> !d_req_valid);

  a_i_req_payload_known: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    i_req_valid |-> !$isunknown(i_req_vpn));

  a_d_req_payload_known: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    d_req_valid |-> (!$isunknown(d_req_vpn) && !$isunknown(d_req_eid)
                  && !$isunknown(d_req_type) && is_dtlb_type(d_req_type)));

  a_issue_fields_known: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    issue_valid
      |-> (! $isunknown(issue_queue_id) && ! $isunknown(issue_eid)
        && ! $isunknown(issue_type) && ! $isunknown(issue_vpn)));

  a_credit_retn_bits_known: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (! $isunknown(i_credit_return) && ! $isunknown(d_credit_return)));

  // L2TLB_SVA_004/007: request allocation must respect ITLB entry0 and DTLB
  // entry1..N partitioning. Normal tests must not request without credit.
  a_i_req_has_free_entry0: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    i_req_valid |-> !entry_vld_vec[0]);

  a_d_req_has_free_dtlb_entry: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    d_req_valid |-> !(&entry_vld_vec[TOTAL_DEPTH-1:1]));

  a_dtlb_alloc_onehot0: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    $onehot0(dtlb_alloc_oh));

  a_alloc_entry0_itlb_only: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    alloc_en_vec[0] |-> i_req_valid);

  a_alloc_dtlb_entries_dtlb_only: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (|alloc_en_vec[TOTAL_DEPTH-1:1]) |-> d_req_valid);

  a_entry0_type_itlb: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    entry_vld_vec[0] |-> (entry_out_type[0] == 3'b011 && entry_out_eid[0] == '0));

  genvar entry_idx;
  generate
    for (entry_idx = 1; entry_idx < TOTAL_DEPTH; entry_idx++) begin : gen_dtlb_partition_sva
      a_dtlb_entry_type: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
        entry_vld_vec[entry_idx] |-> (is_dtlb_type(entry_out_type[entry_idx])
                                   && !$isunknown(entry_out_vpn[entry_idx])
                                   && !$isunknown(entry_out_eid[entry_idx])));
    end
  endgenerate

  a_issue_entry0_is_itlb: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (issue_valid && (issue_queue_id == '0))
      |-> (issue_type == 3'b011 && issue_eid == '0));

  a_issue_dtlb_partition: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (issue_valid && id_in_range(issue_queue_id) && (issue_queue_id != '0))
      |-> is_dtlb_type(issue_type));

  a_issue_id_in_range: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    issue_valid |-> id_in_range(issue_queue_id));

  // L2TLB_SVA_008: grant/feedback IDs must target outstanding queue state.
  a_ffr_onehot0: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    $onehot0(ffr_oh));

  a_entry_grant_onehot0: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    $onehot0(entry_grant_vec));

  a_bypass_grant_onehot0: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    $onehot0(bypass_grant_vec));

  a_feedback_id_known_and_in_range: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    fb_valid |-> id_in_range(fb_trans_id));

  a_feedback_id_outstanding: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (fb_valid && id_in_range(fb_trans_id)) |-> entry_vld_vec[fb_trans_id]);

  a_feedback_result_legal_combo: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    fb_valid |-> $onehot0({fb_hit, fb_miss_alloc, fb_miss_retry}));

  a_retry_keeps_entry_for_replay: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    (fb_valid && fb_miss_retry && id_in_range(fb_trans_id))
      |=> (entry_vld_vec[$past(fb_trans_id)] && entry_rdy_vec[$past(fb_trans_id)]));

  a_itlb_credit_matches_entry0_dealloc: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    i_credit_return == entry_dealloc_vec[0]);

  a_dtlb_credit_matches_dtlb_dealloc: assert property (@(posedge reqq_clk) disable iff (!cpurst_b)
    d_credit_return == (|entry_dealloc_vec[TOTAL_DEPTH-1:1]));

  c_itlb_alloc_issue: cover property (@(posedge reqq_clk) disable iff (!cpurst_b)
    i_req_valid ##[0:2] issue_valid && (issue_queue_id == '0) && issue_grant);

  c_dtlb_alloc_issue: cover property (@(posedge reqq_clk) disable iff (!cpurst_b)
    d_req_valid ##[0:4] issue_valid && (issue_queue_id != '0) && issue_grant);

  c_reqq_retry_feedback: cover property (@(posedge reqq_clk) disable iff (!cpurst_b)
    fb_valid && fb_miss_retry);

endmodule
