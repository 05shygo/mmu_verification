// =============================================================================
// Phase 9 generated test wrapper for TC-PRIV-008
// Checker: cross_scenario_cg  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_PRIV_MODE_S_SVH
`define TEST_MMU_PRIV_MODE_S_SVH

class test_mmu_priv_mode_s extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_priv_mode_s)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-PRIV-008";
    p9_seq_desc = "cp0_priv_switch_seq + mmu_smoke_vseq";
    p9_checker = "cross_scenario_cg";
    p9_reviewer = "B";
    num_txn = 16;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_priv_switch_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_priv_mode_s

`endif // TEST_MMU_PRIV_MODE_S_SVH
