// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_sequencer.svh
// Phase 4: PTW memory agent sequencer
// =============================================================================
`ifndef PTW_MEM_SEQUENCER_SVH
`define PTW_MEM_SEQUENCER_SVH

class ptw_mem_sequencer extends uvm_sequencer #(ptw_mem_txn);
  `uvm_component_utils(ptw_mem_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : ptw_mem_sequencer

`endif // PTW_MEM_SEQUENCER_SVH
