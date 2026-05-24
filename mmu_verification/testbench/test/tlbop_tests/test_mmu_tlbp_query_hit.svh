// =============================================================================
// Phase 9 generated test wrapper for TC-TLBP-001
// Checker: invalidation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TLBP_QUERY_HIT_SVH
`define TEST_MMU_TLBP_QUERY_HIT_SVH

class test_mmu_tlbp_query_hit extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_tlbp_query_hit)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-TLBP-001";
    p9_seq_desc = "cp0_l2tlb_tlbp_hit_exact_seq";
    p9_checker = "cp0_tlbop_exact_readback";
    p9_reviewer = "A+B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_l2tlb_tlbp_hit_exact_seq");
  endfunction

endclass : test_mmu_tlbp_query_hit

`endif // TEST_MMU_TLBP_QUERY_HIT_SVH
