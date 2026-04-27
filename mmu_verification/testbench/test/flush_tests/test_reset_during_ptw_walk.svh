// =============================================================================
// Phase 9 generated test wrapper for RST-004
// Checker: ptw_recovery_sb  Reviewer: B
// =============================================================================
`ifndef TEST_RESET_DURING_PTW_WALK_SVH
`define TEST_RESET_DURING_PTW_WALK_SVH

class test_reset_during_ptw_walk extends phase9_generated_test_base;

  `uvm_component_utils(test_reset_during_ptw_walk)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "RST-004";
    p9_seq_desc = "mmu_reset_midtransaction_vseq";
    p9_checker = "ptw_recovery_sb";
    p9_reviewer = "B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_reset_midtransaction_vseq");
  endfunction

endclass : test_reset_during_ptw_walk

`endif // TEST_RESET_DURING_PTW_WALK_SVH
