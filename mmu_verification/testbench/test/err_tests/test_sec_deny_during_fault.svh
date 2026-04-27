// =============================================================================
// Phase 9 generated test wrapper for EXC-012
// Checker: pgflt_sb  Reviewer: B
// =============================================================================
`ifndef TEST_SEC_DENY_DURING_FAULT_SVH
`define TEST_SEC_DENY_DURING_FAULT_SVH

class test_sec_deny_during_fault extends phase9_generated_test_base;

  `uvm_component_utils(test_sec_deny_during_fault)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "EXC-012";
    p9_seq_desc = "mmu_error_rain_vseq";
    p9_checker = "pgflt_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_error_rain_vseq");
  endfunction

endclass : test_sec_deny_during_fault

`endif // TEST_SEC_DENY_DURING_FAULT_SVH
