// =============================================================================
// Phase 9 generated test wrapper for EXC-010
// Checker: mb_sb  Reviewer: B
// =============================================================================
`ifndef TEST_EXPT_VLD_MB_CLEANUP_SVH
`define TEST_EXPT_VLD_MB_CLEANUP_SVH

class test_expt_vld_mb_cleanup extends phase9_generated_test_base;

  `uvm_component_utils(test_expt_vld_mb_cleanup)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "EXC-010";
    p9_seq_desc = "ptw_mem_bus_error_inject_seq + mmu_ptw_thrash_vseq";
    p9_checker = "mb_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_mem_bus_error_inject_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_expt_vld_mb_cleanup

`endif // TEST_EXPT_VLD_MB_CLEANUP_SVH
