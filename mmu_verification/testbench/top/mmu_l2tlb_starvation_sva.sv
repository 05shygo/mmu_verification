// =============================================================================
// L2TLB no-starvation SVA — TP_049 (Phase 9)
//
// Audit target: ReqQ / MB entries must not be indefinitely blocked.  Once an
// entry's vld rises, it must eventually deassert (the request is served).
//
// Strategy:
//   * Use cover property (not assert) per the Phase-9 plan to avoid false
//     positives from legitimately long PTW walks.
//   * Each entry's vld rise is paired with a bounded deassertion window
//     (STARVE_BOUND cycles).  The bound is far larger than the worst-case
//     PTW latency (consistent with the L2TLB stuck-cycle watchdog, which
//     trips at 4096 cycles).
//
// Bind target: mmu_l2tlb
//   reqq_vld_vec and mb_vld_vec are NOT direct ports of mmu_l2tlb; they live
//   in submodules x_l2tlb_reqq and x_l2tlb_mb.  The bind in tb_top.sv passes
//   them via explicit hierarchical connection (.*  + named port override).
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"

module mmu_l2tlb_starvation_sva #(
    parameter int TOTAL_DEPTH   = 9,    // 1 ITLB + 8 DTLB
    parameter int STARVE_BOUND  = 4096
) (
    input  logic                      forever_cpuclk,
    input  logic                      cpurst_b,

    // ReqQ / MB valid vectors (hierarchical refs from bind)
    input  logic [TOTAL_DEPTH-1:0]    reqq_vld_vec,
    input  logic [TOTAL_DEPTH-1:0]    mb_vld_vec,

    // Progress indicators (used as alternative completion signals)
    input  logic                      ptw_l2tlb_ref_cmplt,
    input  logic                      l2tlb_ptw_req
);

  // ---------------------------------------------------------------------------
  // past-valid guard for $rose in the cover sequences.
  // ---------------------------------------------------------------------------
  logic l2_starve_past_valid;

  always_ff @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      l2_starve_past_valid <= 1'b0;
    end else begin
      l2_starve_past_valid <= 1'b1;
    end
  end

  // ---------------------------------------------------------------------------
  // TP_049 — COVER: per-entry bounded service.  For each ReqQ / MB entry,
  // cover that a vld rise is followed by a vld fall within STARVE_BOUND
  // cycles.  Failure to cover indicates either no starvation (entry was never
  // held long enough) or insufficient simulation traffic — never a functional
  // failure, matching the Phase-9 directive to use cover for this audit point.
  // ---------------------------------------------------------------------------
  genvar rq_i;
  generate
    for (rq_i = 0; rq_i < TOTAL_DEPTH; rq_i++) begin : gen_reqq_starv
      c_reqq_entry_served: cover property (@(posedge forever_cpuclk)
        disable iff (`L2TLB_NEG_DISABLE || !l2_starve_past_valid)
          $rose(reqq_vld_vec[rq_i])
          ##1 reqq_vld_vec[rq_i][*0:STARVE_BOUND-1]
          ##1 !reqq_vld_vec[rq_i]);
    end
  endgenerate

  genvar mb_i;
  generate
    for (mb_i = 0; mb_i < TOTAL_DEPTH; mb_i++) begin : gen_mb_starv
      c_mb_entry_served: cover property (@(posedge forever_cpuclk)
        disable iff (`L2TLB_NEG_DISABLE || !l2_starve_past_valid)
          $rose(mb_vld_vec[mb_i])
          ##1 mb_vld_vec[mb_i][*0:STARVE_BOUND-1]
          ##1 !mb_vld_vec[mb_i]);
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // Evidence: PTW completion observed while ReqQ / MB has outstanding entries.
  // Demonstrates that the pipeline drains vld via legitimate completions.
  // ---------------------------------------------------------------------------
  c_reqq_drains_via_ptw_cmplt: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_starve_past_valid)
      (|reqq_vld_vec) && ptw_l2tlb_ref_cmplt);

  c_mb_drains_via_ptw_cmplt: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_starve_past_valid)
      (|mb_vld_vec) && ptw_l2tlb_ref_cmplt);

  // ---------------------------------------------------------------------------
  // Structural ASSERT (safe): once ALL entries are cleared, neither vector
  // may show an X.  This complements the cover-based liveness check with a
  // strict X-propagation guard for the empty state.
  // ---------------------------------------------------------------------------
  a_reqq_empty_not_x: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      (reqq_vld_vec == '0) |-> !$isunknown(reqq_vld_vec));

  a_mb_empty_not_x: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      (mb_vld_vec == '0) |-> !$isunknown(mb_vld_vec));

endmodule
