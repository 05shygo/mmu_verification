// =============================================================================
// Phase 9 generated test wrapper for PWR-005
// Checker: clock_mon_sb  Reviewer: B
// =============================================================================
`ifndef TEST_CLOCK_GATING_TRANSITION_SVH
`define TEST_CLOCK_GATING_TRANSITION_SVH

class test_clock_gating_transition extends phase9_generated_test_base;

  `uvm_component_utils(test_clock_gating_transition)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PWR-005";
    p9_seq_desc = "mmu_power_gating_vseq";
    p9_checker = "clock_mon_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_power_gating_vseq");
  endfunction

endclass : test_clock_gating_transition

`endif // TEST_CLOCK_GATING_TRANSITION_SVH
