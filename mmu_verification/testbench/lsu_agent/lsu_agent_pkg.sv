// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_agent_pkg.sv
// Phase 3 (Engineer B): LSU agent package
// =============================================================================
`ifndef LSU_AGENT_PKG_SV
`define LSU_AGENT_PKG_SV

package lsu_agent_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;

  `include "uvm_macros.svh"

  // Dependency order: txn → cg → sequencer → driver → monitor → sequences → agent
  `include "lsu_txn.svh"
  `include "lsu_covergroups.svh"
  `include "lsu_sequencer.svh"
  `include "lsu_driver.svh"
  `include "lsu_monitor.svh"
  `include "lsu_sequences.svh"
  `include "lsu_agent.svh"

endpackage : lsu_agent_pkg

`endif // LSU_AGENT_PKG_SV
