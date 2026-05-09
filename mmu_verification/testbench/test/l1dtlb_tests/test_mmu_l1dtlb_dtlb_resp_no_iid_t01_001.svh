`ifndef TEST_MMU_L1DTLB_DTLB_RESP_NO_IID_T01_001_SVH
`define TEST_MMU_L1DTLB_DTLB_RESP_NO_IID_T01_001_SVH

class test_mmu_l1dtlb_dtlb_resp_no_iid_t01_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_dtlb_resp_no_iid_t01_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_RESP_NO_IID_T01_001"; endfunction
endclass : test_mmu_l1dtlb_dtlb_resp_no_iid_t01_001

`endif // TEST_MMU_L1DTLB_DTLB_RESP_NO_IID_T01_001_SVH
