// =============================================================================
// L1DTLB vabuf-no-effect SVA — AUD-014 (Phase 9)
//
// Audit target: when lsu_mmu_vabuf flips between adjacent requests while the
// lookup VA is held stable, the L1DTLB must not change its hit decision,
// returned PA, or response validity purely because of the vabuf toggle.
//
// Bind target: mmu_l1dtlb (clock = forever_cpuclk, reset = cpurst_b)
//
// Guard strategy:
//   * past-valid flag protects $past / $stable / $changed in the first cycle.
//   * Invalidate sources (regs_utlb_clr / tlboper_utlb_clr /
//     tlboper_utlb_inv_va_req / rtu_yy_xx_flush) are excluded from the
//     antecedent window so that a legitimate invalidate-driven hit drop
//     does not trigger a false failure.
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"

module mmu_l1dtlb_vabuf_sva #(
    parameter int VPN_WIDTH    = 27,
    parameter int PPN_WIDTH    = 28,
    parameter int VABUF_WIDTH  = 28
) (
    input  logic                    forever_cpuclk,
    input  logic                    cpurst_b,

    // Invalidate / flush sources (used as antecedent guards)
    input  logic                    regs_utlb_clr,
    input  logic                    tlboper_utlb_clr,
    input  logic                    tlboper_utlb_inv_va_req,
    input  logic                    rtu_yy_xx_flush,

    // Pipe-0 request / vabuf / response
    input  logic                    lsu_mmu_va0_vld,
    input  logic [63:0]             lsu_mmu_va0,
    input  logic [VABUF_WIDTH-1:0]  lsu_mmu_vabuf0,
    input  logic                    p0_hit_vld,
    input  logic                    mmu_lsu_pa0_vld,
    input  logic [PPN_WIDTH-1:0]    mmu_lsu_pa0,

    // Pipe-1 request / vabuf / response
    input  logic                    lsu_mmu_va1_vld,
    input  logic [63:0]             lsu_mmu_va1,
    input  logic [VABUF_WIDTH-1:0]  lsu_mmu_vabuf1,
    input  logic                    p1_hit_vld,
    input  logic                    mmu_lsu_pa1_vld,
    input  logic [PPN_WIDTH-1:0]    mmu_lsu_pa1
);

  // ---------------------------------------------------------------------------
  // past-valid guard: $past / $stable / $changed are only meaningful after the
  // first post-reset clock edge.
  // any_inv_now / any_inv_prev track invalidate sources (current + previous
  // cycle) so the AUD-014 antecedent can exclude any cycle where a legitimate
  // invalidate could have dropped the hit.  Using registered values avoids
  // embedding function calls inside $past(), which keeps the SVA portable
  // across VCS / Xcelium / Questa.
  // ---------------------------------------------------------------------------
  logic l1d_vabuf_past_valid;
  logic any_inv_now;
  logic any_inv_prev;

  always_ff @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      l1d_vabuf_past_valid <= 1'b0;
      any_inv_now          <= 1'b0;
      any_inv_prev         <= 1'b0;
    end else begin
      l1d_vabuf_past_valid <= 1'b1;
      any_inv_prev         <= any_inv_now;
      any_inv_now          <= regs_utlb_clr
                           || tlboper_utlb_clr
                           || tlboper_utlb_inv_va_req
                           || rtu_yy_xx_flush;
    end
  end

  // ---------------------------------------------------------------------------
  // AUD-014 (pipe 0): when the request VA is stable, no invalidate is active
  // in this or the previous cycle, and only vabuf toggles, a previously valid
  // hit must remain valid.
  // ---------------------------------------------------------------------------
  a_vabuf_chg_no_hit_drop_p0: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_vabuf_past_valid)
      ($past(lsu_mmu_va0_vld && p0_hit_vld && !$isunknown(lsu_mmu_vabuf0))
       && lsu_mmu_va0_vld
       && $stable(lsu_mmu_va0)
       && $changed(lsu_mmu_vabuf0)
       && !$isunknown(lsu_mmu_vabuf0)
       && !any_inv_now
       && !any_inv_prev)
    |-> p0_hit_vld);

  a_vabuf_chg_no_hit_drop_p1: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_vabuf_past_valid)
      ($past(lsu_mmu_va1_vld && p1_hit_vld && !$isunknown(lsu_mmu_vabuf1))
       && lsu_mmu_va1_vld
       && $stable(lsu_mmu_va1)
       && $changed(lsu_mmu_vabuf1)
       && !$isunknown(lsu_mmu_vabuf1)
       && !any_inv_now
       && !any_inv_prev)
    |-> p1_hit_vld);

  // ---------------------------------------------------------------------------
  // AUD-014 (pipe 0/1): stricter payload check — when only vabuf toggles and
  // the hit is sustained, PA must remain stable too.  Conditioned on the hit
  // remaining valid this cycle so that a co-incident miss is not a failure.
  // ---------------------------------------------------------------------------
  a_vabuf_chg_pa_stable_p0: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_vabuf_past_valid)
      ($past(lsu_mmu_va0_vld && p0_hit_vld && mmu_lsu_pa0_vld
             && !$isunknown(lsu_mmu_vabuf0) && !$isunknown(mmu_lsu_pa0))
       && lsu_mmu_va0_vld
       && $stable(lsu_mmu_va0)
       && $changed(lsu_mmu_vabuf0)
       && p0_hit_vld
       && mmu_lsu_pa0_vld
       && !any_inv_now
       && !any_inv_prev)
    |-> $stable(mmu_lsu_pa0));

  a_vabuf_chg_pa_stable_p1: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_vabuf_past_valid)
      ($past(lsu_mmu_va1_vld && p1_hit_vld && mmu_lsu_pa1_vld
             && !$isunknown(lsu_mmu_vabuf1) && !$isunknown(mmu_lsu_pa1))
       && lsu_mmu_va1_vld
       && $stable(lsu_mmu_va1)
       && $changed(lsu_mmu_vabuf1)
       && p1_hit_vld
       && mmu_lsu_pa1_vld
       && !any_inv_now
       && !any_inv_prev)
    |-> $stable(mmu_lsu_pa1));

  // ---------------------------------------------------------------------------
  // Covers: gather evidence that the vabuf-toggle event actually occurred
  // during simulation and the DUT returned a coherent response.
  // ---------------------------------------------------------------------------
  c_vabuf_chg_p0_hit_still_valid: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_vabuf_past_valid)
      lsu_mmu_va0_vld && $stable(lsu_mmu_va0) && $changed(lsu_mmu_vabuf0)
      && p0_hit_vld && mmu_lsu_pa0_vld);

  c_vabuf_chg_p1_hit_still_valid: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_vabuf_past_valid)
      lsu_mmu_va1_vld && $stable(lsu_mmu_va1) && $changed(lsu_mmu_vabuf1)
      && p1_hit_vld && mmu_lsu_pa1_vld);

  c_vabuf_chg_p0_va_stable: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_vabuf_past_valid)
      lsu_mmu_va0_vld && $stable(lsu_mmu_va0) && $changed(lsu_mmu_vabuf0));

  c_vabuf_chg_p1_va_stable: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b || !l1d_vabuf_past_valid)
      lsu_mmu_va1_vld && $stable(lsu_mmu_va1) && $changed(lsu_mmu_vabuf1));

endmodule
