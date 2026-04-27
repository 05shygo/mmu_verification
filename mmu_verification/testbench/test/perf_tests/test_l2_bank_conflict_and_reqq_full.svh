// =============================================================================
// Phase 9 generated test wrapper for STRESS-003
// Checker: l2_sb  Reviewer: B
// =============================================================================
`ifndef TEST_L2_BANK_CONFLICT_AND_REQQ_FULL_SVH
`define TEST_L2_BANK_CONFLICT_AND_REQQ_FULL_SVH

class test_l2_bank_conflict_and_reqq_full extends phase9_generated_test_base;

  `uvm_component_utils(test_l2_bank_conflict_and_reqq_full)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "STRESS-003";
    p9_seq_desc = "misc_hpcp_enable_on_seq + mmu_l2tlb_bank_conflict_vseq";
    p9_checker = "l2_sb";
    p9_reviewer = "B";
    num_txn = 128;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_misc_seq_names.push_back("misc_hpcp_enable_on_seq");
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
  endfunction

endclass : test_l2_bank_conflict_and_reqq_full

`endif // TEST_L2_BANK_CONFLICT_AND_REQQ_FULL_SVH
