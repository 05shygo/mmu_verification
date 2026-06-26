// =============================================================================
// L2TLB PTW out-of-order completion SVA — TP_056 (Phase 9)
//
// Audit target: when PTW completes translations out of order, every completion
// ID must correspond to an outstanding request that L2TLB previously issued.
//
// Strategy:
//   * Maintain a per-ID outstanding-bit array (indexed by PTW_ID, width
//     2**PTW_ID_WIDTH).  Set on l2tlb_ptw_req && ptw_ready (fire); clear on
//     ptw_l2tlb_ref_cmplt.
//   * ASSERT: ptw_l2tlb_ref_cmplt requires the matching ID bit to be set.
//   * COVER: gather evidence of out-of-order completion (completion ID !=
//     most-recently-issued ID).
//
// Bind target: mmu_l2tlb (clock = forever_cpuclk, reset = cpurst_b)
//
// NOTE: l2tlb_ptw_id and ptw_l2tlb_ref_id are both L1EID_WIDTH+L2EID_WIDTH
// (= 7 bits) wide at the mmu_l2tlb boundary.
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"

module mmu_l2tlb_ptw_ooo_sva #(
    parameter int PTW_ID_WIDTH = 7,
    parameter int ID_SPACE     = 128   // 2**PTW_ID_WIDTH
) (
    input  logic                       forever_cpuclk,
    input  logic                       cpurst_b,

    // L2 → PTW request side
    input  logic                       l2tlb_ptw_req,
    input  logic [PTW_ID_WIDTH-1:0]    l2tlb_ptw_id,

    // PTW → L2 completion side
    input  logic                       ptw_ready,
    input  logic                       ptw_l2tlb_ref_cmplt,
    input  logic [PTW_ID_WIDTH-1:0]    ptw_l2tlb_ref_id
);

  // ---------------------------------------------------------------------------
  // Outstanding-ID tracking array.  outstanding_id[i] = 1 if a request with
  // ID=i has been issued and not yet completed.  Reset clears the array.
  // ---------------------------------------------------------------------------
  logic [ID_SPACE-1:0] outstanding_id;
  logic [PTW_ID_WIDTH-1:0] last_issued_id;
  logic                   last_issued_valid;

  always_ff @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      outstanding_id    <= '0;
      last_issued_id    <= '0;
      last_issued_valid <= 1'b0;
    end else begin
      // Track most-recent issue for OOO cover evidence.
      if (l2tlb_ptw_req && ptw_ready && !$isunknown(l2tlb_ptw_id)) begin
        outstanding_id[l2tlb_ptw_id] <= 1'b1;
        last_issued_id               <= l2tlb_ptw_id;
        last_issued_valid            <= 1'b1;
      end

      // Clear on completion.  If both issue and complete fire the same ID in
      // the same cycle, the set wins (request outstanding takes precedence).
      if (ptw_l2tlb_ref_cmplt && !$isunknown(ptw_l2tlb_ref_id)
          && !(l2tlb_ptw_req && ptw_ready
               && !$isunknown(l2tlb_ptw_id)
               && (l2tlb_ptw_id == ptw_l2tlb_ref_id))) begin
        outstanding_id[ptw_l2tlb_ref_id] <= 1'b0;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // TP_056 — ASSERT: every completion ID must correspond to an outstanding
  // request that was previously issued.
  // ---------------------------------------------------------------------------
  a_ptw_cmplt_id_outstanding: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      (ptw_l2tlb_ref_cmplt && !$isunknown(ptw_l2tlb_ref_id))
      |-> outstanding_id[ptw_l2tlb_ref_id]);

  // Completion payload must not carry an unknown ID.
  a_ptw_cmplt_id_known: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      ptw_l2tlb_ref_cmplt |-> !$isunknown(ptw_l2tlb_ref_id));

  // Structural: issue and completion fire signals must themselves be known.
  a_l2tlb_ptw_req_known: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      !$isunknown(l2tlb_ptw_req));

  a_ptw_l2tlb_cmplt_known: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      !$isunknown(ptw_l2tlb_ref_cmplt));

  // ---------------------------------------------------------------------------
  // TP_056 — COVER: out-of-order completion evidence.  A completion whose ID
  // differs from the most-recently-issued ID demonstrates true OOO return and
  // exercises the ID-tracking logic.
  // ---------------------------------------------------------------------------
  c_ptw_req_fire: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      l2tlb_ptw_req && ptw_ready);

  c_ptw_cmplt: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      ptw_l2tlb_ref_cmplt);

  c_ptw_ooo_completion: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      ptw_l2tlb_ref_cmplt
      && last_issued_valid
      && (ptw_l2tlb_ref_id != last_issued_id));

  // Concurrent issue + completion (same cycle, different IDs) — stresses the
  // outstanding array update ordering.
  c_ptw_concurrent_issue_cmplt: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      (l2tlb_ptw_req && ptw_ready && ptw_l2tlb_ref_cmplt
       && (l2tlb_ptw_id != ptw_l2tlb_ref_id)));

endmodule
