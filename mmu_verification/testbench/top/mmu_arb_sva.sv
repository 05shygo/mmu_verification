// =============================================================================
// mmu_arb 仲裁 SVA (bind mmu_arb) — Phase 7
// 验证意图: 5 路 grant 多 hot 中至多一路；有全局请求时 five-hot 中恰一路；PTW 写两拍流水在复位下清零 (F5.NEW.2 伪代码 sva_ptw_write_pipe_reset_safe)
// =============================================================================
`timescale 1ns/1ps
`include "l2tlb_negative_sva_guard.svh"
`include "l2tlb_negative_sva_guard.svh"

module mmu_arb_sva (
    input logic forever_cpuclk,
    input logic cpurst_b,
    input logic issue_valid,
    input logic [26:0] issue_vpn,
    input logic [2:0] issue_eid,
    input logic [2:0] issue_type,
    input logic [3:0] issue_queue_id,
    input logic ptw_arb_req,
    input logic [26:0] ptw_arb_vpn,
    input logic [2:0] ptw_arb_pgs,
    input logic tlboper_arb_req,
    input logic [26:0] tlboper_arb_vpn,
    input logic tlboper_arb_write,
    input logic [7:0] tlboper_arb_bank_sel,
    input logic [10:0] tlboper_arb_idx,
    input logic tlboper_arb_idx_not_va,
    input logic lsu_mmu_va2_vld,
    input logic [26:0] l2tlb_arb_pfu_vpn,
    input logic l2tlb_arb_pfu_miss_mb_full,
    input logic l2tlb_arb_rrpv_wbuf_full,
    input logic dutlb_xx_mmu_off,
    input logic mmu_lsu_pa2_err,
    input logic mmu_lsu_pa2_vld,
    input logic arb_l2tlb_req,
    input logic [26:0] arb_l2tlb_vpn,
    input logic arb_l2tlb_write,
    input logic [3:0] arb_l2tlb_trans_id,
    input logic [2:0] arb_l2tlb_eid,
    input logic [2:0] arb_l2tlb_acc_type,
    input logic [7:0] arb_l2tlb_bank_sel,
    input logic [7:0] arb_l2tlb_idx_w0,
    input logic [7:0] arb_l2tlb_idx_w1,
    input logic [7:0] arb_l2tlb_idx_w2,
    input logic [7:0] arb_l2tlb_idx_w3,
    input logic [7:0] arb_l2tlb_idx_w4,
    input logic [7:0] arb_l2tlb_idx_w5,
    input logic [7:0] arb_l2tlb_idx_w6,
    input logic [7:0] arb_l2tlb_idx_w7,
    input logic [23:0] arb_l2tlb_size_bus,
    input logic ptw_write_req1,
    input logic ptw_write_req2,
    input logic [26:0] ptw_write_vpn2,
    input logic [7:0] victim_way,
    input logic [26:0] sel_vpn,
    input logic [1:0] selector,
    input logic [2:0] size_pred [7:0],
    input logic [7:0] raw_idx [7:0],
    input logic [7:0] skew_idx [7:0],
    input logic [7:0] mask_bank_sel,
    input logic arb_ptw_write_grant,
    input logic arb_ptw_grant,
    input logic arb_tlboper_grant,
    input logic arb_reqq_grant,
    input logic arb_pfu_grant,
    input logic tlboper_on,
    input logic ptw_on,
    input logic prefetch_mask
);

  import mmu_params_pkg::*;
  import mmu_common_pkg::*;
  import uvm_pkg::*;

  logic [63:0] l2tlb_hash_check_count;
  logic        l2tlb_hash_check_en_comb;
  logic [63:0] l2tlb_idx_dut_comb;
  logic [63:0] l2tlb_idx_exp_comb;
  logic [63:0] l2tlb_idx_int_comb;
  logic [23:0] l2tlb_size_exp_comb;
  logic [23:0] l2tlb_size_int_comb;
  logic [7:0]  l2tlb_bank_exp_comb;
  logic [7:0]  l2tlb_bank_int_comb;

  longint unsigned arb_ptw_req_seen;
  longint unsigned arb_tlbop_req_seen;
  longint unsigned arb_reqq_req_seen;
  longint unsigned arb_pfu_req_seen;
  longint unsigned arb_ptw_grant_seen;
  longint unsigned arb_ptw_write_grant_seen;
  longint unsigned arb_tlbop_grant_seen;
  longint unsigned arb_reqq_grant_seen;
  longint unsigned arb_pfu_grant_seen;
  longint unsigned arb_reqq_payload_sample_seen;
  longint unsigned arb_pfu_payload_sample_seen;
  longint unsigned arb_tlbop_payload_sample_seen;
  longint unsigned arb_ptw_read_payload_sample_seen;
  longint unsigned arb_ptw_write_payload_sample_seen;
  longint unsigned arb_multi_req_seen;
  longint unsigned arb_four_req_seen;
  longint unsigned arb_reqq_pfu_conflict_seen;
  longint unsigned arb_ptw_reqq_conflict_seen;
  longint unsigned arb_tlbop_reqq_conflict_seen;
  longint unsigned arb_ptw_tlbop_conflict_seen;
  longint unsigned arb_ptw_pfu_conflict_seen;
  longint unsigned arb_tlbop_pfu_conflict_seen;
  longint unsigned arb_ptw_reqq_pfu_conflict_seen;
  longint unsigned arb_tlbop_reqq_pfu_conflict_seen;
  longint unsigned arb_ptw_tlbop_reqq_conflict_seen;
  longint unsigned arb_ptw_tlbop_pfu_conflict_seen;
  longint unsigned arb_ptw_on_seen;
  longint unsigned arb_tlboper_on_seen;
  longint unsigned arb_ptw_on_reqq_block_seen;
  longint unsigned arb_tlboper_on_pfu_block_seen;
  longint unsigned arb_prefetch_mask_seen;
  longint unsigned arb_prefetch_mask_release_seen;

  function automatic int unsigned l2tlb_arb_req_count(
    input logic ptw_req,
    input logic tlbop_req,
    input logic reqq_req,
    input logic pfu_req
  );
    l2tlb_arb_req_count = int'(ptw_req) + int'(tlbop_req)
                        + int'(reqq_req) + int'(pfu_req);
  endfunction

  function automatic void l2tlb_hash_report_error(input string msg);
    uvm_report_error("L2TLB_HASH_FAIL", msg, UVM_NONE,
                     "testbench/top/mmu_arb_sva.sv", 0);
  endfunction

  function automatic logic [63:0] expected_idx_bus_from(
    input logic [26:0] vpn,
    input logic        tlbop_grant,
    input logic        tlbop_idx_not_va,
    input logic [10:0] tlbop_idx
  );
    expected_idx_bus_from = l2tlb_skew_index_bus(vpn_t'(vpn));
    if (tlbop_grant && tlbop_idx_not_va)
      expected_idx_bus_from = {8{tlbop_idx[7:0]}};
  endfunction

  function automatic logic [7:0] expected_bank_sel_from(
    input logic       pfu_grant,
    input logic       reqq_grant,
    input logic       ptw_write_grant,
    input logic       tlbop_grant,
    input logic       ptw_grant,
    input logic [7:0] victim,
    input logic [7:0] tlbop_bank,
    input logic [1:0] ptw_selector,
    input logic [2:0] ptw_pgs
  );
    expected_bank_sel_from = '0;
    if (pfu_grant || reqq_grant)
      expected_bank_sel_from = 8'hff;
    else if (ptw_write_grant)
      expected_bank_sel_from = victim;
    else if (tlbop_grant)
      expected_bank_sel_from = tlbop_bank;
    else if (ptw_grant)
      expected_bank_sel_from = l2tlb_page_bank_mask(ptw_selector, ptw_pgs);
  endfunction

  function automatic logic [23:0] expected_size_bus_from(input logic [26:0] vpn);
    expected_size_bus_from = l2tlb_size_bus(vpn_t'(vpn));
  endfunction

  function automatic bit valid_l2tlb_page_size(input logic [2:0] pgs);
    return (pgs == PGS_4K) || (pgs == PGS_2M) || (pgs == PGS_1G);
  endfunction

  assign l2tlb_hash_check_en_comb =
      arb_l2tlb_req
      && !$isunknown({arb_ptw_grant, arb_ptw_write_grant,
                      arb_tlboper_grant, arb_reqq_grant, arb_pfu_grant,
                      arb_l2tlb_vpn, arb_l2tlb_size_bus, arb_l2tlb_bank_sel})
      && !(arb_tlboper_grant && $isunknown(tlboper_arb_bank_sel))
      && !(arb_tlboper_grant && tlboper_arb_idx_not_va && $isunknown(tlboper_arb_idx[7:0]))
      && !(arb_ptw_grant && $isunknown({ptw_arb_vpn[19:18], ptw_arb_pgs}))
      && !(arb_ptw_write_grant && $isunknown(victim_way));

  assign l2tlb_idx_dut_comb  = {arb_l2tlb_idx_w7, arb_l2tlb_idx_w6,
                                arb_l2tlb_idx_w5, arb_l2tlb_idx_w4,
                                arb_l2tlb_idx_w3, arb_l2tlb_idx_w2,
                                arb_l2tlb_idx_w1, arb_l2tlb_idx_w0};
  assign l2tlb_idx_exp_comb  = expected_idx_bus_from(
      arb_l2tlb_vpn, arb_tlboper_grant, tlboper_arb_idx_not_va,
      tlboper_arb_idx);
  assign l2tlb_idx_int_comb  = {skew_idx[7], skew_idx[6], skew_idx[5], skew_idx[4],
                                skew_idx[3], skew_idx[2], skew_idx[1], skew_idx[0]};
  assign l2tlb_size_exp_comb = expected_size_bus_from(arb_l2tlb_vpn);
  assign l2tlb_size_int_comb = {size_pred[7], size_pred[6], size_pred[5], size_pred[4],
                                size_pred[3], size_pred[2], size_pred[1], size_pred[0]};
  assign l2tlb_bank_exp_comb = expected_bank_sel_from(
      arb_pfu_grant, arb_reqq_grant, arb_ptw_write_grant,
      arb_tlboper_grant, arb_ptw_grant, victim_way, tlboper_arb_bank_sel,
      ptw_arb_vpn[19:18], ptw_arb_pgs);
  assign l2tlb_bank_int_comb = mask_bank_sel;

  always_ff @(posedge forever_cpuclk or negedge cpurst_b) begin
    if (!cpurst_b) begin
      l2tlb_hash_check_count <= 64'd0;
      arb_ptw_req_seen <= 0;
      arb_tlbop_req_seen <= 0;
      arb_reqq_req_seen <= 0;
      arb_pfu_req_seen <= 0;
      arb_ptw_grant_seen <= 0;
      arb_ptw_write_grant_seen <= 0;
      arb_tlbop_grant_seen <= 0;
      arb_reqq_grant_seen <= 0;
      arb_pfu_grant_seen <= 0;
      arb_reqq_payload_sample_seen <= 0;
      arb_pfu_payload_sample_seen <= 0;
      arb_tlbop_payload_sample_seen <= 0;
      arb_ptw_read_payload_sample_seen <= 0;
      arb_ptw_write_payload_sample_seen <= 0;
      arb_multi_req_seen <= 0;
      arb_four_req_seen <= 0;
      arb_reqq_pfu_conflict_seen <= 0;
      arb_ptw_reqq_conflict_seen <= 0;
      arb_tlbop_reqq_conflict_seen <= 0;
      arb_ptw_tlbop_conflict_seen <= 0;
      arb_ptw_pfu_conflict_seen <= 0;
      arb_tlbop_pfu_conflict_seen <= 0;
      arb_ptw_reqq_pfu_conflict_seen <= 0;
      arb_tlbop_reqq_pfu_conflict_seen <= 0;
      arb_ptw_tlbop_reqq_conflict_seen <= 0;
      arb_ptw_tlbop_pfu_conflict_seen <= 0;
      arb_ptw_on_seen <= 0;
      arb_tlboper_on_seen <= 0;
      arb_ptw_on_reqq_block_seen <= 0;
      arb_tlboper_on_pfu_block_seen <= 0;
      arb_prefetch_mask_seen <= 0;
      arb_prefetch_mask_release_seen <= 0;
    end else begin
      if (ptw_arb_req)
        arb_ptw_req_seen <= arb_ptw_req_seen + 1;
      if (tlboper_arb_req)
        arb_tlbop_req_seen <= arb_tlbop_req_seen + 1;
      if (issue_valid)
        arb_reqq_req_seen <= arb_reqq_req_seen + 1;
      if (lsu_mmu_va2_vld && !dutlb_xx_mmu_off)
        arb_pfu_req_seen <= arb_pfu_req_seen + 1;
      if (arb_ptw_grant)
        arb_ptw_grant_seen <= arb_ptw_grant_seen + 1;
      if (arb_ptw_write_grant)
        arb_ptw_write_grant_seen <= arb_ptw_write_grant_seen + 1;
      if (arb_tlboper_grant)
        arb_tlbop_grant_seen <= arb_tlbop_grant_seen + 1;
      if (arb_reqq_grant)
        arb_reqq_grant_seen <= arb_reqq_grant_seen + 1;
      if (arb_pfu_grant)
        arb_pfu_grant_seen <= arb_pfu_grant_seen + 1;
      if (arb_reqq_grant)
        arb_reqq_payload_sample_seen <= arb_reqq_payload_sample_seen + 1;
      if (arb_pfu_grant)
        arb_pfu_payload_sample_seen <= arb_pfu_payload_sample_seen + 1;
      if (arb_tlboper_grant)
        arb_tlbop_payload_sample_seen <= arb_tlbop_payload_sample_seen + 1;
      if (arb_ptw_grant)
        arb_ptw_read_payload_sample_seen <= arb_ptw_read_payload_sample_seen + 1;
      if (arb_ptw_write_grant)
        arb_ptw_write_payload_sample_seen <= arb_ptw_write_payload_sample_seen + 1;
      if (l2tlb_arb_req_count(ptw_arb_req, tlboper_arb_req, issue_valid,
            lsu_mmu_va2_vld && !dutlb_xx_mmu_off) >= 2)
        arb_multi_req_seen <= arb_multi_req_seen + 1;
      if (l2tlb_arb_req_count(ptw_arb_req, tlboper_arb_req, issue_valid,
            lsu_mmu_va2_vld && !dutlb_xx_mmu_off) == 4) begin
        if (arb_four_req_seen == 0)
          $display("[L2TLB_ARB_FINE_HIT] bin=four_req t=%0t ptw_req=%0b tlbop_req=%0b reqq_req=%0b pfu_req=%0b grant={ptw_wr:%0b ptw:%0b tlbop:%0b reqq:%0b pfu:%0b} block={ptw_on:%0b tlboper_on:%0b prefetch_mask:%0b wbuf_full:%0b}",
            $time, ptw_arb_req, tlboper_arb_req, issue_valid,
            lsu_mmu_va2_vld && !dutlb_xx_mmu_off,
            arb_ptw_write_grant, arb_ptw_grant, arb_tlboper_grant,
            arb_reqq_grant, arb_pfu_grant, ptw_on, tlboper_on,
            prefetch_mask, l2tlb_arb_rrpv_wbuf_full);
        arb_four_req_seen <= arb_four_req_seen + 1;
      end
      if (issue_valid && lsu_mmu_va2_vld && !dutlb_xx_mmu_off) begin
        if (arb_reqq_pfu_conflict_seen == 0)
          $display("[L2TLB_ARB_FINE_HIT] bin=reqq_pfu_conflict t=%0t issue_type=0x%0h pfu_vpn=0x%07h grant={reqq:%0b pfu:%0b} block={ptw_on:%0b tlboper_on:%0b prefetch_mask:%0b}",
            $time, issue_type, l2tlb_arb_pfu_vpn, arb_reqq_grant,
            arb_pfu_grant, ptw_on, tlboper_on, prefetch_mask);
        arb_reqq_pfu_conflict_seen <= arb_reqq_pfu_conflict_seen + 1;
      end
      if (ptw_arb_req && issue_valid) begin
        if (arb_ptw_reqq_conflict_seen == 0)
          $display("[L2TLB_ARB_FINE_HIT] bin=ptw_reqq_conflict t=%0t ptw_vpn=0x%07h issue_vpn=0x%07h issue_type=0x%0h grant={ptw:%0b reqq:%0b} block={ptw_on:%0b tlboper_on:%0b}",
            $time, ptw_arb_vpn, issue_vpn, issue_type, arb_ptw_grant,
            arb_reqq_grant, ptw_on, tlboper_on);
        arb_ptw_reqq_conflict_seen <= arb_ptw_reqq_conflict_seen + 1;
      end
      if (tlboper_arb_req && issue_valid) begin
        if (arb_tlbop_reqq_conflict_seen == 0)
          $display("[L2TLB_ARB_FINE_HIT] bin=tlbop_reqq_conflict t=%0t tlbop_vpn=0x%07h issue_vpn=0x%07h issue_type=0x%0h grant={tlbop:%0b reqq:%0b} block={ptw_on:%0b tlboper_on:%0b}",
            $time, tlboper_arb_vpn, issue_vpn, issue_type,
            arb_tlboper_grant, arb_reqq_grant, ptw_on, tlboper_on);
        arb_tlbop_reqq_conflict_seen <= arb_tlbop_reqq_conflict_seen + 1;
      end
      if (ptw_arb_req && tlboper_arb_req) begin
        if (arb_ptw_tlbop_conflict_seen == 0)
          $display("[L2TLB_ARB_FINE_DIAG] bin=ptw_tlbop_conflict t=%0t ptw_vpn=0x%07h tlbop_vpn=0x%07h grant={ptw:%0b tlbop:%0b} block={ptw_on:%0b tlboper_on:%0b}",
            $time, ptw_arb_vpn, tlboper_arb_vpn, arb_ptw_grant,
            arb_tlboper_grant, ptw_on, tlboper_on);
        arb_ptw_tlbop_conflict_seen <= arb_ptw_tlbop_conflict_seen + 1;
      end
      if (ptw_arb_req && lsu_mmu_va2_vld && !dutlb_xx_mmu_off) begin
        if (arb_ptw_pfu_conflict_seen == 0)
          $display("[L2TLB_ARB_FINE_DIAG] bin=ptw_pfu_conflict t=%0t ptw_vpn=0x%07h pfu_vpn=0x%07h grant={ptw:%0b pfu:%0b} block={ptw_on:%0b prefetch_mask:%0b}",
            $time, ptw_arb_vpn, l2tlb_arb_pfu_vpn, arb_ptw_grant,
            arb_pfu_grant, ptw_on, prefetch_mask);
        arb_ptw_pfu_conflict_seen <= arb_ptw_pfu_conflict_seen + 1;
      end
      if (tlboper_arb_req && lsu_mmu_va2_vld && !dutlb_xx_mmu_off) begin
        if (arb_tlbop_pfu_conflict_seen == 0)
          $display("[L2TLB_ARB_FINE_DIAG] bin=tlbop_pfu_conflict t=%0t tlbop_vpn=0x%07h pfu_vpn=0x%07h grant={tlbop:%0b pfu:%0b} block={tlboper_on:%0b prefetch_mask:%0b}",
            $time, tlboper_arb_vpn, l2tlb_arb_pfu_vpn, arb_tlboper_grant,
            arb_pfu_grant, tlboper_on, prefetch_mask);
        arb_tlbop_pfu_conflict_seen <= arb_tlbop_pfu_conflict_seen + 1;
      end
      if (ptw_arb_req && issue_valid && lsu_mmu_va2_vld && !dutlb_xx_mmu_off) begin
        if (arb_ptw_reqq_pfu_conflict_seen == 0)
          $display("[L2TLB_ARB_FINE_DIAG] bin=ptw_reqq_pfu_conflict t=%0t ptw_vpn=0x%07h issue_vpn=0x%07h pfu_vpn=0x%07h grant={ptw:%0b reqq:%0b pfu:%0b} block={ptw_on:%0b prefetch_mask:%0b}",
            $time, ptw_arb_vpn, issue_vpn, l2tlb_arb_pfu_vpn,
            arb_ptw_grant, arb_reqq_grant, arb_pfu_grant,
            ptw_on, prefetch_mask);
        arb_ptw_reqq_pfu_conflict_seen <= arb_ptw_reqq_pfu_conflict_seen + 1;
      end
      if (tlboper_arb_req && issue_valid && lsu_mmu_va2_vld && !dutlb_xx_mmu_off) begin
        if (arb_tlbop_reqq_pfu_conflict_seen == 0)
          $display("[L2TLB_ARB_FINE_DIAG] bin=tlbop_reqq_pfu_conflict t=%0t tlbop_vpn=0x%07h issue_vpn=0x%07h pfu_vpn=0x%07h grant={tlbop:%0b reqq:%0b pfu:%0b} block={tlboper_on:%0b prefetch_mask:%0b}",
            $time, tlboper_arb_vpn, issue_vpn, l2tlb_arb_pfu_vpn,
            arb_tlboper_grant, arb_reqq_grant, arb_pfu_grant,
            tlboper_on, prefetch_mask);
        arb_tlbop_reqq_pfu_conflict_seen <= arb_tlbop_reqq_pfu_conflict_seen + 1;
      end
      if (ptw_arb_req && tlboper_arb_req && issue_valid) begin
        if (arb_ptw_tlbop_reqq_conflict_seen == 0)
          $display("[L2TLB_ARB_FINE_DIAG] bin=ptw_tlbop_reqq_conflict t=%0t ptw_vpn=0x%07h tlbop_vpn=0x%07h issue_vpn=0x%07h grant={ptw:%0b tlbop:%0b reqq:%0b}",
            $time, ptw_arb_vpn, tlboper_arb_vpn, issue_vpn,
            arb_ptw_grant, arb_tlboper_grant, arb_reqq_grant);
        arb_ptw_tlbop_reqq_conflict_seen <= arb_ptw_tlbop_reqq_conflict_seen + 1;
      end
      if (ptw_arb_req && tlboper_arb_req && lsu_mmu_va2_vld && !dutlb_xx_mmu_off) begin
        if (arb_ptw_tlbop_pfu_conflict_seen == 0)
          $display("[L2TLB_ARB_FINE_DIAG] bin=ptw_tlbop_pfu_conflict t=%0t ptw_vpn=0x%07h tlbop_vpn=0x%07h pfu_vpn=0x%07h grant={ptw:%0b tlbop:%0b pfu:%0b} prefetch_mask=%0b",
            $time, ptw_arb_vpn, tlboper_arb_vpn, l2tlb_arb_pfu_vpn,
            arb_ptw_grant, arb_tlboper_grant, arb_pfu_grant,
            prefetch_mask);
        arb_ptw_tlbop_pfu_conflict_seen <= arb_ptw_tlbop_pfu_conflict_seen + 1;
      end
      if (ptw_on)
        arb_ptw_on_seen <= arb_ptw_on_seen + 1;
      if (tlboper_on)
        arb_tlboper_on_seen <= arb_tlboper_on_seen + 1;
      if (ptw_on && issue_valid && !arb_reqq_grant) begin
        if (arb_ptw_on_reqq_block_seen == 0)
          $display("[L2TLB_ARB_FINE_HIT] bin=ptw_on_reqq_block t=%0t issue_vpn=0x%07h issue_type=0x%0h grant={ptw_wr:%0b ptw:%0b tlbop:%0b reqq:%0b pfu:%0b}",
            $time, issue_vpn, issue_type, arb_ptw_write_grant,
            arb_ptw_grant, arb_tlboper_grant, arb_reqq_grant,
            arb_pfu_grant);
        arb_ptw_on_reqq_block_seen <= arb_ptw_on_reqq_block_seen + 1;
      end
      if (tlboper_on && lsu_mmu_va2_vld && !arb_pfu_grant) begin
        if (arb_tlboper_on_pfu_block_seen == 0)
          $display("[L2TLB_ARB_FINE_HIT] bin=tlboper_on_pfu_block t=%0t pfu_vpn=0x%07h grant={ptw_wr:%0b ptw:%0b tlbop:%0b reqq:%0b pfu:%0b} prefetch_mask=%0b",
            $time, l2tlb_arb_pfu_vpn, arb_ptw_write_grant,
            arb_ptw_grant, arb_tlboper_grant, arb_reqq_grant,
            arb_pfu_grant, prefetch_mask);
        arb_tlboper_on_pfu_block_seen <= arb_tlboper_on_pfu_block_seen + 1;
      end
      if (prefetch_mask)
        arb_prefetch_mask_seen <= arb_prefetch_mask_seen + 1;
      if (prefetch_mask && (mmu_lsu_pa2_err || mmu_lsu_pa2_vld || l2tlb_arb_pfu_miss_mb_full))
        arb_prefetch_mask_release_seen <= arb_prefetch_mask_release_seen + 1;
      if (arb_l2tlb_req) begin
        l2tlb_hash_check_count <= l2tlb_hash_check_count + 64'd1;
        // Detailed per-cycle hash check disabled by default — uncomment
        // for L2TLB hash function debugging only.  The formatted $display
        // on every L2TLB request cycle severely slows simulation.
        // $display("[L2TLB_HASH_CHECK] count=%0d ...", ...);
      end
    end
  end

  // 验证意图: 5 个 grant 在任意周期至多 1 个为 1（固定优先级 + ptw 写时序的互斥结构）
  a_grant_onehot0: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    $onehot0({arb_pfu_grant, arb_reqq_grant, arb_tlboper_grant, arb_ptw_grant, arb_ptw_write_grant}));

  // 验证意图: 有 arb_l2tlb_req 时，上述五路中恰有一路置位（与 OR 合路一致）
  a_grant_onehot_when_req: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_l2tlb_req |-> $onehot({arb_pfu_grant, arb_reqq_grant, arb_tlboper_grant, arb_ptw_grant, arb_ptw_write_grant}));

  // 验证意图: 同步复位低有效期间/释放后的采样边沿，PTW 两拍写请求寄存器被清零
  a_ptw_write_pipe_reset_safe: assert property (@(posedge forever_cpuclk)
    !cpurst_b |-> (!ptw_write_req1 && !ptw_write_req2));

  // L2TLB_SVA_005/019/020/021: block windows must not leak grants to
  // lower-priority or masked sources. PTW writeback is allowed during ptw_on.
  a_ptw_on_blocks_non_write_sources: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_on |-> !(arb_ptw_grant || arb_tlboper_grant || arb_reqq_grant || arb_pfu_grant));

  a_tlboper_on_blocks_lookup_sources: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlboper_on |-> !(arb_ptw_grant || arb_reqq_grant || arb_pfu_grant));

  a_wbuf_full_blocks_new_reads: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    l2tlb_arb_rrpv_wbuf_full |-> !(arb_ptw_grant || arb_tlboper_grant || arb_reqq_grant || arb_pfu_grant));

  // L2TLB_SVA_022 / Phase6F: wbuf full blocks only new RRPV-producing reads.
  // PTW writeback is the drain-side architectural update and must remain legal.
  a_wbuf_full_allows_ptw_writeback: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (l2tlb_arb_rrpv_wbuf_full && ptw_write_req2 && ptw_on && !tlboper_on)
      |-> arb_ptw_write_grant);

  a_prefetch_mask_blocks_pfu_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    prefetch_mask |-> !arb_pfu_grant);

  // L2TLB_SVA_005/006: fixed-priority grant eligibility when no block is active.
  a_ptw_priority_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (ptw_arb_req && !ptw_on && !tlboper_on && !l2tlb_arb_rrpv_wbuf_full)
      |-> arb_ptw_grant);

  a_tlboper_priority_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (tlboper_arb_req && !ptw_arb_req && !ptw_on && !l2tlb_arb_rrpv_wbuf_full)
      |-> arb_tlboper_grant);

  a_reqq_priority_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (issue_valid && !ptw_arb_req && !tlboper_arb_req && !ptw_on && !tlboper_on
      && !l2tlb_arb_rrpv_wbuf_full)
      |-> arb_reqq_grant);

  a_pfu_priority_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (lsu_mmu_va2_vld && !dutlb_xx_mmu_off && !ptw_arb_req && !tlboper_arb_req
      && !issue_valid && !ptw_on && !tlboper_on && !prefetch_mask
      && !l2tlb_arb_rrpv_wbuf_full)
      |-> arb_pfu_grant);

  // L2TLB_SVA_005: selected payload must come from the granted source.
  a_reqq_payload_no_cross: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_reqq_grant |-> (arb_l2tlb_vpn == issue_vpn
                     && arb_l2tlb_trans_id == issue_queue_id
                     && arb_l2tlb_eid == issue_eid
                     && arb_l2tlb_acc_type == issue_type));

  a_pfu_payload_no_cross: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_pfu_grant |-> (arb_l2tlb_vpn == l2tlb_arb_pfu_vpn
                    && arb_l2tlb_acc_type == 3'b100));

  a_tlboper_payload_no_cross: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_tlboper_grant |-> (arb_l2tlb_vpn == tlboper_arb_vpn
                        && arb_l2tlb_acc_type == 3'b001
                        && arb_l2tlb_write == tlboper_arb_write));

  a_ptw_read_payload_no_cross: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_ptw_grant |-> (arb_l2tlb_vpn == ptw_arb_vpn
                    && !arb_l2tlb_write
                    && arb_l2tlb_acc_type == 3'b000));

  a_ptw_write_payload_class: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_ptw_write_grant |-> (arb_l2tlb_write && arb_l2tlb_acc_type == 3'b101));

  // L2TLB_HASH_MODEL: exact address hash/size/bank modeling must match mmu_arb
  // for all L2TLB request sources. The model intentionally does not predict
  // victim state beyond checking the already-selected PTW write victim_way.
  a_l2tlb_idx_hash_exact: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (l2tlb_hash_check_en_comb && !(arb_tlboper_grant && tlboper_arb_idx_not_va))
      |-> (l2tlb_idx_int_comb == l2tlb_idx_exp_comb))
    else l2tlb_hash_report_error($sformatf("kind=idx src={ptw:%0b ptw_wr:%0b tlbop:%0b reqq:%0b pfu:%0b} vpn=0x%07h sel_vpn=0x%07h tlbop_idx_not_va=%0b idx_dut=0x%016h idx_int=0x%016h idx_exp=0x%016h",
      $sampled(arb_ptw_grant), $sampled(arb_ptw_write_grant),
      $sampled(arb_tlboper_grant), $sampled(arb_reqq_grant),
      $sampled(arb_pfu_grant), $sampled(arb_l2tlb_vpn),
      $sampled(sel_vpn), $sampled(tlboper_arb_idx_not_va),
      $sampled(l2tlb_idx_dut_comb), $sampled(l2tlb_idx_int_comb),
      $sampled(l2tlb_idx_exp_comb)));

  a_l2tlb_size_pred_exact: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    l2tlb_hash_check_en_comb |-> (arb_l2tlb_size_bus == l2tlb_size_exp_comb))
    else l2tlb_hash_report_error($sformatf("kind=size src={ptw:%0b ptw_wr:%0b tlbop:%0b reqq:%0b pfu:%0b} vpn=0x%07h sel_vpn=0x%07h size_dut=0x%06h size_int=0x%06h size_exp=0x%06h",
      $sampled(arb_ptw_grant), $sampled(arb_ptw_write_grant),
      $sampled(arb_tlboper_grant), $sampled(arb_reqq_grant),
      $sampled(arb_pfu_grant), $sampled(arb_l2tlb_vpn),
      $sampled(sel_vpn), $sampled(arb_l2tlb_size_bus),
      $sampled(l2tlb_size_int_comb), $sampled(l2tlb_size_exp_comb)));

  a_l2tlb_bank_sel_exact: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    l2tlb_hash_check_en_comb |-> (arb_l2tlb_bank_sel == l2tlb_bank_exp_comb))
    else l2tlb_hash_report_error($sformatf("kind=bank src={ptw:%0b ptw_wr:%0b tlbop:%0b reqq:%0b pfu:%0b} vpn=0x%07h ptw_selector=0x%0h ptw_pgs=0x%0h bank_dut=0x%02h bank_int=0x%02h bank_exp=0x%02h victim=0x%02h tlbop_bank=0x%02h",
      $sampled(arb_ptw_grant), $sampled(arb_ptw_write_grant),
      $sampled(arb_tlboper_grant), $sampled(arb_reqq_grant),
      $sampled(arb_pfu_grant), $sampled(arb_l2tlb_vpn),
      $sampled(ptw_arb_vpn[19:18]), $sampled(ptw_arb_pgs),
      $sampled(arb_l2tlb_bank_sel), $sampled(l2tlb_bank_int_comb),
      $sampled(l2tlb_bank_exp_comb), $sampled(victim_way),
      $sampled(tlboper_arb_bank_sel)));

  a_ptw_pgs_legal_when_read_grant: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_ptw_grant |-> valid_l2tlb_page_size(ptw_arb_pgs));

  // L2TLB_SVA_021: a sustained PFU request is masked after accept until
  // response/error or MB-full retry releases the mask.
  a_pfu_grant_sets_prefetch_mask: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (arb_pfu_grant && !(mmu_lsu_pa2_err || mmu_lsu_pa2_vld || l2tlb_arb_pfu_miss_mb_full))
      |=> prefetch_mask);

  a_pfu_response_releases_prefetch_mask: assert property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    (mmu_lsu_pa2_err || mmu_lsu_pa2_vld || l2tlb_arb_pfu_miss_mb_full)
      |=> !prefetch_mask);

  // Trigger evidence for Phase6G assertion/cover extraction.
  c_pairwise_reqq_pfu_conflict: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    issue_valid && lsu_mmu_va2_vld && arb_reqq_grant);

  c_pairwise_ptw_reqq_conflict: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_arb_req && issue_valid);

  c_pairwise_tlbop_reqq_conflict: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlboper_arb_req && issue_valid);

  c_diag_ptw_tlbop_conflict: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_arb_req && tlboper_arb_req);

  c_diag_ptw_reqq_pfu_conflict: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_arb_req && issue_valid && lsu_mmu_va2_vld && !dutlb_xx_mmu_off);

  c_diag_tlbop_reqq_pfu_conflict: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlboper_arb_req && issue_valid && lsu_mmu_va2_vld && !dutlb_xx_mmu_off);

  c_ptw_on_blocks_reqq: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    ptw_on && issue_valid && !arb_reqq_grant);

  c_tlboper_on_blocks_pfu: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    tlboper_on && lsu_mmu_va2_vld && !arb_pfu_grant);

  c_prefetch_mask_release: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    prefetch_mask ##1 (mmu_lsu_pa2_err || mmu_lsu_pa2_vld || l2tlb_arb_pfu_miss_mb_full) ##1 !prefetch_mask);

  c_wbuf_full_blocks_new_reads: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    l2tlb_arb_rrpv_wbuf_full
    && (ptw_arb_req || tlboper_arb_req || issue_valid || lsu_mmu_va2_vld)
    && !(arb_ptw_grant || arb_tlboper_grant || arb_reqq_grant || arb_pfu_grant));

  c_wbuf_full_allows_ptw_writeback: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    l2tlb_arb_rrpv_wbuf_full && arb_ptw_write_grant);

  c_l2tlb_hash_selector_00: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_l2tlb_req && (arb_l2tlb_vpn[19:18] == 2'b00));

  c_l2tlb_hash_selector_01: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_l2tlb_req && (arb_l2tlb_vpn[19:18] == 2'b01));

  c_l2tlb_hash_selector_10: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_l2tlb_req && (arb_l2tlb_vpn[19:18] == 2'b10));

  c_l2tlb_hash_selector_11: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_l2tlb_req && (arb_l2tlb_vpn[19:18] == 2'b11));

  c_l2tlb_hash_tlbop_idx_not_va: cover property (@(posedge forever_cpuclk) disable iff (`L2TLB_NEG_DISABLE)
    arb_l2tlb_req && arb_tlboper_grant && tlboper_arb_idx_not_va);

  final begin
    $display("[L2TLB_ARB_FINE] ptw_req=%0d tlbop_req=%0d reqq_req=%0d pfu_req=%0d ptw_grant=%0d ptw_write_grant=%0d tlbop_grant=%0d reqq_grant=%0d pfu_grant=%0d reqq_payload=%0d pfu_payload=%0d tlbop_payload=%0d ptw_read_payload=%0d ptw_write_payload=%0d multi_req=%0d four_req=%0d reqq_pfu_conflict=%0d ptw_reqq_conflict=%0d tlbop_reqq_conflict=%0d ptw_tlbop_conflict=%0d ptw_pfu_conflict=%0d tlbop_pfu_conflict=%0d ptw_reqq_pfu_conflict=%0d tlbop_reqq_pfu_conflict=%0d ptw_tlbop_reqq_conflict=%0d ptw_tlbop_pfu_conflict=%0d ptw_on=%0d tlboper_on=%0d ptw_on_reqq_block=%0d tlboper_on_pfu_block=%0d prefetch_mask=%0d prefetch_mask_release=%0d",
      arb_ptw_req_seen, arb_tlbop_req_seen, arb_reqq_req_seen,
      arb_pfu_req_seen, arb_ptw_grant_seen, arb_ptw_write_grant_seen,
      arb_tlbop_grant_seen, arb_reqq_grant_seen, arb_pfu_grant_seen,
      arb_reqq_payload_sample_seen, arb_pfu_payload_sample_seen,
      arb_tlbop_payload_sample_seen, arb_ptw_read_payload_sample_seen,
      arb_ptw_write_payload_sample_seen, arb_multi_req_seen,
      arb_four_req_seen, arb_reqq_pfu_conflict_seen,
      arb_ptw_reqq_conflict_seen, arb_tlbop_reqq_conflict_seen,
      arb_ptw_tlbop_conflict_seen, arb_ptw_pfu_conflict_seen,
      arb_tlbop_pfu_conflict_seen, arb_ptw_reqq_pfu_conflict_seen,
      arb_tlbop_reqq_pfu_conflict_seen,
      arb_ptw_tlbop_reqq_conflict_seen,
      arb_ptw_tlbop_pfu_conflict_seen, arb_ptw_on_seen,
      arb_tlboper_on_seen, arb_ptw_on_reqq_block_seen,
      arb_tlboper_on_pfu_block_seen, arb_prefetch_mask_seen,
      arb_prefetch_mask_release_seen);
  end

endmodule
