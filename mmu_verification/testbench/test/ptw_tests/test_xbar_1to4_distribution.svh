// =============================================================================
// Phase 9 generated test wrapper for XBAR-001
// Checker: arb_sva  Reviewer: A+B
// =============================================================================
`ifndef TEST_XBAR_1TO4_DISTRIBUTION_SVH
`define TEST_XBAR_1TO4_DISTRIBUTION_SVH

class test_xbar_1to4_distribution extends phase9_generated_test_base;

  `uvm_component_utils(test_xbar_1to4_distribution)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "XBAR-001";
    p9_seq_desc = "mmu_stress_all_ports_vseq";
    p9_checker = "arb_sva";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_stress_all_ports_vseq");
  endfunction

endclass : test_xbar_1to4_distribution

`endif // TEST_XBAR_1TO4_DISTRIBUTION_SVH
