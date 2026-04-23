// =============================================================================
// MMU UVM Verification — testbench/sysmap_cfg_agent/sysmap_cfg_agent_pkg.sv
// Phase 3: SysMap configuration agent package
// =============================================================================
`ifndef SYSMAP_CFG_AGENT_PKG_SV
`define SYSMAP_CFG_AGENT_PKG_SV

package sysmap_cfg_agent_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;

  `include "uvm_macros.svh"

  `include "sysmap_cfg_txn.svh"
  `include "sysmap_cfg_covergroups.svh"
  `include "sysmap_cfg_sequencer.svh"
  `include "sysmap_cfg_driver.svh"
  `include "sysmap_cfg_monitor.svh"
  `include "sysmap_cfg_sequences.svh"
  `include "sysmap_cfg_agent.svh"

endpackage : sysmap_cfg_agent_pkg

`endif // SYSMAP_CFG_AGENT_PKG_SV
