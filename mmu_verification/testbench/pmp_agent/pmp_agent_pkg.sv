// =============================================================================
// MMU UVM Verification — testbench/pmp_agent/pmp_agent_pkg.sv
// Phase 3: PMP agent package
// =============================================================================
`ifndef PMP_AGENT_PKG_SV
`define PMP_AGENT_PKG_SV

package pmp_agent_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;

  `include "uvm_macros.svh"

  `include "pmp_txn.svh"
  `include "pmp_covergroups.svh"
  `include "pmp_sequencer.svh"
  `include "pmp_driver.svh"
  `include "pmp_monitor.svh"
  `include "pmp_sequences.svh"
  `include "pmp_agent.svh"

endpackage : pmp_agent_pkg

`endif // PMP_AGENT_PKG_SV
