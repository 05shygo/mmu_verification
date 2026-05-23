// =============================================================================
// mmu_arb 仲裁 SVA (bind mmu_arb) — Phase 7
// 验证意图: 5 路 grant 多 hot 中至多一路；有全局请求时 five-hot 中恰一路；PTW 写两拍流水在复位下清零 (F5.NEW.2 伪代码 sva_ptw_write_pipe_reset_safe)
// =============================================================================
`timescale 1ns/1ps

module mmu_arb_sva (
    input logic forever_cpuclk,
    input logic cpurst_b,
    input logic issue_valid,
    input logic [26:0] issue_vpn,
    input logic [2:0] issue_eid,
    input logic [2:0] issue_type,
    input logic [3:0] issue_queue_id,
    input logic ptw_arb_req,
    input logic [26:0] ptw_arb_vpn,
    input logic tlboper_arb_req,
    input logic [26:0] tlboper_arb_vpn,
    input logic tlboper_arb_write,
    input logic lsu_mmu_va2_vld,
    input logic [26:0] l2tlb_arb_pfu_vpn,
    input logic l2tlb_arb_pfu_miss_mb_full,
    input logic l2tlb_arb_rrpv_wbuf_full,
    input logic dutlb_xx_mmu_off,
    input logic mmu_lsu_pa2_err,
    input logic mmu_lsu_pa2_vld,
    input logic arb_l2tlb_req,
    input logic [26:0] arb_l2tlb_vpn,
    input logic arb_l2tlb_write,
    input logic [3:0] arb_l2tlb_trans_id,
    input logic [2:0] arb_l2tlb_eid,
    input logic [2:0] arb_l2tlb_acc_type,
    input logic ptw_write_req1,
    input logic ptw_write_req2,
    input logic arb_ptw_write_grant,
    input logic arb_ptw_grant,
    input logic arb_tlboper_grant,
    input logic arb_reqq_grant,
    input logic arb_pfu_grant,
    input logic tlboper_on,
    input logic ptw_on,
    input logic prefetch_mask
);

  // 验证意图: 5 个 grant 在任意周期至多 1 个为 1（固定优先级 + ptw 写时序的互斥结构）
  a_grant_onehot0: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    $onehot0({arb_pfu_grant, arb_reqq_grant, arb_tlboper_grant, arb_ptw_grant, arb_ptw_write_grant}));

  // 验证意图: 有 arb_l2tlb_req 时，上述五路中恰有一路置位（与 OR 合路一致）
  a_grant_onehot_when_req: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    arb_l2tlb_req |-> $onehot({arb_pfu_grant, arb_reqq_grant, arb_tlboper_grant, arb_ptw_grant, arb_ptw_write_grant}));

  // 验证意图: 同步复位低有效期间/释放后的采样边沿，PTW 两拍写请求寄存器被清零
  a_ptw_write_pipe_reset_safe: assert property (@(posedge forever_cpuclk)
    !cpurst_b |-> (!ptw_write_req1 && !ptw_write_req2));

  // L2TLB_SVA_005/019/020/021: block windows must not leak grants to
  // lower-priority or masked sources. PTW writeback is allowed during ptw_on.
  a_ptw_on_blocks_non_write_sources: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    ptw_on |-> !(arb_ptw_grant || arb_tlboper_grant || arb_reqq_grant || arb_pfu_grant));

  a_tlboper_on_blocks_lookup_sources: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    tlboper_on |-> !(arb_ptw_grant || arb_reqq_grant || arb_pfu_grant));

  a_wbuf_full_blocks_new_reads: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    l2tlb_arb_rrpv_wbuf_full |-> !(arb_ptw_grant || arb_tlboper_grant || arb_reqq_grant || arb_pfu_grant));

  a_prefetch_mask_blocks_pfu_grant: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    prefetch_mask |-> !arb_pfu_grant);

  // L2TLB_SVA_005/006: fixed-priority grant eligibility when no block is active.
  a_ptw_priority_grant: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (ptw_arb_req && !ptw_on && !tlboper_on && !l2tlb_arb_rrpv_wbuf_full)
      |-> arb_ptw_grant);

  a_tlboper_priority_grant: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (tlboper_arb_req && !ptw_arb_req && !ptw_on && !l2tlb_arb_rrpv_wbuf_full)
      |-> arb_tlboper_grant);

  a_reqq_priority_grant: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (issue_valid && !ptw_arb_req && !tlboper_arb_req && !ptw_on && !tlboper_on
      && !l2tlb_arb_rrpv_wbuf_full)
      |-> arb_reqq_grant);

  a_pfu_priority_grant: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (lsu_mmu_va2_vld && !dutlb_xx_mmu_off && !ptw_arb_req && !tlboper_arb_req
      && !issue_valid && !ptw_on && !tlboper_on && !prefetch_mask
      && !l2tlb_arb_rrpv_wbuf_full)
      |-> arb_pfu_grant);

  // L2TLB_SVA_005: selected payload must come from the granted source.
  a_reqq_payload_no_cross: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    arb_reqq_grant |-> (arb_l2tlb_vpn == issue_vpn
                     && arb_l2tlb_trans_id == issue_queue_id
                     && arb_l2tlb_eid == issue_eid
                     && arb_l2tlb_acc_type == issue_type));

  a_pfu_payload_no_cross: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    arb_pfu_grant |-> (arb_l2tlb_vpn == l2tlb_arb_pfu_vpn
                    && arb_l2tlb_acc_type == 3'b100));

  a_tlboper_payload_no_cross: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    arb_tlboper_grant |-> (arb_l2tlb_vpn == tlboper_arb_vpn
                        && arb_l2tlb_acc_type == 3'b001
                        && arb_l2tlb_write == tlboper_arb_write));

  a_ptw_read_payload_no_cross: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    arb_ptw_grant |-> (arb_l2tlb_vpn == ptw_arb_vpn
                    && !arb_l2tlb_write
                    && arb_l2tlb_acc_type == 3'b000));

  a_ptw_write_payload_class: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    arb_ptw_write_grant |-> (arb_l2tlb_write && arb_l2tlb_acc_type == 3'b101));

  // L2TLB_SVA_021: a sustained PFU request is masked after accept until
  // response/error or MB-full retry releases the mask.
  a_pfu_grant_sets_prefetch_mask: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (arb_pfu_grant && !(mmu_lsu_pa2_err || mmu_lsu_pa2_vld || l2tlb_arb_pfu_miss_mb_full))
      |=> prefetch_mask);

  a_pfu_response_releases_prefetch_mask: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (mmu_lsu_pa2_err || mmu_lsu_pa2_vld || l2tlb_arb_pfu_miss_mb_full)
      |=> !prefetch_mask);

  // Trigger evidence for Phase6G assertion/cover extraction.
  c_pairwise_reqq_pfu_conflict: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    issue_valid && lsu_mmu_va2_vld && arb_reqq_grant);

  c_ptw_on_blocks_reqq: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    ptw_on && issue_valid && !arb_reqq_grant);

  c_tlboper_on_blocks_pfu: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    tlboper_on && lsu_mmu_va2_vld && !arb_pfu_grant);

  c_prefetch_mask_release: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    prefetch_mask ##1 (mmu_lsu_pa2_err || mmu_lsu_pa2_vld || l2tlb_arb_pfu_miss_mb_full) ##1 !prefetch_mask);

endmodule
