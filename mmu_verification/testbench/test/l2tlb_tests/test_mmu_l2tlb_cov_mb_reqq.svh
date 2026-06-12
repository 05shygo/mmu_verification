`ifndef TEST_MMU_L2TLB_COV_MB_REQQ_SVH
`define TEST_MMU_L2TLB_COV_MB_REQQ_SVH
class test_mmu_l2tlb_cov_mb_reqq extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_mb_reqq)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_COV_MB_REQQ";
    num_txn = 128;
    timeout_ns = 60_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    // MB lifecycle: allocate/deallocate cycles
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
    // REQQ depth + credit stress
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
    // Hash/index skew distribution
    m_vseq_names.push_back("mmu_l2tlb_hash_directed_vseq");
    // Bank page size matrix
    m_vseq_names.push_back("mmu_l2tlb_bank_page_size_matrix_vseq");
  endfunction
endclass
`endif
