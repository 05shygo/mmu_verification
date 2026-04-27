// =============================================================================
// Phase 9 generated test wrapper for TC-SYSMAP-011
// Checker: translation_sb + ptw_walk_cg  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_SYSMAP_PTE_WALK_ADDR_SVH
`define TEST_MMU_SYSMAP_PTE_WALK_ADDR_SVH

class test_mmu_sysmap_pte_walk_addr extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_sysmap_pte_walk_addr)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-SYSMAP-011";
    p9_seq_desc = "sysmap_hit_cross_tlb_seq + ptw_page_table_build_4k_seq + mmu_smoke_vseq";
    p9_checker = "translation_sb + ptw_walk_cg";
    p9_reviewer = "A+B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_sysmap_seq_names.push_back("sysmap_hit_cross_tlb_seq");
    m_ptw_seq_names.push_back("ptw_page_table_build_4k_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_sysmap_pte_walk_addr

`endif // TEST_MMU_SYSMAP_PTE_WALK_ADDR_SVH
