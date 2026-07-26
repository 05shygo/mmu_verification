// =============================================================================
// T-G2 (toggle_closure_plan v2, wave 2) — L2 all-8-ways hit sweep.
// Closes: final_way_sel_vec[7:0] (one-hot, each bit 0→1 and 1→0);
//         raw_way_sel_vec[7:0]; data_dout PPN high↔low both dirs;
//         tag_dout ASID 1→0 across all 8 ways of a set.
// Extends T-G (test_mmu_l2tlb_cov_toggle_highaddr_001).
// =============================================================================
`ifndef TEST_MMU_L2TLB_COV_TOGGLE_HIGHADDR_002_SVH
`define TEST_MMU_L2TLB_COV_TOGGLE_HIGHADDR_002_SVH

class test_mmu_l2tlb_cov_toggle_highaddr_002 extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_mmu_l2tlb_cov_toggle_highaddr_002)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id            = "L2TLB_COV_TOGGLE_HIGHADDR_002";
    p9_seq_desc         = "mmu_l2tlb_toggle_highaddr_v2_vseq";
    phase6e_scenario_id = "L2TLB_COV_TOGGLE_HIGHADDR_002";
    num_txn = 256; timeout_ns = 180_000_000;
    m_enable_sv39_4k_bringup = 1'b1; m_run_misc_init = 1'b1;
    m_vseq_names.push_back("mmu_l2tlb_toggle_highaddr_v2_vseq");
  endfunction
endclass

`endif // TEST_MMU_L2TLB_COV_TOGGLE_HIGHADDR_002_SVH
