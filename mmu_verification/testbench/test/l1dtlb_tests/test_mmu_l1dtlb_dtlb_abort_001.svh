// =============================================================================
// Phase 9 generated test wrapper for DTLB_ABORT_001
// Checker: translation_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_L1DTLB_DTLB_ABORT_001_SVH
`define TEST_MMU_L1DTLB_DTLB_ABORT_001_SVH

class test_mmu_l1dtlb_dtlb_abort_001 extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_l1dtlb_dtlb_abort_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "DTLB_ABORT_001";
    p9_seq_desc = "lsu_abort_seq";
    p9_checker = "translation_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_lsu_seq_names.push_back("lsu_abort_seq");
  endfunction

endclass : test_mmu_l1dtlb_dtlb_abort_001

`endif // TEST_MMU_L1DTLB_DTLB_ABORT_001_SVH
