// =============================================================================
// Phase 9 generated test wrapper for EXC-008
// Checker: prefetch_sb  Reviewer: B
// =============================================================================
`ifndef TEST_PIPE2_PREFETCH_ERR_SVH
`define TEST_PIPE2_PREFETCH_ERR_SVH

class test_pipe2_prefetch_err extends phase9_generated_test_base;

  `uvm_component_utils(test_pipe2_prefetch_err)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "EXC-008";
    p9_seq_desc = "lsu_prefetch_pipe2_seq";
    p9_checker = "prefetch_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_lsu_seq_names.push_back("lsu_prefetch_pipe2_seq");
  endfunction

endclass : test_pipe2_prefetch_err

`endif // TEST_PIPE2_PREFETCH_ERR_SVH
