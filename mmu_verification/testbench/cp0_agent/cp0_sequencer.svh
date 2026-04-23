// =============================================================================
// MMU UVM Verification — testbench/cp0_agent/cp0_sequencer.svh
// Phase 3: CP0 sequencer
// =============================================================================
`ifndef CP0_SEQUENCER_SVH
`define CP0_SEQUENCER_SVH

class cp0_sequencer extends uvm_sequencer #(cp0_txn);
  `uvm_component_utils(cp0_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : cp0_sequencer

`endif // CP0_SEQUENCER_SVH
