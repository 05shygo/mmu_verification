// =============================================================================
// Phase 9 generated test wrapper for TC-CSR-012
// Checker: coherency_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_CSR_MAEE_SVH
`define TEST_MMU_CSR_MAEE_SVH

class test_mmu_csr_maee extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_csr_maee)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-CSR-012";
    p9_seq_desc = "cp0_maee_enable_seq + mmu_smoke_vseq";
    p9_checker = "coherency_sb";
    p9_reviewer = "B";
    num_txn = 8;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_maee_enable_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_csr_maee

`endif // TEST_MMU_CSR_MAEE_SVH
