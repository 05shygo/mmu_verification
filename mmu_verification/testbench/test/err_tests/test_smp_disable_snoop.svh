// =============================================================================
// Phase 9 generated test wrapper for PWR-004
// Checker: snoop_sb  Reviewer: B
// =============================================================================
`ifndef TEST_SMP_DISABLE_SNOOP_SVH
`define TEST_SMP_DISABLE_SNOOP_SVH

class test_smp_disable_snoop extends phase9_generated_test_base;

  `uvm_component_utils(test_smp_disable_snoop)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "PWR-004";
    p9_seq_desc = "misc_smp_disable_on_seq + mmu_smoke_vseq";
    p9_checker = "snoop_sb";
    p9_reviewer = "B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_misc_seq_names.push_back("misc_smp_disable_on_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_smp_disable_snoop

`endif // TEST_SMP_DISABLE_SNOOP_SVH
