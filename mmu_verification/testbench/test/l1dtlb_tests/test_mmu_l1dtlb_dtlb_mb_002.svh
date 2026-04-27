// =============================================================================
// Phase 9 generated test wrapper for DTLB_MB_002
// Checker: credit_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_L1DTLB_DTLB_MB_002_SVH
`define TEST_MMU_L1DTLB_DTLB_MB_002_SVH

class test_mmu_l1dtlb_dtlb_mb_002 extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_l1dtlb_dtlb_mb_002)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "DTLB_MB_002";
    p9_seq_desc = "mmu_ptw_thrash_vseq";
    p9_checker = "credit_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mmu_l1dtlb_dtlb_mb_002

`endif // TEST_MMU_L1DTLB_DTLB_MB_002_SVH
