// =============================================================================
// T-G (toggle_closure_plan v2) — L2 functional signals: high ASID/VPN/G/TLBOP.
// Closes: mmu_l2tlb cur_asid/tlbr_asid[15:14]/final_idx, TLBWI/TLBR/TLBP path
// under ASID=FFFF, upper-half + all-ones VPN lookups (canonical raw drive),
// ITLB-type L2 requests, PFU pipe2 high addresses, fb same-VPN timing.
// =============================================================================
`ifndef TEST_MMU_L2TLB_COV_TOGGLE_HIGHADDR_001_SVH
`define TEST_MMU_L2TLB_COV_TOGGLE_HIGHADDR_001_SVH

class test_mmu_l2tlb_cov_toggle_highaddr_001 extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_toggle_highaddr_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id            = "L2TLB_COV_TOGGLE_HIGHADDR_001";
    p9_seq_desc         = "mmu_l2tlb_toggle_highaddr_vseq";
    phase6e_scenario_id = "L2TLB_COV_TOGGLE_HIGHADDR_001";
    num_txn = 256; timeout_ns = 180_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_toggle_highaddr_vseq");
  endfunction
endclass

`endif // TEST_MMU_L2TLB_COV_TOGGLE_HIGHADDR_001_SVH
