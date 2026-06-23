`ifndef TEST_MMU_L2TLB_COV_PFU_CHK_DENY_SVH
`define TEST_MMU_L2TLB_COV_PFU_CHK_DENY_SVH
// TASK L2TLB-T01 / T13 — PFU full-path closure: LINE 1368/1382, FSM, BRANCH
// Updated to use mmu_l2tlb_pfu_fullpath_vseq which covers:
//   PFU_IDLE→PFU_CHK→PFU_DENY and PFU_IDLE→PFU_CHK→PFU_OK paths.
// Conditions: sysmap safe PFU flags + PMP port4 deny R enables
// PFU_CHK→PFU_DENY. After PMP restore, PFU_CHK→PFU_OK.
class test_mmu_l2tlb_cov_pfu_chk_deny extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_pfu_chk_deny)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    phase6e_scenario_id = "L2TLB_COV_PFU_CHK_DENY";
    num_txn = 8;
    timeout_ns = 60_000_000;
    m_enable_sv39_4k_bringup = 1'b1;
    m_run_misc_init = 1'b1;
    // PMP deny is now applied INSIDE the vseq (after entry installs, before PFU).
    // Sysmap safe flags are still applied pre-vseq to prevent sysmap faults.
    m_sysmap_seq_names.push_back("sysmap_pfu_safe_flag_seq");
    m_vseq_names.push_back("mmu_l2tlb_pfu_fullpath_vseq");
  endfunction
endclass
`endif
