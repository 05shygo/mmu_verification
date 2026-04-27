// =============================================================================
// Phase 9 generated test wrapper for TC-BANK-004
// Checker: credit_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_DIR_L2TLB_BANK_WRITE_CONFLICT_PTW_PRIOR_SVH
`define TEST_MMU_DIR_L2TLB_BANK_WRITE_CONFLICT_PTW_PRIOR_SVH

class test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-BANK-004";
    p9_seq_desc = "mmu_l2tlb_bank_conflict_vseq";
    p9_checker = "credit_sb";
    p9_reviewer = "B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
  endfunction

endclass : test_mmu_dir_l2tlb_bank_write_conflict_ptw_prior

`endif // TEST_MMU_DIR_L2TLB_BANK_WRITE_CONFLICT_PTW_PRIOR_SVH
