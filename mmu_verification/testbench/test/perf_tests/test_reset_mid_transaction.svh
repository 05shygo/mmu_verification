// =============================================================================
// Phase 9 generated test wrapper for STRESS-012
// Checker: mid_txn_sb  Reviewer: B
// =============================================================================
`ifndef TEST_RESET_MID_TRANSACTION_SVH
`define TEST_RESET_MID_TRANSACTION_SVH

class test_reset_mid_transaction extends phase9_generated_test_base;

  `uvm_component_utils(test_reset_mid_transaction)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "STRESS-012";
    p9_seq_desc = "misc_hpcp_enable_on_seq + mmu_reset_midtransaction_vseq";
    p9_checker = "mid_txn_sb";
    p9_reviewer = "B";
    num_txn = 128;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_misc_seq_names.push_back("misc_hpcp_enable_on_seq");
    m_vseq_names.push_back("mmu_reset_midtransaction_vseq");
  endfunction

endclass : test_reset_mid_transaction

`endif // TEST_RESET_MID_TRANSACTION_SVH
