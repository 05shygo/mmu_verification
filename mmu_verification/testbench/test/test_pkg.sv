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
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;
  import cp0_agent_pkg::*;
  import pmp_agent_pkg::*;
  import sysmap_cfg_agent_pkg::*;
  import ifu_agent_pkg::*;
  import lsu_agent_pkg::*;
  import ptw_mem_agent_pkg::*;  // Phase 4
  import mmu_env_pkg::*;   // mmu_top_cfg, mmu_env, mmu_ref_model, mmu_page_table_mem

  `include "uvm_macros.svh"

  // ── Phase 3: base test (must precede all derived tests) ───────────────────
  `include "test_base.svh"

  // ── Phase 3: basic sanity tests ───────────────────────────────────────────
  `include "basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh"

  // ── Phase 4: PTW map4k directed test ──────────────────────────────────────
  `include "basic_tests/test_ptw_map4k_directed.svh"

endpackage : test_pkg

`endif // TEST_PKG_SV
