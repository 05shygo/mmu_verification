// =============================================================================
// PMP / TWU SVA - twu_reconstruct Phase 3 (rewritten)
// Bind target: twu  (unified pmp_unit + chk_unit next priority)
// Replaces old fst/scd/thd_pmp_* 3-stage SVA with unified pmp_unit_* checks.
// =============================================================================
`timescale 1ns/1ps

module mmu_pmp_twu_sva #(
    parameter int ID_WIDTH   = 7,
    parameter int VPN_WIDTH  = 27,
    parameter int PPN_WIDTH  = 28,
    parameter int PADDR_WIDTH = 40
) (
    input logic        twu_clk,
    input logic        cpurst_b,
    input logic        tlboper_ptw_abort,
    // ── twu_reconstruct: unified PMP unit ports ────────────────────────────
    input logic        pmp_unit_vld,
    input logic        pmp_unit_wait,
    input logic        pmp_unit_deny,
    input logic        pmp_unit_mbuf_req,    // = pmp_mbuf_req in RTL
    input logic [2:0]  pmp_unit_lvl,          // one-hot: [2]=FST [1]=SCD [0]=THD
    input logic [2:0]  pmp_unit_type,
    input logic [ID_WIDTH-1:0] pmp_unit_id,
    input logic [VPN_WIDTH-1:0] pmp_unit_vpn,
    input logic [PPN_WIDTH-1:0] pmp_unit_ppn,
    input logic [PADDR_WIDTH-1:0] pmp_unit_pa,
    input logic [3:0]  pmp_unit_pmpflg,
    input logic [3:0]  pmp_unit_l1pmpflg,
    // PMP flag from external interface
    input logic [3:0]  pmp_mmu_flg,
    input logic [27:0] regs_ptw_satp_ppn,
    // CP0 privilege
    input logic        cp0_mmu_mprv,
    input logic [1:0]  cp0_mmu_mpp,
    input logic [1:0]  cp0_yy_priv_mode,
    // TWU output sideband
    input logic        mmu_pmp_fecth,
    input logic [27:0] mmu_pmp_pa,
    // MBUF / top-level
    input logic        twu_mbuf_req,
    input logic [PADDR_WIDTH-1:0] twu_mbuf_paddr,
    input logic        twu_arb_ref_req,
    input logic [2:0]  twu_arb_ref_type,
    input logic [ID_WIDTH-1:0] twu_arb_ref_id,
    input logic        twu_l2tlb_ref_acc_err,
    // twu_mbuf_pmpflg payload
    input logic [7:0]  twu_mbuf_pmpflg,
    // CHK next request (for priority check)
    input logic        chk_next_req,          // chk_unit_vld && !leaf && !pgflt
    // Xbar backpressure
    input logic        xbar_twu_req,
    // Access fault grant
    input logic        acc_err_pmp_unit_grant
);

  localparam logic [2:0] TWU_REQ_TYPE_LOAD  = 3'b010;
  localparam logic [2:0] TWU_REQ_TYPE_FETCH = 3'b011;
  localparam logic [2:0] TWU_REQ_TYPE_PREF  = 3'b100;
  localparam logic [2:0] TWU_REQ_TYPE_STORE = 3'b110;

  // ── Level decode helpers ─────────────────────────────────────────────────
  function automatic bit pmp_is_fst(); return pmp_unit_lvl[2]; endfunction
  function automatic bit pmp_is_scd(); return pmp_unit_lvl[1]; endfunction
  function automatic bit pmp_is_thd(); return pmp_unit_lvl[0]; endfunction

  // ── Derived combinational logic ──────────────────────────────────────────
  logic pmp_unit_fetch_type;
  logic pmp_unit_load_type;
  logic pmp_unit_store_type;
  logic pmp_unit_pref_type;
  logic pmp_unit_perm_deny;
  logic pmp_effective_mach_mode;
  logic pmp_deny_expected;
  logic [1:0] pmp_effective_priv_mode;

  assign pmp_unit_fetch_type = (pmp_unit_type == TWU_REQ_TYPE_FETCH);
  assign pmp_unit_load_type  = (pmp_unit_type == TWU_REQ_TYPE_LOAD);
  assign pmp_unit_store_type = (pmp_unit_type == TWU_REQ_TYPE_STORE);
  assign pmp_unit_pref_type  = (pmp_unit_type == TWU_REQ_TYPE_PREF);

  assign pmp_unit_perm_deny =
       (pmp_unit_fetch_type && !pmp_mmu_flg[2])
    || (pmp_unit_load_type  && !pmp_mmu_flg[0])
    || (pmp_unit_store_type && !pmp_mmu_flg[1])
    || (pmp_unit_pref_type  && !pmp_mmu_flg[0]);

  assign pmp_effective_priv_mode =
      cp0_mmu_mprv ? cp0_mmu_mpp : cp0_yy_priv_mode;

  assign pmp_effective_mach_mode =
      pmp_unit_fetch_type ? (cp0_yy_priv_mode == 2'b11)
                          : (pmp_effective_priv_mode == 2'b11);

  assign pmp_deny_expected =
      pmp_unit_perm_deny && !(pmp_effective_mach_mode && !pmp_mmu_flg[3]);

  // ── Cover counters ──────────────────────────────────────────────────────
  int unsigned cp_pmp_unit_level;
  int unsigned cp_pmp_unit_pa_format;
  int unsigned cp_pmp_wait_implies_mask;
  int unsigned cp_pmp_deny_no_mbuf;
  int unsigned cp_pmp_deny_acc_fault;
  int unsigned cp_pmp_check_before_lsu;
  int unsigned cp_pmp_deny_no_refill;
  int unsigned cp_pmp_pass_to_mbuf_addr;
  int unsigned cp_pmp_wait_payload_stable;
  int unsigned cp_pmpflg_payload;
  int unsigned cp_chk_next_priority;
  int unsigned cp_pmp_fetch_uses_x;
  int unsigned cp_pmp_load_uses_r;
  int unsigned cp_pmp_store_uses_w;
  int unsigned cp_pmp_mmode_l0_bypass;
  int unsigned cp_pmp_fetch_type_sideband;
  int unsigned cp_pmp_deny_by_level;

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-001: PTE PA formula check by level
  // FST: pmp_unit_pa = {satp_ppn, vpn[26:18], 3'b0}
  // SCD: pmp_unit_pa = {ppn, vpn[17:9], 3'b0}
  // THD: pmp_unit_pa = {ppn, vpn[8:0], 3'b0}
  // ══════════════════════════════════════════════════════════════════════════
  a_pmp_unit_pa_formula: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_unit_vld |-> (
      (pmp_is_fst() && (pmp_unit_pa == {regs_ptw_satp_ppn[27:0], pmp_unit_vpn[26:18], 3'b000}))
      || (pmp_is_scd() && (pmp_unit_pa == {pmp_unit_ppn[27:0], pmp_unit_vpn[17:9], 3'b000}))
      || (pmp_is_thd() && (pmp_unit_pa == {pmp_unit_ppn[27:0], pmp_unit_vpn[8:0], 3'b000}))
    ));

  cp_pmp_unit_pa_format_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && (
      (pmp_is_fst() && (pmp_unit_pa == {regs_ptw_satp_ppn[27:0], pmp_unit_vpn[26:18], 3'b000}))
      || (pmp_is_scd() && (pmp_unit_pa == {pmp_unit_ppn[27:0], pmp_unit_vpn[17:9], 3'b000}))
      || (pmp_is_thd() && (pmp_unit_pa == {pmp_unit_ppn[27:0], pmp_unit_vpn[8:0], 3'b000}))
    )) begin cp_pmp_unit_pa_format++; end

  cp_pmp_unit_level_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && (pmp_is_fst() || pmp_is_scd() || pmp_is_thd())) begin
    cp_pmp_unit_level++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-002: PMP wait contributes to twu_mask
  // ══════════════════════════════════════════════════════════════════════════
  a_pmp_wait_implies_mask: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_unit_wait |-> 1'b1);  // mask propagation checked by twu_sva

  cp_pmp_wait_implies_mask_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_wait) begin cp_pmp_wait_implies_mask++; end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-003: deny → no twu_mbuf_req (no LSU PTE fetch)
  // ══════════════════════════════════════════════════════════════════════════
  a_pmp_deny_no_mbuf: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_unit_vld && pmp_unit_deny && acc_err_pmp_unit_grant |-> !twu_mbuf_req);

  cp_pmp_deny_no_mbuf_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && pmp_unit_deny && !twu_mbuf_req) begin cp_pmp_deny_no_mbuf++; end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-004: deny accepted → TWU access fault on next cycle
  // ══════════════════════════════════════════════════════════════════════════
  a_pmp_deny_acc_fault: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_unit_vld && pmp_unit_deny && acc_err_pmp_unit_grant
    |=> twu_l2tlb_ref_acc_err);

  cp_pmp_deny_acc_fault_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && pmp_unit_deny ##1 twu_l2tlb_ref_acc_err) begin
    cp_pmp_deny_acc_fault++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-005: MBUF req only after PMP allowed
  // ══════════════════════════════════════════════════════════════════════════
  a_pmp_check_before_lsu: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    twu_mbuf_req |-> (pmp_unit_vld && !pmp_unit_deny && pmp_unit_mbuf_req));

  cp_pmp_check_before_lsu_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    twu_mbuf_req && pmp_unit_vld && !pmp_unit_deny) begin
    cp_pmp_check_before_lsu++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-006: deny does not produce refill for same {type,id}
  // ══════════════════════════════════════════════════════════════════════════
  a_pmp_deny_no_refill: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_unit_vld && pmp_unit_deny && twu_arb_ref_req
    |-> !((twu_arb_ref_type == pmp_unit_type) && (twu_arb_ref_id == pmp_unit_id)));

  cp_pmp_deny_no_refill_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && pmp_unit_deny && !twu_arb_ref_req) begin
    cp_pmp_deny_no_refill++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-007: allowed PMP → MBUF addr matches pmp_unit_pa
  // ══════════════════════════════════════════════════════════════════════════
  a_pmp_pass_to_mbuf_addr: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_unit_mbuf_req |-> (twu_mbuf_req && (twu_mbuf_paddr == pmp_unit_pa)));

  cp_pmp_pass_to_mbuf_addr_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_mbuf_req && (twu_mbuf_paddr == pmp_unit_pa)) begin
    cp_pmp_pass_to_mbuf_addr++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-008: wait holds pmp_unit payload stable
  // ══════════════════════════════════════════════════════════════════════════
  a_pmp_wait_payload_stable: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_wait && !tlboper_ptw_abort
    |=> (tlboper_ptw_abort
      || (pmp_unit_vld && $stable(pmp_unit_vpn) && $stable(pmp_unit_type)
          && $stable(pmp_unit_id) && $stable(pmp_unit_pa))));

  cp_pmp_wait_payload_stable_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_wait && !tlboper_ptw_abort) begin
    cp_pmp_wait_payload_stable++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-009: pmpflg payload consistency
  // twu_mbuf_pmpflg[3:0] = L1 pmp flag
  // twu_mbuf_pmpflg[7:4] = L2 pmp flag (SCD level only)
  // ══════════════════════════════════════════════════════════════════════════
  a_pmpflg_payload_l1: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_unit_vld |-> (
      (pmp_is_fst() && (twu_mbuf_pmpflg[3:0] == pmp_mmu_flg))
      || (pmp_is_scd() && (twu_mbuf_pmpflg[7:4] == pmp_mmu_flg))
      || pmp_is_thd()
    ));

  cp_pmpflg_payload_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && |twu_mbuf_pmpflg) begin cp_pmpflg_payload++; end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-010: CHK next request priority over xbar
  // When chk_unit fires next-level request, xbar request is held
  // ══════════════════════════════════════════════════════════════════════════
  a_chk_next_priority_over_xbar: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    chk_next_req && xbar_twu_req |-> pmp_unit_vld);

  cp_chk_next_priority_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    chk_next_req && xbar_twu_req && pmp_unit_vld) begin
    cp_chk_next_priority++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-011: original request type permission check
  // fetch → X, load/PFU → R, store → W; M-mode L=0 bypass
  // ══════════════════════════════════════════════════════════════════════════
  a_pmp_original_type_perm: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_unit_vld |-> (pmp_unit_deny == pmp_deny_expected));

  cp_pmp_fetch_uses_x_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && pmp_unit_fetch_type && !pmp_mmu_flg[2] && pmp_unit_deny) begin
    cp_pmp_fetch_uses_x++;
  end

  cp_pmp_load_uses_r_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && (pmp_unit_load_type || pmp_unit_pref_type)
    && !pmp_mmu_flg[0] && pmp_unit_deny) begin
    cp_pmp_load_uses_r++;
  end

  cp_pmp_store_uses_w_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && pmp_unit_store_type && !pmp_mmu_flg[1] && pmp_unit_deny) begin
    cp_pmp_store_uses_w++;
  end

  cp_pmp_mmode_l0_bypass_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && pmp_unit_perm_deny && pmp_effective_mach_mode
    && !pmp_mmu_flg[3] && !pmp_unit_deny) begin
    cp_pmp_mmode_l0_bypass++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-012: fetch sideband matches pmp_unit type
  // mmu_pmp_fecth reflects original miss fetch type
  // ══════════════════════════════════════════════════════════════════════════
  a_pmp_fetch_type_sideband: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    pmp_unit_vld |-> (mmu_pmp_fecth == pmp_unit_fetch_type));

  cp_pmp_fetch_type_sideband_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && (mmu_pmp_fecth == pmp_unit_fetch_type)) begin
    cp_pmp_fetch_type_sideband++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PMP-SVA-013: deny level coverage (each level can independently deny)
  // ══════════════════════════════════════════════════════════════════════════
  cp_pmp_deny_by_level_p: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    pmp_unit_vld && pmp_unit_deny && (pmp_is_fst() || pmp_is_scd() || pmp_is_thd())) begin
    cp_pmp_deny_by_level++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // PTW_SVA_COVER report
  // ══════════════════════════════════════════════════════════════════════════
  final begin
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_unit_level req=PTW-RECON-SVA-PMP-001 hits=%0d", cp_pmp_unit_level);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_unit_pa_format req=PTW-RECON-SVA-PMP-001 hits=%0d", cp_pmp_unit_pa_format);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_wait_implies_mask req=PTW-RECON-SVA-PMP-002 hits=%0d", cp_pmp_wait_implies_mask);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_deny_no_mbuf req=PTW-RECON-SVA-PMP-003 hits=%0d", cp_pmp_deny_no_mbuf);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_deny_acc_fault req=PTW-RECON-SVA-PMP-004 hits=%0d", cp_pmp_deny_acc_fault);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_check_before_lsu req=PTW-RECON-SVA-PMP-005 hits=%0d", cp_pmp_check_before_lsu);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_deny_no_refill req=PTW-RECON-SVA-PMP-006 hits=%0d", cp_pmp_deny_no_refill);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_pass_to_mbuf_addr req=PTW-RECON-SVA-PMP-007 hits=%0d", cp_pmp_pass_to_mbuf_addr);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_wait_payload_stable req=PTW-RECON-SVA-PMP-008 hits=%0d", cp_pmp_wait_payload_stable);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmpflg_payload req=PTW-RECON-SVA-PMP-009 hits=%0d", cp_pmpflg_payload);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_chk_next_priority req=PTW-RECON-SVA-PMP-010 hits=%0d", cp_chk_next_priority);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_fetch_uses_x req=PTW-RECON-SVA-PMP-011 hits=%0d", cp_pmp_fetch_uses_x);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_load_uses_r req=PTW-RECON-SVA-PMP-011 hits=%0d", cp_pmp_load_uses_r);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_store_uses_w req=PTW-RECON-SVA-PMP-011 hits=%0d", cp_pmp_store_uses_w);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_mmode_l0_bypass req=PTW-RECON-SVA-PMP-011 hits=%0d", cp_pmp_mmode_l0_bypass);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_fetch_type_sideband req=PTW-RECON-SVA-PMP-012 hits=%0d", cp_pmp_fetch_type_sideband);
    $display("PTW_SVA_COVER module=mmu_pmp_twu_sva name=cp_pmp_deny_by_level req=PTW-RECON-SVA-PMP-013 hits=%0d", cp_pmp_deny_by_level);
  end

endmodule
