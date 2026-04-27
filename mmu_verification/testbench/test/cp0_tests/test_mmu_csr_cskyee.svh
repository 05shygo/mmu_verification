// =============================================================================
// Phase 9 generated test wrapper for TC-CSR-013
// Checker: coherency_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_CSR_CSKYEE_SVH
`define TEST_MMU_CSR_CSKYEE_SVH

class test_mmu_csr_cskyee extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_csr_cskyee)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-CSR-013";
    p9_seq_desc = "cp0_cskyee_enable_seq + mmu_smoke_vseq";
    p9_checker = "coherency_sb";
    p9_reviewer = "B";
    num_txn = 8;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_cskyee_enable_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_csr_cskyee

`endif // TEST_MMU_CSR_CSKYEE_SVH
