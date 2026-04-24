// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_sequencer.svh
// Phase 3 (Engineer B): IFU sequencer
// =============================================================================
`ifndef IFU_SEQUENCER_SVH
`define IFU_SEQUENCER_SVH

class ifu_sequencer extends uvm_sequencer #(ifu_txn);
  `uvm_component_utils(ifu_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : ifu_sequencer

`endif // IFU_SEQUENCER_SVH
