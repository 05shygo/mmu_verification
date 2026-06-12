`ifndef TEST_MMU_L1DTLB_COV_ENTRY0_WFG_SVH
`define TEST_MMU_L1DTLB_COV_ENTRY0_WFG_SVH
class test_mmu_l1dtlb_cov_entry0_wfg extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_entry0_wfg)
  function new(string n, uvm_component p); super.new(n, p); endfunction
  virtual function string get_l1dtlb_tc_id(); return "L1DTLB_ENTRY0_WFG"; endfunction
  virtual function void setup_plan();
    super.setup_plan();
    p9_seq_desc = "mmu_l1dtlb_entry0_wfg_vseq";
    num_txn = 64; timeout_ns = 120_000_000;
  endfunction
endclass
`endif
