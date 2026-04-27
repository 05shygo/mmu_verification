// =============================================================================
// Phase 9 generated test wrapper for TC-PMP-012
// Checker: pmp_cg  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_PMP_CROSS_PORT_DENY_SVH
`define TEST_MMU_PMP_CROSS_PORT_DENY_SVH

class test_mmu_pmp_cross_port_deny extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_pmp_cross_port_deny)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-PMP-012";
    p9_seq_desc = "pmp_flg_deny_rw_seq + mmu_smoke_vseq";
    p9_checker = "pmp_cg";
    p9_reviewer = "A+B";
    num_txn = 32;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_pmp_seq_names.push_back("pmp_flg_deny_rw_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_pmp_cross_port_deny

`endif // TEST_MMU_PMP_CROSS_PORT_DENY_SVH
