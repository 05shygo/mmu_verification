// =============================================================================
// Phase 9 generated test wrapper for EXC-013
// Checker: exception_arb_sb  Reviewer: B
// =============================================================================
`ifndef TEST_CONCURRENT_EXC_PRIORITY_SVH
`define TEST_CONCURRENT_EXC_PRIORITY_SVH

class test_concurrent_exc_priority extends phase9_generated_test_base;

  `uvm_component_utils(test_concurrent_exc_priority)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "EXC-013";
    p9_seq_desc = "mmu_error_rain_vseq";
    p9_checker = "exception_arb_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_error_rain_vseq");
  endfunction

endclass : test_concurrent_exc_priority

`endif // TEST_CONCURRENT_EXC_PRIORITY_SVH
