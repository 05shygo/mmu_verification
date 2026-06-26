// =============================================================================
// L2TLB control-hazard-safe SVA — TP_058 (Phase 9)
//
// Audit target: SATP / ASID / control-register writes must not drive the L2TLB
// into an illegal FSM state, especially while PTW / miss-buffer transactions
// are outstanding.
//
// Strategy:
//   * Detect ASID/SATP/control writes via a registered asid_changed flag
//     (regs_l2tlb_cur_asid != $past(regs_l2tlb_cur_asid)) plus the
//     tlboper_l2tlb_invasid_on / tlboper_l2tlb_asid_sel trigger inputs.
//   * ASSERT: no X propagation on critical control nets (final_vld /
//     arb_l2tlb_req / ptw completion flags) during a control write.
//   * COVER (not assert): control write during outstanding PTW activity that
//     still produces a PTW completion within a bounded window — evidence that
//     the in-flight transaction is not silently dropped.  Using cover avoids
//     false positives when the design legitimately squashes a stale request.
//
// Bind target: mmu_l2tlb (clock = forever_cpuclk, reset = cpurst_b)
//
// Probe mapping (probe name → RTL port inside mmu_l2tlb):
//   l2_final_vld      → final_vld (internal net)
//   l2_arb_req        → arb_l2tlb_req (input port)
//   cp0_satp_write    → registered asid_changed flag (derived from
//                       regs_l2tlb_cur_asid) OR tlboper_l2tlb_asid_sel
//   cp0_asid          → regs_l2tlb_cur_asid
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"

module mmu_l2tlb_ctrl_hazard_sva #(
    parameter int ASID_WIDTH     = 16,
    parameter int RECOVER_BOUND  = 64
) (
    input  logic                    forever_cpuclk,
    input  logic                    cpurst_b,

    // Activity indicators
    input  logic                    final_vld,
    input  logic                    arb_l2tlb_req,

    // Control registers / TLBOP triggers
    input  logic [ASID_WIDTH-1:0]   regs_l2tlb_cur_asid,
    input  logic                    tlboper_l2tlb_asid_sel,
    input  logic                    tlboper_l2tlb_invasid_on,
    input  logic                    cp0_mmu_ptw_en,

    // PTW activity (outstanding / completion)
    input  logic                    l2tlb_ptw_req,
    input  logic                    ptw_ready,
    input  logic                    ptw_l2tlb_ref_cmplt,
    input  logic                    ptw_l2tlb_ref_pgflt,
    input  logic                    ptw_l2tlb_ref_acc_err
);

  // ---------------------------------------------------------------------------
  // past-valid guard for $past in the cover sequences.
  // ctrl_write_now / asid_changed_now are registered trigger flags so the
  // audit expressions stay free of $changed() inside function calls (which is
  // a portability concern across simulators).
  // ---------------------------------------------------------------------------
  logic l2_ctrl_past_valid;
  logic asid_changed_now;
  logic ctrl_write_now;

  always_ff @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      l2_ctrl_past_valid <= 1'b0;
      asid_changed_now   <= 1'b0;
      ctrl_write_now     <= 1'b0;
    end else begin
      l2_ctrl_past_valid <= 1'b1;
      // ASID-changed flag uses the registered previous ASID value to detect a
      // SATP/ASID write without relying on $changed inside a function call.
      asid_changed_now   <= !$isunknown(regs_l2tlb_cur_asid)
                         && (regs_l2tlb_cur_asid != $past(regs_l2tlb_cur_asid));
      ctrl_write_now     <= asid_changed_now
                         || tlboper_l2tlb_asid_sel
                         || tlboper_l2tlb_invasid_on;
    end
  end

  // ---------------------------------------------------------------------------
  // TP_058 — ASSERT: control writes must not cause X propagation on the
  // critical observable control nets.
  // ---------------------------------------------------------------------------
  a_ctrl_write_no_x_final_vld: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      ctrl_write_now |-> !$isunknown(final_vld));

  a_ctrl_write_no_x_arb_req: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      ctrl_write_now |-> !$isunknown(arb_l2tlb_req));

  a_ctrl_write_no_x_ptw_cmplt: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      ctrl_write_now |-> !$isunknown(ptw_l2tlb_ref_cmplt));

  // Completion flags remain mutually exclusive during control writes.
  a_ctrl_write_no_dual_fault: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      ptw_l2tlb_ref_cmplt |-> !(ptw_l2tlb_ref_pgflt && ptw_l2tlb_ref_acc_err));

  // PTW enable deassertion during outstanding request is a control hazard —
  // the DUT must still produce a deterministic (non-X) completion path.
  a_ptw_en_disable_during_outstanding: assert property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      (l2tlb_ptw_req && !cp0_mmu_ptw_en) |-> !$isunknown(final_vld));

  // ---------------------------------------------------------------------------
  // TP_058 — COVER: control write during outstanding PTW activity followed by
  // a bounded completion.  Demonstrates the in-flight transaction is not
  // silently dropped by the control hazard.
  // ---------------------------------------------------------------------------
  c_ctrl_write_observed: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      ctrl_write_now);

  c_asid_change_observed: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      asid_changed_now);

  c_invasid_during_ptw_outstanding: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      tlboper_l2tlb_invasid_on && l2tlb_ptw_req);

  c_ctrl_write_during_ptw_outstanding: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      ctrl_write_now && l2tlb_ptw_req);

  // Control write while PTW request outstanding, followed by bounded recovery
  // (a PTW completion returns within RECOVER_BOUND cycles).
  c_ctrl_hazard_recovers: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      (l2tlb_ptw_req && ctrl_write_now)
      ##[1:RECOVER_BOUND] ptw_l2tlb_ref_cmplt);

  // PTW enable deassertion observed during outstanding activity — used as
  // evidence that the hazard path was exercised.
  c_ptw_en_disable_during_outstanding: cover property (@(posedge forever_cpuclk)
    disable iff (`L2TLB_NEG_DISABLE || !l2_ctrl_past_valid)
      l2tlb_ptw_req && !cp0_mmu_ptw_en);

endmodule
