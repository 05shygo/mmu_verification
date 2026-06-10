// =============================================================================
// Focused SysMap configuration mirror coverage sweep
// =============================================================================
`ifndef TEST_SYSMAP_CFG_COVERAGE_SWEEP_SVH
`define TEST_SYSMAP_CFG_COVERAGE_SWEEP_SVH

class test_sysmap_cfg_coverage_sweep extends phase9_generated_test_base;

  `uvm_component_utils(test_sysmap_cfg_coverage_sweep)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "SYSMAP-CFG-COV-SWEEP-001";
    p9_seq_desc = "sysmap_cfg_coverage_sweep_seq";
    p9_checker = "sysmap_cfg_cg";
    p9_reviewer = "B";
    num_txn = 1;
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_sysmap_seq_names.push_back("sysmap_cfg_coverage_sweep_seq");
  endfunction

endclass : test_sysmap_cfg_coverage_sweep

`endif // TEST_SYSMAP_CFG_COVERAGE_SWEEP_SVH
