// =============================================================================
// T-B (toggle_closure_plan v2) — dTLB 1G + high-PA fill, two-round scheme.
// Closes: mmu_l1dtlb entry_ppn_vec/entry_pgs high bits, hit_rd/_sva datapath,
// entry_vpn[26/25/23] (corrected VAs, plan §五#12), U/R/W flag both dirs.
// Tail hooks assert_mid_test_reset() for T-I (plusarg-gated no-op otherwise).
// =============================================================================
`ifndef TEST_MMU_L1DTLB_COV_TOGGLE_HIGHPA_1G_001_SVH
`define TEST_MMU_L1DTLB_COV_TOGGLE_HIGHPA_1G_001_SVH

class test_mmu_l1dtlb_cov_toggle_highpa_1g_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_toggle_highpa_1g_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  // Unknown to decode_tc_id → run_test_body falls through to m_vseq_names.
  virtual function string get_l1dtlb_tc_id(); return "DTLB_TOGGLE_HIGHPA_1G_001"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "mmu_l1dtlb_toggle_highpa_1g_vseq";
    p9_checker  = "translation_sb,l1dtlb_spec_sb,whitebox_cg,l1dtlb_sva";
    num_txn     = 64;
    timeout_ns  = 240_000_000;
    m_vseq_names.push_back("mmu_l1dtlb_toggle_highpa_1g_vseq");
  endfunction
endclass

`endif // TEST_MMU_L1DTLB_COV_TOGGLE_HIGHPA_1G_001_SVH
