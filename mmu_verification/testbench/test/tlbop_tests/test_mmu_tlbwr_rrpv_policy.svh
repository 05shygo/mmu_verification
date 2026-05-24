// =============================================================================
// Phase 9 generated test wrapper for TC-TLBWR-002
// Checker: invalidation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TLBWR_RRPV_POLICY_SVH
`define TEST_MMU_TLBWR_RRPV_POLICY_SVH

class test_mmu_tlbwr_rrpv_policy extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_tlbwr_rrpv_policy)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-TLBWR-002";
    p9_seq_desc = "cp0_l2tlb_tlbwr_rrpv_visible_exact_seq";
    p9_checker = "cp0_tlbop_exact_readback; exact RRPV/victim not checked";
    p9_reviewer = "A+B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_l2tlb_tlbwr_rrpv_visible_exact_seq");
  endfunction

endclass : test_mmu_tlbwr_rrpv_policy

`endif // TEST_MMU_TLBWR_RRPV_POLICY_SVH
