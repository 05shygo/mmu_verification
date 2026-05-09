// =============================================================================
// mmu_dut_probes_if.sv
// Whitebox 观测：DUT 内部 net 在 tb_top 中用 assign 驱动本 interface 的 net；
// mmu_env_pkg 内 mmu_env_cg_whitebox 只持有 virtual mmu_dut_probes_if（禁止 $root）。
// =============================================================================
`ifndef MMU_DUT_PROBES_IF_SV
`define MMU_DUT_PROBES_IF_SV

interface mmu_dut_probes_if (
  input logic clk_i,
  input logic rst_ni
);

  // mmu_l1itlb
  wire [31:0]  l1i_entry_vld;
  wire [1:0]   l1i_ref_fsm;
  wire         l1i_credit_cnt;

  // mmu_l1dtlb
  wire [7:0]   l1d_mb_vld;       // MB_DEPTH=8
  wire [2:0]   l1d_mb_st0;       // mb_entry_state[0]
  wire [15:0]  l1d_entry_vld;
  wire [7:0][2:0]  l1d_mb_state;
  wire [7:0][26:0] l1d_mb_vpn;
  wire [7:0][6:0]  l1d_mb_iid;
  wire [7:0]   l1d_mb_ready;
  wire [7:0]   l1d_mb_wfc;
  wire [7:0]   l1d_mb_wfi;
  wire [7:0]   l1d_mb_store;
  wire [4:0]   l1d_sched_credit_cnt;
  wire         l1d_l2_req_vld;
  wire [26:0]  l1d_l2_req_vpn;
  wire [2:0]   l1d_l2_req_eid;
  wire         l1d_l2_req_is_load;
  wire [26:0]  l1d_p0_req_vpn;
  wire         l1d_p0_addr_hit;
  wire         l1d_p0_hit_vld;
  wire         l1d_p0_miss_vld;
  wire         l1d_p0_pre_sel;
  wire         l1d_p0_expt_match;
  wire [27:0]  l1d_p0_entry_pa;
  wire [27:0]  l1d_p0_off_pa;
  wire [27:0]  l1d_p0_fin_pa;
  wire [26:0]  l1d_p1_req_vpn;
  wire         l1d_p1_addr_hit;
  wire         l1d_p1_hit_vld;
  wire         l1d_p1_miss_vld;
  wire         l1d_p1_pre_sel;
  wire         l1d_p1_expt_match;
  wire [27:0]  l1d_p1_entry_pa;
  wire [27:0]  l1d_p1_off_pa;
  wire [27:0]  l1d_p1_fin_pa;
  wire         l1d_refill_vld;
  wire [1:0]   l1d_refill_src;
  wire [3:0]   l1d_refill_idx;
  wire [26:0]  l1d_refill_vpn;
  wire [27:0]  l1d_refill_ppn;
  wire [2:0]   l1d_refill_pgs;
  wire [15:0]  l1d_entry_upd;
  wire [6:0]   l1d_refill_iid0;
  wire [6:0]   l1d_refill_iid1;
  wire [6:0]   l1d_refill_iid_sel;
  wire [15:0]  l1d_p0_hit_vec;
  wire [3:0]   l1d_p0_hit_idx;
  wire [26:0]  l1d_p0_hit_vpn;
  wire [27:0]  l1d_p0_hit_ppn;
  wire [2:0]   l1d_p0_hit_pgs;
  wire [15:0]  l1d_p1_hit_vec;
  wire [3:0]   l1d_p1_hit_idx;
  wire [26:0]  l1d_p1_hit_vpn;
  wire [27:0]  l1d_p1_hit_ppn;
  wire [2:0]   l1d_p1_hit_pgs;
  wire         l1d_ptw_ref_mb_vld;
  wire [6:0]   l1d_ptw_ref_mb_iid;
  wire [26:0]  l1d_ptw_ref_mb_vpn;
  wire         l1d_expt_wr0_vld;
  wire [3:0]   l1d_expt_wr0_eid;
  wire [6:0]   l1d_expt_wr0_iid;
  wire [26:0]  l1d_expt_wr0_vpn;
  wire         l1d_expt_wr0_pgflt;
  wire         l1d_expt_wr0_acflt;
  wire         l1d_expt_wr1_vld;
  wire [3:0]   l1d_expt_wr1_eid;
  wire [6:0]   l1d_expt_wr1_iid;
  wire [26:0]  l1d_expt_wr1_vpn;
  wire         l1d_expt_wr1_pgflt;
  wire         l1d_expt_wr1_acflt;

  // mmu_l2tlb
  wire [2:0]   l2_bank0;   // way_index[0][2:0]
  wire [7:0]   l2_final_way_hit;
  wire [2:0]   l2_raw_pre_pgs0;
  wire         l2_final_vld;
  wire         l2_final_tlb_hit;
  wire         l2_miss;
  wire         l2_final_is_dtlb;
  wire [26:0]  l2_final_vpn;
  wire [27:0]  l2_final_hit_ppn;
  wire         l2_dtlb_ref_pavld;
  wire         l2_dtlb_ref_cmplt;
  wire [26:0]  l2_dtlb_ref_vpn;
  wire [27:0]  l2_dtlb_ref_ppn;

  // mmu_l2tlb / x_l2tlb_reqq
  wire [8:0]   l2_reqq_vld_vec;  // TOTAL_DEPTH=9
  wire [8:0]   l2_reqq_rdy_vec;
  wire [2:0]   l2_reqq_qid;
  wire         l2_reqq_issue_valid;
  wire [2:0]   l2_reqq_issue_type;

  // mmu_l2tlb / x_l2tlb_mb
  wire [8:0]   l2mb_vld_vec;
  wire [8:0]   l2mb_rdy_vec;
  wire         l2mb_issue_req;
  wire [5:0]   l2mb_issue_eid;
  wire [2:0]   l2mb_issue_type;
  wire         l2mb_alloc_valid;

  // ptw
  wire [1:0]   ptw_xbar_hit_lvl;
  wire [2:0]   ptw_mbuf_twu_lvl;
  wire         ptw_fault_any;    // pgflt_vld | acc_err_vld
  wire         ptw_jtlb_ready;
  wire [3:0]   ptw_twu_idle;
  wire [3:0]   ptw_twu_mask;
  wire [3:0][2:0] ptw_twu_data_ready;
  wire [3:0]   ptw_mbuf_twu_have;
  wire [8:0]   ptw_mbuf_entry_vld;
  wire [3:0]   ptw_twu_ref_req;
  wire [3:0]   ptw_twu_pgflt_vec;
  wire [3:0]   ptw_twu_acc_err_vec;
  wire         ptw_pgflt_vld;
  wire         ptw_acc_err_vld;
  wire         ptw_l2tlb_ref_pgflt;
  wire         ptw_l2tlb_ref_acc_err;
  wire         l2tlb_ptw_req;
  wire [5:0]   l2tlb_ptw_id;
  wire [2:0]   l2tlb_ptw_type;
  wire         ptw_lsu_data_req;
  wire [8:0]   ptw_lsu_data_req_grant;
  wire         ptw_l2tlb_cmplt;
  wire [5:0]   ptw_l2tlb_id;
  wire [2:0]   ptw_l2tlb_type;
  wire         ptw_l1i_ref_cmplt;
  wire         ptw_arb_req;
  wire         arb_ptw_grant;
  wire         arb_pfu_grant;
  wire         arb_l2tlb_req;
  wire [2:0]   ptw_arb_pgs;
  wire [26:0]  ptw_arb_vpn;
  wire         ptw_l1d_ref_cmplt;
  wire [2:0]   ptw_l1d_ref_id;
  wire [27:0]  ptw_l1d_ref_ppn;
  wire [47:0]  ptw_arb_ref_tag_din;
  wire         ptw_cp0_maee;
  wire         maee_leaf_lvl1_hit;
  wire         maee_leaf_lvl2_hit;
  wire         maee_leaf_lvl3_hit;
  wire         maee_csr_path_hit;
  wire         maee_refill_path_hit;

  // Phase 13 PMP/TWU and SysMap/TWU probes.
  wire [3:0][2:0] p13_pmp_vld_vec;
  wire [3:0][2:0] p13_pmp_grant_vec;
  wire [3:0][2:0] p13_pmp_deny_vec;
  wire [3:0][2:0] p13_pmp_wait_vec;
  wire [3:0][2:0] p13_pmp_mbuf_req_vec;
  wire [3:0][2:0][2:0] p13_pmp_type_vec;
  wire [3:0][3:0] p13_pmp_flg_vec;
  wire [3:0][27:0] p13_pmp_pa_vec;
  wire [3:0] p13_pmp_fetch_vec;
  wire [3:0] pfu_pmp_flg4;
  wire [4:0] pfu_sysmap_flg4;
  wire       pfu_l2tlb_deny;
  wire       pfu_l2tlb_acc_fault;
  wire       pfu_l2tlb_flag_fault;
  wire [3:0][4:0] p13_sysmap_flg_vec;
  wire [3:0][7:0] p13_sysmap_hit_vec;
  wire [3:0][27:0] p13_sysmap_pa_vec;
  wire [3:0][39:0] p13_twu_sysmap_adder_vec;
  wire [3:0] p13_twu_csr_cross_vec;
  wire [3:0] p13_twu_crs2_1g_vec;
  wire [3:0] p13_twu_crs2_2m_vec;
  wire [3:0] p13_twu_crs2_chk_vec;
  wire [3:0] p13_csr_refill_req_vec;
  wire [3:0][2:0] p13_csr_refill_pgs_vec;
  wire [3:0][41:0] p13_csr_refill_data_vec;

  // ct_mmu_tlboper
  wire [3:0]   tlbiva_cur_st;
  wire         rtu_yy_xx_flush;
  wire         tlboper_utlb_clr;
  wire         tlboper_utlb_inv_va_req;

  // Monitor clocking
  clocking mon_cb @(posedge clk_i);
    default input #1step;
    input l1i_entry_vld, l1i_ref_fsm, l1i_credit_cnt;
    input l1d_mb_vld, l1d_mb_st0;
    input l1d_entry_vld, l1d_mb_state, l1d_mb_vpn, l1d_mb_iid;
    input l1d_mb_ready, l1d_mb_wfc, l1d_mb_wfi, l1d_mb_store;
    input l1d_sched_credit_cnt, l1d_l2_req_vld, l1d_l2_req_vpn;
    input l1d_l2_req_eid, l1d_l2_req_is_load;
    input l1d_p0_req_vpn, l1d_p0_addr_hit, l1d_p0_hit_vld, l1d_p0_miss_vld;
    input l1d_p0_pre_sel, l1d_p0_expt_match, l1d_p0_entry_pa, l1d_p0_off_pa, l1d_p0_fin_pa;
    input l1d_p1_req_vpn, l1d_p1_addr_hit, l1d_p1_hit_vld, l1d_p1_miss_vld;
    input l1d_p1_pre_sel, l1d_p1_expt_match, l1d_p1_entry_pa, l1d_p1_off_pa, l1d_p1_fin_pa;
    input l1d_refill_vld, l1d_refill_src, l1d_refill_idx, l1d_refill_vpn, l1d_refill_ppn;
    input l1d_refill_pgs, l1d_entry_upd, l1d_refill_iid0, l1d_refill_iid1, l1d_refill_iid_sel;
    input l1d_p0_hit_vec, l1d_p0_hit_idx, l1d_p0_hit_vpn, l1d_p0_hit_ppn, l1d_p0_hit_pgs;
    input l1d_p1_hit_vec, l1d_p1_hit_idx, l1d_p1_hit_vpn, l1d_p1_hit_ppn, l1d_p1_hit_pgs;
    input l1d_ptw_ref_mb_vld, l1d_ptw_ref_mb_iid, l1d_ptw_ref_mb_vpn;
    input l1d_expt_wr0_vld, l1d_expt_wr0_eid, l1d_expt_wr0_iid, l1d_expt_wr0_vpn;
    input l1d_expt_wr0_pgflt, l1d_expt_wr0_acflt;
    input l1d_expt_wr1_vld, l1d_expt_wr1_eid, l1d_expt_wr1_iid, l1d_expt_wr1_vpn;
    input l1d_expt_wr1_pgflt, l1d_expt_wr1_acflt;
    input l2_bank0, l2_final_way_hit, l2_raw_pre_pgs0, l2_final_vld, l2_final_tlb_hit;
    input l2_miss, l2_final_is_dtlb, l2_final_vpn, l2_final_hit_ppn;
    input l2_dtlb_ref_pavld, l2_dtlb_ref_cmplt, l2_dtlb_ref_vpn, l2_dtlb_ref_ppn;
    input l2_reqq_vld_vec, l2_reqq_rdy_vec, l2_reqq_qid, l2_reqq_issue_valid, l2_reqq_issue_type;
    input l2mb_vld_vec, l2mb_rdy_vec, l2mb_issue_req, l2mb_issue_eid, l2mb_issue_type, l2mb_alloc_valid;
    input ptw_xbar_hit_lvl, ptw_mbuf_twu_lvl, ptw_fault_any;
    input ptw_jtlb_ready, ptw_twu_idle, ptw_twu_mask, ptw_twu_data_ready;
    input ptw_mbuf_twu_have, ptw_mbuf_entry_vld;
    input ptw_twu_ref_req, ptw_twu_pgflt_vec, ptw_twu_acc_err_vec;
    input ptw_pgflt_vld, ptw_acc_err_vld, ptw_l2tlb_ref_pgflt, ptw_l2tlb_ref_acc_err;
    input l2tlb_ptw_req, l2tlb_ptw_id, l2tlb_ptw_type, ptw_lsu_data_req, ptw_lsu_data_req_grant;
    input ptw_l2tlb_cmplt, ptw_l2tlb_id, ptw_l2tlb_type, ptw_l1i_ref_cmplt;
    input ptw_arb_req, arb_ptw_grant, arb_pfu_grant, arb_l2tlb_req;
    input ptw_arb_pgs, ptw_arb_vpn, ptw_l1d_ref_cmplt, ptw_l1d_ref_id, ptw_l1d_ref_ppn;
    input ptw_arb_ref_tag_din, ptw_cp0_maee;
    input maee_leaf_lvl1_hit, maee_leaf_lvl2_hit, maee_leaf_lvl3_hit;
    input maee_csr_path_hit, maee_refill_path_hit;
    input p13_pmp_vld_vec, p13_pmp_grant_vec, p13_pmp_deny_vec;
    input p13_pmp_wait_vec, p13_pmp_mbuf_req_vec, p13_pmp_type_vec;
    input p13_pmp_flg_vec, p13_pmp_pa_vec, p13_pmp_fetch_vec;
    input pfu_pmp_flg4, pfu_sysmap_flg4, pfu_l2tlb_deny;
    input pfu_l2tlb_acc_fault, pfu_l2tlb_flag_fault;
    input p13_sysmap_flg_vec, p13_sysmap_hit_vec, p13_sysmap_pa_vec;
    input p13_twu_sysmap_adder_vec, p13_twu_csr_cross_vec;
    input p13_twu_crs2_1g_vec, p13_twu_crs2_2m_vec, p13_twu_crs2_chk_vec;
    input p13_csr_refill_req_vec, p13_csr_refill_pgs_vec, p13_csr_refill_data_vec;
    input tlbiva_cur_st, rtu_yy_xx_flush, tlboper_utlb_clr, tlboper_utlb_inv_va_req;
  endclocking

endinterface : mmu_dut_probes_if

`endif // MMU_DUT_PROBES_IF_SV
