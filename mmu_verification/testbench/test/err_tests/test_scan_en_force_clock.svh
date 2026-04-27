// =============================================================================
// Phase 9 generated test wrapper for PWR-003
// Checker: clock_mon_sb  Reviewer: B
// =============================================================================
`ifndef TEST_SCAN_EN_FORCE_CLOCK_SVH
`define TEST_SCAN_EN_FORCE_CLOCK_SVH

class test_scan_en_force_clock extends phase9_generated_test_base;

  `uvm_component_utils(test_scan_en_force_clock)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PWR-003";
    p9_seq_desc = "mmu_power_gating_vseq";
    p9_checker = "clock_mon_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_power_gating_vseq");
  endfunction

endclass : test_scan_en_force_clock

`endif // TEST_SCAN_EN_FORCE_CLOCK_SVH
