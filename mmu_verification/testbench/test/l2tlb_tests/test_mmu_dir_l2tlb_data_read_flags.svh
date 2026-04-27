// =============================================================================
// Phase 9 generated test wrapper for TC-L2TLB-013
// Checker: credit_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_DIR_L2TLB_DATA_READ_FLAGS_SVH
`define TEST_MMU_DIR_L2TLB_DATA_READ_FLAGS_SVH

class test_mmu_dir_l2tlb_data_read_flags extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_dir_l2tlb_data_read_flags)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-L2TLB-013";
    p9_seq_desc = "mmu_l2tlb_bank_conflict_vseq";
    p9_checker = "credit_sb";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
  endfunction

endclass : test_mmu_dir_l2tlb_data_read_flags

`endif // TEST_MMU_DIR_L2TLB_DATA_READ_FLAGS_SVH
