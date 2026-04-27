// =============================================================================
// Phase 9 generated test wrapper for PERF-001
// Checker: perf_mon_sb  Reviewer: B
// =============================================================================
`ifndef TEST_IUTLB_MISS_PULSE_1TO1_SVH
`define TEST_IUTLB_MISS_PULSE_1TO1_SVH

class test_iutlb_miss_pulse_1to1 extends phase9_generated_test_base;

  `uvm_component_utils(test_iutlb_miss_pulse_1to1)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PERF-001";
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

endclass : test_iutlb_miss_pulse_1to1

`endif // TEST_IUTLB_MISS_PULSE_1TO1_SVH
