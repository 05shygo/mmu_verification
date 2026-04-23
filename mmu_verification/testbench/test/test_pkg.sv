// =============================================================================
// MMU UVM Verification — testbench/test/test_pkg.sv
// Phase 3 (Batch 2): Test package — aggregates all UVM test classes.
//
// Compilation order: must follow mmu_env_pkg (which re-exports all 3 agent pkgs).
// Include order:  test_base (dependency) → specific test classes
// =============================================================================
`ifndef TEST_PKG_SV
`define TEST_PKG_SV

package test_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import mmu_env_pkg::*;   // re-exports cp0/pmp/sysmap_cfg agent pkgs + env classes

  `include "uvm_macros.svh"

  // ── Phase 3: base test (must precede all derived tests) ───────────────────
  `include "test_base.svh"

  // ── Phase 3: basic sanity tests ───────────────────────────────────────────
  `include "basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh"

endpackage : test_pkg

`endif // TEST_PKG_SV
