// =============================================================================
// Phase 9 generated test wrapper for PTW-007
// Checker: ptw_walk_cg  Reviewer: A+B
// =============================================================================
`ifndef TEST_PTW_L1_PDE_MISS_WALK_SVH
`define TEST_PTW_L1_PDE_MISS_WALK_SVH

class test_ptw_l1_pde_miss_walk extends phase9_generated_test_base;

  `uvm_component_utils(test_ptw_l1_pde_miss_walk)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PTW-007";
    p9_seq_desc = "pmp_flg_normal_seq(all-allow pmpflg) + ptw_deep_tree_random_seq(tag-miss profile) + mmu_ptw_thrash_vseq";
    p9_checker = "ptw_walk_cg + L1 tag-miss walk; L1 cached-pmpflg deny is a permission-qualified miss and not a tag-only expected";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_pmp_seq_names.push_back("pmp_flg_normal_seq");
    m_ptw_seq_names.push_back("ptw_deep_tree_random_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_ptw_l1_pde_miss_walk

`endif // TEST_PTW_L1_PDE_MISS_WALK_SVH
