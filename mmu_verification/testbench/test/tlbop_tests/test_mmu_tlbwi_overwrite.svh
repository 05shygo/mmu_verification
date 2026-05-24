// =============================================================================
// Phase 9 generated test wrapper for TC-TLBWI-002
// Checker: invalidation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TLBWI_OVERWRITE_SVH
`define TEST_MMU_TLBWI_OVERWRITE_SVH

class test_mmu_tlbwi_overwrite extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_tlbwi_overwrite)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-TLBWI-002";
    p9_seq_desc = "cp0_l2tlb_tlbwi_overwrite_exact_seq";
    p9_checker = "cp0_tlbop_exact_readback";
    p9_reviewer = "A+B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_l2tlb_tlbwi_overwrite_exact_seq");
  endfunction

endclass : test_mmu_tlbwi_overwrite

`endif // TEST_MMU_TLBWI_OVERWRITE_SVH
