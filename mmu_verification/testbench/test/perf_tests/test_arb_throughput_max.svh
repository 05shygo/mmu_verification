// =============================================================================
// Phase 9 generated test wrapper for PERF-ARB-001
// Checker: perf_mon  Reviewer: B
// =============================================================================
`ifndef TEST_ARB_THROUGHPUT_MAX_SVH
`define TEST_ARB_THROUGHPUT_MAX_SVH

class test_arb_throughput_max extends phase9_generated_test_base;

  `uvm_component_utils(test_arb_throughput_max)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PERF-ARB-001";
    p9_seq_desc = "misc_hpcp_enable_on_seq + mmu_stress_all_ports_vseq";
    p9_checker = "perf_mon";
    p9_reviewer = "B";
    num_txn = 128;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_misc_seq_names.push_back("misc_hpcp_enable_on_seq");
    m_vseq_names.push_back("mmu_stress_all_ports_vseq");
  endfunction

endclass : test_arb_throughput_max

`endif // TEST_ARB_THROUGHPUT_MAX_SVH
