// =============================================================================
// T-A (toggle_closure_plan v2) — iUTLB entry full sweep.
// Closes: mmu_l1itlb entryN_ppn/flg/pgs (421b), ct_mmu_iutlb_entry /
// _fst_entry high bits, ifu_mmu_va[62] (plan §五#11), plru one-hot rotation.
// Methodology: >=2 complementary pattern rounds per phase (both directions);
// tail hooks assert_mid_test_reset() for T-I (plusarg-gated no-op otherwise).
// =============================================================================
`ifndef TEST_MMU_L1ITLB_COV_TOGGLE_ENTRY_SWEEP_001_SVH
`define TEST_MMU_L1ITLB_COV_TOGGLE_ENTRY_SWEEP_001_SVH

class test_mmu_l1itlb_cov_toggle_entry_sweep_001 extends phase9_generated_test_base;
  `uvm_component_utils(test_mmu_l1itlb_cov_toggle_entry_sweep_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id    = "L1ITLB_COV_TOGGLE_ENTRY_SWEEP_001";
    p9_seq_desc = "mmu_l1itlb_toggle_entry_sweep_vseq";
    p9_checker  = "translation_sb,whitebox_cg";
    p9_reviewer = "B";
    num_txn     = 64;
    timeout_ns  = 240_000_000;
    m_enable_sv39_4k_bringup = 1'b0;  // vseq runs its own do_bringup()
    m_run_misc_init          = 1'b1;
    m_post_drain             = 500ns;
    m_vseq_names.push_back("mmu_l1itlb_toggle_entry_sweep_vseq");
  endfunction
endclass

`endif // TEST_MMU_L1ITLB_COV_TOGGLE_ENTRY_SWEEP_001_SVH
