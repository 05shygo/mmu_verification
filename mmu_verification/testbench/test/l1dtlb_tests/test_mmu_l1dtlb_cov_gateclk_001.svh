// =============================================================================
// Gateclk FSM + Toggle Coverage Test
//
// Goal: cover all gateclk (clock gating cell) FSM states and transitions
//       across all MMU clock domains (686 instances across DTLB/iUTLB/L2TLB/PTW).
//
// Each gateclk cell has an internal latch-based FSM:
//   - Transparent: clk_en=1 (clock passes through)
//   - Opaque:      clk_en=0 (clock gated)
//
// The enable is: (global_en && (module_en || local_en)) || external_en
// where module_en = cp0_mmu_icg_en (CSR), local_en = per-block activity.
//
// Strategy:
//   1. Run full MMU activity to exercise transparent state via local_en
//      (all blocks active simultaneously)
//   2. Toggle cp0_mmu_icg_en 1→0 and wait for idle → opaque via module_en
//   3. Toggle cp0_mmu_icg_en 0→1 and run activity → transparent via module_en
//   4. Repeat cycle 4 times to cover all transitions
// =============================================================================
`ifndef TEST_MMU_L1DTLB_COV_GATECLK_001_SVH
`define TEST_MMU_L1DTLB_COV_GATECLK_001_SVH

class test_mmu_l1dtlb_cov_gateclk_001 extends l1dtlb_directed_test_base;
  `uvm_component_utils(test_mmu_l1dtlb_cov_gateclk_001)
  function new(string name, uvm_component parent); super.new(name, parent); endfunction
  virtual function string get_l1dtlb_tc_id(); return "DTLB_COV_GATECLK_001"; endfunction
endclass : test_mmu_l1dtlb_cov_gateclk_001

`endif
