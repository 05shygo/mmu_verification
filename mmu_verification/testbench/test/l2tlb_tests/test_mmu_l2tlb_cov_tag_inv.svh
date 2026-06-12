`ifndef TEST_MMU_L2TLB_COV_TAG_INV_SVH
`define TEST_MMU_L2TLB_COV_TAG_INV_SVH
class test_mmu_l2tlb_cov_tag_inv extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_tag_inv)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_COV_TAG_INV";
    num_txn = 128;
    timeout_ns = 60_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    // Tag write/read/invalidate mix
    m_vseq_names.push_back("mmu_l2tlb_tag_write_read_inv_mix_vseq");
    m_vseq_names.push_back("mmu_l2tlb_tag_write_read_inv_mix_vseq");
    // Bank conflict for tag array utilization
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
    // Priority stress for arbiter
    m_pmp_seq_names.push_back("pmp_flg_normal_seq");
    m_sysmap_seq_names.push_back("sysmap_perm_flag_seq");
  endfunction
endclass
`endif
