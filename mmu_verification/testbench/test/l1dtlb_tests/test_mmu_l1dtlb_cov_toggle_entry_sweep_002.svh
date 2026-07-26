// =============================================================================
// T-B2 (toggle_closure_plan v2, wave 2) — dTLB full entry sweep.
// Closes: entry_flg_vec (all 14 bits × 16 entries, W/D/X/U/sysmap both dirs),
//         entry_ppn_vec (28 bits × 16, 3 complementary rounds),
//         mb_entry_ppn/vpn/flg (8 MB slots, high→complement PPN),
//         entry_pgs[15:0] (2M + 1G → 4K rewrite, pgs[1]/[2] 1→0).
// =============================================================================
`ifndef TEST_MMU_L1DTLB_COV_TOGGLE_ENTRY_SWEEP_002_SVH
`define TEST_MMU_L1DTLB_COV_TOGGLE_ENTRY_SWEEP_002_SVH

class test_mmu_l1dtlb_cov_toggle_entry_sweep_002 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_toggle_entry_sweep_002)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_TOGGLE_ENTRY_SWEEP_002"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "mmu_l1dtlb_toggle_entry_sweep_vseq";
    p9_checker  = "translation_sb,l1dtlb_spec_sb,whitebox_cg,l1dtlb_sva";
    num_txn     = 128;
    timeout_ns  = 300_000_000;
    m_vseq_names.push_back("mmu_l1dtlb_toggle_entry_sweep_vseq");
  endfunction
endclass

`endif // TEST_MMU_L1DTLB_COV_TOGGLE_ENTRY_SWEEP_002_SVH
