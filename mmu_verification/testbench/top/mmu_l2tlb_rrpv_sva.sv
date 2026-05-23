// =============================================================================
// mmu_l2tlb side SVA: visible L2TLB request/write and PTW replacement staging
// checks (bind mmu_l2tlb).
// =============================================================================
`timescale 1ns/1ps

module mmu_l2tlb_rrpv_sva (
    input logic forever_cpuclk,
    input logic cpurst_b,
    input logic i_req_valid,
    input logic [26:0] i_req_vpn,
    input logic d_req_valid,
    input logic [26:0] d_req_vpn,
    input logic [2:0] d_req_eid,
    input logic d_req_is_load,
    input logic queue_arb_req,
    input logic [26:0] queue_arb_vpn,
    input logic [2:0] queue_arb_eid,
    input logic [3:0] queue_arb_trans_id,
    input logic [2:0] queue_arb_acc_type,
    input logic arb_l2tlb_req,
    input logic arb_l2tlb_write,
    input logic [26:0] arb_l2tlb_vpn,
    input logic [3:0] arb_l2tlb_trans_id,
    input logic [2:0] arb_l2tlb_eid,
    input logic [2:0] arb_l2tlb_acc_type,
    input logic [47:0] arb_l2tlb_tag_din,
    input logic [41:0] arb_l2tlb_data_din,
    input logic arb_l2tlb_cmp_with_va,
    input logic raw_vld,
    input logic final_vld,
    input logic final_cmp_with_va,
    input logic [26:0] final_vpn,
    input logic [2:0] final_eid,
    input logic [3:0] final_queue_id,
    input logic [2:0] final_acc_type,
    input logic final_tlb_hit_mult,
    input logic final_pa_vld,
    input logic l2tlb_miss,
    input logic cp0_mmu_ptw_en,
    input logic l2tlb_reqq_fb_vld,
    input logic [3:0] l2tlb_reqq_fb_id,
    input logic l2tlb_reqq_fb_hit,
    input logic l2tlb_reqq_fb_miss_alloc,
    input logic l2tlb_reqq_fb_miss_retry,
    input logic ptw_ready,
    input logic l2tlb_ptw_req,
    input logic [6:0] l2tlb_ptw_id,
    input logic [2:0] l2tlb_ptw_type,
    input logic [26:0] l2tlb_ptw_vpn,
    input logic ptw_l2tlb_ref_cmplt,
    input logic ptw_l2tlb_ref_data_vld,
    input logic ptw_l2tlb_ref_pgflt,
    input logic ptw_l2tlb_ref_acc_err,
    input logic [2:0] ptw_l2tlb_ref_type,
    input logic [6:0] ptw_l2tlb_ref_id,
    input logic [13:0] ptw_l2tlb_ref_flg,
    input logic l2tlb_l1dtlb_pgflt,
    input logic l2tlb_l1dtlb_ref_cmplt,
    input logic l2tlb_l1dtlb_ref_pavld,
    input logic [2:0] l2tlb_l1dtlb_ref_eid,
    input logic l2tlb_l1itlb_pgflt,
    input logic l2tlb_l1itlb_ref_cmplt,
    input logic l2tlb_l1itlb_ref_pavld,
    input logic [13:0] l2tlb_l1tlb_ref_flg,
    input logic [2:0] l2tlb_l1tlb_ref_pgs,
    input logic [27:0] l2tlb_l1tlb_ref_ppn,
    input logic [26:0] l2tlb_l1tlb_ref_vpn,
    input logic l2tlb_top_utlb_pavld,
    input logic lsu_mmu_va2_vld,
    input logic [27:0] lsu_mmu_va2,
    input logic [27:0] mmu_lsu_pa2,
    input logic mmu_lsu_pa2_err,
    input logic mmu_lsu_pa2_vld,
    input logic mmu_lsu_sec2,
    input logic mmu_lsu_share2,
    input logic l2tlb_arb_pfu_miss_mb_full,
    input logic l2tlb_arb_rrpv_wbuf_full,
    input logic l2tlb_tlboper_cmplt,
    input logic [7:0] l2tlb_tlboper_sel,
    input logic l2tlb_tlboper_va_hit
);

  function automatic logic is_reqq_type(input logic [2:0] acc_type);
    is_reqq_type = (acc_type == 3'b010) || (acc_type == 3'b110) || (acc_type == 3'b011);
  endfunction

  function automatic logic is_valid_type(input logic [2:0] acc_type);
    is_valid_type = (acc_type == 3'b000) || (acc_type == 3'b001) ||
                    (acc_type == 3'b010) || (acc_type == 3'b011) ||
                    (acc_type == 3'b100) || (acc_type == 3'b101) ||
                    (acc_type == 3'b110);
  endfunction

  // L2TLB_SVA_001: active low reset must visibly drain L2TLB-owned active
  // state. This assertion intentionally is not disabled by reset.
  a_reset_drains_visible_l2tlb_state: assert property (@(posedge forever_cpuclk)
    !cpurst_b |-> (!raw_vld && !final_vld && !l2tlb_reqq_fb_vld
                && !l2tlb_ptw_req && !l2tlb_l1dtlb_ref_cmplt
                && !l2tlb_l1dtlb_ref_pavld && !l2tlb_l1itlb_ref_cmplt
                && !l2tlb_l1itlb_ref_pavld && !mmu_lsu_pa2_vld
                && !l2tlb_tlboper_cmplt && !l2tlb_arb_pfu_miss_mb_full));

  // L2TLB_SVA_018: source request and arb/final payload are known on valid beats.
  a_i_req_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    i_req_valid |-> !$isunknown(i_req_vpn));

  a_d_req_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    d_req_valid |-> (!$isunknown(d_req_vpn) && !$isunknown(d_req_eid)
                  && !$isunknown(d_req_is_load)));

  a_queue_arb_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    queue_arb_req |-> (!$isunknown(queue_arb_vpn) && !$isunknown(queue_arb_eid)
                    && !$isunknown(queue_arb_trans_id)
                    && !$isunknown(queue_arb_acc_type)
                    && is_reqq_type(queue_arb_acc_type)));

  a_arb_l2tlb_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    arb_l2tlb_req |-> (!$isunknown(arb_l2tlb_vpn)
                    && !$isunknown(arb_l2tlb_trans_id)
                    && !$isunknown(arb_l2tlb_eid)
                    && !$isunknown(arb_l2tlb_acc_type)
                    && !$isunknown(arb_l2tlb_cmp_with_va)
                    && is_valid_type(arb_l2tlb_acc_type)));

  a_final_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    final_vld |-> (!$isunknown(final_vpn) && !$isunknown(final_eid)
                && !$isunknown(final_queue_id) && !$isunknown(final_acc_type)
                && is_valid_type(final_acc_type)));

  // Write paths, including PTW refill and TLB operation writes, must present
  // known tag/data when the L2TLB request is active.
  a_write_bus_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (arb_l2tlb_req && arb_l2tlb_write)
      |-> (!$isunknown(arb_l2tlb_tag_din) && !$isunknown(arb_l2tlb_data_din)));

  // PTW read (acc_type 000) must enter the raw stage so replacement policy can
  // consume the RRPV/tag-valid read data and choose a victim for the later write.
  a_ptw_read_sets_raw_vld: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (arb_l2tlb_req && !arb_l2tlb_write && (arb_l2tlb_acc_type == 3'b000))
      |=> raw_vld);

  // PTW write (acc_type 101) is the refill write beat and must not re-enter the
  // raw lookup/replacement read stage.
  a_ptw_write_skips_raw_vld: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (arb_l2tlb_req && arb_l2tlb_write && (arb_l2tlb_acc_type == 3'b101))
      |=> !raw_vld);

  // L2TLB_SVA_011: PTW request payload must remain stable while ready is low.
  a_l2tlb_ptw_req_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    l2tlb_ptw_req |-> (!$isunknown(l2tlb_ptw_id) && !$isunknown(l2tlb_ptw_type)
                    && !$isunknown(l2tlb_ptw_vpn) && is_valid_type(l2tlb_ptw_type)));

  a_l2tlb_ptw_req_stable_under_backpressure: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (l2tlb_ptw_req && !ptw_ready)
      |=> (l2tlb_ptw_req && $stable(l2tlb_ptw_id)
        && $stable(l2tlb_ptw_type) && $stable(l2tlb_ptw_vpn)));

  // L2TLB_SVA_012/018: PTW completion result class is legal and known.
  a_ptw_completion_matches_result_or: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    ptw_l2tlb_ref_cmplt == (ptw_l2tlb_ref_data_vld
                         || ptw_l2tlb_ref_pgflt
                         || ptw_l2tlb_ref_acc_err));

  a_ptw_completion_result_onehot: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    $onehot0({ptw_l2tlb_ref_data_vld, ptw_l2tlb_ref_pgflt, ptw_l2tlb_ref_acc_err}));

  a_ptw_completion_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    ptw_l2tlb_ref_cmplt |-> (!$isunknown(ptw_l2tlb_ref_type)
                          && !$isunknown(ptw_l2tlb_ref_id)
                          && is_valid_type(ptw_l2tlb_ref_type)));

  // A ReqQ multi-hit is a terminal page-fault result, so it must release the
  // sent ReqQ entry instead of leaving it stuck in sent state.
  a_reqq_multihit_releases: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (final_vld && final_cmp_with_va && is_reqq_type(final_acc_type) && final_tlb_hit_mult)
      |-> (l2tlb_reqq_fb_vld && !l2tlb_reqq_fb_miss_retry
        && !l2tlb_reqq_fb_miss_alloc && !l2tlb_reqq_fb_hit
        && (l2tlb_reqq_fb_id == final_queue_id)));

  // When PTW is disabled, a ReqQ miss is also a terminal page-fault result. It
  // must not be replayed just because the miss buffer cannot accept it.
  a_reqq_ptw_disabled_miss_releases: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (final_vld && final_cmp_with_va && is_reqq_type(final_acc_type) && l2tlb_miss && !cp0_mmu_ptw_en)
      |-> (l2tlb_reqq_fb_vld && !l2tlb_reqq_fb_miss_retry
        && !l2tlb_reqq_fb_miss_alloc && !l2tlb_reqq_fb_hit
        && (l2tlb_reqq_fb_id == final_queue_id)));

  a_reqq_feedback_result_legal_combo: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    l2tlb_reqq_fb_vld |-> $onehot0({l2tlb_reqq_fb_hit,
                                    l2tlb_reqq_fb_miss_alloc,
                                    l2tlb_reqq_fb_miss_retry}));

  a_l1_response_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (l2tlb_l1dtlb_ref_cmplt || l2tlb_l1itlb_ref_cmplt || l2tlb_top_utlb_pavld)
      |-> (!$isunknown(l2tlb_l1tlb_ref_flg) && !$isunknown(l2tlb_l1tlb_ref_pgs)
        && !$isunknown(l2tlb_l1tlb_ref_ppn) && !$isunknown(l2tlb_l1tlb_ref_vpn)));

  a_pfu_response_payload_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    mmu_lsu_pa2_vld |-> (!$isunknown(mmu_lsu_pa2) && !$isunknown(mmu_lsu_pa2_err)
                      && !$isunknown(mmu_lsu_sec2) && !$isunknown(mmu_lsu_share2)));

  a_tlboper_response_known: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    l2tlb_tlboper_cmplt |-> (!$isunknown(l2tlb_tlboper_sel)
                          && !$isunknown(l2tlb_tlboper_va_hit)));

  c_reqq_multihit_terminal_fault: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    final_vld && final_cmp_with_va && is_reqq_type(final_acc_type)
    && final_tlb_hit_mult && l2tlb_reqq_fb_vld);

  c_reqq_ptw_disabled_terminal_fault: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    final_vld && final_cmp_with_va && is_reqq_type(final_acc_type)
    && l2tlb_miss && !cp0_mmu_ptw_en && l2tlb_reqq_fb_vld);

  c_ptw_ready_backpressure: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    l2tlb_ptw_req && !ptw_ready ##1 l2tlb_ptw_req && ptw_ready);

  c_ptw_fault_completion: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    ptw_l2tlb_ref_cmplt && (ptw_l2tlb_ref_pgflt || ptw_l2tlb_ref_acc_err));

endmodule
