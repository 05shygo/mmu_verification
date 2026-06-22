`ifndef TEST_MMU_L1DTLB_COV_ENTRY_SWEEP_SVH
`define TEST_MMU_L1DTLB_COV_ENTRY_SWEEP_SVH
// TASK L1DTLB-T01 — DTLB entry 0..15 sweep + va8 invalidate.
// Closes: gen_l1dtlb_entry_sva[0..15].a_va8_inv_clears_matching_entry,
//         mmu_l1dtlb lines 1116/1120/1190/1194 (per-entry COND), and the
//         entry_*[8..15] toggle population that the original
//         mmu_l1dtlb_coverage_vseq leaves cold because it does not vary
//         va[19:12] across all 16 values.
class test_mmu_l1dtlb_cov_entry_sweep extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_entry_sweep)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "L1DTLB_COV_ENTRY_SWEEP"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "mmu_l1dtlb_entry_sweep_vseq";
    m_vseq_names.push_back("mmu_l1dtlb_entry_sweep_vseq");
    p9_checker = "translation_sb,l1dtlb_spec_sb,whitebox_cg,l1dtlb_sva";
    num_txn = 512;
    timeout_ns = 240_000_000;
  endfunction
endclass
`endif
