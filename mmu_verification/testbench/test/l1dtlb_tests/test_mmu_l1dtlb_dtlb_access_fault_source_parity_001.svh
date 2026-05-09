`ifndef TEST_MMU_L1DTLB_DTLB_ACCESS_FAULT_SOURCE_PARITY_001_SVH
`define TEST_MMU_L1DTLB_DTLB_ACCESS_FAULT_SOURCE_PARITY_001_SVH

class test_mmu_l1dtlb_dtlb_access_fault_source_parity_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_dtlb_access_fault_source_parity_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_ACCESS_FAULT_SOURCE_PARITY_001"; endfunction
endclass : test_mmu_l1dtlb_dtlb_access_fault_source_parity_001

`endif // TEST_MMU_L1DTLB_DTLB_ACCESS_FAULT_SOURCE_PARITY_001_SVH
