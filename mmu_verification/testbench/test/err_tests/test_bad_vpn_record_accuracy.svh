// =============================================================================
// Phase 9 generated test wrapper for EXC-009
// Checker: pgflt_sb  Reviewer: B
// =============================================================================
`ifndef TEST_BAD_VPN_RECORD_ACCURACY_SVH
`define TEST_BAD_VPN_RECORD_ACCURACY_SVH

class test_bad_vpn_record_accuracy extends phase9_generated_test_base;

  `uvm_component_utils(test_bad_vpn_record_accuracy)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "EXC-009";
    p9_seq_desc = "mmu_error_rain_vseq";
    p9_checker = "pgflt_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_error_rain_vseq");
  endfunction

endclass : test_bad_vpn_record_accuracy

`endif // TEST_BAD_VPN_RECORD_ACCURACY_SVH
