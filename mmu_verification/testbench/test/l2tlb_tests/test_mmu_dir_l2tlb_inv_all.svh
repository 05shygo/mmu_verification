// =============================================================================
// Phase 9 generated test wrapper for TC-INV-001
// Checker: invalidation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_DIR_L2TLB_INV_ALL_SVH
`define TEST_MMU_DIR_L2TLB_INV_ALL_SVH

class test_mmu_dir_l2tlb_inv_all extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_dir_l2tlb_inv_all)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-INV-001";
    p9_seq_desc = "tlb_inv_all_seq + mmu_smoke_vseq";
    p9_checker = "invalidation_sb";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_lsu_seq_names.push_back("tlb_inv_all_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_dir_l2tlb_inv_all

`endif // TEST_MMU_DIR_L2TLB_INV_ALL_SVH
