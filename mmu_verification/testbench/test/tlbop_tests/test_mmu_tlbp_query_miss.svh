// =============================================================================
// Phase 9 generated test wrapper for TC-TLBP-002
// Checker: invalidation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TLBP_QUERY_MISS_SVH
`define TEST_MMU_TLBP_QUERY_MISS_SVH

class test_mmu_tlbp_query_miss extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_tlbp_query_miss)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-TLBP-002";
    p9_seq_desc = "cp0_tlbp_seq + mmu_smoke_vseq";
    p9_checker = "invalidation_sb";
    p9_reviewer = "A+B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_tlbp_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_tlbp_query_miss

`endif // TEST_MMU_TLBP_QUERY_MISS_SVH
