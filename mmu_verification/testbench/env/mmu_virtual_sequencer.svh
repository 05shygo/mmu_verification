// =============================================================================
// MMU UVM — mmu_virtual_sequencer.svh  (Phase 8)
// Holds handles to 6 sub-sequencers; ptw_mem is responder-only (no sequencer).
// See BuildPlan v3 §8.6.
// =============================================================================
`ifndef MMU_VIRTUAL_SEQUENCER_SVH
`define MMU_VIRTUAL_SEQUENCER_SVH

class mmu_virtual_sequencer extends uvm_sequencer #(uvm_sequence_item);
  `uvm_component_utils(mmu_virtual_sequencer)

  ifu_sequencer        ifu_sqr;
  lsu_sequencer        lsu_sqr;
  cp0_sequencer        cp0_sqr;
  pmp_sequencer        pmp_sqr;
  sysmap_cfg_sequencer sysmap_sqr;
  misc_sequencer       misc_sqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass : mmu_virtual_sequencer

`endif // MMU_VIRTUAL_SEQUENCER_SVH
