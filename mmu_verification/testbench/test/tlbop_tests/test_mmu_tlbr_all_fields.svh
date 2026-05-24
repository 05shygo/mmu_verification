// =============================================================================
// Phase 9 generated test wrapper for TC-TLBR-002
// Checker: invalidation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TLBR_ALL_FIELDS_SVH
`define TEST_MMU_TLBR_ALL_FIELDS_SVH

class test_mmu_tlbr_all_fields extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_tlbr_all_fields)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-TLBR-002";
    p9_seq_desc = "cp0_l2tlb_tlbr_all_fields_exact_seq";
    p9_checker = "cp0_tlbop_exact_readback";
    p9_reviewer = "A+B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_l2tlb_tlbr_all_fields_exact_seq");
  endfunction

endclass : test_mmu_tlbr_all_fields

`endif // TEST_MMU_TLBR_ALL_FIELDS_SVH
