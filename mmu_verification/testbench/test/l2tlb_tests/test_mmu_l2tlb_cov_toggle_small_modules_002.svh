// =============================================================================
// T-H2 (toggle_closure_plan v2, wave 2) — L2 small-modules invall_cnt sweep.
// Closes: invall_cnt[7:0] (all 8 bits, 0→255 walk twice — both dirs);
//         req_entry_asid[15:0] mid bits via A5A5 burst;
//         invall-path ASID check signals under ASID=FFFF/0000/A5A5.
// Extends T-H (test_mmu_l2tlb_cov_toggle_small_modules_001).
// =============================================================================
`ifndef TEST_MMU_L2TLB_COV_TOGGLE_SMALL_MODULES_002_SVH
`define TEST_MMU_L2TLB_COV_TOGGLE_SMALL_MODULES_002_SVH

class test_mmu_l2tlb_cov_toggle_small_modules_002 extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_toggle_small_modules_002)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id            = "L2TLB_COV_TOGGLE_SMALL_MODULES_002";
    p9_seq_desc         = "mmu_l2tlb_toggle_small_modules_v2_vseq";
    phase6e_scenario_id = "L2TLB_COV_TOGGLE_SMALL_MODULES_002";
    num_txn = 512; timeout_ns = 300_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_toggle_small_modules_v2_vseq");
  endfunction
endclass

`endif // TEST_MMU_L2TLB_COV_TOGGLE_SMALL_MODULES_002_SVH
