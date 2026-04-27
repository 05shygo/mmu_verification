// =============================================================================
// Phase 9 generated test wrapper for ITLB_ASID_001
// Checker: coherency_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_L1ITLB_ITLB_ASID_001_SVH
`define TEST_MMU_L1ITLB_ITLB_ASID_001_SVH

class test_mmu_l1itlb_itlb_asid_001 extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_l1itlb_itlb_asid_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "ITLB_ASID_001";
    p9_seq_desc = "mmu_asid_context_switch_vseq";
    p9_checker = "coherency_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_asid_context_switch_vseq");
  endfunction

endclass : test_mmu_l1itlb_itlb_asid_001

`endif // TEST_MMU_L1ITLB_ITLB_ASID_001_SVH
