`ifndef TEST_MMU_L2TLB_COV_PFU_CHK_DENY_SVH
`define TEST_MMU_L2TLB_COV_PFU_CHK_DENY_SVH
// TASK L2TLB-T01 — PFU_CHK→PFU_DENY transition coverage.
// Closes mmu_l2tlb.sv:1361 (PFU_IDLE→PFU_CHK) and :1368 (PFU_CHK→PFU_DENY)
// by ensuring the L2TLB entries installed for the PFU lookup have full
// R/W/X/A/D/V permissions so l2tlb_pfu_flag_fault=0, letting the FSM
// advance into PFU_CHK where pmp_mmu_flg4[0]=0 then drives PFU_DENY.
class test_mmu_l2tlb_cov_pfu_chk_deny extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_pfu_chk_deny)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_COV_PFU_CHK_DENY";
    num_txn = 8;
    timeout_ns = 30_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    // sysmap with safe PFU flags (no flag fault)
    m_sysmap_seq_names.push_back("sysmap_pfu_safe_flag_seq");
    // PMP port4 deny R — sets pmp_mmu_flg4[0]=0 → l2tlb_pfu_deny=1
    m_pmp_seq_names.push_back("pmp_flg_deny_pfu_seq");
    m_vseq_names.push_back("mmu_l2tlb_pfu_chk_via_clean_entry_vseq");
  endfunction
endclass
`endif
