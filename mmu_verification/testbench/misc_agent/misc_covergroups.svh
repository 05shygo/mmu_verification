// =============================================================================
// MMU UVM Verification — testbench/misc_agent/misc_covergroups.svh
// Phase 7: §10.1 — cg_hpcp（iff hpcp_mmu_cnt_en）+ 额外 RTU/Debug 辅助组
// =============================================================================
`ifndef MISC_COVERGROUPS_SVH
`define MISC_COVERGROUPS_SVH

class misc_cg_wrapper extends uvm_component;
  `uvm_component_utils(misc_cg_wrapper)

  virtual misc_if vif;

  // BuildPlan 表行 2022：cg_hpcp
  covergroup cg_hpcp;
    option.per_instance = 1;
    cp_iutlb_miss: coverpoint vif.mmu_hpcp_iutlb_miss iff (vif.hpcp_mmu_cnt_en);
    cp_dutlb_miss: coverpoint vif.mmu_hpcp_dutlb_miss iff (vif.hpcp_mmu_cnt_en);
    cp_jtlb_miss: coverpoint vif.mmu_hpcp_jtlb_miss iff (vif.hpcp_mmu_cnt_en);
  endgroup

  covergroup cg_misc_rtu;
    option.per_instance = 1;
    cp_flush: coverpoint vif.rtu_yy_xx_flush;
    cp_expt_vld: coverpoint vif.rtu_mmu_expt_vld;
    cp_smp_disable: coverpoint vif.biu_mmu_smp_disable;
    cx_flush_expt: cross cp_flush, cp_expt_vld;
  endgroup

  covergroup cg_misc_debug;
    option.per_instance = 1;
    cp_debug_nonzero: coverpoint (|vif.mmu_had_debug_info) { bins active = {1'b1}; bins inactive = {1'b0}; }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_hpcp       = new();
    cg_misc_rtu   = new();
    cg_misc_debug = new();
  endfunction

  virtual function void set_vif(virtual misc_if v);
    vif = v;
  endfunction

  virtual function void sample_hpcp();
    if (cg_hpcp != null) cg_hpcp.sample();
  endfunction

  virtual function void sample_rtu();
    if (cg_misc_rtu != null) cg_misc_rtu.sample();
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk_i);
      if (vif.rst_ni === 1'b0) continue;
      if (cg_misc_debug != null) cg_misc_debug.sample();
      if (vif.hpcp_mmu_cnt_en && cg_hpcp != null) cg_hpcp.sample();
      if (cg_misc_rtu != null) cg_misc_rtu.sample();
    end
  endtask

endclass : misc_cg_wrapper

`endif // MISC_COVERGROUPS_SVH
