// =============================================================================
// Phase 9 generated test wrapper for PERF-005
// Checker: perf_mon_sb  Reviewer: B
// =============================================================================
`ifndef TEST_JTLB_MISS_COUNTED_SVH
`define TEST_JTLB_MISS_COUNTED_SVH

class test_jtlb_miss_counted extends phase9_generated_test_base;

  `uvm_component_utils(test_jtlb_miss_counted)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PERF-005";
    p9_seq_desc = "misc_hpcp_enable_on_seq + mmu_perf_bench_vseq";
    p9_checker = "perf_mon_sb";
    p9_reviewer = "B";
    num_txn = 128;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_misc_seq_names.push_back("misc_hpcp_enable_on_seq");
    m_vseq_names.push_back("mmu_perf_bench_vseq");
  endfunction

endclass : test_jtlb_miss_counted

`endif // TEST_JTLB_MISS_COUNTED_SVH
