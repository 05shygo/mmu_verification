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
  protected task _collect_req();
    ifu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.ifu_mmu_va_vld);
      tr       = ifu_txn::type_id::create("ifu_req_mon");
      tr.va    = vif.monitor_cb.ifu_mmu_va;
      tr.abort = vif.monitor_cb.ifu_mmu_abort;
      `uvm_info(get_type_name(), {"IFU REQ: ", tr.convert2string()}, UVM_HIGH)
      m_pending_req.push_back(tr); // Enqueue for req/rsp correlation
      ap_req.write(tr);
    end
  endtask

  // ── Collect PA response events ────────────────────────────────────────────
  // Phase 5: Pop oldest pending req (FIFO), merge VA/abort into the response
  //   txn so that ap_rsp subscribers (mmu_translation_sb) have both VA and PA.
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
      // --- Req/rsp correlation (FIFO, 1-outstanding) ---
      // Wait until the corresponding request has been captured.
      wait(m_pending_req.size() > 0);
      req_tr   = m_pending_req.pop_front();
      tr.va    = req_tr.va;    // Carry VA for ref_model.translate()
      tr.abort = req_tr.abort; // Carry abort for SB context
      `uvm_info(get_type_name(), {"IFU RSP: ", tr.convert2string()}, UVM_HIGH)
      ap_rsp.write(tr);
    end
  endtask

endclass : ifu_monitor

`endif // IFU_MONITOR_SVH
