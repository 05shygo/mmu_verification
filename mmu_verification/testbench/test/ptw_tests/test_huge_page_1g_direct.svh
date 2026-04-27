// =============================================================================
// Phase 9 generated test wrapper for PTW-023
// Checker: ptw_walk_cg  Reviewer: A+B
// =============================================================================
`ifndef TEST_HUGE_PAGE_1G_DIRECT_SVH
`define TEST_HUGE_PAGE_1G_DIRECT_SVH

class test_huge_page_1g_direct extends phase9_generated_test_base;

  `uvm_component_utils(test_huge_page_1g_direct)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PTW-023";
    p9_seq_desc = "ptw_page_table_build_1g_seq + mmu_huge_page_mix_vseq";
    p9_checker = "ptw_walk_cg";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_page_table_build_1g_seq");
    m_vseq_names.push_back("mmu_huge_page_mix_vseq");
  endfunction

endclass : test_huge_page_1g_direct

`endif // TEST_HUGE_PAGE_1G_DIRECT_SVH
