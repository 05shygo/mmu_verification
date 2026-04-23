// =============================================================================
// MMU UVM Verification — testbench/sysmap_cfg_agent/sysmap_cfg_monitor.svh
// Phase 3: SysMap configuration monitor
// Observes cfg_enable[] changes on the interface and publishes snapshots.
// Analysis port feeds: m_ref.af_sysmap_cfg (Phase 5)
// =============================================================================
`ifndef SYSMAP_CFG_MONITOR_SVH
`define SYSMAP_CFG_MONITOR_SVH

class sysmap_cfg_monitor extends uvm_monitor;

  `uvm_component_utils(sysmap_cfg_monitor)

  virtual sysmap_cfg_if vif;

  // AP for configuration snapshots.
  // Downstream (Phase 5+): ap → m_ref.af_sysmap_cfg
  uvm_analysis_port #(sysmap_cfg_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual sysmap_cfg_if)::get(this, "", "SYSMAP_CFG_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get SYSMAP_CFG_VIF from config_db")
    ap = new("ap", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    _detect_cfg_changes();
  endtask

  // ── Detect any change in cfg_enable[] and publish a full snapshot ─────────
  // cfg_* fields are written directly by the driver (not via clocking block),
  // so we poll every cycle.
  protected task _detect_cfg_changes();
    bit prev_enable[8];
    bit changed;
    sysmap_cfg_txn tr;
    foreach (prev_enable[i]) prev_enable[i] = 1'bX;  // force first publish
    forever begin
      @(vif.monitor_cb);
      changed = 1'b0;
      foreach (prev_enable[i]) begin
        if (vif.cfg_enable[i] !== prev_enable[i]) begin
          changed = 1'b1;
          break;
        end
      end
      if (changed) begin
        tr = sysmap_cfg_txn::type_id::create("sysmap_snap");
        foreach (tr.base[i]) begin
          tr.base  [i] = vif.cfg_base  [i];
          tr.mask  [i] = vif.cfg_mask  [i];
          tr.flg   [i] = vif.cfg_flg   [i];
          tr.enable[i] = vif.cfg_enable[i];
          prev_enable[i] = vif.cfg_enable[i];
        end
        `uvm_info(get_type_name(),
                  {"SysMap cfg snapshot: ", tr.convert2string()}, UVM_MEDIUM)
        ap.write(tr);
      end
    end
  endtask

endclass : sysmap_cfg_monitor

`endif // SYSMAP_CFG_MONITOR_SVH
