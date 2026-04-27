// =============================================================================
// Phase 9 generated test wrapper for TC-SFENCE-014
// Checker: invalidation_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_SFENCE_CONCURRENT_ACCESS_STALL_SVH
`define TEST_MMU_SFENCE_CONCURRENT_ACCESS_STALL_SVH

class test_mmu_sfence_concurrent_access_stall extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_sfence_concurrent_access_stall)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-SFENCE-014";
    p9_seq_desc = "sfence_vma_stress_seq";
    p9_checker = "invalidation_sb";
    p9_reviewer = "B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_lsu_seq_names.push_back("sfence_vma_stress_seq");
  endfunction

endclass : test_mmu_sfence_concurrent_access_stall

`endif // TEST_MMU_SFENCE_CONCURRENT_ACCESS_STALL_SVH
