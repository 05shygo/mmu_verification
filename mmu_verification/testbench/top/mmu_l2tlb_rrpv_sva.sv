// =============================================================================
// mmu_l2tlb side SVA: visible L2TLB request/write and PTW replacement staging
// checks (bind mmu_l2tlb).
// =============================================================================
`timescale 1ns/1ps

module mmu_l2tlb_rrpv_sva (
    input logic forever_cpuclk,
    input logic cpurst_b,
    input logic arb_l2tlb_req,
    input logic arb_l2tlb_write,
    input logic [2:0] arb_l2tlb_acc_type,
    input logic [47:0] arb_l2tlb_tag_din,
    input logic [41:0] arb_l2tlb_data_din,
    input logic raw_vld,
    input logic final_vld,
    input logic final_cmp_with_va,
    input logic [2:0] final_acc_type,
    input logic final_tlb_hit_mult,
    input logic l2tlb_miss,
    input logic cp0_mmu_ptw_en,
    input logic l2tlb_reqq_fb_vld,
    input logic l2tlb_reqq_fb_miss_retry
);

  function automatic logic is_reqq_type(input logic [2:0] acc_type);
    is_reqq_type = (acc_type == 3'b010) || (acc_type == 3'b110) || (acc_type == 3'b011);
  endfunction

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

  // A ReqQ multi-hit is a terminal page-fault result, so it must release the
  // sent ReqQ entry instead of leaving it stuck in sent state.
  a_reqq_multihit_releases: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (final_vld && final_cmp_with_va && is_reqq_type(final_acc_type) && final_tlb_hit_mult)
      |-> (l2tlb_reqq_fb_vld && !l2tlb_reqq_fb_miss_retry));

  // When PTW is disabled, a ReqQ miss is also a terminal page-fault result. It
  // must not be replayed just because the miss buffer cannot accept it.
  a_reqq_ptw_disabled_miss_releases: assert property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    (final_vld && final_cmp_with_va && is_reqq_type(final_acc_type) && l2tlb_miss && !cp0_mmu_ptw_en)
      |-> (l2tlb_reqq_fb_vld && !l2tlb_reqq_fb_miss_retry));

endmodule
