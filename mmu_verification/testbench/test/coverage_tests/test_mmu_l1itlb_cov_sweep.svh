`ifndef TEST_MMU_L1ITLB_COV_SWEEP_SVH
`define TEST_MMU_L1ITLB_COV_SWEEP_SVH
class test_mmu_l1itlb_cov_sweep extends phase9_generated_test_base;
  `uvm_component_utils(test_mmu_l1itlb_cov_sweep)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "L1ITLB-COV-SWEEP";
    p9_seq_desc = "ifu_burst_sweep";
    p9_checker = "translation_sb,credit_sb,whitebox_cg";
    num_txn = 128;
    timeout_ns = 60_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    // IFU sequences for comprehensive ITLB exercise
    m_ifu_seq_names.push_back("ifu_mapped_va_seq");
    m_ifu_seq_names.push_back("ifu_mapped_va_seq");
    m_ifu_seq_names.push_back("ifu_mapped_va_seq");
    // LSU loads to create TLB entries + cause DTLB activity
    m_lsu_seq_names.push_back("lsu_mapped_va_seq");
    // Invalidation to trigger ITLB flush
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
  endfunction
endclass
`endif
