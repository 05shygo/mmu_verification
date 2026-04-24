// =============================================================================
// MMU UVM Verification — testbench/sysmap_cfg_agent/sysmap_cfg_covergroups.svh
// Phase 3: SysMap configuration coverage (skeleton — Phase 7 fills details)
// =============================================================================
`ifndef SYSMAP_CFG_COVERGROUPS_SVH
`define SYSMAP_CFG_COVERGROUPS_SVH

class sysmap_cfg_cg_wrapper extends uvm_component;
  `uvm_component_utils(sysmap_cfg_cg_wrapper)

  virtual sysmap_cfg_if vif;

  // ── Region enable states ──────────────────────────────────────────────────
  covergroup cg_sysmap_regions;
    // Sample how many regions are simultaneously enabled
    cp_en0 : coverpoint vif.cfg_enable[0];
    cp_en1 : coverpoint vif.cfg_enable[1];
    cp_en2 : coverpoint vif.cfg_enable[2];
    cp_en3 : coverpoint vif.cfg_enable[3];
    // Cross: region 0 vs region 1 enable
    cx_r0_r1 : cross cp_en0, cp_en1;
  endgroup

  // ── Permission flag coverage ──────────────────────────────────────────────
  covergroup cg_sysmap_flags;
    cp_flg0 : coverpoint vif.cfg_flg[0] {
      bins deny   = {[5'h10:5'h1F]};
      bins allow  = {5'h00};
      bins other  = default;
    }
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_sysmap_regions = new();
    cg_sysmap_flags   = new();
  endfunction

  virtual function void set_vif(virtual sysmap_cfg_if v);
    vif = v;
  endfunction

  virtual function void sample();
    if (cg_sysmap_regions != null) cg_sysmap_regions.sample();
    if (cg_sysmap_flags   != null) cg_sysmap_flags.sample();
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(vif.monitor_cb);
      sample();
    end
  endtask

endclass : sysmap_cfg_cg_wrapper

`endif // SYSMAP_CFG_COVERGROUPS_SVH
