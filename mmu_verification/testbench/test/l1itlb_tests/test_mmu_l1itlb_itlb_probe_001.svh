// =============================================================================
// Phase 9 generated test wrapper for ITLB_PROBE_001
// Checker: cov_software_ops  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_L1ITLB_ITLB_PROBE_001_SVH
`define TEST_MMU_L1ITLB_ITLB_PROBE_001_SVH

class test_mmu_l1itlb_itlb_probe_001 extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_l1itlb_itlb_probe_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "ITLB_PROBE_001";
    p9_seq_desc = "cp0_tlbp_seq + ifu_random_vaddr_seq";
    p9_checker = "cov_software_ops";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_tlbp_seq");
    m_ifu_seq_names.push_back("ifu_random_vaddr_seq");
  endfunction

endclass : test_mmu_l1itlb_itlb_probe_001

`endif // TEST_MMU_L1ITLB_ITLB_PROBE_001_SVH
