// =============================================================================
// Phase 9 generated test wrapper for TC-CSR-008
// Checker: csr_cg + translation_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_CSR_SATP_SWITCH_SVH
`define TEST_MMU_CSR_SATP_SWITCH_SVH

class test_mmu_csr_satp_switch extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_csr_satp_switch)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-CSR-008";
    p9_seq_desc = "mmu_satp_hotswap_vseq";
    p9_checker = "csr_cg + translation_sb";
    p9_reviewer = "B";
    num_txn = 8;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_satp_hotswap_vseq");
  endfunction

endclass : test_mmu_csr_satp_switch

`endif // TEST_MMU_CSR_SATP_SWITCH_SVH
