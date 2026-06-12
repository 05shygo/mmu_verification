`ifndef TEST_MMU_L1DTLB_COV_MB_EXPT_SVH
`define TEST_MMU_L1DTLB_COV_MB_EXPT_SVH
class test_mmu_l1dtlb_cov_mb_expt extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_mb_expt)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "L1DTLB_COV_MB_EXPT"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "mmu_l1dtlb_mb_expt_coverage_vseq";
    num_txn = 128;
    timeout_ns = 60_000_000;
  endfunction
endclass
`endif
