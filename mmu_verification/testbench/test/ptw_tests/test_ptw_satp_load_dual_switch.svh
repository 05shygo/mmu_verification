// =============================================================================
// Phase 9 generated test wrapper for PTW-002
// Checker: translation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_PTW_SATP_LOAD_DUAL_SWITCH_SVH
`define TEST_PTW_SATP_LOAD_DUAL_SWITCH_SVH

class test_ptw_satp_load_dual_switch extends phase9_generated_test_base;

  `uvm_component_utils(test_ptw_satp_load_dual_switch)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PTW-002";
    p9_seq_desc = "mmu_satp_hotswap_vseq";
    p9_checker = "translation_sb";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_satp_hotswap_vseq");
  endfunction

endclass : test_ptw_satp_load_dual_switch

`endif // TEST_PTW_SATP_LOAD_DUAL_SWITCH_SVH
