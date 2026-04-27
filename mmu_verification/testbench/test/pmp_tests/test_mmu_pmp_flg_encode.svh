// =============================================================================
// Phase 9 generated test wrapper for TC-PMP-004
// Checker: pmp_cg  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_PMP_FLG_ENCODE_SVH
`define TEST_MMU_PMP_FLG_ENCODE_SVH

class test_mmu_pmp_flg_encode extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_pmp_flg_encode)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-PMP-004";
    p9_seq_desc = "pmp_flg_normal_seq + mmu_ptw_thrash_vseq";
    p9_checker = "pmp_cg";
    p9_reviewer = "A+B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_pmp_seq_names.push_back("pmp_flg_normal_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mmu_pmp_flg_encode

`endif // TEST_MMU_PMP_FLG_ENCODE_SVH
