// =============================================================================
// PTW top-level source-side SVA - Stage 6
// Bind target: ptw
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"
`include "l2tlb_negative_sva_guard.svh"

module mmu_ptw_top_sva #(
    parameter int VPN_WIDTH  = 27,
    parameter int PPN_WIDTH  = 28,
    parameter int FLG_WIDTH  = 14,
    parameter int ASID_WIDTH = 16,
    parameter int PGS_WIDTH  = 3,
    parameter int TYPE_WIDTH = 3,
    parameter int ID_WIDTH   = 7,
    parameter int TAG_WIDTH  = 48,
    parameter int DATA_WIDTH = 42
) (
    input logic                   ptw_clk,
    input logic                   cpurst_b,
    input logic                   l2tlb_ptw_req,
    input logic [VPN_WIDTH-1:0]   l2tlb_ptw_vpn,
    input logic [TYPE_WIDTH-1:0]  l2tlb_ptw_type,
    input logic [ID_WIDTH-1:0]    l2tlb_ptw_id,
    input logic                   pde_cache_ready,
    input logic                   abort_flop,
    input logic                   ptw_jtlb_ready,
    input logic                   tlboper_ptw_abort,
    input logic                   arb_ptw_grant,
    input logic                   arb_ptw_mask,
    input logic                   ptw_arb_req,
    input logic [VPN_WIDTH-1:0]   ptw_arb_vpn,
    input logic [DATA_WIDTH-1:0]  ptw_arb_ref_data_din,
    input logic [TAG_WIDTH-1:0]   ptw_arb_ref_tag_din,
    input logic [PGS_WIDTH-1:0]   ptw_arb_ref_pgs,
    input logic [TYPE_WIDTH-1:0]  ptw_arb_ref_type,
    input logic [ID_WIDTH-1:0]    ptw_arb_ref_id,
    input logic                   acc_err_vld,
    input logic                   pgflt_vld,
    input logic                   ref_vld,
    input logic [3:0]             twu_l2tlb_ref_acc_err,
    input logic [3:0][TYPE_WIDTH-1:0] twu_l2tlb_ref_acc_err_type,
    input logic [3:0][ID_WIDTH-1:0]   twu_l2tlb_ref_acc_err_id,
    input logic                   mbuf_bus_error,
    input logic [TYPE_WIDTH-1:0]  mbuf_bus_error_type,
    input logic [ID_WIDTH-1:0]    mbuf_bus_error_id,
    input logic                   PDE_cache_acc_err_vld,
    input logic [TYPE_WIDTH-1:0]  PDE_cache_acc_err_type,
    input logic [ID_WIDTH-1:0]    PDE_cache_acc_err_id,
    input logic [5:0]             acc_err_twu_grant,
    input logic                   ptw_l2tlb_ref_acc_err,
    input logic                   ptw_l2tlb_ref_pgflt,
    input logic                   ptw_l2tlb_ref_data_vld,
    input logic                   ptw_l2tlb_cmplt,
    input logic [TYPE_WIDTH-1:0]  ptw_l2tlb_type,
    input logic [ID_WIDTH-1:0]    ptw_l2tlb_id,
    input logic [FLG_WIDTH-1:0]   ptw_l2tlb_flg,
    input logic                   ptw_l1dtlb_ref_pa_vld,
    input logic                   ptw_l1dtlb_cmplt,
    input logic [VPN_WIDTH-1:0]   ptw_l1dtlb_ref_vpn,
    input logic [PGS_WIDTH-1:0]   ptw_l1dtlb_ref_pgs,
    input logic [PPN_WIDTH-1:0]   ptw_l1dtlb_ref_ppn,
    input logic [FLG_WIDTH-1:0]   ptw_l1dtlb_ref_flg,
    input logic                   ptw_l1dtlb_pgflt,
    input logic                   ptw_l1dtlb_ref_acc_err,
    input logic                   ptw_l1itlb_ref_pa_vld,
    input logic                   ptw_l1itlb_cmplt,
    input logic [VPN_WIDTH-1:0]   ptw_l1itlb_ref_vpn,
    input logic [PGS_WIDTH-1:0]   ptw_l1itlb_ref_pgs,
    input logic [PPN_WIDTH-1:0]   ptw_l1itlb_ref_ppn,
    input logic [FLG_WIDTH-1:0]   ptw_l1itlb_ref_flg,
    input logic                   ptw_l1itlb_pgflt,
    input logic                   ptw_l1itlb_ref_acc_err
);

  localparam logic [2:0] PTW_TYPE_LOAD  = 3'b010;
  localparam logic [2:0] PTW_TYPE_FETCH = 3'b011;
  localparam logic [2:0] PTW_TYPE_PREF  = 3'b100;
  localparam logic [2:0] PTW_TYPE_STORE = 3'b110;

  int unsigned cp_req_ready_hold_hits;
  int unsigned cp_req_reselect_under_backpressure_hits;
  int unsigned cp_req_accept_type_hits;
  int unsigned cp_class_onehot_hits;
  int unsigned cp_class_priority_hits;
  int unsigned cp_abort_refill_block_hits;
  int unsigned cp_cmplt_or_hits;
  int unsigned cp_type_id_route_hits;
  int unsigned cp_target_load_store_hits;
  int unsigned cp_target_fetch_hits;
  int unsigned cp_target_pfu_hits;
  int unsigned cp_refill_layout_hits;
  int unsigned cp_pde_accerr_priority_hits;
  int unsigned cp_pde_accerr_class_hits;
  int unsigned cp_pde_accerr_no_dup_hits;
  logic tlboper_ptw_abort_q;
  logic ptw_sva_past_valid;

  always_ff @(posedge ptw_clk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      tlboper_ptw_abort_q <= 1'b0;
      ptw_sva_past_valid <= 1'b0;
    end else begin
      tlboper_ptw_abort_q <= tlboper_ptw_abort;
      ptw_sva_past_valid <= 1'b1;
    end
  end

  function automatic bit legal_ptw_type(input logic [TYPE_WIDTH-1:0] typ);
    legal_ptw_type = (typ == PTW_TYPE_LOAD)
                  || (typ == PTW_TYPE_FETCH)
                  || (typ == PTW_TYPE_PREF)
                  || (typ == PTW_TYPE_STORE);
  endfunction

  function automatic bit is_data_type(input logic [TYPE_WIDTH-1:0] typ);
    is_data_type = (typ == PTW_TYPE_LOAD) || (typ == PTW_TYPE_STORE);
  endfunction

  // PTW-SVA-REQ-001/002: a backpressured source request must keep the same
  // payload while the same request id remains selected.
  a_ptw_req_hold_until_ready: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE || !ptw_sva_past_valid || abort_flop
              || tlboper_ptw_abort || tlboper_ptw_abort_q)
    (l2tlb_ptw_req && !ptw_jtlb_ready
     && $past(l2tlb_ptw_req && !ptw_jtlb_ready)
     && (l2tlb_ptw_id == $past(l2tlb_ptw_id)))
    |-> ($stable(l2tlb_ptw_vpn) && $stable(l2tlb_ptw_type)));

  cp_ptw_req_ready_hold: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    l2tlb_ptw_req && !ptw_jtlb_ready ##1 l2tlb_ptw_req && ptw_jtlb_ready) begin
    cp_req_ready_hold_hits++;
  end

  cp_ptw_req_reselect_under_backpressure: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE || !ptw_sva_past_valid)
    l2tlb_ptw_req && !ptw_jtlb_ready
    && $past(l2tlb_ptw_req && !ptw_jtlb_ready)
    && (l2tlb_ptw_id != $past(l2tlb_ptw_id))) begin
    cp_req_reselect_under_backpressure_hits++;
  end

  // PTW-SVA-REQ-002: ready is the PDE/xbar ready gated by outstanding abort.
  a_ptw_ready_definition: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_jtlb_ready == (pde_cache_ready && !abort_flop));

  // PTW-SVA-REQ-003/004: one PTW request interface, legal accepted type.
  a_ptw_accept_type_legal: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    (l2tlb_ptw_req && ptw_jtlb_ready) |-> legal_ptw_type(l2tlb_ptw_type));

  cp_ptw_req_accept_type: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    l2tlb_ptw_req && ptw_jtlb_ready && legal_ptw_type(l2tlb_ptw_type)) begin
    cp_req_accept_type_hits++;
  end

  // PTW-SVA-ARB-001/002: visible completion class and fixed priority.
  a_ptw_completion_class_onehot0: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    $onehot0({ptw_l2tlb_ref_acc_err, ptw_l2tlb_ref_pgflt, ptw_l2tlb_ref_data_vld}));

  cp_ptw_completion_class_onehot: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_l2tlb_ref_acc_err || ptw_l2tlb_ref_pgflt || ptw_l2tlb_ref_data_vld) begin
    cp_class_onehot_hits++;
  end

  a_ptw_class_priority_access_over_page_refill: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    acc_err_vld |-> (ptw_l2tlb_ref_acc_err && !ptw_l2tlb_ref_pgflt && !ptw_l2tlb_ref_data_vld));

  a_ptw_class_priority_page_over_refill: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    (!acc_err_vld && pgflt_vld) |-> (ptw_l2tlb_ref_pgflt && !ptw_l2tlb_ref_data_vld));

  cp_ptw_class_priority: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    (acc_err_vld && (pgflt_vld || ref_vld) && ptw_l2tlb_ref_acc_err)
    || (!acc_err_vld && pgflt_vld && ref_vld && ptw_l2tlb_ref_pgflt)) begin
    cp_class_priority_hits++;
  end

  // PTW-SVA-ARB-003: abort blocks normal refill; visible exceptions are not masked here.
  a_ptw_abort_blocks_normal_refill: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    tlboper_ptw_abort |-> (!ptw_arb_req
                        && !ptw_l2tlb_ref_data_vld
                        && !ptw_l1dtlb_ref_pa_vld
                        && !ptw_l1itlb_ref_pa_vld));

  cp_ptw_abort_refill_block: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    tlboper_ptw_abort && !ptw_arb_req && !ptw_l2tlb_ref_data_vld) begin
    cp_abort_refill_block_hits++;
  end

  // PTW-SVA-ARB-004: L2 completion is the OR of visible classes.
  a_ptw_l2_cmplt_or: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_l2tlb_cmplt == (ptw_l2tlb_ref_data_vld
                     || ptw_l2tlb_ref_pgflt
                     || ptw_l2tlb_ref_acc_err));

  cp_ptw_l2_cmplt_or: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_l2tlb_cmplt
    && (ptw_l2tlb_ref_data_vld || ptw_l2tlb_ref_pgflt || ptw_l2tlb_ref_acc_err)) begin
    cp_cmplt_or_hits++;
  end

  // PTW-SVA-ARB-005/006/007: type/id and target route.
  a_ptw_refill_type_id_route: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_l2tlb_ref_data_vld |-> (ptw_l2tlb_type == ptw_arb_ref_type
                             && ptw_l2tlb_id == ptw_arb_ref_id));

  cp_ptw_type_id_route: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_l2tlb_cmplt && legal_ptw_type(ptw_l2tlb_type)) begin
    cp_type_id_route_hits++;
  end

  a_ptw_load_store_success_targets_l1d_l2: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    (ptw_l2tlb_ref_data_vld && is_data_type(ptw_l2tlb_type))
    |-> (ptw_l1dtlb_ref_pa_vld && ptw_l1dtlb_cmplt && !ptw_l1itlb_ref_pa_vld));

  cp_ptw_target_load_store: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_l2tlb_ref_data_vld && is_data_type(ptw_l2tlb_type) && ptw_l1dtlb_ref_pa_vld) begin
    cp_target_load_store_hits++;
  end

  a_ptw_fetch_success_targets_l1i_l2: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    (ptw_l2tlb_ref_data_vld && (ptw_l2tlb_type == PTW_TYPE_FETCH))
    |-> (ptw_l1itlb_ref_pa_vld && ptw_l1itlb_cmplt && !ptw_l1dtlb_ref_pa_vld));

  cp_ptw_target_fetch: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_l2tlb_ref_data_vld && (ptw_l2tlb_type == PTW_TYPE_FETCH) && ptw_l1itlb_ref_pa_vld) begin
    cp_target_fetch_hits++;
  end

  a_ptw_pfu_success_targets_l2_only: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    (ptw_l2tlb_ref_data_vld && (ptw_l2tlb_type == PTW_TYPE_PREF))
    |-> (!ptw_l1dtlb_ref_pa_vld && !ptw_l1itlb_ref_pa_vld));

  cp_ptw_target_pfu_l2_only: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_l2tlb_ref_data_vld && (ptw_l2tlb_type == PTW_TYPE_PREF)
    && !ptw_l1dtlb_ref_pa_vld && !ptw_l1itlb_ref_pa_vld) begin
    cp_target_pfu_hits++;
  end

  // PTW-SVA-ARB-008: visible L1 payload is a bit-exact projection of the PTW refill bus.
  a_ptw_l1d_refill_layout: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_l1dtlb_ref_pa_vld |-> (ptw_l1dtlb_ref_vpn == ptw_arb_ref_tag_din[46:20]
                            && ptw_l1dtlb_ref_pgs == ptw_arb_ref_pgs
                            && ptw_l1dtlb_ref_ppn == ptw_arb_ref_data_din[41:14]
                            && ptw_l1dtlb_ref_flg == ptw_arb_ref_data_din[FLG_WIDTH-1:0]
                            && ptw_l2tlb_flg == ptw_arb_ref_data_din[FLG_WIDTH-1:0]
                            && ptw_arb_vpn == ptw_arb_ref_tag_din[46:20]));

  a_ptw_l1i_refill_layout: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    ptw_l1itlb_ref_pa_vld |-> (ptw_l1itlb_ref_vpn == ptw_arb_ref_tag_din[46:20]
                            && ptw_l1itlb_ref_pgs == ptw_arb_ref_pgs
                            && ptw_l1itlb_ref_ppn == ptw_arb_ref_data_din[41:14]
                            && ptw_l1itlb_ref_flg == ptw_arb_ref_data_din[FLG_WIDTH-1:0]));

  cp_ptw_refill_layout: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    (ptw_l1dtlb_ref_pa_vld || ptw_l1itlb_ref_pa_vld)
    && (ptw_arb_vpn == ptw_arb_ref_tag_din[46:20])) begin
    cp_refill_layout_hits++;
  end

  // PTW-SVA-ARB-010: PDE cache direct accerr has priority and routes its type/id.
  a_ptw_pde_accerr_priority_grant: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    PDE_cache_acc_err_vld |-> (acc_err_twu_grant[5] && !(|acc_err_twu_grant[4:0])));

  a_ptw_pde_accerr_priority_type_id: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    PDE_cache_acc_err_vld && (mbuf_bus_error || (|twu_l2tlb_ref_acc_err))
    |-> (ptw_l2tlb_ref_acc_err
      && (ptw_l2tlb_type == PDE_cache_acc_err_type)
      && (ptw_l2tlb_id == PDE_cache_acc_err_id)));

  cp_ptw_pde_accerr_priority: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    PDE_cache_acc_err_vld && (mbuf_bus_error || (|twu_l2tlb_ref_acc_err))
    && ptw_l2tlb_ref_acc_err
    && (ptw_l2tlb_type == PDE_cache_acc_err_type)
    && (ptw_l2tlb_id == PDE_cache_acc_err_id)) begin
    cp_pde_accerr_priority_hits++;
  end

  // PTW-SVA-ARB-011: PDE direct accerr returns a single visible completion class.
  a_ptw_pde_accerr_completion_class_onehot: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    PDE_cache_acc_err_vld
    |-> (ptw_l2tlb_ref_acc_err
      && !ptw_l2tlb_ref_pgflt
      && !ptw_l2tlb_ref_data_vld
      && $onehot({ptw_l2tlb_ref_acc_err, ptw_l2tlb_ref_pgflt, ptw_l2tlb_ref_data_vld})));

  cp_ptw_pde_accerr_class: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    PDE_cache_acc_err_vld && ptw_l2tlb_ref_acc_err
    && !ptw_l2tlb_ref_pgflt && !ptw_l2tlb_ref_data_vld) begin
    cp_pde_accerr_class_hits++;
  end

  // PTW-SVA-ARB-012: a granted PDE direct accerr must not be returned again as the same pending fault.
  a_ptw_pde_accerr_no_same_pending_duplicate_grant: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    acc_err_twu_grant[5]
    |=> !(acc_err_twu_grant[5]
       && (PDE_cache_acc_err_type == $past(PDE_cache_acc_err_type))
       && (PDE_cache_acc_err_id == $past(PDE_cache_acc_err_id))
       && !$past(l2tlb_ptw_req && ptw_jtlb_ready)));

  cp_ptw_pde_accerr_no_dup: cover property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    acc_err_twu_grant[5] ##1 !acc_err_twu_grant[5]) begin
    cp_pde_accerr_no_dup_hits++;
  end

  // ══════════════════════════════════════════════════════════════════════════
  // twu_reconstruct Phase 3: unified TWU fault/refill source assertions
  //
  // Old:  TWU acc fault from 3 parallel PMP stages (fst/scd/thd_pmp)
  //       TWU page fault from 3 parallel CHK stages (fst/scd/thd_chk)
  //       Refill from 4 sources (fst_chk + scd_chk + thd_chk + csr)
  // New:  TWU acc fault from single pmp_unit
  //       TWU page fault from single chk_unit
  //       Refill from 2 sources (chk_unit_refill + csr_refill)
  //
  // acc_err_twu_grant mapping (4TWU→1TWU):
  //   [5] = PDE direct, [4:3] unused, [2] = MBUF bus error, [1:0] = TWU
  // New TWU acc_err: single-bit from pmp_unit, mapped to acc_err_twu_grant[0]
  // ══════════════════════════════════════════════════════════════════════════

  // acc_err_twu_grant is now 6-bit with only 3 active sources
  a_ptw_accerr_single_twu_source: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    $onehot0(acc_err_twu_grant));

  // MBUF bus error routes from mbuf entry to visible access fault
  a_ptw_mbuf_bus_error_route: assert property (@(posedge ptw_clk)
    disable iff (`L2TLB_NEG_DISABLE)
    mbuf_bus_error |-> (ptw_l2tlb_ref_acc_err
                     && (ptw_l2tlb_type == mbuf_bus_error_type)
                     && (ptw_l2tlb_id == mbuf_bus_error_id)));

  final begin
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_req_ready_hold req=PTW-SVA-REQ-001 hits=%0d", cp_req_ready_hold_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_req_reselect_under_backpressure req=PTW-SVA-REQ-001 hits=%0d", cp_req_reselect_under_backpressure_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_req_accept_type req=PTW-SVA-REQ-003,PTW-SVA-REQ-004 hits=%0d", cp_req_accept_type_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_completion_class_onehot req=PTW-SVA-ARB-001 hits=%0d", cp_class_onehot_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_class_priority req=PTW-SVA-ARB-002 hits=%0d", cp_class_priority_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_abort_refill_block req=PTW-SVA-ARB-003 hits=%0d", cp_abort_refill_block_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_l2_cmplt_or req=PTW-SVA-ARB-004 hits=%0d", cp_cmplt_or_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_type_id_route req=PTW-SVA-ARB-005 hits=%0d", cp_type_id_route_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_target_load_store req=PTW-SVA-ARB-006 hits=%0d", cp_target_load_store_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_target_fetch req=PTW-SVA-ARB-006 hits=%0d", cp_target_fetch_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_target_pfu_l2_only req=PTW-SVA-ARB-007 hits=%0d", cp_target_pfu_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_refill_layout req=PTW-SVA-ARB-008 hits=%0d", cp_refill_layout_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_pde_accerr_priority req=PTW-SVA-ARB-010 hits=%0d", cp_pde_accerr_priority_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_pde_accerr_class req=PTW-SVA-ARB-011 hits=%0d", cp_pde_accerr_class_hits);
    $display("PTW_SVA_COVER module=mmu_ptw_top_sva name=cp_ptw_pde_accerr_no_dup req=PTW-SVA-ARB-012 hits=%0d", cp_pde_accerr_no_dup_hits);
  end

endmodule
