// =============================================================================
// Toggle coverage: fill all 16 DTLB entries with alternating bit patterns
// to cover PPN/FLG/VPN bit toggles across the full entry array.
//
// Two passes:
//   Pass A: fill entries 0-15 with all-ones pattern (0xFFFFFFF / 0x3FFF)
//   Pass B: fill entries 15-0 with all-zeros pattern (0x0000000 / 0x0000)
// This ensures every bit sees both 0->1 and 1->0.
// =============================================================================
`ifndef TEST_MMU_L1DTLB_COV_TOGGLE_ENTRY_SWEEP_001_SVH
`define TEST_MMU_L1DTLB_COV_TOGGLE_ENTRY_SWEEP_001_SVH

class test_mmu_l1dtlb_cov_toggle_entry_sweep_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_toggle_entry_sweep_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_TOGGLE_ENTRY_SWEEP_001"; endfunction
endclass

`endif
