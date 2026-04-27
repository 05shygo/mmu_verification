// =============================================================================
// Phase 9 generated test wrapper for TC-CSR-016
// Checker: csr_cg  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_CSR_COMPLETE_SIGNAL_SVH
`define TEST_MMU_CSR_COMPLETE_SIGNAL_SVH

class test_mmu_csr_complete_signal extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_csr_complete_signal)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-CSR-016";
    p9_seq_desc = "cp0_reg_access_seq + mmu_smoke_vseq";
    p9_checker = "csr_cg";
    p9_reviewer = "B";
    num_txn = 8;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_reg_access_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_csr_complete_signal

`endif // TEST_MMU_CSR_COMPLETE_SIGNAL_SVH
