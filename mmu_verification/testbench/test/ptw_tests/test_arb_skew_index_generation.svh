// =============================================================================
// Phase 9 generated test wrapper for ARB-006
// Checker: arb_sva  Reviewer: A+B
// =============================================================================
`ifndef TEST_ARB_SKEW_INDEX_GENERATION_SVH
`define TEST_ARB_SKEW_INDEX_GENERATION_SVH

class test_arb_skew_index_generation extends phase9_generated_test_base;

  `uvm_component_utils(test_arb_skew_index_generation)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "ARB-006";
    p9_seq_desc = "mmu_l2tlb_hash_directed_vseq";
    p9_checker = "arb_sva + l2tlb_hash_golden_model";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_l2tlb_hash_directed_vseq");
  endfunction

endclass : test_arb_skew_index_generation

`endif // TEST_ARB_SKEW_INDEX_GENERATION_SVH
