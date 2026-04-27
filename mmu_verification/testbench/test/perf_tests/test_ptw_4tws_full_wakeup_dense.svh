// =============================================================================
// Phase 9 generated test wrapper for STRESS-004
// Checker: ptw_sb  Reviewer: B
// =============================================================================
`ifndef TEST_PTW_4TWS_FULL_WAKEUP_DENSE_SVH
`define TEST_PTW_4TWS_FULL_WAKEUP_DENSE_SVH

class test_ptw_4tws_full_wakeup_dense extends phase9_generated_test_base;

  `uvm_component_utils(test_ptw_4tws_full_wakeup_dense)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "STRESS-004";
    p9_seq_desc = "misc_hpcp_enable_on_seq + mmu_ptw_thrash_vseq";
    p9_checker = "ptw_sb";
    p9_reviewer = "B";
    num_txn = 128;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_misc_seq_names.push_back("misc_hpcp_enable_on_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_ptw_4tws_full_wakeup_dense

`endif // TEST_PTW_4TWS_FULL_WAKEUP_DENSE_SVH
