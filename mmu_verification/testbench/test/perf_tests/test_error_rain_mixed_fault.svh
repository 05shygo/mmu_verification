// =============================================================================
// Phase 9 generated test wrapper for STRESS-010
// Checker: error_sb  Reviewer: B
// =============================================================================
`ifndef TEST_ERROR_RAIN_MIXED_FAULT_SVH
`define TEST_ERROR_RAIN_MIXED_FAULT_SVH

class test_error_rain_mixed_fault extends phase9_generated_test_base;

  `uvm_component_utils(test_error_rain_mixed_fault)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "STRESS-010";
    p9_seq_desc = "misc_hpcp_enable_on_seq + mmu_error_rain_vseq";
    p9_checker = "error_sb";
    p9_reviewer = "B";
    num_txn = 128;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_misc_seq_names.push_back("misc_hpcp_enable_on_seq");
    m_vseq_names.push_back("mmu_error_rain_vseq");
  endfunction

endclass : test_error_rain_mixed_fault

`endif // TEST_ERROR_RAIN_MIXED_FAULT_SVH
