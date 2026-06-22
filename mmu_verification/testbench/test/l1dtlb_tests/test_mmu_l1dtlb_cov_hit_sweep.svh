`ifndef TEST_MMU_L1DTLB_COV_HIT_SWEEP_SVH
`define TEST_MMU_L1DTLB_COV_HIT_SWEEP_SVH
class test_mmu_l1dtlb_cov_hit_sweep extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_hit_sweep)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "L1DTLB_COV_HIT_SWEEP"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "mmu_l1dtlb_coverage_vseq";
    // Without this push, the default phase9 run_test_body() path would
    // only run misc_init_seq and exit without ever starting the vseq.
    m_vseq_names.push_back("mmu_l1dtlb_coverage_vseq");
    num_txn = 256;
    timeout_ns = 80_000_000;
  endfunction
endclass
`endif
