// =============================================================================
// Phase 9 generated test wrapper for EXC-011
// Checker: reqq_sb  Reviewer: B
// =============================================================================
`ifndef TEST_RTU_FLUSH_ALL_PENDING_SVH
`define TEST_RTU_FLUSH_ALL_PENDING_SVH

class test_rtu_flush_all_pending extends phase9_generated_test_base;

  `uvm_component_utils(test_rtu_flush_all_pending)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "EXC-011";
    p9_seq_desc = "misc_rtu_flush_seq + mmu_reset_midtransaction_vseq";
    p9_checker = "reqq_sb";
    p9_reviewer = "B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_misc_seq_names.push_back("misc_rtu_flush_seq");
    m_vseq_names.push_back("mmu_reset_midtransaction_vseq");
  endfunction

endclass : test_rtu_flush_all_pending

`endif // TEST_RTU_FLUSH_ALL_PENDING_SVH
