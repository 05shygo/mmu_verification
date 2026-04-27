// =============================================================================
// Phase 9 generated test wrapper for ITLB_PERM_002
// Checker: translation_sb + cov_csr  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_L1ITLB_ITLB_PERM_002_SVH
`define TEST_MMU_L1ITLB_ITLB_PERM_002_SVH

class test_mmu_l1itlb_itlb_perm_002 extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_l1itlb_itlb_perm_002)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "ITLB_PERM_002";
    p9_seq_desc = "ifu_exec_perm_mix_seq";
    p9_checker = "translation_sb + cov_csr";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ifu_seq_names.push_back("ifu_exec_perm_mix_seq");
  endfunction

endclass : test_mmu_l1itlb_itlb_perm_002

`endif // TEST_MMU_L1ITLB_ITLB_PERM_002_SVH
