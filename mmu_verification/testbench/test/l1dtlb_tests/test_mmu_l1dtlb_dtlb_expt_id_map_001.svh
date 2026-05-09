`ifndef TEST_MMU_L1DTLB_DTLB_EXPT_ID_MAP_001_SVH
`define TEST_MMU_L1DTLB_DTLB_EXPT_ID_MAP_001_SVH

class test_mmu_l1dtlb_dtlb_expt_id_map_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_dtlb_expt_id_map_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_EXPT_ID_MAP_001"; endfunction
endclass : test_mmu_l1dtlb_dtlb_expt_id_map_001

`endif // TEST_MMU_L1DTLB_DTLB_EXPT_ID_MAP_001_SVH
