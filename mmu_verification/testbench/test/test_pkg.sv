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
  import misc_agent_pkg::*;     // Phase 6 misc sequences/types
  import mmu_env_pkg::*;   // mmu_top_cfg, mmu_env, mmu_ref_model, mmu_page_table_mem

  `include "uvm_macros.svh"

  // ── Phase 3: base test (must precede all derived tests) ───────────────────
  `include "test_base.svh"

  // ── Phase 3: basic sanity tests ───────────────────────────────────────────
  `include "basic_tests/test_mmu_sanity_csr_pmp_sysmap.svh"

  // ── Phase 4: PTW map4k directed test ──────────────────────────────────────
  `include "basic_tests/test_ptw_map4k_directed.svh"

  // ── Phase 5: IFU + LSU Translation Sanity test ────────────────────────────
  `include "basic_tests/test_mmu_translation_sanity.svh"

  // ── Phase 6: SFENCE.VMA invalidate matrix test ────────────────────────────
  `include "basic_tests/test_mmu_invalidate_sfence_matrix.svh"
  `include "basic_tests/test_mmu_phase6_misc_inv_smoke.svh"
  `include "basic_tests/test_mmu_phase6_rtu_flush_ptw.svh"

  // Phase 8: virtual sequence harness (+VSEQ_NAME=...)
  `include "phase8_tests/test_mmu_vseq_runner.svh"

  // Phase 9: generated thin-wrapper test base + directory suites
  `include "phase9_common/phase9_generated_test_base.svh"
  `include "phase11_common/phase11_generated_test_base.svh"
  `include "l1itlb_tests/l1itlb_tests_suite.svh"
  `include "l1dtlb_tests/l1dtlb_tests_suite.svh"
  `include "l2tlb_tests/l2tlb_tests_suite.svh"
  `include "ptw_tests/ptw_tests_suite.svh"
  `include "tlbop_tests/tlbop_tests_suite.svh"
  `include "pmp_tests/pmp_tests_suite.svh"
  `include "sysmap_tests/sysmap_tests_suite.svh"
  `include "cp0_tests/cp0_tests_suite.svh"
  `include "flush_tests/flush_tests_suite.svh"
  `include "cross_tests/cross_tests_suite.svh"
  `include "perf_tests/perf_tests_suite.svh"
  `include "err_tests/err_tests_suite.svh"
  `include "bug_hunt_tests/bug_hunt_tests_suite.svh"
  `include "ptw_lsu_protocol_tests/ptw_lsu_protocol_tests_suite.svh"

endpackage : test_pkg

`endif // TEST_PKG_SV
