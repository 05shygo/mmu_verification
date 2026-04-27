// =============================================================================
// Phase 9 generated test wrapper for TC-SFENCE-010
// Checker: invalidation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_SFENCE_GLOBAL_VA_AFFECTED_SVH
`define TEST_MMU_SFENCE_GLOBAL_VA_AFFECTED_SVH

class test_mmu_sfence_global_va_affected extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_sfence_global_va_affected)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-SFENCE-010";
    p9_seq_desc = "tlb_inv_va_seq";
    p9_checker = "invalidation_sb";
    p9_reviewer = "A+B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_lsu_seq_names.push_back("tlb_inv_va_seq");
  endfunction

endclass : test_mmu_sfence_global_va_affected

`endif // TEST_MMU_SFENCE_GLOBAL_VA_AFFECTED_SVH
