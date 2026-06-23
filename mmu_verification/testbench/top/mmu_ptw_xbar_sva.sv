// =============================================================================
// PTW PDE-to-TWU xbar SVA - Stage 5
// Bind target: one_to_four_xbar
// =============================================================================
`timescale 1ns/1ps

module mmu_ptw_xbar_sva #(
    parameter int VPN_WIDTH  = 27,
    parameter int PPN_WIDTH  = 28,
    parameter int PTE_LEVEL  = 3,
    parameter int TYPE_WIDTH = 3,
    parameter int ID_WIDTH   = 7
) (
    input logic                  forever_cpuclk,
    input logic                  cpurst_b,
    input logic [3:0]            twu_mask,
    input logic                  PDE_xbar_req,
    input logic                  L2PDE_xbar_hit_vld,
    input logic                  L1PDE_xbar_hit_vld,
    input logic [PPN_WIDTH-1:0]  PDE_xbar_ppn,
    input logic [VPN_WIDTH-1:0]  PDE_xbar_vpn,
    input logic [TYPE_WIDTH-1:0] PDE_xbar_type,
    input logic [ID_WIDTH-1:0]   PDE_xbar_id,
    input logic [3:0]            xbar_twu_req,
    input logic [PTE_LEVEL-2:0]  xbar_twu_hit_level,
    input logic [PPN_WIDTH-1:0]  xbar_twu_ppn,
    input logic [VPN_WIDTH-1:0]  xbar_twu_vpn,
    input logic [TYPE_WIDTH-1:0] xbar_twu_type,
    input logic [ID_WIDTH-1:0]   xbar_twu_id,
    // ── twu_reconstruct Phase 3: l1pmpflg payload ports ──────────────────
    input logic [3:0]            PDE_xbar_l1pmpflg,
    input logic [3:0]            xbar_twu_l1pmpflg,
    input logic                  tlboper_ptw_abort,
    input logic                  xbar_pde_ready,
    input logic                  twu_xbar_mask,
    input logic [1:0]            twu_hash,
    input logic [3:0]            twu_req_hash
);

  int unsigned cp_xbar_hash0_hits;
  int unsigned cp_xbar_hash1_hits;
  int unsigned cp_xbar_hash2_hits;
  int unsigned cp_xbar_hash3_hits;
  int unsigned cp_xbar_target_mask_hits;
  int unsigned cp_xbar_non_target_mask_hits;
  int unsigned cp_xbar_abort_no_dispatch_hits;
  int unsigned cp_xbar_payload_hits;
  int unsigned cp_xbar_l1pmpflg_hold_hits;
  int unsigned cp_xbar_l1pmpflg_payload_hits;
  int unsigned cp_xbar_hold_hits;

  function automatic logic [1:0] calc_hash(input logic [VPN_WIDTH-1:0] vpn);
    calc_hash = vpn[1:0] ^ vpn[10:9] ^ vpn[19:18] ^ vpn[26:25];
  endfunction

  function automatic logic [3:0] hash_onehot(input logic [1:0] h);
    case (h)
      2'b00: hash_onehot = 4'b0001;
      2'b01: hash_onehot = 4'b0010;
      2'b10: hash_onehot = 4'b0100;
      2'b11: hash_onehot = 4'b1000;
      default: hash_onehot = 4'b0000;
    endcase
  endfunction

  // PTW-SVA-XBAR-001: 4TWU→1TWU: single TWU always target 0 (no hash needed).
  a_xbar_hash_value: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    twu_hash == 2'b00);

  a_xbar_hash_onehot: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    twu_req_hash == 4'b0001);

  a_xbar_dispatch_matches_hash: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    (PDE_xbar_req && xbar_pde_ready && !tlboper_ptw_abort)
    |-> (xbar_twu_req == twu_req_hash));

  // 4TWU→1TWU: only hash0 remains reachable
  cp_xbar_hash0: cover property (@(posedge forever_cpuclk) disable iff (!cpurst_b)
    PDE_xbar_req && xbar_pde_ready && (twu_req_hash == 4'b0001)) begin
    cp_xbar_hash0_hits++;
  end

  // PTW-SVA-XBAR-002/003: the TWU mask backpressures the request.
  a_xbar_target_mask_ready_low: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    (PDE_xbar_req && |(twu_mask & twu_req_hash)) |-> (!xbar_pde_ready && (xbar_twu_req == 4'b0000)));

  cp_xbar_target_mask: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    PDE_xbar_req && |(twu_mask & twu_req_hash) && !xbar_pde_ready && (xbar_twu_req == 4'b0000)) begin
    cp_xbar_target_mask_hits++;
  end

  // 4TWU→1TWU: non-target mask scenario cannot occur with single TWU; assertion vacuously true.
  a_xbar_non_target_mask_does_not_block: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    (PDE_xbar_req && |(twu_mask & ~twu_req_hash) && !(|(twu_mask & twu_req_hash)) && !tlboper_ptw_abort)
    |-> (xbar_pde_ready && (xbar_twu_req == twu_req_hash)));

  // 4TWU→1TWU: cp_xbar_non_target_mask removed (no non-target TWU exists)

  // PTW-SVA-XBAR-004: abort must clear the xbar dispatch path on the next beat.
  // Same-cycle TWU acceptance is blocked by abort priority inside twu.
  a_xbar_abort_no_dispatch: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    tlboper_ptw_abort |=> (xbar_twu_req == 4'b0000));

  cp_xbar_abort_no_dispatch: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    tlboper_ptw_abort ##1 (xbar_twu_req == 4'b0000)) begin
    cp_xbar_abort_no_dispatch_hits++;
  end

  // PTW-SVA-XBAR-005/006: payload route and backpressure hold.
  a_xbar_payload_route: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    (PDE_xbar_req && !tlboper_ptw_abort) |-> (xbar_twu_hit_level == {L1PDE_xbar_hit_vld, L2PDE_xbar_hit_vld}
                                           && xbar_twu_ppn == PDE_xbar_ppn
                                           && xbar_twu_vpn == PDE_xbar_vpn
                                           && xbar_twu_type == PDE_xbar_type
                                           && xbar_twu_id == PDE_xbar_id));

  cp_xbar_payload: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    PDE_xbar_req && xbar_pde_ready && (xbar_twu_vpn == PDE_xbar_vpn)
    && (xbar_twu_type == PDE_xbar_type) && (xbar_twu_id == PDE_xbar_id)) begin
    cp_xbar_payload_hits++;
  end

  // PTW-SVA-XBAR-006: while the target TWU masks the dispatch path, the PDE
  // request payload must be held stable.  Mask clear (xbar_pde_ready) in the
  // next cycle means the handshake completed and the xbar dispatched the old
  // request with pre-update values, so payload change at that edge is legal.
  a_xbar_payload_hold_while_masked: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    (PDE_xbar_req && !xbar_pde_ready && !tlboper_ptw_abort)
    |=> (tlboper_ptw_abort
      || xbar_pde_ready
      || (PDE_xbar_req
       && $stable(PDE_xbar_ppn)
       && $stable(PDE_xbar_vpn)
       && $stable(PDE_xbar_type)
       && $stable(PDE_xbar_id)
       && $stable(L2PDE_xbar_hit_vld)
       && $stable(L1PDE_xbar_hit_vld))));

  cp_xbar_hold: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    PDE_xbar_req && !xbar_pde_ready ##1 PDE_xbar_req && xbar_pde_ready) begin
    cp_xbar_hold_hits++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // twu_reconstruct Phase 3: l1pmpflg payload route and hold
  // ══════════════════════════════════════════════════════════════════════════
  a_xbar_l1pmpflg_payload_route: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    (PDE_xbar_req && !tlboper_ptw_abort)
    |-> (xbar_twu_l1pmpflg == PDE_xbar_l1pmpflg));

  cp_xbar_l1pmpflg_payload: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    PDE_xbar_req && xbar_pde_ready && (xbar_twu_l1pmpflg == PDE_xbar_l1pmpflg)) begin
    cp_xbar_l1pmpflg_payload_hits++;
  end

  a_xbar_l1pmpflg_hold_while_masked: assert property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    (PDE_xbar_req && !xbar_pde_ready && !tlboper_ptw_abort)
    |=> (tlboper_ptw_abort
      || xbar_pde_ready
      || (PDE_xbar_req && $stable(PDE_xbar_l1pmpflg)
          && $stable(xbar_twu_l1pmpflg))));

  cp_xbar_l1pmpflg_hold: cover property (@(posedge forever_cpuclk)
    disable iff (!cpurst_b)
    PDE_xbar_req && !xbar_pde_ready ##1 PDE_xbar_req
    && ($stable(PDE_xbar_l1pmpflg) && $stable(xbar_twu_l1pmpflg))) begin
    cp_xbar_l1pmpflg_hold_hits++;
  end

  final begin
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_hash0 req=PTW-SVA-XBAR-001 hits=%0d", cp_xbar_hash0_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_hash1 req=PTW-SVA-XBAR-001 hits=%0d", cp_xbar_hash1_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_hash2 req=PTW-SVA-XBAR-001 hits=%0d", cp_xbar_hash2_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_hash3 req=PTW-SVA-XBAR-001 hits=%0d", cp_xbar_hash3_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_target_mask req=PTW-SVA-XBAR-002 hits=%0d", cp_xbar_target_mask_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_non_target_mask req=PTW-SVA-XBAR-003 hits=%0d", cp_xbar_non_target_mask_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_abort_no_dispatch req=PTW-SVA-XBAR-004 hits=%0d", cp_xbar_abort_no_dispatch_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_payload req=PTW-SVA-XBAR-005 hits=%0d", cp_xbar_payload_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_hold req=PTW-SVA-XBAR-006 hits=%0d", cp_xbar_hold_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_l1pmpflg_payload req=PTW-RECON-SVA-XBAR-007 hits=%0d", cp_xbar_l1pmpflg_payload_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_xbar_sva name=cp_xbar_l1pmpflg_hold req=PTW-RECON-SVA-XBAR-008 hits=%0d", cp_xbar_l1pmpflg_hold_hits);
  end

endmodule
