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
  // Phase 5+:
  //  import misc_agent_pkg::*;

  `include "uvm_macros.svh"

  `include "mmu_top_cfg.svh"
  `include "mmu_page_table_mem.svh"  // Phase 4: shared shadow page table
  `include "mmu_ref_model.svh"       // Phase 4: Sv39 reference model
  `include "mmu_env.svh"

endpackage : mmu_env_pkg

`endif // MMU_ENV_PKG_SV
