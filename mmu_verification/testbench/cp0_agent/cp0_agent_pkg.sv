// =============================================================================
// MMU UVM Verification — testbench/cp0_agent/cp0_agent_pkg.sv
// Phase 3: CP0 agent package — include order satisfies UVM dependencies
// =============================================================================
`ifndef CP0_AGENT_PKG_SV
`define CP0_AGENT_PKG_SV

package cp0_agent_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;

  `include "uvm_macros.svh"

  // Dependency order: txn → cg → sequencer → driver → monitor → sequences → agent
  `include "cp0_txn.svh"
  `include "cp0_covergroups.svh"
  `include "cp0_sequencer.svh"
  `include "cp0_driver.svh"
  `include "cp0_monitor.svh"
  `include "cp0_sequences.svh"
  `include "cp0_agent.svh"

endpackage : cp0_agent_pkg

`endif // CP0_AGENT_PKG_SV
