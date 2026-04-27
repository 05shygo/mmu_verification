// =============================================================================
// Phase 9 generated test wrapper for PERF-PTW-001
// Checker: perf_mon  Reviewer: B
// =============================================================================
`ifndef TEST_PTW_WALK_LATENCY_SVH
`define TEST_PTW_WALK_LATENCY_SVH

class test_ptw_walk_latency extends phase9_generated_test_base;

  `uvm_component_utils(test_ptw_walk_latency)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PERF-PTW-001";
    p9_seq_desc = "misc_hpcp_enable_on_seq + mmu_ptw_thrash_vseq";
    p9_checker = "perf_mon";
    p9_reviewer = "B";
    num_txn = 128;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_misc_seq_names.push_back("misc_hpcp_enable_on_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_ptw_walk_latency

`endif // TEST_PTW_WALK_LATENCY_SVH
