// =============================================================================
// Phase 9 generated test wrapper for STRESS-005
// Checker: satp_sb  Reviewer: B
// =============================================================================
`ifndef TEST_SATP_HOTSWAP_CONCURRENT_SVH
`define TEST_SATP_HOTSWAP_CONCURRENT_SVH

class test_satp_hotswap_concurrent extends phase9_generated_test_base;

  `uvm_component_utils(test_satp_hotswap_concurrent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "STRESS-005";
    p9_seq_desc = "misc_hpcp_enable_on_seq + mmu_satp_hotswap_vseq";
    p9_checker = "satp_sb";
    p9_reviewer = "B";
    num_txn = 128;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_misc_seq_names.push_back("misc_hpcp_enable_on_seq");
    m_vseq_names.push_back("mmu_satp_hotswap_vseq");
  endfunction

endclass : test_satp_hotswap_concurrent

`endif // TEST_SATP_HOTSWAP_CONCURRENT_SVH
