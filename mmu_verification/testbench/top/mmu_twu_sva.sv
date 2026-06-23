// =============================================================================
// TWU internal SVA (bind twu) - twu_reconstruct Phase 3 (rewritten)
// Replaces old fst/scd/thd pipeline SVA with unified pmp_unit/chk_unit checks.
// =============================================================================
`timescale 1ns/1ps

module mmu_twu_sva (
    input logic        twu_clk,
    input logic        cpurst_b,
    // ── twu_reconstruct: unified TWU protocol signals ─────────────────────
    input logic        twu_mask,
    input logic        twu_data_ready,       // scalar ready (was [2:0])
    input logic        twu_csr_cross,
    input logic [63:0] csr_data_flop,
    input logic        csr_refill_req,       // CSR FSM refill request (single-source)
    // Unified PMP unit
    input logic        pmp_unit_vld,
    input logic        pmp_unit_wait,
    input logic        pmp_unit_deny,
    input logic [2:0]  pmp_unit_lvl,         // one-hot: [2]=FST [1]=SCD [0]=THD
    // Unified CHK unit
    input logic        chk_unit_vld,
    input logic        chk_unit_wait,
    input logic        chk_unit_leaf_vld,
    input logic        chk_unit_page_flt,
    input logic        chk_unit_refill_req,
    input logic        chk_unit_csr_req,
    input logic [2:0]  chk_unit_lvl,         // one-hot: [2]=FST [1]=SCD [0]=THD
    // Xbar / CSR idle
    input logic        xbar_twu_req,
    input logic        csr_idle,
    input logic        tlboper_ptw_abort
);

  // ── Derived signals ─────────────────────────────────────────────────────
  // CHK next: non-leaf, no page fault → needs next-level PMP walk
  logic chk_next;
  assign chk_next = chk_unit_vld && !chk_unit_leaf_vld && !chk_unit_page_flt;

  // Idle: no PMP, no CHK, CSR FSM idle
  logic twu_idle;
  assign twu_idle = !pmp_unit_vld && !chk_unit_vld && csr_idle;

  // ── Cover counters ──────────────────────────────────────────────────────
  int unsigned cp_twu_mask_unified_equation;
  int unsigned cp_twu_scalar_ready_hold;
  int unsigned cp_twu_idle_implies_no_mask;
  int unsigned cp_twu_multi_inflight_legal;

  // ══════════════════════════════════════════════════════════════════════════
  // TWU-SVA-001: Unified mask equation
  // twu_mask = pmp_unit_wait | chk_next × (next-level pmp wait)
  // Busy-no-mask is legal (pmp_unit active but not waiting, or csr active).
  // ══════════════════════════════════════════════════════════════════════════
  a_twu_mask_unified_equation: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    twu_mask == (pmp_unit_wait || chk_next));

  cp_twu_mask_unified_equation_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    (twu_mask && pmp_unit_wait)
    || (twu_mask && chk_next)
    || (!twu_mask && !pmp_unit_wait && !chk_next)) begin
    cp_twu_mask_unified_equation++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // TWU-SVA-002: Idle → mask must be 0; busy-no-mask is legal
  // ══════════════════════════════════════════════════════════════════════════
  a_twu_idle_implies_no_mask: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    twu_idle |-> !twu_mask);

  cp_twu_idle_implies_no_mask_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    twu_idle && !twu_mask) begin
    cp_twu_idle_implies_no_mask++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // TWU-SVA-003: CSR grant single-active (csr_refill_req is single-bit)
  // ══════════════════════════════════════════════════════════════════════════
  a_twu_csr_single_source: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    chk_unit_csr_req |-> !chk_unit_refill_req);

  // ══════════════════════════════════════════════════════════════════════════
  // TWU-SVA-004: Scalar ready — CHK wait implies !ready (RTL invariant)
  // ══════════════════════════════════════════════════════════════════════════
  a_twu_scalar_ready_relation: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    chk_unit_wait |-> !twu_data_ready);

  cp_twu_scalar_ready_hold_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    !twu_data_ready || chk_unit_wait) begin
    cp_twu_scalar_ready_hold++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // TWU-SVA-005: CHK next priority — when chk_next fires, xbar request
  //              is held (mask high)
  // ══════════════════════════════════════════════════════════════════════════
  a_twu_chk_next_priority: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    chk_next |-> twu_mask);

  // ══════════════════════════════════════════════════════════════════════════
  // TWU-SVA-006: Multi-level inflight is legal in unified TWU
  // ══════════════════════════════════════════════════════════════════════════
  c_twu_multi_inflight_legal: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && chk_unit_vld) begin
    cp_twu_multi_inflight_legal++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // TWU-SVA-007: 2M CSR cross updates csr_data_flop (preserved from old SVA)
  // ══════════════════════════════════════════════════════════════════════════
  a_twu_2m_cross_data: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    (twu_crs2_2m && twu_csr_cross) |=> (csr_data_flop != $past(csr_data_flop)));

  final begin
    $display("PTW_SVA_COVER module=mmu_twu_sva name=cp_twu_mask_unified_equation req=PTW-RECON-SVA-TWU-001 hits=%0d", cp_twu_mask_unified_equation);
    $display("PTW_SVA_COVER module=mmu_twu_sva name=cp_twu_idle_implies_no_mask req=PTW-RECON-SVA-TWU-002 hits=%0d", cp_twu_idle_implies_no_mask);
    $display("PTW_SVA_COVER module=mmu_twu_sva name=cp_twu_scalar_ready_hold req=PTW-RECON-SVA-TWU-003 hits=%0d", cp_twu_scalar_ready_hold);
    $display("PTW_SVA_COVER module=mmu_twu_sva name=cp_twu_multi_inflight_legal req=PTW-RECON-SVA-TWU-004 hits=%0d", cp_twu_multi_inflight_legal);
  end

endmodule
