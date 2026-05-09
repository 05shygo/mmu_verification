`ifndef TEST_MMU_L1DTLB_DTLB_TYPE_PROP_LOAD_STORE_AMO_001_SVH
`define TEST_MMU_L1DTLB_DTLB_TYPE_PROP_LOAD_STORE_AMO_001_SVH

class test_mmu_l1dtlb_dtlb_type_prop_load_store_amo_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_dtlb_type_prop_load_store_amo_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_TYPE_PROP_LOAD_STORE_AMO_001"; endfunction
endclass : test_mmu_l1dtlb_dtlb_type_prop_load_store_amo_001

`endif // TEST_MMU_L1DTLB_DTLB_TYPE_PROP_LOAD_STORE_AMO_001_SVH
