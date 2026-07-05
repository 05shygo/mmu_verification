// =============================================================================
// Precision exception CAM entry toggle test
// Targets: ent[1].pgflt, ent[6].acflt, ent[7].acflt, same_hit_entry
//
// Strategy: pre-fill MB entries to control which entry gets the PTW exception,
// then configure PTW responder to return pgflt or acflt for the target entry.
// =============================================================================
`ifndef TEST_MMU_L1DTLB_COV_EXPT_ENTRY_PRECISE_001_SVH
`define TEST_MMU_L1DTLB_COV_EXPT_ENTRY_PRECISE_001_SVH

class test_mmu_l1dtlb_cov_expt_entry_precise_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_expt_entry_precise_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_EXPT_ENTRY_PRECISE_001"; endfunction
endclass

`endif
