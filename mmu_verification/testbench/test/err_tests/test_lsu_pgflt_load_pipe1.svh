// =============================================================================
// Phase 9 generated test wrapper for EXC-005
// Checker: pgflt_sb  Reviewer: B
// =============================================================================
`ifndef TEST_LSU_PGFLT_LOAD_PIPE1_SVH
`define TEST_LSU_PGFLT_LOAD_PIPE1_SVH

class test_lsu_pgflt_load_pipe1 extends phase9_generated_test_base;

  `uvm_component_utils(test_lsu_pgflt_load_pipe1)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "EXC-005";
    p9_seq_desc = "lsu_pipe1_only_seq";
    p9_checker = "pgflt_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_lsu_seq_names.push_back("lsu_pipe1_only_seq");
  endfunction

endclass : test_lsu_pgflt_load_pipe1

`endif // TEST_LSU_PGFLT_LOAD_PIPE1_SVH
