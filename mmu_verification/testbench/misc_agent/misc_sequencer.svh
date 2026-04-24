// =============================================================================
// MMU UVM Verification — testbench/misc_agent/misc_sequencer.svh
// Phase 5 (Engineer A): Misc sequencer
// =============================================================================
`ifndef MISC_SEQUENCER_SVH
`define MISC_SEQUENCER_SVH

class misc_sequencer extends uvm_sequencer #(misc_txn);
  `uvm_component_utils(misc_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : misc_sequencer

`endif // MISC_SEQUENCER_SVH
