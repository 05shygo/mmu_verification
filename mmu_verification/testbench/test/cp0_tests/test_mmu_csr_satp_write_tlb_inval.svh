// =============================================================================
// Phase 9 generated test wrapper for TC-CSR-009
// Checker: csr_cg + invalidation_sb  Reviewer: B
// =============================================================================
`ifndef TEST_MMU_CSR_SATP_WRITE_TLB_INVAL_SVH
`define TEST_MMU_CSR_SATP_WRITE_TLB_INVAL_SVH

class test_mmu_csr_satp_write_tlb_inval extends phase9_generated_test_base;

  `uvm_component_utils(test_mmu_csr_satp_write_tlb_inval)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "TC-CSR-009";
    p9_seq_desc = "cp0_satp_mode_sv39_seq + cp0_tlb_allinv_seq + mmu_smoke_vseq";
    p9_checker = "csr_cg + invalidation_sb";
    p9_reviewer = "B";
    num_txn = 8;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_satp_mode_sv39_seq");
    m_cp0_seq_names.push_back("cp0_tlb_allinv_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_mmu_csr_satp_write_tlb_inval

`endif // TEST_MMU_CSR_SATP_WRITE_TLB_INVAL_SVH
