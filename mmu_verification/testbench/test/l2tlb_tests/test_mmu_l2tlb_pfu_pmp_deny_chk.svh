`ifndef TEST_MMU_L2TLB_PFU_PMP_DENY_CHK_SVH
`define TEST_MMU_L2TLB_PFU_PMP_DENY_CHK_SVH

class test_mmu_l2tlb_pfu_pmp_deny_chk extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_pfu_pmp_deny_chk)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_SCN_PFU_PMP_DENY_CHK";
    num_txn = 8; timeout_ns = 15_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_sysmap_seq_names.push_back("sysmap_pfu_safe_flag_seq");
    m_pmp_seq_names.push_back("pmp_flg_deny_pfu_seq");
    m_vseq_names.push_back("mmu_l2tlb_pfu_chk_deny_vseq");
  endfunction
endclass
`endif
