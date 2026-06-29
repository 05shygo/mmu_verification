// =============================================================================
// L1DTLB T0/T1 response pulse-width SVA — AUD-015 (Phase 9)
//
// Audit target: L1DTLB response pulses are single-cycle unless a new request
// sustains them.
//   * T0 responses: mmu_lsu_pa0_vld / mmu_lsu_pa1_vld, page_fault0 / page_fault1
//   * T1 responses: mmu_lsu_access_fault0 / mmu_lsu_access_fault1
//
// Rule: after a response pulse rises, it must deassert the next cycle unless a
// new request (lsu_mmu_vaN_vld) is presented in that same next cycle.  This
// catches any path that latches a response high without an ongoing request.
//
// Bind target: mmu_l1dtlb (clock = forever_cpuclk, reset = cpurst_b)
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"

module mmu_l1dtlb_pulse_width_sva (
    input  logic forever_cpuclk,
    input  logic cpurst_b,

    // Request valids (sustain qualifier)
    input  logic lsu_mmu_va0_vld,
    input  logic lsu_mmu_va1_vld,

    // T0 response pulses
    input  logic mmu_lsu_pa0_vld,
    input  logic mmu_lsu_pa1_vld,
    input  logic mmu_lsu_page_fault0,
    input  logic mmu_lsu_page_fault1,

    // T1 response pulses
    input  logic mmu_lsu_access_fault0,
    input  logic mmu_lsu_access_fault1
);

  // ---------------------------------------------------------------------------
  // past-valid guard: $rose / $past only meaningful after the first edge.
  // ---------------------------------------------------------------------------
  logic l1d_pulse_past_valid;

  always_ff @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      l1d_pulse_past_valid <= 1'b0;
    end else begin
      l1d_pulse_past_valid <= 1'b1;
    end
  end

  // ---------------------------------------------------------------------------
  // AUD-015 (T0 pa_vld): after pa_vld rises it must fall the next cycle unless
  // a new request is presented (lsu_mmu_vaN_vld high in the deassertion cycle).
  // ---------------------------------------------------------------------------
  a_pa0_pulse_single_cycle: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_pa0_vld) |-> (!mmu_lsu_pa0_vld || lsu_mmu_va0_vld));

  a_pa1_pulse_single_cycle: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_pa1_vld) |-> (!mmu_lsu_pa1_vld || lsu_mmu_va1_vld));

  // ---------------------------------------------------------------------------
  // AUD-015 (T0 page_fault): page_fault is a terminal response that is always
  // accompanied by pa_vld; it must pulse for a single cycle unless a new
  // request re-triggers it.
  // ---------------------------------------------------------------------------
  a_page_fault0_pulse_single_cycle: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_page_fault0)
      |-> (!mmu_lsu_page_fault0 || lsu_mmu_va0_vld));

  a_page_fault1_pulse_single_cycle: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_page_fault1)
      |-> (!mmu_lsu_page_fault1 || lsu_mmu_va1_vld));

  // ---------------------------------------------------------------------------
  // AUD-015 (T1 access_fault): access_fault arrives one cycle later than the
  // T0 response in this design.  It must still be a single-cycle pulse and is
  // only allowed to re-assert when a new request re-enters the pipeline.
  // Because access_fault is a T1 (1-cycle-delayed) response, the request that
  // caused it (lsu_mmu_vaN_vld) was valid in the PREVIOUS cycle, so the
  // sustain qualifier must be sampled with $past.  The $past read is safe:
  // l1d_pulse_past_valid disables the assertion on the very first cycle.
  // ---------------------------------------------------------------------------
  a_access_fault0_pulse_single_cycle: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_access_fault0)
      |-> (!mmu_lsu_access_fault0 || $past(lsu_mmu_va0_vld)));

  a_access_fault1_pulse_single_cycle: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_access_fault1)
      |-> (!mmu_lsu_access_fault1 || $past(lsu_mmu_va1_vld)));

  // ---------------------------------------------------------------------------
  // Structural helpers: terminal responses require pa_vld.
  //   * page_fault is a T0 (same-cycle) response → pa_vld checked this cycle.
  //   * access_fault is a T1 (1-cycle-delayed) response → the pa_vld that
  //     accompanied the fault was valid one cycle earlier, so check $past and
  //     guard the first cycle with l1d_pulse_past_valid.
  // ---------------------------------------------------------------------------
  a_page_fault0_has_pa_vld: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
      mmu_lsu_page_fault0 |-> mmu_lsu_pa0_vld);

  a_page_fault1_has_pa_vld: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
      mmu_lsu_page_fault1 |-> mmu_lsu_pa1_vld);

  a_access_fault0_has_pa_vld: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      mmu_lsu_access_fault0 |-> $past(mmu_lsu_pa0_vld));

  a_access_fault1_has_pa_vld: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      mmu_lsu_access_fault1 |-> $past(mmu_lsu_pa1_vld));

  // ---------------------------------------------------------------------------
  // Covers: gather evidence that each pulse type fired during simulation.
  // ---------------------------------------------------------------------------
  c_pa0_pulse: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_pa0_vld));

  c_pa1_pulse: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_pa1_vld));

  c_page_fault0_pulse: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_page_fault0));

  c_page_fault1_pulse: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_page_fault1));

  c_access_fault0_pulse: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_access_fault0));

  c_access_fault1_pulse: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_access_fault1));

  // Back-to-back pulse sustain evidence (legitimate multi-cycle pulse caused
  // by sustained request).
  c_pa0_pulse_sustained_by_req: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_pulse_past_valid)
      $rose(mmu_lsu_pa0_vld) ##1 mmu_lsu_pa0_vld && lsu_mmu_va0_vld);

endmodule
