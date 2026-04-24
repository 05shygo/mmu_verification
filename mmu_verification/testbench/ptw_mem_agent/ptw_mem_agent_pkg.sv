// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_agent_pkg.sv
// Phase 4: PTW memory channel agent package
//
// Include order satisfies UVM dependency rules:
//   txn (leaf) → cg → sequencer → responder → monitor → sequences
//   → page_table_builder (tool; depends on txn types) → agent wrapper
// =============================================================================
`ifndef PTW_MEM_AGENT_PKG_SV
`define PTW_MEM_AGENT_PKG_SV

package ptw_mem_agent_pkg;

  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import mmu_params_pkg::*;
  import mmu_common_pkg::*;

  `include "uvm_macros.svh"

  `include "ptw_mem_txn.svh"
  `include "page_table_builder.svh"    // must precede responder + sequences (forward-ref fix)
  `include "ptw_mem_covergroups.svh"
  `include "ptw_mem_sequencer.svh"
  `include "ptw_mem_responder.svh"
  `include "ptw_mem_monitor.svh"
  `include "ptw_mem_sequences.svh"
  `include "ptw_mem_agent.svh"

endpackage : ptw_mem_agent_pkg

`endif // PTW_MEM_AGENT_PKG_SV
