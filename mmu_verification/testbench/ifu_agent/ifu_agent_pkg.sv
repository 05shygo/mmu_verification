// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_agent_pkg.sv
// Phase 3 (Engineer B): IFU agent package
// =============================================================================
`ifndef IFU_AGENT_PKG_SV
`define IFU_AGENT_PKG_SV

package ifu_agent_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;

  `include "uvm_macros.svh"

  // Dependency order: txn → cg → sequencer → driver → monitor → sequences → agent
  `include "ifu_txn.svh"
  `include "ifu_covergroups.svh"
  `include "ifu_sequencer.svh"
  `include "ifu_driver.svh"
  `include "ifu_monitor.svh"
  `include "ifu_sequences.svh"
  `include "ifu_agent.svh"

endpackage : ifu_agent_pkg

`endif // IFU_AGENT_PKG_SV
