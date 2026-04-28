// =============================================================================
// Phase 12 generated test wrapper for TC-TWU-MAEE1-REFILL-001
// F-ID: F4.NEW.12  Priority: P0  Status: Implemented
// Checker: sva_twu_maee_paths_mutex + cg_maee_leaf_level  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TWU_MAEE1_DIRECT_REFILL_SVH
`define TEST_MMU_TWU_MAEE1_DIRECT_REFILL_SVH

class test_mmu_twu_maee1_direct_refill extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_maee1_direct_refill)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "maee_twu";
    p12_trace_id = "TC-TWU-MAEE1-REFILL-001";
    p12_fid      = "F4.NEW.12";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "cp0_maee_enable_seq + mmu_huge_page_mix_vseq";
    p12_checker  = "sva_twu_maee_paths_mutex + cg_maee_leaf_level";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 800ns;
    m_cp0_seq_names.push_back("cp0_maee_enable_seq");
    m_vseq_names.push_back("mmu_huge_page_mix_vseq");
  endfunction

endclass : test_mmu_twu_maee1_direct_refill

`endif // TEST_MMU_TWU_MAEE1_DIRECT_REFILL_SVH
