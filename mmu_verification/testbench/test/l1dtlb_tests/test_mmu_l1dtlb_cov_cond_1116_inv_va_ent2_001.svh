`ifndef TEST_MMU_L1DTLB_COV_COND_1116_INV_VA_ENT2_001_SVH
`define TEST_MMU_L1DTLB_COV_COND_1116_INV_VA_ENT2_001_SVH

class test_mmu_l1dtlb_cov_cond_1116_inv_va_ent2_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_cond_1116_inv_va_ent2_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_COND_1116_INV_VA_ENT2_001"; endfunction
endclass : test_mmu_l1dtlb_cov_cond_1116_inv_va_ent2_001

`endif // TEST_MMU_L1DTLB_COV_COND_1116_INV_VA_ENT2_001_SVH
