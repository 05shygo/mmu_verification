// =============================================================================
// MMU UVM Verification — testbench/pmp_agent/pmp_covergroups.svh
// Phase 3: PMP functional coverage (skeleton — full coverpoints in Phase 7)
// =============================================================================
`ifndef PMP_COVERGROUPS_SVH
`define PMP_COVERGROUPS_SVH

class pmp_cg_wrapper extends uvm_component;
  `uvm_component_utils(pmp_cg_wrapper)

  virtual pmp_if vif;

  // ── PMP flag states (sampled on manual call) ──────────────────────────────
  covergroup cg_pmp_flags;
    cp_flg0 : coverpoint vif.pmp_mmu_flg0;
    cp_flg1 : coverpoint vif.pmp_mmu_flg1;
    cp_flg2 : coverpoint vif.pmp_mmu_flg2;
    cp_flg3 : coverpoint vif.pmp_mmu_flg3;
    // Cross IFU port vs LSU Pipe0 port deny states
    cx_ifu_lsu0 : cross cp_flg0, cp_flg1;
  endgroup

  // ── Fetch-enable outputs (from DUT) ──────────────────────────────────────
  covergroup cg_pmp_fetch;
    cp_fetch3 : coverpoint vif.mmu_pmp_fetch3;
    cp_fetch5 : coverpoint vif.mmu_pmp_fetch5;
    cp_fetch6 : coverpoint vif.mmu_pmp_fetch6;
    cp_fetch7 : coverpoint vif.mmu_pmp_fetch7;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Call from pmp_agent.connect_phase AFTER vif is assigned
  virtual function void set_vif(virtual pmp_if v);
    vif          = v;
    cg_pmp_flags = new();
    cg_pmp_fetch = new();
  endfunction

  virtual function void sample();
    if (cg_pmp_flags != null) cg_pmp_flags.sample();
    if (cg_pmp_fetch != null) cg_pmp_fetch.sample();
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk_i);
      sample();
    end
  endtask

endclass : pmp_cg_wrapper

`endif // PMP_COVERGROUPS_SVH
