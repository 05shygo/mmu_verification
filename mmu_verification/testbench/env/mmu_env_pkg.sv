// =============================================================================
// MMU UVM Verification — testbench/env/mmu_env_pkg.sv
// Phase 3 (Batch 1): Environment package
// Imports the three Phase-3 agent packages; ifu/lsu/ptw_mem/misc added in Ph5.
// =============================================================================
`ifndef MMU_ENV_PKG_SV
`define MMU_ENV_PKG_SV

package mmu_env_pkg;

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
  import ptw_mem_agent_pkg::*;  // Phase 4: PTW memory agent
  import misc_agent_pkg::*;    // Phase 5: misc agent

  `include "uvm_macros.svh"

  `include "mmu_top_cfg.svh"
  `include "mmu_page_table_mem.svh"  // Phase 4: shared shadow page table
  `include "mmu_ref_model.svh"       // Phase 4: Sv39 reference model
  `include "ptw_source_types.svh"     // PTW source-side shared types/helpers
  `include "ptw_source_monitor.svh"   // PTW source-side monitor skeleton
  `include "ptw_source_ref_model.svh" // PTW source-side ref model skeleton
  `include "ptw_source_sb.svh"        // PTW source-side scoreboard skeleton
  `include "mmu_translation_sb.svh"  // Phase 5: translation scoreboard
  `include "mmu_invalidate_sb.svh"   // Phase 6: invalidate scoreboard
  `include "mmu_credit_sb.svh"       // Phase 5: credit / capacity scoreboard
  `include "mmu_perf_mon.svh"        // Phase 5: performance monitor skeleton
  `include "mmu_l1dtlb_spec_sb.svh"  // L1DTLB chapter-3 audit checker
  `include "mmu_env_cg_whitebox.svh" // Phase 7: §10.2 whitebox CG
  `include "mmu_virtual_sequencer.svh" // Phase 8 (before mmu_env uses m_vseqr)
  `include "mmu_env.svh"
  `include "mmu_vseq_lib.svh"  // Phase 8: 14 vseq + mmu_base_vseq
  `include "mmu_l1dtlb_vseq_lib.svh" // L1DTLB directed audit scenarios

endpackage : mmu_env_pkg

`endif // MMU_ENV_PKG_SV
