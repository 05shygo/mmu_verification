// =============================================================================
// Phase 9 generated test wrapper for PTW-028
// Checker: ptw_walk_cg  Reviewer: A+B
// =============================================================================
`ifndef TEST_SFENCE_ABORT_WALK_SVH
`define TEST_SFENCE_ABORT_WALK_SVH

class test_sfence_abort_walk extends phase9_generated_test_base;

  `uvm_component_utils(test_sfence_abort_walk)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PTW-028";
    p9_seq_desc = "mmu_sfence_during_walk_vseq";
    p9_checker = "ptw_walk_cg";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_sfence_during_walk_vseq");
  endfunction

endclass : test_sfence_abort_walk

`endif // TEST_SFENCE_ABORT_WALK_SVH
