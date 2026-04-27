// =============================================================================
// Phase 9 generated test wrapper for TC-MB-003
// Checker: credit_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_DIR_L2TLB_MB_DUP_ALLOC_PREVENTION_SVH
`define TEST_MMU_DIR_L2TLB_MB_DUP_ALLOC_PREVENTION_SVH

class test_mmu_dir_l2tlb_mb_dup_alloc_prevention extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_dir_l2tlb_mb_dup_alloc_prevention)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-MB-003";
    p9_seq_desc = "mmu_ptw_thrash_vseq";
    p9_checker = "credit_sb";
    p9_reviewer = "B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mmu_dir_l2tlb_mb_dup_alloc_prevention

`endif // TEST_MMU_DIR_L2TLB_MB_DUP_ALLOC_PREVENTION_SVH
