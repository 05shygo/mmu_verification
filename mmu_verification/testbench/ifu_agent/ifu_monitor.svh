// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_monitor.svh
// Phase 3 (Engineer B): IFU monitor skeleton
// Observes IFU↔MMU interface; publishes to two analysis ports.
//   ap_req: fires when ifu_mmu_va_vld=1 (request observed)
//   ap_rsp: fires when mmu_ifu_pavld=1 (merged req+rsp txn containing VA+PA)
//
// Phase 5 (Engineer B): Added m_pending_req queue for req/rsp correlation.
//   IFU is 1-outstanding: FIFO order is guaranteed.
//   ap_rsp txn carries both VA (from req) and PA/pgflt/deny (from DUT response)
//   → mmu_translation_sb.af_ifu_rsp can directly call ref_model.translate().
// =============================================================================
`ifndef IFU_MONITOR_SVH
`define IFU_MONITOR_SVH

class ifu_monitor extends uvm_monitor;

  `uvm_component_utils(ifu_monitor)

  virtual ifu_if vif;

  // Analysis port: VA request (ifu_mmu_va_vld assertion)
  uvm_analysis_port #(ifu_txn) ap_req;
  // Analysis port: merged req+rsp (mmu_ifu_pavld assertion, txn contains VA+PA)
  // Phase 5 downstream: ap_rsp → mmu_translation_sb.af_ifu_rsp
  uvm_analysis_port #(ifu_txn) ap_rsp;

  // Phase 5: Outstanding request FIFO for req/rsp correlation.
  // IFU is 1-outstanding (no out-of-order), FIFO pop is safe.
  protected ifu_txn m_pending_req[$];

  // Timeout-resilience flag: set by _collect_rsp when pavld arrives,
  // checked by _collect_req when va_vld deasserts.
  protected bit m_rsp_seen;

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
  // Phase 5: push to m_pending_req queue so _collect_rsp can merge VA fields.
  // Edge detection: wait for ifu_mmu_va_vld HIGH, sample once, then wait for
  // LOW before looping.  This prevents duplicate publications when the driver
  // holds va_vld asserted across multiple cycles (hold-until-pavld protocol).
  protected task _collect_req();
    ifu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.ifu_mmu_va_vld);
      tr       = ifu_txn::type_id::create("ifu_req_mon");
      tr.va    = 63'(vif.monitor_cb.ifu_mmu_va << 1);
      tr.abort = vif.monitor_cb.ifu_mmu_abort;
      `uvm_info(get_type_name(), {"IFU REQ: ", tr.convert2string()}, UVM_HIGH)
      m_rsp_seen = 0;
      m_pending_req.push_back(tr);
      ap_req.write(tr);
      @(vif.monitor_cb iff !vif.monitor_cb.ifu_mmu_va_vld);
      // If va_vld fell without pavld (driver timeout), discard pending entry.
      if (!m_rsp_seen && m_pending_req.size() > 0) begin
        void'(m_pending_req.pop_back());
        `uvm_info(get_type_name(),
          $sformatf("IFU REQ dropped (no pavld before va_vld deassert): VA=0x%010h",
            {1'b0, tr.va[38:0]}), UVM_MEDIUM)
      end
    end
  endtask

  // ── Collect PA response events ────────────────────────────────────────────
  protected task _collect_rsp();
    ifu_txn tr, req_tr;
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
      wait(m_pending_req.size() > 0);
      req_tr   = m_pending_req.pop_front();
      m_rsp_seen = 1;
      tr.va    = req_tr.va;
      tr.abort = req_tr.abort;
      `uvm_info(get_type_name(), {"IFU RSP: ", tr.convert2string()}, UVM_HIGH)
      ap_rsp.write(tr);
      @(vif.monitor_cb iff !vif.monitor_cb.mmu_ifu_pavld);
    end
  endtask

endclass : ifu_monitor

`endif // IFU_MONITOR_SVH
