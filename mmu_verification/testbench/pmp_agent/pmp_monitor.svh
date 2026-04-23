// =============================================================================
// MMU UVM Verification — testbench/pmp_agent/pmp_monitor.svh
// Phase 3: PMP monitor — observes PA outputs and fetch-enable outputs
// Analysis port feeds: m_ref.af_pmp_cfg (Phase 5)
// =============================================================================
`ifndef PMP_MONITOR_SVH
`define PMP_MONITOR_SVH

class pmp_monitor extends uvm_monitor;

  `uvm_component_utils(pmp_monitor)

  virtual pmp_if vif;

  // Single AP for all PMP observations.
  // Downstream (Phase 5+): ap → m_ref.af_pmp_cfg
  uvm_analysis_port #(pmp_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual pmp_if)::get(this, "", "PMP_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get PMP_VIF from config_db")
    ap = new("ap", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      _collect_pa_samples();
      _collect_flag_changes();
    join_none
  endtask

  // ── Sample PA outputs on every clock (for translation SB, Phase 5) ───────
  protected task _collect_pa_samples();
    pmp_txn tr;
    // Only sample when any PA is non-zero (DUT is actively translating)
    forever begin
      @(vif.monitor_cb);
      if (|{vif.monitor_cb.mmu_pmp_pa0, vif.monitor_cb.mmu_pmp_pa1,
             vif.monitor_cb.mmu_pmp_pa2, vif.monitor_cb.mmu_pmp_pa3,
             vif.monitor_cb.mmu_pmp_pa4, vif.monitor_cb.mmu_pmp_pa5,
             vif.monitor_cb.mmu_pmp_pa6, vif.monitor_cb.mmu_pmp_pa7}) begin
        tr         = pmp_txn::type_id::create("pa_sample");
        tr.pa[0]   = vif.monitor_cb.mmu_pmp_pa0;
        tr.pa[1]   = vif.monitor_cb.mmu_pmp_pa1;
        tr.pa[2]   = vif.monitor_cb.mmu_pmp_pa2;
        tr.pa[3]   = vif.monitor_cb.mmu_pmp_pa3;
        tr.pa[4]   = vif.monitor_cb.mmu_pmp_pa4;
        tr.pa[5]   = vif.monitor_cb.mmu_pmp_pa5;
        tr.pa[6]   = vif.monitor_cb.mmu_pmp_pa6;
        tr.pa[7]   = vif.monitor_cb.mmu_pmp_pa7;
        tr.fetch_en[0] = vif.monitor_cb.mmu_pmp_fetch3;
        tr.fetch_en[1] = vif.monitor_cb.mmu_pmp_fetch5;
        tr.fetch_en[2] = vif.monitor_cb.mmu_pmp_fetch6;
        tr.fetch_en[3] = vif.monitor_cb.mmu_pmp_fetch7;
        // Also capture current flags for PMP check
        tr.flg[0]  = vif.monitor_cb.pmp_mmu_flg0;
        tr.flg[1]  = vif.monitor_cb.pmp_mmu_flg1;
        tr.flg[2]  = vif.monitor_cb.pmp_mmu_flg2;
        tr.flg[3]  = vif.monitor_cb.pmp_mmu_flg3;
        tr.flg[4]  = vif.monitor_cb.pmp_mmu_flg4;
        tr.flg[5]  = vif.monitor_cb.pmp_mmu_flg5;
        tr.flg[6]  = vif.monitor_cb.pmp_mmu_flg6;
        tr.flg[7]  = vif.monitor_cb.pmp_mmu_flg7;
        ap.write(tr);
      end
    end
  endtask

  // ── Detect flag configuration changes (for ref_model update) ─────────────
  protected task _collect_flag_changes();
    pmp_txn prev_tr;
    pmp_txn tr;
    bit [3:0] prev_flg[8];
    bit changed;
    // Initialise prev
    foreach (prev_flg[i]) prev_flg[i] = 4'hF;  // force first publish
    forever begin
      @(vif.monitor_cb);
      changed = 1'b0;
      if (vif.monitor_cb.pmp_mmu_flg0 !== prev_flg[0]) changed = 1'b1;
      if (vif.monitor_cb.pmp_mmu_flg1 !== prev_flg[1]) changed = 1'b1;
      if (vif.monitor_cb.pmp_mmu_flg2 !== prev_flg[2]) changed = 1'b1;
      if (vif.monitor_cb.pmp_mmu_flg3 !== prev_flg[3]) changed = 1'b1;
      if (vif.monitor_cb.pmp_mmu_flg4 !== prev_flg[4]) changed = 1'b1;
      if (vif.monitor_cb.pmp_mmu_flg5 !== prev_flg[5]) changed = 1'b1;
      if (vif.monitor_cb.pmp_mmu_flg6 !== prev_flg[6]) changed = 1'b1;
      if (vif.monitor_cb.pmp_mmu_flg7 !== prev_flg[7]) changed = 1'b1;
      if (changed) begin
        tr       = pmp_txn::type_id::create("flg_change");
        tr.flg[0] = vif.monitor_cb.pmp_mmu_flg0;
        tr.flg[1] = vif.monitor_cb.pmp_mmu_flg1;
        tr.flg[2] = vif.monitor_cb.pmp_mmu_flg2;
        tr.flg[3] = vif.monitor_cb.pmp_mmu_flg3;
        tr.flg[4] = vif.monitor_cb.pmp_mmu_flg4;
        tr.flg[5] = vif.monitor_cb.pmp_mmu_flg5;
        tr.flg[6] = vif.monitor_cb.pmp_mmu_flg6;
        tr.flg[7] = vif.monitor_cb.pmp_mmu_flg7;
        foreach (prev_flg[i]) prev_flg[i] = tr.flg[i];
        `uvm_info(get_type_name(), {"PMP flags changed: ", tr.convert2string()}, UVM_MEDIUM)
        ap.write(tr);
      end
    end
  endtask

endclass : pmp_monitor

`endif // PMP_MONITOR_SVH
