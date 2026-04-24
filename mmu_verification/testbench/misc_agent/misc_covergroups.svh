// =============================================================================
// MMU UVM Verification — testbench/misc_agent/misc_covergroups.svh
// Phase 5 (Engineer A): Misc functional coverage skeleton
// Full coverpoints are expanded in Phase 7.
//
// P3-3 fix applied: covergroup new() called in class new(), NOT in set_vif().
// =============================================================================
`ifndef MISC_COVERGROUPS_SVH
`define MISC_COVERGROUPS_SVH

class misc_cg_wrapper extends uvm_component;
  `uvm_component_utils(misc_cg_wrapper)

  virtual misc_if vif;

  // ── Performance counter enable / disable transition ──────────────────────
  // Sampled manually via sample_hpcp()
  covergroup cg_misc_hpcp;
    cp_cnt_en       : coverpoint vif.hpcp_mmu_cnt_en;
    cp_dutlb_miss   : coverpoint vif.mmu_hpcp_dutlb_miss;
    cp_iutlb_miss   : coverpoint vif.mmu_hpcp_iutlb_miss;
    cp_jtlb_miss    : coverpoint vif.mmu_hpcp_jtlb_miss;
    cx_en_dutlb     : cross cp_cnt_en, cp_dutlb_miss;
    cx_en_iutlb     : cross cp_cnt_en, cp_iutlb_miss;
  endgroup

  // ── RTU flush / exception injection ──────────────────────────────────────
  // Sampled manually via sample_rtu()
  covergroup cg_misc_rtu;
    cp_flush        : coverpoint vif.rtu_yy_xx_flush;
    cp_expt_vld     : coverpoint vif.rtu_mmu_expt_vld;
    cp_smp_disable  : coverpoint vif.biu_mmu_smp_disable;
    cx_flush_expt   : cross cp_flush, cp_expt_vld;
  endgroup

  // ── Debug info active ─────────────────────────────────────────────────────
  // Sampled periodically in run_phase
  covergroup cg_misc_debug;
    cp_debug_nonzero : coverpoint (|vif.mmu_had_debug_info) {
      bins active   = {1'b1};
      bins inactive = {1'b0};
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    // P3-3: all new() calls must be in class new() constructor
    cg_misc_hpcp  = new();
    cg_misc_rtu   = new();
    cg_misc_debug = new();
  endfunction

  // Call from misc_agent.connect_phase AFTER vif is assigned
  virtual function void set_vif(virtual misc_if v);
    vif = v;
  endfunction

  // Manual sample hooks called from misc_monitor or misc_agent
  virtual function void sample_hpcp();
    if (cg_misc_hpcp != null) cg_misc_hpcp.sample();
  endfunction

  virtual function void sample_rtu();
    if (cg_misc_rtu != null) cg_misc_rtu.sample();
  endfunction

  // Periodic global sampling (every cycle in run_phase)
  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk_i);
      if (cg_misc_debug != null) cg_misc_debug.sample();
      if (cg_misc_hpcp  != null) cg_misc_hpcp.sample();
    end
  endtask

endclass : misc_cg_wrapper

`endif // MISC_COVERGROUPS_SVH
