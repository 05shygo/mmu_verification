// =============================================================================
// MMU UVM Verification — testbench/sysmap_cfg_agent/sysmap_cfg_sequencer.svh
// Phase 3: SysMap configuration sequencer
// =============================================================================
`ifndef SYSMAP_CFG_SEQUENCER_SVH
`define SYSMAP_CFG_SEQUENCER_SVH

class sysmap_cfg_sequencer extends uvm_sequencer #(sysmap_cfg_txn);
  `uvm_component_utils(sysmap_cfg_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

endclass : sysmap_cfg_sequencer

`endif // SYSMAP_CFG_SEQUENCER_SVH
