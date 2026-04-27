// =============================================================================
// Phase 9 generated test wrapper for EXC-006
// Checker: access_fault_sb  Reviewer: B
// =============================================================================
`ifndef TEST_LSU_ACCESS_FAULT_PMP_DENY_SVH
`define TEST_LSU_ACCESS_FAULT_PMP_DENY_SVH

class test_lsu_access_fault_pmp_deny extends phase9_generated_test_base;

  `uvm_component_utils(test_lsu_access_fault_pmp_deny)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "EXC-006";
    p9_seq_desc = "pmp_flg_deny_fetch_seq + lsu_pipe0_only_seq";
    p9_checker = "access_fault_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_pmp_seq_names.push_back("pmp_flg_deny_fetch_seq");
    m_lsu_seq_names.push_back("lsu_pipe0_only_seq");
  endfunction

endclass : test_lsu_access_fault_pmp_deny

`endif // TEST_LSU_ACCESS_FAULT_PMP_DENY_SVH
