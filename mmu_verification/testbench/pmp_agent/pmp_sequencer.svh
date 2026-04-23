// =============================================================================
// MMU UVM Verification — testbench/pmp_agent/pmp_sequencer.svh
// Phase 3: PMP sequencer
// =============================================================================
`ifndef PMP_SEQUENCER_SVH
`define PMP_SEQUENCER_SVH

class pmp_sequencer extends uvm_sequencer #(pmp_txn);
  `uvm_component_utils(pmp_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : pmp_sequencer

`endif // PMP_SEQUENCER_SVH
