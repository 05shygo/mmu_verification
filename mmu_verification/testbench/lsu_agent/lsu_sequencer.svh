// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_sequencer.svh
// Phase 3 (Engineer B): LSU sequencer
// =============================================================================
`ifndef LSU_SEQUENCER_SVH
`define LSU_SEQUENCER_SVH

class lsu_sequencer extends uvm_sequencer #(lsu_txn);
  `uvm_component_utils(lsu_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : lsu_sequencer

`endif // LSU_SEQUENCER_SVH
