// =============================================================================
// MMU UVM Verification — testbench/misc_agent/misc_monitor.svh
// Phase 5 (Engineer A): Misc monitor
//
// Observes misc_if read-back signals and publishes two analysis ports:
//
//   ap_hpcp  — fires every clock when any of the three HPCP miss signals
//              changes value (dutlb_miss | iutlb_miss | jtlb_miss).
//              Downstream: mmu_perf_mon.af_hpcp
//
//   ap_debug — fires every clock when mmu_had_debug_info changes value.
//              (Phase 7: connect to dedicated debug checker)
//
// The monitor does NOT drive any output signals — it is purely passive on
// the sampling side (monitor_cb clocking block, #1step input skew).
// =============================================================================
`ifndef MISC_MONITOR_SVH
`define MISC_MONITOR_SVH

class misc_monitor extends uvm_monitor;

  `uvm_component_utils(misc_monitor)

  virtual misc_if vif;

  // HPCP miss event port
  // Published when any HPCP miss output changes (low→high or high→low).
  uvm_analysis_port #(misc_txn) ap_hpcp;

  // Debug info change port
  // Published when mmu_had_debug_info changes value.
  uvm_analysis_port #(misc_txn) ap_debug;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual misc_if)::get(this, "", "MISC_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get MISC_VIF from config_db")
    ap_hpcp  = new("ap_hpcp",  this);
    ap_debug = new("ap_debug", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // Wait for reset de-assertion before sampling
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(vif.monitor_cb);

    fork
      _collect_hpcp();
      _collect_debug();
    join_none
  endtask

  // ── Collect HPCP miss events ──────────────────────────────────────────────
  // Samples every clock cycle; publishes a misc_txn whenever at least one of
  // the three miss signals is asserted high.  This gives a pulse-per-miss
  // granularity that the perf_mon can count.
  protected task _collect_hpcp();
    misc_txn tr;
    forever begin
      @(vif.monitor_cb);
      // Only publish when a miss event is visible
      if (vif.monitor_cb.mmu_hpcp_dutlb_miss ||
          vif.monitor_cb.mmu_hpcp_iutlb_miss ||
          vif.monitor_cb.mmu_hpcp_jtlb_miss) begin
        tr              = misc_txn::type_id::create("hpcp_mon");
        tr.op           = MISC_HPCP_CNT_EN;  // tag as HPCP observation
        tr.dutlb_miss   = vif.monitor_cb.mmu_hpcp_dutlb_miss;
        tr.iutlb_miss   = vif.monitor_cb.mmu_hpcp_iutlb_miss;
        tr.jtlb_miss    = vif.monitor_cb.mmu_hpcp_jtlb_miss;
        tr.hpcp_cnt_en  = vif.monitor_cb.hpcp_mmu_cnt_en;
        `uvm_info(get_type_name(),
          $sformatf("HPCP miss: dutlb=%0b iutlb=%0b jtlb=%0b cnt_en=%0b",
            tr.dutlb_miss, tr.iutlb_miss, tr.jtlb_miss, tr.hpcp_cnt_en),
          UVM_HIGH)
        ap_hpcp.write(tr);
      end
    end
  endtask

  // ── Collect debug info changes ────────────────────────────────────────────
  // Samples every clock; publishes only when mmu_had_debug_info changes.
  protected task _collect_debug();
    misc_txn   tr;
    bit [33:0] prev_debug = 34'h0;
    forever begin
      @(vif.monitor_cb);
      if (vif.monitor_cb.mmu_had_debug_info !== prev_debug) begin
        prev_debug = vif.monitor_cb.mmu_had_debug_info;
        tr                = misc_txn::type_id::create("debug_mon");
        tr.op             = MISC_IDLE;  // tag — op not applicable for debug obs
        tr.had_debug_info = vif.monitor_cb.mmu_had_debug_info;
        `uvm_info(get_type_name(),
          $sformatf("DEBUG info changed: 0x%09h", tr.had_debug_info),
          UVM_HIGH)
        ap_debug.write(tr);
      end
    end
  endtask

endclass : misc_monitor

`endif // MISC_MONITOR_SVH
