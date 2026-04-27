// =============================================================================
// Phase 9 generated test wrapper for TC-SFENCE-017
// Checker: invalidation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_SFENCE_REFILL_CONFLICT_SVH
`define TEST_MMU_SFENCE_REFILL_CONFLICT_SVH

class test_mmu_sfence_refill_conflict extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_sfence_refill_conflict)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-SFENCE-017";
    p9_seq_desc = "ptw_mem_normal_rsp_seq + tlb_inv_all_seq + mmu_ptw_thrash_vseq";
    p9_checker = "invalidation_sb";
    p9_reviewer = "A+B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_mem_normal_rsp_seq");
    m_lsu_seq_names.push_back("tlb_inv_all_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mmu_sfence_refill_conflict

`endif // TEST_MMU_SFENCE_REFILL_CONFLICT_SVH
