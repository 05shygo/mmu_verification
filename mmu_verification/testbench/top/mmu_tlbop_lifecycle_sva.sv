// =============================================================================
// mmu_tlbop_lifecycle_sva.sv
// Phase 6F+: TLBOP lifecycle protocol assertions (bind ct_mmu_tlboper).
//
// Proves 1:1 correspondence of request→grant→done for TLBP/TLBR/TLBWI/TLBWR.
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"
`include "l2tlb_negative_sva_guard.svh"

module mmu_tlbop_lifecycle_sva (
    input logic forever_cpuclk,
    input logic cpurst_b,

    // TLB operation FSM states
    input logic [1:0] tlbp_cur_st,
    input logic [1:0] tlbr_cur_st,
    input logic [1:0] tlbwi_cur_st,
    input logic [1:0] tlbwr_cur_st,

    // Arbiter interface
    input logic tlboper_arb_req,
    input logic arb_tlboper_grant,

    // L2TLB completion
    input logic jtlb_tlboper_cmplt,

    // Register completion
    input logic tlboper_regs_cmplt,

    // INV FSM states (for l2_cmplt assertion context)
    input logic [2:0] tlbiasid_cur_st,
    input logic       tlbiall_cur_st,
    input logic [3:0] tlbiva_cur_st,

    // PTW abort (for TP_044)
    input logic       tlboper_ptw_abort,
    input logic       tlb_lsu_oper,
    input logic       tlb_lsu_oper_flop
);

  localparam [1:0] IDLE      = 2'b00;
  localparam [1:0] TLBOP_WFG = 2'b01;
  localparam [1:0] TLBWR_WFG = 2'b10;

  localparam [2:0] IASID_WT  = 3'b011;
  localparam [3:0] IVA_RD    = 4'b0010;
  localparam [3:0] IVA_WR    = 4'b0100;

  // ── Helper: FSM active (not IDLE) ──────────────────────────────────────
  logic tlbp_active, tlbr_active, tlbwi_active, tlbwr_active;
  assign tlbp_active  = (tlbp_cur_st  != IDLE);
  assign tlbr_active  = (tlbr_cur_st  != IDLE);
  assign tlbwi_active = (tlbwi_cur_st != IDLE);
  assign tlbwr_active = (tlbwr_cur_st != IDLE);

  // INV FSM activity
  logic tlbiasid_active, tlbiall_active, tlbiva_active;
  assign tlbiasid_active = (tlbiasid_cur_st != 3'b000);
  assign tlbiall_active  = (tlbiall_cur_st != 1'b0);
  assign tlbiva_active   = (tlbiva_cur_st != 4'b0000);

  logic any_active;
  assign any_active = tlbp_active || tlbr_active || tlbwi_active || tlbwr_active
                   || tlbiasid_active || tlbiall_active || tlbiva_active;

  // ── G2: Arb request implies an FSM is active ───────────────────────────
  a_arb_req_implies_active: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlboper_arb_req |-> any_active);

  // ── G2: Grant implies an FSM is active AND arb_req was asserted ────────
  a_grant_implies_active: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_tlboper_grant |-> any_active && tlboper_arb_req);

  // ── G2: Grant during active → exactly 1 grant per operation ────────────
  // When an FSM leaves IDLE, eventually it should get exactly 1 grant
  // before returning to IDLE.
  logic tlbp_grant_seen, tlbr_grant_seen, tlbwi_grant_seen, tlbwr_grant_seen;
  logic tlbp_grant_lock, tlbr_grant_lock, tlbwi_grant_lock, tlbwr_grant_lock;

  always_ff @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      tlbp_grant_seen  <= 1'b0; tlbr_grant_seen  <= 1'b0;
      tlbwi_grant_seen <= 1'b0; tlbwr_grant_seen <= 1'b0;
      tlbp_grant_lock  <= 1'b0; tlbr_grant_lock  <= 1'b0;
      tlbwi_grant_lock <= 1'b0; tlbwr_grant_lock <= 1'b0;
    end else begin
      if (tlbp_cur_st == IDLE)  begin tlbp_grant_seen <= 1'b0; tlbp_grant_lock <= 1'b0; end
      else if (arb_tlboper_grant && tlbp_active) begin
        if (!tlbp_grant_lock) tlbp_grant_seen <= 1'b1;
        tlbp_grant_lock <= 1'b1;
      end

      if (tlbr_cur_st == IDLE)  begin tlbr_grant_seen <= 1'b0; tlbr_grant_lock <= 1'b0; end
      else if (arb_tlboper_grant && tlbr_active) begin
        if (!tlbr_grant_lock) tlbr_grant_seen <= 1'b1;
        tlbr_grant_lock <= 1'b1;
      end

      if (tlbwi_cur_st == IDLE) begin tlbwi_grant_seen <= 1'b0; tlbwi_grant_lock <= 1'b0; end
      else if (arb_tlboper_grant && tlbwi_active) begin
        if (!tlbwi_grant_lock) tlbwi_grant_seen <= 1'b1;
        tlbwi_grant_lock <= 1'b1;
      end

      if (tlbwr_cur_st == IDLE) begin tlbwr_grant_seen <= 1'b0; tlbwr_grant_lock <= 1'b0; end
      else if (arb_tlboper_grant && tlbwr_active) begin
        if (!tlbwr_grant_lock) tlbwr_grant_seen <= 1'b1;
        tlbwr_grant_lock <= 1'b1;
      end
    end
  end

  // Each operation must get at least 1 grant before returning to IDLE
  a_tlbp_gets_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlbp_cur_st != IDLE ##1 tlbp_cur_st == IDLE |-> tlbp_grant_seen);

  a_tlbr_gets_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlbr_cur_st != IDLE ##1 tlbr_cur_st == IDLE |-> tlbr_grant_seen);

  a_tlbwi_gets_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlbwi_cur_st != IDLE ##1 tlbwi_cur_st == IDLE |-> tlbwi_grant_seen);

  a_tlbwr_gets_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlbwr_cur_st != IDLE ##1 tlbwr_cur_st == IDLE |-> tlbwr_grant_seen);

  // ── G2: Exactly 1 grant per operation ──────────────────────────────────
  a_tlbp_single_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (tlbp_active && tlbp_grant_lock && arb_tlboper_grant) |-> !tlbp_active);

  a_tlbr_single_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (tlbr_active && tlbr_grant_lock && arb_tlboper_grant) |-> !tlbr_active);

  // ── G2: TLBWI has at most 1 grant ──────────────────────────────────────
  a_tlbwi_single_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (tlbwi_active && tlbwi_grant_lock && arb_tlboper_grant) |-> !tlbwi_active);

  // ── G2: TLBWR has at most 2 grants (read + write phases) ───────────────
  // TLBWR goes through WRWFG(read)→WRTAG(write), can get 2 grants max
  logic tlbwr_grant_double;
  always_ff @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b)
      tlbwr_grant_double <= 1'b0;
    else if (tlbwr_cur_st == IDLE)
      tlbwr_grant_double <= 1'b0;
    else if (tlbwr_grant_lock && arb_tlboper_grant && tlbwr_active)
      tlbwr_grant_double <= 1'b1;
  end
  a_tlbwr_at_most_2_grants: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (tlbwr_active && tlbwr_grant_double && arb_tlboper_grant) |-> !tlbwr_active);

  // ── TP_043: reset during TLBOP clears all FSM to IDLE ──────────────────
  a_reset_clears_tlbop_fsm: assert property (@(posedge forever_cpuclk)
    !cpurst_b |-> (tlbp_cur_st == IDLE && tlbr_cur_st == IDLE
                && tlbwi_cur_st == IDLE && tlbwr_cur_st == IDLE));

  // VCS T-2022.06 does not count these asynchronous reset arcs as FSM hits in
  // the XML bitstring, so keep explicit protocol evidence for waiver review.
  logic       prev_cpurst_b;
  logic [1:0] prev_tlbp_cur_st;
  logic [1:0] prev_tlbr_cur_st;
  logic [1:0] prev_tlbwi_cur_st;
  logic [1:0] prev_tlbwr_cur_st;
  logic [2:0] prev_tlbiasid_cur_st;
  logic [3:0] prev_tlbiva_cur_st;

  int unsigned reset_tlbp_wfg_seen;
  int unsigned reset_tlbr_wfg_seen;
  int unsigned reset_tlbwi_wfg_seen;
  int unsigned reset_tlbwr_wfg_seen;
  int unsigned reset_invasid_wt_seen;
  int unsigned reset_invva_rd_seen;
  int unsigned reset_invva_wr_seen;

  wire reset_fell_on_clk = !cpurst_b && prev_cpurst_b;

  always_ff @(posedge forever_cpuclk) begin
    if (reset_fell_on_clk) begin
      if ((prev_tlbp_cur_st == TLBOP_WFG) && (tlbp_cur_st == IDLE))
        reset_tlbp_wfg_seen++;
      if ((prev_tlbr_cur_st == TLBOP_WFG) && (tlbr_cur_st == IDLE))
        reset_tlbr_wfg_seen++;
      if ((prev_tlbwi_cur_st == TLBOP_WFG) && (tlbwi_cur_st == IDLE))
        reset_tlbwi_wfg_seen++;
      if ((prev_tlbwr_cur_st == TLBWR_WFG) && (tlbwr_cur_st == IDLE))
        reset_tlbwr_wfg_seen++;
      if ((prev_tlbiasid_cur_st == IASID_WT) && (tlbiasid_cur_st == 3'b000))
        reset_invasid_wt_seen++;
      if ((prev_tlbiva_cur_st == IVA_RD) && (tlbiva_cur_st == 4'b0000))
        reset_invva_rd_seen++;
      if ((prev_tlbiva_cur_st == IVA_WR) && (tlbiva_cur_st == 4'b0000))
        reset_invva_wr_seen++;
    end

    prev_cpurst_b        <= cpurst_b;
    prev_tlbp_cur_st     <= tlbp_cur_st;
    prev_tlbr_cur_st     <= tlbr_cur_st;
    prev_tlbwi_cur_st    <= tlbwi_cur_st;
    prev_tlbwr_cur_st    <= tlbwr_cur_st;
    prev_tlbiasid_cur_st <= tlbiasid_cur_st;
    prev_tlbiva_cur_st   <= tlbiva_cur_st;
  end

  a_reset_from_tlbp_wfg_clears: assert property (@(posedge forever_cpuclk)
    (reset_fell_on_clk && (prev_tlbp_cur_st == TLBOP_WFG)) |-> (tlbp_cur_st == IDLE));
  a_reset_from_tlbr_wfg_clears: assert property (@(posedge forever_cpuclk)
    (reset_fell_on_clk && (prev_tlbr_cur_st == TLBOP_WFG)) |-> (tlbr_cur_st == IDLE));
  a_reset_from_tlbwi_wfg_clears: assert property (@(posedge forever_cpuclk)
    (reset_fell_on_clk && (prev_tlbwi_cur_st == TLBOP_WFG)) |-> (tlbwi_cur_st == IDLE));
  a_reset_from_tlbwr_wfg_clears: assert property (@(posedge forever_cpuclk)
    (reset_fell_on_clk && (prev_tlbwr_cur_st == TLBWR_WFG)) |-> (tlbwr_cur_st == IDLE));
  a_reset_from_invasid_wt_clears: assert property (@(posedge forever_cpuclk)
    (reset_fell_on_clk && (prev_tlbiasid_cur_st == IASID_WT)) |-> (tlbiasid_cur_st == 3'b000));
  a_reset_from_invva_rd_clears: assert property (@(posedge forever_cpuclk)
    (reset_fell_on_clk && (prev_tlbiva_cur_st == IVA_RD)) |-> (tlbiva_cur_st == 4'b0000));
  a_reset_from_invva_wr_clears: assert property (@(posedge forever_cpuclk)
    (reset_fell_on_clk && (prev_tlbiva_cur_st == IVA_WR)) |-> (tlbiva_cur_st == 4'b0000));

  c_reset_from_tlbp_wfg: cover property (@(posedge forever_cpuclk)
    reset_fell_on_clk && (prev_tlbp_cur_st == TLBOP_WFG) && (tlbp_cur_st == IDLE));
  c_reset_from_tlbr_wfg: cover property (@(posedge forever_cpuclk)
    reset_fell_on_clk && (prev_tlbr_cur_st == TLBOP_WFG) && (tlbr_cur_st == IDLE));
  c_reset_from_tlbwi_wfg: cover property (@(posedge forever_cpuclk)
    reset_fell_on_clk && (prev_tlbwi_cur_st == TLBOP_WFG) && (tlbwi_cur_st == IDLE));
  c_reset_from_tlbwr_wfg: cover property (@(posedge forever_cpuclk)
    reset_fell_on_clk && (prev_tlbwr_cur_st == TLBWR_WFG) && (tlbwr_cur_st == IDLE));
  c_reset_from_invasid_wt: cover property (@(posedge forever_cpuclk)
    reset_fell_on_clk && (prev_tlbiasid_cur_st == IASID_WT) && (tlbiasid_cur_st == 3'b000));
  c_reset_from_invva_rd: cover property (@(posedge forever_cpuclk)
    reset_fell_on_clk && (prev_tlbiva_cur_st == IVA_RD) && (tlbiva_cur_st == 4'b0000));
  c_reset_from_invva_wr: cover property (@(posedge forever_cpuclk)
    reset_fell_on_clk && (prev_tlbiva_cur_st == IVA_WR) && (tlbiva_cur_st == 4'b0000));

  final begin
    $display("[TLBOP_RESET_SVA_COVER] tlbp_wfg=%0d tlbr_wfg=%0d tlbwi_wfg=%0d tlbwr_wfg=%0d invasid_wt=%0d invva_rd=%0d invva_wr=%0d",
      reset_tlbp_wfg_seen, reset_tlbr_wfg_seen, reset_tlbwi_wfg_seen,
      reset_tlbwr_wfg_seen, reset_invasid_wt_seen, reset_invva_rd_seen,
      reset_invva_wr_seen);
  end

  // ── TP_043: reset must not leave stale done/grant ──────────────────────
  a_reset_no_stale_done: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    !cpurst_b ##1 cpurst_b |-> !tlboper_regs_cmplt && !arb_tlboper_grant);

  // ── TP_044: tlboper_ptw_abort marks an uncaptured LSU invalidate ───────
  // OpenC910 drives this as a level while the raw LSU invalidate request is
  // pending but has not yet been captured by TLBOper.  It is not a one-cycle
  // pulse when real LSU CTCQ holds the request until mmu_lsu_tlb_inv_done.
  a_ptw_abort_only_uncaptured_lsu: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlboper_ptw_abort |-> (tlb_lsu_oper && !tlb_lsu_oper_flop));

  a_ptw_abort_drops_after_capture: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlb_lsu_oper_flop |-> !tlboper_ptw_abort);

  // ── G2: L2TLB completion only when an FSM is active ────────────────────
  // l2tlb_tlboper_cmplt = final_vld && (final_acc_type == 3'b001) is a pure
  // combinational pipeline signal.  It can fire up to 3 cycles after the FSM
  // returns to IDLE due to pipeline drain, or during post-reset pipeline
  // flush.  The 3-cycle $past window covers multi-stage pipeline delay from
  // FSM → arbiter → L2TLB → completion path.
  a_l2_cmplt_during_active: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    jtlb_tlboper_cmplt |-> any_active || $past(any_active) || $past(any_active, 2) || $past(any_active, 3));

  // ── G2: regs_cmplt only when an FSM is active (or just finished) ──────
  // regs_cmplt is pulsed when the operation is done
  a_regs_cmplt_implies_was_active: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlboper_regs_cmplt |-> any_active || $past(any_active));

  // ── Cover properties for evidence ──────────────────────────────────────
  c_tlbp_full_lifecycle: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlbp_cur_st == IDLE ##1 tlbp_active ##1 arb_tlboper_grant
    ##1 jtlb_tlboper_cmplt ##1 tlbp_cur_st == IDLE);

  c_tlbr_full_lifecycle: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlbr_cur_st == IDLE ##1 tlbr_active ##1 arb_tlboper_grant
    ##1 jtlb_tlboper_cmplt ##1 tlbr_cur_st == IDLE);

  c_tlbwi_full_lifecycle: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlbwi_cur_st == IDLE ##1 tlbwi_active ##1 arb_tlboper_grant
    ##1 tlbwi_cur_st == IDLE);

  c_tlbwr_full_lifecycle: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlbwr_cur_st == IDLE ##1 tlbwr_active ##1 arb_tlboper_grant
    ##1 tlbwr_cur_st == IDLE);

endmodule
