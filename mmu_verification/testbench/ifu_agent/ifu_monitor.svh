// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_monitor.svh
// Phase 3 (Engineer B): IFU monitor skeleton
// Observes IFU↔MMU interface; publishes to two analysis ports.
//   ap_req: fires when ifu_mmu_va_vld=1 (request observed)
//   ap_rsp: fires when mmu_ifu_pavld=1 (response observed)
//
// TODO (Phase 5): Correlate req/rsp by maintaining outstanding request queue;
//   fill tr.pa/pgflt/deny back into the original request txn before publishing
//   to ap_rsp → mmu_translation_sb.af_ifu_rsp.
// =============================================================================
`ifndef IFU_MONITOR_SVH
`define IFU_MONITOR_SVH

class ifu_monitor extends uvm_monitor;

  `uvm_component_utils(ifu_monitor)

  virtual ifu_if vif;

  // Analysis port: VA request (ifu_mmu_va_vld assertion)
  uvm_analysis_port #(ifu_txn) ap_req;
  // Analysis port: PA response (mmu_ifu_pavld assertion)
  // Phase 5 downstream: ap_rsp → mmu_translation_sb.af_ifu_rsp
  uvm_analysis_port #(ifu_txn) ap_rsp;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ifu_if)::get(this, "", "IFU_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get IFU_VIF from config_db")
    ap_req = new("ap_req", this);
    ap_rsp = new("ap_rsp", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      _collect_req();
      _collect_rsp();
    join_none
  endtask

  // ── Collect VA request events ─────────────────────────────────────────────
  protected task _collect_req();
    ifu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.ifu_mmu_va_vld);
      tr       = ifu_txn::type_id::create("ifu_req_mon");
      tr.va    = vif.monitor_cb.ifu_mmu_va;
      tr.abort = vif.monitor_cb.ifu_mmu_abort;
      `uvm_info(get_type_name(), {"IFU REQ: ", tr.convert2string()}, UVM_HIGH)
      ap_req.write(tr);
    end
  endtask

  // ── Collect PA response events ────────────────────────────────────────────
  // TODO (Phase 5): Match response to outstanding request by FIFO order.
  protected task _collect_rsp();
    ifu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.mmu_ifu_pavld);
      tr         = ifu_txn::type_id::create("ifu_rsp_mon");
      tr.pavld   = 1'b1;
      tr.pa      = vif.monitor_cb.mmu_ifu_pa;
      tr.pgflt   = vif.monitor_cb.mmu_ifu_pgflt;
      tr.deny    = vif.monitor_cb.mmu_ifu_deny;
      tr.sec     = vif.monitor_cb.mmu_ifu_sec;
      tr.ca      = vif.monitor_cb.mmu_ifu_ca;
      tr.buf_bit = vif.monitor_cb.mmu_ifu_buf;
      `uvm_info(get_type_name(), {"IFU RSP: ", tr.convert2string()}, UVM_HIGH)
      ap_rsp.write(tr);
    end
  endtask

endclass : ifu_monitor

`endif // IFU_MONITOR_SVH
