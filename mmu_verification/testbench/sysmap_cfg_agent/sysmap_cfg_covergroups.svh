// =============================================================================
// MMU UVM Verification — testbench/sysmap_cfg_agent/sysmap_cfg_covergroups.svh
// Phase 7: §10.1 — cg_sysmap：配置变更窗口（region + attr / sec-ca-buf 域）
// =============================================================================
`ifndef SYSMAP_CFG_COVERGROUPS_SVH
`define SYSMAP_CFG_COVERGROUPS_SVH

class sysmap_cfg_cg_wrapper extends uvm_component;
  `uvm_component_utils(sysmap_cfg_cg_wrapper)

  virtual sysmap_cfg_if vif;

  bit        prev_en[8];
  bit [4:0]  prev_flg[8];
  bit [27:0] prev_base[8];
  bit [27:0] prev_mask[8];
  bit        have_prev;
  // 本拍变更 region id 与 5bit attr
  int        r_id;
  bit [4:0]  r_flg;
  bit        r_pulse;

  covergroup cg_sysmap;
    option.per_instance = 1;
    cp_region: coverpoint r_id { bins r[] = {[0:7]}; }
    // attr: sec/ca/buff/so 由 flg[4:0] 整体分档（全空间 default + 关关键值）
    cp_attr: coverpoint r_flg;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_sysmap = new();
  endfunction

  virtual function void set_vif(virtual sysmap_cfg_if v);
    vif = v;
  endfunction

  function void detect_cfg_pulse;
    r_pulse = 0;
    for (int i = 0; i < 8; i++) begin
      if (!have_prev) break;
      if (vif.cfg_enable[i] != prev_en[i] || vif.cfg_flg[i] != prev_flg[i]
          || vif.cfg_base[i] != prev_base[i] || vif.cfg_mask[i] != prev_mask[i]) begin
        r_id   = i;
        r_flg  = vif.cfg_flg[i];
        r_pulse = 1;
        break; // 一周期只计一次
      end
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    have_prev = 0;
    forever begin
      @(vif.monitor_cb);
      if (!have_prev) begin
        for (int i = 0; i < 8; i++) begin
          prev_en[i]   = vif.cfg_enable[i];
          prev_flg[i]  = vif.cfg_flg[i];
          prev_base[i] = vif.cfg_base[i];
          prev_mask[i] = vif.cfg_mask[i];
        end
        have_prev = 1;
        continue;
      end
      detect_cfg_pulse();
      for (int i = 0; i < 8; i++) begin
        prev_en[i]   = vif.cfg_enable[i];
        prev_flg[i]  = vif.cfg_flg[i];
        prev_base[i] = vif.cfg_base[i];
        prev_mask[i] = vif.cfg_mask[i];
      end
      if (r_pulse) cg_sysmap.sample();
    end
  endtask

endclass : sysmap_cfg_cg_wrapper

`endif // SYSMAP_CFG_COVERGROUPS_SVH
