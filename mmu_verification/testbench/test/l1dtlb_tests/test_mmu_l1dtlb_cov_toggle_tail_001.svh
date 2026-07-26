// =============================================================================
// T-C (toggle_closure_plan v2, shrunk) — dTLB surviving tail signals only.
// Closes: dutlb_pa_buf[27], fin/off_flg[13:9] (sysmap rounds), pmp_mmu_flg1[3],
// ctc_inv_va_hit_clr[15:9], mb_hit1_vec[4], cp0_mmu_mpp[0], icg enables.
// Dead/stub targets (ref_cur_st/stall/issue_*/fin_pgs...) are waived §二-A(b).
// =============================================================================
`ifndef TEST_MMU_L1DTLB_COV_TOGGLE_TAIL_001_SVH
`define TEST_MMU_L1DTLB_COV_TOGGLE_TAIL_001_SVH

class test_mmu_l1dtlb_cov_toggle_tail_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_toggle_tail_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_TOGGLE_TAIL_001"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "mmu_l1dtlb_toggle_tail_vseq";
    p9_checker  = "translation_sb,l1dtlb_spec_sb,whitebox_cg,l1dtlb_sva";
    num_txn     = 64;
    timeout_ns  = 120_000_000;
    m_vseq_names.push_back("mmu_l1dtlb_toggle_tail_vseq");
  endfunction
endclass

`endif // TEST_MMU_L1DTLB_COV_TOGGLE_TAIL_001_SVH
