// =============================================================================
// TWU internal SVA (bind twu) - Phase 11
// Focus: R19 bug capture and TWU pipeline/mask guardrails from the v3 gap plan.
// =============================================================================
`timescale 1ns/1ps

module mmu_twu_sva (
    input logic        twu_clk,
    input logic        cpurst_b,
    input logic        twu_crs2_2m,
    input logic        twu_csr_cross,
    input logic [63:0] csr_data_flop,
    input logic [1:0]  csr_grant,
    input logic        twu_mask,
    input logic        fst_pmp_wait,
    input logic        scd_pmp_wait,
    input logic        thd_pmp_wait,
    input logic        fst_chk_vld,
    input logic        fst_chk_page_flt,
    input logic        fst_chk_leaf_vld,
    input logic        scd_chk_vld,
    input logic        scd_chk_page_flt,
    input logic        scd_chk_leaf_vld,
    input logic        xbar_twu_req,
    input logic [1:0]  xbar_twu_hit_level,
    input logic        fst_pmp_vld,
    input logic        scd_pmp_vld,
    input logic        thd_pmp_vld,
    input logic        thd_chk_vld
);

  // R19: 2 MB CSR cross must shift-update csr_data_flop.
  a_twu_2m_cross_data: assert property (@(posedge twu_clk) disable iff (!cpurst_b)
    (twu_crs2_2m && twu_csr_cross) |=> (csr_data_flop != $past(csr_data_flop)));

  // F4.NEW.5: CSR grant selection must never drive both sources together.
  a_csr_grant_onehot: assert property (@(posedge twu_clk) disable iff (!cpurst_b)
    $onehot0(csr_grant));

  // F4.NEW.2 / F4.52: twu_mask is driven by TWU self-stall conditions only.
  a_twu_mask_semantics: assert property (@(posedge twu_clk) disable iff (!cpurst_b)
    twu_mask
    == (fst_pmp_wait
        || scd_pmp_wait
        || thd_pmp_wait
        || (fst_chk_vld && !fst_chk_page_flt && !fst_chk_leaf_vld && !scd_pmp_wait)
        || (scd_chk_vld && !scd_chk_page_flt && !scd_chk_leaf_vld && !thd_pmp_wait)));

  // When the first-stage slot is free and the TWU is unmasked, a new request
  // must advance into fst_pmp_vld on the next TWU clock.
  a_twu_pipeline_no_stall_when_unmasked: assert property (@(posedge twu_clk) disable iff (!cpurst_b)
    (xbar_twu_req && !twu_mask && (xbar_twu_hit_level == 2'b00)) |=> fst_pmp_vld);

  // This is a legal scenario, not an error: multiple stage valids may coexist.
  c_twu_multi_inflight_legal: cover property (@(posedge twu_clk) disable iff (!cpurst_b)
    ($countones({fst_pmp_vld, fst_chk_vld, scd_pmp_vld, scd_chk_vld, thd_pmp_vld, thd_chk_vld}) >= 2));

endmodule
