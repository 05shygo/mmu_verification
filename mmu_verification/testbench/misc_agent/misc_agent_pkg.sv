// =============================================================================
// MMU UVM Verification — testbench/misc_agent/misc_agent_pkg.sv
// Phase 5 (Engineer A): Misc agent package
//
// Include order satisfies forward-reference rules:
//   txn → covergroups → sequencer → driver → monitor → sequences → agent
// (covergroups before sequencer: cg_wrapper only depends on misc_if, not txn)
// =============================================================================
`ifndef MISC_AGENT_PKG_SV
`define MISC_AGENT_PKG_SV

package misc_agent_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;

  `include "uvm_macros.svh"

  // Dependency order:
  //   txn → cg → sequencer → driver → monitor → sequences → agent
  `include "misc_txn.svh"
  `include "misc_covergroups.svh"
  `include "misc_sequencer.svh"
  `include "misc_driver.svh"
  `include "misc_monitor.svh"
  `include "misc_sequences.svh"
  `include "misc_agent.svh"

endpackage : misc_agent_pkg

`endif // MISC_AGENT_PKG_SV
