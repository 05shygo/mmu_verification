// =============================================================================
// Phase 9 generated test wrapper for TC-RRPV-010
// Checker: credit_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_DIR_RRPV_VICTIM_SELECTION_FIRST_FREE_SVH
`define TEST_MMU_DIR_RRPV_VICTIM_SELECTION_FIRST_FREE_SVH

class test_mmu_dir_rrpv_victim_selection_first_free extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_dir_rrpv_victim_selection_first_free)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-RRPV-010";
    p9_seq_desc = "mmu_rrpv_aging_vseq";
    p9_checker = "credit_sb";
    p9_reviewer = "B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_rrpv_aging_vseq");
  endfunction

endclass : test_mmu_dir_rrpv_victim_selection_first_free

`endif // TEST_MMU_DIR_RRPV_VICTIM_SELECTION_FIRST_FREE_SVH
