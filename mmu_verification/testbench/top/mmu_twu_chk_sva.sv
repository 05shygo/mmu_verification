// =============================================================================
// PTW TWU CHK SVA - Stage 5
// Bind target: twu
// =============================================================================
`timescale 1ns/1ps

module mmu_twu_chk_sva #(
    parameter int VPN_WIDTH  = 27,
    parameter int DATA_WIDTH = 64,
    parameter int TYPE_WIDTH = 3,
    parameter int ID_WIDTH   = 7
) (
    input logic                  twu_clk,
    input logic                  cpurst_b,
    input logic                  tlboper_ptw_abort,
    input logic                  cp0_mmu_maee,
    input logic                  cp0_mmu_mxr,
    input logic                  cp0_mmu_sum,
    input logic [1:0]            cp0_mmu_mpp,
    input logic                  cp0_mmu_mprv,
    input logic [1:0]            cp0_yy_priv_mode,
    input logic [1:0]            cp0_priv_mode,
    input logic                  fst_chk_vld,
    input logic [VPN_WIDTH-1:0]  fst_chk_vpn,
    input logic [TYPE_WIDTH-1:0] fst_chk_type,
    input logic [ID_WIDTH-1:0]   fst_chk_id,
    input logic [DATA_WIDTH-1:0] fst_chk_data,
    input logic [8:0]            fst_chk_flg,
    input logic                  fst_chk_page_flt,
    input logic                  fst_chk_leaf_vld,
    input logic                  fst_chk_refill_req,
    input logic                  fst_chk_csr_req,
    input logic                  fst_chk_wait,
    input logic                  fst_chk_fetch_type,
    input logic                  fst_chk_load_type,
    input logic                  fst_chk_store_type,
    input logic                  fst_chk_cp0_user_mode,
    input logic                  fst_chk_cp0_supv_mode,
    input logic                  scd_chk_vld,
    input logic [VPN_WIDTH-1:0]  scd_chk_vpn,
    input logic [TYPE_WIDTH-1:0] scd_chk_type,
    input logic [ID_WIDTH-1:0]   scd_chk_id,
    input logic [DATA_WIDTH-1:0] scd_chk_data,
    input logic [8:0]            scd_chk_flg,
    input logic                  scd_chk_page_flt,
    input logic                  scd_chk_leaf_vld,
    input logic                  scd_chk_refill_req,
    input logic                  scd_chk_csr_req,
    input logic                  scd_chk_wait,
    input logic                  scd_chk_fetch_type,
    input logic                  scd_chk_load_type,
    input logic                  scd_chk_store_type,
    input logic                  scd_chk_cp0_user_mode,
    input logic                  scd_chk_cp0_supv_mode,
    input logic                  thd_chk_vld,
    input logic [VPN_WIDTH-1:0]  thd_chk_vpn,
    input logic [TYPE_WIDTH-1:0] thd_chk_type,
    input logic [ID_WIDTH-1:0]   thd_chk_id,
    input logic [DATA_WIDTH-1:0] thd_chk_data,
    input logic [8:0]            thd_chk_flg,
    input logic                  thd_chk_page_flt,
    input logic                  thd_chk_refill_req,
    input logic                  thd_chk_wait,
    input logic                  thd_chk_fetch_type,
    input logic                  thd_chk_load_type,
    input logic                  thd_chk_store_type,
    input logic                  thd_chk_cp0_user_mode,
    input logic                  thd_chk_cp0_supv_mode,
    input logic                  scd_pmp_wait,
    input logic                  thd_pmp_wait,
    input logic                  refill_fst_chk_grant,
    input logic                  refill_scd_chk_grant,
    input logic                  refill_thd_chk_grant,
    input logic                  pgflt_fst_chk_grant,
    input logic                  pgflt_scd_chk_grant,
    input logic                  pgflt_thd_chk_grant,
    input logic                  fst_csr_grant,
    input logic                  scd_csr_grant,
    input logic                  twu_l2tlb_ref_pgflt,
    input logic                  twu_arb_ref_req,
    input logic [2:0]            twu_data_ready
);

  localparam logic [2:0] PTW_TYPE_FETCH = 3'b011;
  localparam logic [2:0] PTW_TYPE_PREF  = 3'b100;

  int unsigned cp_chk_leaf_write_only_hits;
  int unsigned cp_chk_nonleaf_level_hits;
  int unsigned cp_chk_fetch_hits;
  int unsigned cp_chk_load_hits;
  int unsigned cp_chk_store_hits;
  int unsigned cp_chk_pfu_hits;
  int unsigned cp_chk_us_sum_hits;
  int unsigned cp_chk_huge_align_hits;
  int unsigned cp_chk_no_side_effect_hits;
  int unsigned cp_chk_wait_hold_hits;
  int unsigned cp_chk_rsw_reserved_seen_hits;

  function automatic logic [8:0] decode_flg(input logic [DATA_WIDTH-1:0] data);
    decode_flg = {data[9:6], data[4:0]};
  endfunction

  function automatic bit leaf_from_flg(input logic [8:0] flg);
    leaf_from_flg = flg[0] && (flg[1] || flg[3]);
  endfunction

  function automatic bit write_only_fault(input logic [8:0] flg, input logic mxr);
    write_only_fault = flg[2] && !(flg[1] || (mxr && flg[3]));
  endfunction

  function automatic bit huge1g_misaligned(input logic [DATA_WIDTH-1:0] data);
    huge1g_misaligned = (data[27:10] != 18'b0);
  endfunction

  function automatic bit huge2m_misaligned(input logic [DATA_WIDTH-1:0] data);
    huge2m_misaligned = (data[18:10] != 9'b0);
  endfunction

  // PTW-SVA-CHK-001/002: leaf and non-leaf level classification.
  a_chk_fst_leaf_decode: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    fst_chk_vld |-> (fst_chk_leaf_vld == leaf_from_flg(fst_chk_flg)));

  a_chk_scd_leaf_decode: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    scd_chk_vld |-> (scd_chk_leaf_vld == leaf_from_flg(scd_chk_flg)));

  a_chk_flg_decode_matches_raw: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld |-> (fst_chk_flg == decode_flg(fst_chk_data)))
    and (scd_chk_vld |-> (scd_chk_flg == decode_flg(scd_chk_data)))
    and (thd_chk_vld |-> (thd_chk_flg == decode_flg(thd_chk_data))));

  a_chk_write_only_faults: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_leaf_vld && write_only_fault(fst_chk_flg, cp0_mmu_mxr) |-> fst_chk_page_flt)
    and (scd_chk_vld && scd_chk_leaf_vld && write_only_fault(scd_chk_flg, cp0_mmu_mxr) |-> scd_chk_page_flt)
    and (thd_chk_vld && write_only_fault(thd_chk_flg, cp0_mmu_mxr) |-> thd_chk_page_flt));

  cp_chk_leaf_write_only: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_leaf_vld && write_only_fault(fst_chk_flg, cp0_mmu_mxr))
    || (scd_chk_vld && scd_chk_leaf_vld && write_only_fault(scd_chk_flg, cp0_mmu_mxr))
    || (thd_chk_vld && write_only_fault(thd_chk_flg, cp0_mmu_mxr))) begin
    cp_chk_leaf_write_only_hits++;
  end

  a_chk_fst_scd_pointer_not_page_fault: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_flg[0] && !fst_chk_flg[1] && !fst_chk_flg[2] && !fst_chk_flg[3])
    |-> (!fst_chk_leaf_vld && !fst_chk_page_flt));

  a_chk_scd_pointer_not_page_fault: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (scd_chk_vld && scd_chk_flg[0] && !scd_chk_flg[1] && !scd_chk_flg[2] && !scd_chk_flg[3])
    |-> (!scd_chk_leaf_vld && !scd_chk_page_flt));

  a_chk_thd_nonleaf_faults: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (thd_chk_vld && thd_chk_flg[0] && !thd_chk_flg[1] && !thd_chk_flg[3])
    |-> thd_chk_page_flt);

  cp_chk_nonleaf_level: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && !fst_chk_leaf_vld && !fst_chk_page_flt)
    || (scd_chk_vld && !scd_chk_leaf_vld && !scd_chk_page_flt)
    || (thd_chk_vld && thd_chk_flg[0] && !thd_chk_flg[1] && !thd_chk_flg[3] && thd_chk_page_flt)) begin
    cp_chk_nonleaf_level_hits++;
  end

  // PTW-SVA-CHK-003/004/005/006/007/008: permission and huge-page guards.
  a_chk_fetch_needs_x: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_leaf_vld && fst_chk_fetch_type && !fst_chk_flg[3] |-> fst_chk_page_flt)
    and (scd_chk_vld && scd_chk_leaf_vld && scd_chk_fetch_type && !scd_chk_flg[3] |-> scd_chk_page_flt)
    and (thd_chk_vld && thd_chk_fetch_type && !thd_chk_flg[3] |-> thd_chk_page_flt));

  cp_chk_fetch: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_fetch_type) || (scd_chk_vld && scd_chk_fetch_type) || (thd_chk_vld && thd_chk_fetch_type)) begin
    cp_chk_fetch_hits++;
  end

  a_chk_load_needs_r_or_mxr_x: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_leaf_vld && fst_chk_load_type && !fst_chk_flg[1] && !(cp0_mmu_mxr && fst_chk_flg[3]) |-> fst_chk_page_flt)
    and (scd_chk_vld && scd_chk_leaf_vld && scd_chk_load_type && !scd_chk_flg[1] && !(cp0_mmu_mxr && scd_chk_flg[3]) |-> scd_chk_page_flt)
    and (thd_chk_vld && thd_chk_load_type && !thd_chk_flg[1] && !(cp0_mmu_mxr && thd_chk_flg[3]) |-> thd_chk_page_flt));

  cp_chk_load: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_load_type) || (scd_chk_vld && scd_chk_load_type) || (thd_chk_vld && thd_chk_load_type)) begin
    cp_chk_load_hits++;
  end

  a_chk_store_needs_w_d: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_leaf_vld && fst_chk_store_type && (!fst_chk_flg[2] || !fst_chk_flg[6]) |-> fst_chk_page_flt)
    and (scd_chk_vld && scd_chk_leaf_vld && scd_chk_store_type && (!scd_chk_flg[2] || !scd_chk_flg[6]) |-> scd_chk_page_flt)
    and (thd_chk_vld && thd_chk_store_type && (!thd_chk_flg[2] || !thd_chk_flg[6]) |-> thd_chk_page_flt));

  cp_chk_store: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_store_type) || (scd_chk_vld && scd_chk_store_type) || (thd_chk_vld && thd_chk_store_type)) begin
    cp_chk_store_hits++;
  end

  cp_chk_pfu_no_rxd: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    ((fst_chk_vld && fst_chk_type == PTW_TYPE_PREF)
     || (scd_chk_vld && scd_chk_type == PTW_TYPE_PREF)
     || (thd_chk_vld && thd_chk_type == PTW_TYPE_PREF))) begin
    cp_chk_pfu_hits++;
  end

  a_chk_user_supervisor_rules: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_leaf_vld && ((fst_chk_flg[4] && fst_chk_cp0_supv_mode && !cp0_mmu_sum) || (!fst_chk_flg[4] && fst_chk_cp0_user_mode)) |-> fst_chk_page_flt)
    and (scd_chk_vld && scd_chk_leaf_vld && ((scd_chk_flg[4] && scd_chk_cp0_supv_mode && !cp0_mmu_sum) || (!scd_chk_flg[4] && scd_chk_cp0_user_mode)) |-> scd_chk_page_flt)
    and (thd_chk_vld && ((thd_chk_flg[4] && thd_chk_cp0_supv_mode && !cp0_mmu_sum) || (!thd_chk_flg[4] && thd_chk_cp0_user_mode)) |-> thd_chk_page_flt));

  cp_chk_us_sum: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (cp0_priv_mode == (cp0_mmu_mprv ? cp0_mmu_mpp : cp0_yy_priv_mode))
    && ((fst_chk_vld && fst_chk_page_flt) || (scd_chk_vld && scd_chk_page_flt) || (thd_chk_vld && thd_chk_page_flt))) begin
    cp_chk_us_sum_hits++;
  end

  a_chk_huge_align_faults_before_refill: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_leaf_vld && huge1g_misaligned(fst_chk_data) |-> (fst_chk_page_flt && !fst_chk_refill_req && !fst_chk_csr_req))
    and (scd_chk_vld && scd_chk_leaf_vld && huge2m_misaligned(scd_chk_data) |-> (scd_chk_page_flt && !scd_chk_refill_req && !scd_chk_csr_req)));

  cp_chk_huge_align: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_leaf_vld && huge1g_misaligned(fst_chk_data))
    || (scd_chk_vld && scd_chk_leaf_vld && huge2m_misaligned(scd_chk_data))) begin
    cp_chk_huge_align_hits++;
  end

  // PTW-SVA-CHK-011 and WAIT family: page faults and waits do not leak side effects.
  a_chk_page_fault_no_refill_or_csr: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && fst_chk_page_flt |-> (!fst_chk_refill_req && !fst_chk_csr_req))
    and (scd_chk_vld && scd_chk_page_flt |-> (!scd_chk_refill_req && !scd_chk_csr_req))
    and (thd_chk_vld && thd_chk_page_flt |-> !thd_chk_refill_req));

  cp_chk_no_side_effect: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    ((fst_chk_vld && fst_chk_page_flt && !fst_chk_refill_req && !fst_chk_csr_req)
     || (scd_chk_vld && scd_chk_page_flt && !scd_chk_refill_req && !scd_chk_csr_req)
     || (thd_chk_vld && thd_chk_page_flt && !thd_chk_refill_req))) begin
    cp_chk_no_side_effect_hits++;
  end

  a_chk_wait_holds_payload: assert property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    (fst_chk_wait && !tlboper_ptw_abort |=> (tlboper_ptw_abort || (fst_chk_vld && $stable(fst_chk_vpn) && $stable(fst_chk_type) && $stable(fst_chk_id) && $stable(fst_chk_data))))
    and (scd_chk_wait && !tlboper_ptw_abort |=> (tlboper_ptw_abort || (scd_chk_vld && $stable(scd_chk_vpn) && $stable(scd_chk_type) && $stable(scd_chk_id) && $stable(scd_chk_data))))
    and (thd_chk_wait && !tlboper_ptw_abort |=> (tlboper_ptw_abort || (thd_chk_vld && $stable(thd_chk_vpn) && $stable(thd_chk_type) && $stable(thd_chk_id) && $stable(thd_chk_data)))));

  cp_chk_wait_hold: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b)
    (fst_chk_wait || scd_chk_wait || thd_chk_wait) && !tlboper_ptw_abort) begin
    cp_chk_wait_hold_hits++;
  end

  cp_chk_rsw_high_reserved_seen: cover property (@(posedge twu_clk)
    disable iff (!cpurst_b || tlboper_ptw_abort)
    (fst_chk_vld && (|fst_chk_data[63:38] || |fst_chk_data[9:8]))
    || (scd_chk_vld && (|scd_chk_data[63:38] || |scd_chk_data[9:8]))
    || (thd_chk_vld && (|thd_chk_data[63:38] || |thd_chk_data[9:8]))) begin
    cp_chk_rsw_reserved_seen_hits++;
  end

  final begin
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_leaf_write_only req=PTW-SVA-CHK-001 hits=%0d", cp_chk_leaf_write_only_hits);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_nonleaf_level req=PTW-SVA-CHK-002 hits=%0d", cp_chk_nonleaf_level_hits);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_fetch req=PTW-SVA-CHK-003 hits=%0d", cp_chk_fetch_hits);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_load req=PTW-SVA-CHK-004 hits=%0d", cp_chk_load_hits);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_store req=PTW-SVA-CHK-005 hits=%0d", cp_chk_store_hits);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_pfu_no_rxd req=PTW-SVA-CHK-006 hits=%0d", cp_chk_pfu_hits);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_us_sum req=PTW-SVA-CHK-007 hits=%0d", cp_chk_us_sum_hits);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_huge_align req=PTW-SVA-CHK-008 hits=%0d", cp_chk_huge_align_hits);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_no_side_effect req=PTW-SVA-CHK-011 hits=%0d", cp_chk_no_side_effect_hits);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_wait_hold req=PTW-SVA-WAIT-001,PTW-SVA-WAIT-002,PTW-SVA-WAIT-003,PTW-SVA-WAIT-004,PTW-SVA-WAIT-005 hits=%0d", cp_chk_wait_hold_hits);
    $display("PTW_SVA_COVER module=mmu_twu_chk_sva name=cp_chk_rsw_high_reserved_seen req=PTW-SVA-CHK-009 hits=%0d provisional=1", cp_chk_rsw_reserved_seen_hits);
  end

endmodule
