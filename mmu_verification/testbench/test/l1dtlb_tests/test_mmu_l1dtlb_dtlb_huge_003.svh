`ifndef TEST_MMU_L1DTLB_DTLB_HUGE_003_SVH
`define TEST_MMU_L1DTLB_DTLB_HUGE_003_SVH

class test_mmu_l1dtlb_dtlb_huge_003 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_dtlb_huge_003)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_HUGE_003"; endfunction
endclass : test_mmu_l1dtlb_dtlb_huge_003

`endif // TEST_MMU_L1DTLB_DTLB_HUGE_003_SVH
