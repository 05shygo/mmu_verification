// =============================================================================
// Phase 9 generated test wrapper for TC-RRPV-012
// Checker: credit_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_RAND_RRPV_VICTIM_ALL_SCENARIOS_SVH
`define TEST_MMU_RAND_RRPV_VICTIM_ALL_SCENARIOS_SVH

class test_mmu_rand_rrpv_victim_all_scenarios extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_rand_rrpv_victim_all_scenarios)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-RRPV-012";
    p9_seq_desc = "mmu_rrpv_aging_vseq";
    p9_checker = "credit_sb";
    p9_reviewer = "B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_rrpv_aging_vseq");
  endfunction

endclass : test_mmu_rand_rrpv_victim_all_scenarios

`endif // TEST_MMU_RAND_RRPV_VICTIM_ALL_SCENARIOS_SVH
