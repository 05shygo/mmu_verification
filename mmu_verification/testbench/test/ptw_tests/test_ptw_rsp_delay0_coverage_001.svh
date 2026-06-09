// =============================================================================
// Focused PTW memory responder minimum-delay coverage
// =============================================================================
`ifndef TEST_PTW_RSP_DELAY0_COVERAGE_001_SVH
`define TEST_PTW_RSP_DELAY0_COVERAGE_001_SVH

class test_ptw_rsp_delay0_coverage_001 extends phase9_generated_test_base;

  `uvm_component_utils(test_ptw_rsp_delay0_coverage_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PTW-RSP-DELAY0-COV-001";
    p9_seq_desc = "ptw_mem_delay0_rsp_seq + mmu_ptw_thrash_vseq";
    p9_checker = "ptw_mem_monitor + cg_rsp_delay_range";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_mem_delay0_rsp_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_ptw_rsp_delay0_coverage_001

`endif // TEST_PTW_RSP_DELAY0_COVERAGE_001_SVH
