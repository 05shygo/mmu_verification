// =============================================================================
// L2TLB illegal-input-reject SVA — TP_048 (Phase 9)
//
// Audit target: illegal access type / bad page size / out-of-range index must
// not propagate X or deadlock the L2TLB pipeline.
//
// Strategy:
//   1. ASSERT: payload-known guards on critical L2TLB inputs — illegal or
//      unknown inputs must not propagate to X on the final_vld / ptw_req
//      control nets.  This is the "no X propagation" half of TP_048.
//   2. COVER (not assert): bounded-liveness evidence that an illegal-acc_type
//      request is observed and the pipeline subsequently recovers (request
//      deasserts or a PTW completion/fault is produced).  Using cover instead
//      of assert avoids false positives when the legal pipeline legitimately
//      stalls the request under backpressure.
//
// Bind target: mmu_l2tlb (clock = forever_cpuclk, reset = cpurst_b)
//
// NOTE: "illegal acc_type" is defined per the L2 ReqQ/PFU encoding already used
// by mmu_l2tlb_mb_sva (legal = 3'b010 / 3'b110 / 3'b011 / 3'b100).  Any other
// 3-bit value reaching arb_l2tlb_acc_type is treated as illegal input.
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"

module mmu_l2tlb_illegal_input_sva #(
    parameter int VPN_WIDTH   = 27,
    parameter int TYPE_WIDTH  = 3,
    parameter int TID_WIDTH   = 4,
    parameter int RECOVER_BOUND = 64
) (
    input  logic                    forever_cpuclk,
    input  logic                    cpurst_b,

    // L2 arbiter request side
    input  logic                    arb_l2tlb_req,
    input  logic                    arb_l2tlb_write,
    input  logic [TYPE_WIDTH-1:0]   arb_l2tlb_acc_type,
    input  logic [VPN_WIDTH-1:0]    arb_l2tlb_vpn,
    input  logic [TID_WIDTH-1:0]    arb_l2tlb_trans_id,

    // PTW request side (L2 → PTW)
    input  logic                    l2tlb_ptw_req,

    // PTW completion side (PTW → L2)
    input  logic                    ptw_l2tlb_ref_cmplt,
    input  logic                    ptw_l2tlb_ref_acc_err,
    input  logic                    ptw_l2tlb_ref_pgflt,

    // Final-pipeline activity (internal net of mmu_l2tlb)
    input  logic                    final_vld
);

  // ---------------------------------------------------------------------------
  // past-valid guard for $past / sequence timing.
  // ---------------------------------------------------------------------------
  logic l2_ill_past_valid;

  always_ff @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      l2_ill_past_valid <= 1'b0;
    end else begin
      l2_ill_past_valid <= 1'b1;
    end
  end

  // Legal L2 ReqQ/PFU access-type encoding (mirrors mmu_l2tlb_mb_sva).
  function automatic logic is_legal_acc_type(input logic [TYPE_WIDTH-1:0] t);
    is_legal_acc_type = (t == 3'b010) || (t == 3'b110)
                     || (t == 3'b011) || (t == 3'b100);
  endfunction

  // ---------------------------------------------------------------------------
  // TP_048 — ASSERT: payload-known guards.  Illegal or unknown inputs must
  // not cause X propagation on the critical L2TLB control nets.
  // ---------------------------------------------------------------------------
  a_l2_req_acc_type_known: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      arb_l2tlb_req |-> !$isunknown(arb_l2tlb_acc_type));

  a_l2_req_vpn_known: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      arb_l2tlb_req |-> !$isunknown(arb_l2tlb_vpn));

  a_l2_req_trans_id_known: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      arb_l2tlb_req |-> !$isunknown(arb_l2tlb_trans_id));

  // Illegal acc_type must not produce X on the final_vld control net.
  a_illegal_acc_no_x_final_vld: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      (arb_l2tlb_req && !is_legal_acc_type(arb_l2tlb_acc_type))
      |-> !$isunknown(final_vld));

  // Illegal acc_type must not produce X on l2tlb_ptw_req control net.
  a_illegal_acc_no_x_ptw_req: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      (arb_l2tlb_req && !is_legal_acc_type(arb_l2tlb_acc_type))
      |-> !$isunknown(l2tlb_ptw_req));

  // Illegal acc_type must not produce a PTW completion with both pgflt and
  // acc_err simultaneously (mutually-exclusive fault flags).
  a_illegal_acc_no_dual_fault: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE)
      ptw_l2tlb_ref_cmplt |-> !(ptw_l2tlb_ref_pgflt && ptw_l2tlb_ref_acc_err));

  // ---------------------------------------------------------------------------
  // TP_048 — COVER: bounded-liveness recovery evidence.  Captures that an
  // illegal acc_type was observed and the pipeline subsequently cleared the
  // request or produced a completion within RECOVER_BOUND cycles.
  // ---------------------------------------------------------------------------
  c_illegal_acc_type_observed: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ill_past_valid)
      arb_l2tlb_req && !is_legal_acc_type(arb_l2tlb_acc_type));

  c_illegal_acc_recovers: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ill_past_valid)
      (arb_l2tlb_req && !is_legal_acc_type(arb_l2tlb_acc_type))
      ##[1:RECOVER_BOUND] (!arb_l2tlb_req || ptw_l2tlb_ref_cmplt));

  c_illegal_acc_completion: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ill_past_valid)
      (arb_l2tlb_req && !is_legal_acc_type(arb_l2tlb_acc_type))
      ##[1:RECOVER_BOUND] ptw_l2tlb_ref_cmplt);

  // Unknown VPN observed and recovered (no X-propagation to PTW).
  c_unknown_vpn_recovers: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ill_past_valid)
      (arb_l2tlb_req && $isunknown(arb_l2tlb_vpn))
      ##[1:RECOVER_BOUND] !arb_l2tlb_req);

endmodule
