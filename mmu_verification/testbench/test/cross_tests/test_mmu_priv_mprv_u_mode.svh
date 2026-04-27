// =============================================================================
// Phase 9 generated test wrapper for TC-PRIV-005
// Checker: cross_scenario_cg  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_PRIV_MPRV_U_MODE_SVH
`define TEST_MMU_PRIV_MPRV_U_MODE_SVH

class test_mmu_priv_mprv_u_mode extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_priv_mprv_u_mode)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-PRIV-005";
    p9_seq_desc = "cp0_mprv_seq + mmu_smoke_vseq";
    p9_checker = "cross_scenario_cg";
    p9_reviewer = "B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_mprv_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_priv_mprv_u_mode

`endif // TEST_MMU_PRIV_MPRV_U_MODE_SVH
