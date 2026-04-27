// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-002
// F-ID: F4.NEW.3  Priority: P1  Status: Functional
// Checker: sva_thd_a_bit_pgflt positive guard  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_002_THD_CHK_4K_A_BIT_SVH
`define TEST_BUG_002_THD_CHK_4K_A_BIT_SVH

class test_bug_002_thd_chk_4k_a_bit extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_002_thd_chk_4k_a_bit)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "positive_guard";
    p11_trace_id = "TC-BUG-002";
    p11_fid      = "F4.NEW.3";
    p11_priority = "P1";
    p11_status   = "Functional";
    p11_seq_desc = "ptw_mem_illegal_pte_seq + ifu_pagefault_trigger_seq";
    p11_checker  = "sva_thd_a_bit_pgflt";
    p11_reviewer = "A+B";
    num_txn      = 32;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_mem_illegal_pte_seq");
    m_ifu_seq_names.push_back("ifu_pagefault_trigger_seq");
  endfunction

endclass : test_bug_002_thd_chk_4k_a_bit

`endif // TEST_BUG_002_THD_CHK_4K_A_BIT_SVH
