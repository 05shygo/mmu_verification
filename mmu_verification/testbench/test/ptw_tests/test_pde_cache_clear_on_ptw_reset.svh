// =============================================================================
// Phase 9 generated test wrapper for PDE-003
// Checker: ptw_walk_cg  Reviewer: A+B
// =============================================================================
`ifndef TEST_PDE_CACHE_CLEAR_ON_PTW_RESET_SVH
`define TEST_PDE_CACHE_CLEAR_ON_PTW_RESET_SVH

class test_pde_cache_clear_on_ptw_reset extends phase9_generated_test_base;

  `uvm_component_utils(test_pde_cache_clear_on_ptw_reset)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PDE-003";
    p9_seq_desc = "ptw_page_table_build_4k_seq + mmu_ptw_thrash_vseq";
    p9_checker = "ptw_walk_cg";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_page_table_build_4k_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_pde_cache_clear_on_ptw_reset

`endif // TEST_PDE_CACHE_CLEAR_ON_PTW_RESET_SVH
