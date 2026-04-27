// =============================================================================
// Phase 9 generated test wrapper for PTW-027
// Checker: translation_sb  Reviewer: A+B
// =============================================================================
`ifndef TEST_SATP_SWITCH_DURING_WALK_SVH
`define TEST_SATP_SWITCH_DURING_WALK_SVH

class test_satp_switch_during_walk extends phase9_generated_test_base;

  `uvm_component_utils(test_satp_switch_during_walk)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PTW-027";
    p9_seq_desc = "ptw_mem_normal_rsp_seq + mmu_ptw_thrash_vseq";
    p9_checker = "translation_sb";
    p9_reviewer = "A+B";
    num_txn = 64;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_mem_normal_rsp_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_satp_switch_during_walk

`endif // TEST_SATP_SWITCH_DURING_WALK_SVH
