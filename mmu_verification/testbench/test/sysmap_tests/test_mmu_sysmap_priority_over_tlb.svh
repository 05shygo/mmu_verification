// =============================================================================
// Phase 9 generated test wrapper for TC-SYSMAP-009
// Checker: translation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_SYSMAP_PRIORITY_OVER_TLB_SVH
`define TEST_MMU_SYSMAP_PRIORITY_OVER_TLB_SVH

class test_mmu_sysmap_priority_over_tlb extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_sysmap_priority_over_tlb)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-SYSMAP-009";
    p9_seq_desc = "sysmap_hit_cross_tlb_seq + mmu_smoke_vseq";
    p9_checker = "translation_sb";
    p9_reviewer = "A+B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_sysmap_seq_names.push_back("sysmap_hit_cross_tlb_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_sysmap_priority_over_tlb

`endif // TEST_MMU_SYSMAP_PRIORITY_OVER_TLB_SVH
