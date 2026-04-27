// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-001
// F-ID: F4.NEW.2  Priority: P1  Status: Functional
// Checker: twu fetch-type positive guard  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_001_TWU_FST_FETCH_TYPE_SVH
`define TEST_BUG_001_TWU_FST_FETCH_TYPE_SVH

class test_bug_001_twu_fst_fetch_type extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_001_twu_fst_fetch_type)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "positive_guard";
    p11_trace_id = "TC-BUG-001";
    p11_fid      = "F4.NEW.2";
    p11_priority = "P1";
    p11_status   = "Functional";
    p11_seq_desc = "ifu_sequential_fetch_seq + mmu_ptw_thrash_vseq";
    p11_checker  = "positive guard for twu fetch type";
    p11_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 500ns;
    m_ifu_seq_names.push_back("ifu_sequential_fetch_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_bug_001_twu_fst_fetch_type

`endif // TEST_BUG_001_TWU_FST_FETCH_TYPE_SVH
