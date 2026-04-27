// =============================================================================
// Phase 9 generated test wrapper for EXC-001
// Checker: pgflt_sb  Reviewer: B
// =============================================================================
`ifndef TEST_IFU_PGFLT_V_BIT_ZERO_SVH
`define TEST_IFU_PGFLT_V_BIT_ZERO_SVH

class test_ifu_pgflt_v_bit_zero extends phase9_generated_test_base;

  `uvm_component_utils(test_ifu_pgflt_v_bit_zero)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "EXC-001";
    p9_seq_desc = "ifu_pagefault_trigger_seq";
    p9_checker = "pgflt_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ifu_seq_names.push_back("ifu_pagefault_trigger_seq");
  endfunction

endclass : test_ifu_pgflt_v_bit_zero

`endif // TEST_IFU_PGFLT_V_BIT_ZERO_SVH
