// =============================================================================
// Phase 12 generated test wrapper for TC-TWU-MAEE0-CSR-002
// F-ID: F4.NEW.12  Priority: P0  Status: Implemented
// Checker: sva_twu_maee_paths_mutex + cg_maee_leaf_level  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TWU_MAEE0_CSR_SYMMETRIC_SVH
`define TEST_MMU_TWU_MAEE0_CSR_SYMMETRIC_SVH

class test_mmu_twu_maee0_csr_symmetric extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_maee0_csr_symmetric)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "maee_twu";
    p12_trace_id = "TC-TWU-MAEE0-CSR-002";
    p12_fid      = "F4.NEW.12";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "cp0_maee_disable_seq + mmu_ptw_thrash_vseq";
    p12_checker  = "sva_twu_maee_paths_mutex + cg_maee_leaf_level";
    p12_reviewer = "A+B";
    num_txn      = 128;
    m_post_drain = 800ns;
    m_cp0_seq_names.push_back("cp0_maee_disable_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mmu_twu_maee0_csr_symmetric

`endif // TEST_MMU_TWU_MAEE0_CSR_SYMMETRIC_SVH
