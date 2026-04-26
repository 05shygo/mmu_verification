// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_monitor.svh
// Phase 3 (Engineer B): IFU monitor skeleton
// Observes IFU↔MMU interface; publishes to two analysis ports.
//   ap_req: fires when ifu_mmu_va_vld=1 (request observed)
//   ap_rsp: fires when mmu_ifu_pavld=1 (merged req+rsp txn containing VA+PA)
//
// Phase 5 (Engineer B): Added req/rsp correlation.
//   IFU uses 1-outstanding hold protocol: va_vld may stay HIGH continuously,
//   and VA updates only after current response returns.
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
  // Analysis port: pending req dropped without rsp (for credit compensation)
  uvm_analysis_port #(ifu_txn) ap_drop;

  // IFU hold protocol is 1-outstanding: keep a single pending request.
  protected ifu_txn m_pending_req;
  protected bit     m_has_pending;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_has_pending = 1'b0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ifu_if)::get(this, "", "IFU_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get IFU_VIF from config_db")
    ap_req = new("ap_req", this);
    ap_rsp = new("ap_rsp", this);
    ap_drop = new("ap_drop", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    _collect();
  endtask

  // ── Cycle-accurate collector for IFU hold protocol ────────────────────────
  // One request can be outstanding at a time. IFU may hold va_vld high across
  // consecutive fetches. Open when (va_vld && !has_pending) — not only on a
  // rising edge of va_vld — or pavld would fire with m_has_pending==0.
  // Ordering each cycle: (1) open new request if bus shows va_vld and idle,
  // (2) consume pavld (same-cycle hit: open first, then pavld in one tick).
  protected task _collect();
    ifu_txn req_tr, rsp_tr;
    va_t cur_va;
    forever begin
      @(vif.monitor_cb);

      // ifu_mmu_va is VA[63:1] on interface, restore byte-address form VA[63:0].
      cur_va = va_t'({vif.monitor_cb.ifu_mmu_va, 1'b0});

      // 1) Open request whenever the bus is presenting a VA and we have no
      //    outstanding request (covers first fetch and back-to-back with va_vld held).
      if (vif.monitor_cb.ifu_mmu_va_vld && !m_has_pending) begin
        req_tr       = ifu_txn::type_id::create("ifu_req_mon");
        req_tr.va    = cur_va;
        req_tr.abort = vif.monitor_cb.ifu_mmu_abort;
        m_pending_req = req_tr;
        m_has_pending = 1'b1;
        `uvm_info(get_type_name(),
          $sformatf("[IFU_MON_REQ_DBG] open pending: va=0x%010h abort=%0b pavld=%0b pa=0x%07h has_pending=%0b",
            {1'b0, cur_va[38:0]}, req_tr.abort, vif.monitor_cb.mmu_ifu_pavld,
            vif.monitor_cb.mmu_ifu_pa, m_has_pending),
          UVM_DEBUG)
        `uvm_info(get_type_name(), {"IFU REQ: ", req_tr.convert2string()}, UVM_HIGH)
        ap_req.write(req_tr);
      end

      // 2) Consume response.
      if (vif.monitor_cb.mmu_ifu_pavld) begin
        if (!m_has_pending) begin
          `uvm_warning(get_type_name(),
            $sformatf("IFU rsp observed without pending req: pa=0x%07h pgflt=%0b deny=%0b",
              vif.monitor_cb.mmu_ifu_pa,
              vif.monitor_cb.mmu_ifu_pgflt,
              vif.monitor_cb.mmu_ifu_deny))
        end else begin
          rsp_tr         = ifu_txn::type_id::create("ifu_rsp_mon");
          rsp_tr.pavld   = 1'b1;
          // Keep all response fields in the same sampling domain (monitor_cb)
          // to avoid mixed-time snapshots on combinational outputs.
          rsp_tr.pa      = vif.monitor_cb.mmu_ifu_pa;
          rsp_tr.pgflt   = vif.monitor_cb.mmu_ifu_pgflt;
          rsp_tr.deny    = vif.monitor_cb.mmu_ifu_deny;
          rsp_tr.sec     = vif.monitor_cb.mmu_ifu_sec;
          rsp_tr.ca      = vif.monitor_cb.mmu_ifu_ca;
          rsp_tr.buf_bit = vif.monitor_cb.mmu_ifu_buf;
          rsp_tr.va      = m_pending_req.va;
          rsp_tr.abort   = m_pending_req.abort;
          `uvm_info(get_type_name(),
            $sformatf("[IFU_MON_RSP_DBG] bind rsp: pending_va=0x%010h cur_va=0x%010h pa=0x%07h pavld=%0b pgflt=%0b deny=%0b",
              {1'b0, m_pending_req.va[38:0]}, {1'b0, cur_va[38:0]}, rsp_tr.pa,
              vif.monitor_cb.mmu_ifu_pavld, rsp_tr.pgflt, rsp_tr.deny),
            UVM_DEBUG)
          m_has_pending  = 1'b0;
          `uvm_info(get_type_name(), {"IFU RSP: ", rsp_tr.convert2string()}, UVM_HIGH)
          ap_rsp.write(rsp_tr);
        end
      end

      // Protocol sanity: VA should stay stable while request is outstanding
      // and before response returns.
      if (m_has_pending && vif.monitor_cb.ifu_mmu_va_vld &&
          !vif.monitor_cb.mmu_ifu_pavld && (cur_va !== m_pending_req.va)) begin
        `uvm_error(get_type_name(),
          $sformatf("[IFU_HOLD_PROTOCOL] VA changed before rsp: pending_va=0x%010h cur_va=0x%010h",
            {1'b0, m_pending_req.va[38:0]}, {1'b0, cur_va[38:0]}))
      end

      // If request disappears without a response:
      // - abort req: close immediately (expected cancel path)
      // - non-abort req: treat as monitor-visible drop (e.g. driver timeout),
      //   close with warning and publish ap_drop for credit compensation.
      if (m_has_pending && !vif.monitor_cb.ifu_mmu_va_vld) begin
        if (m_pending_req.abort) begin
          ifu_txn drop_tr;
          drop_tr       = ifu_txn::type_id::create("ifu_drop_mon");
          drop_tr.va    = m_pending_req.va;
          drop_tr.abort = m_pending_req.abort;
          // Abort request is allowed to terminate without pavld.
          `uvm_info(get_type_name(),
            $sformatf("IFU abort req closed on va_vld deassert: va=0x%010h",
              {1'b0, m_pending_req.va[38:0]}), UVM_MEDIUM)
          m_has_pending = 1'b0;
          ap_drop.write(drop_tr);
        end else begin
          ifu_txn drop_tr;
          drop_tr       = ifu_txn::type_id::create("ifu_drop_mon");
          drop_tr.va    = m_pending_req.va;
          drop_tr.abort = m_pending_req.abort;
          `uvm_warning(get_type_name(),
            $sformatf("[IFU_REQ_DROP] non-abort pending req closed before rsp (likely timeout/retry): pending_va=0x%010h cur_va=0x%010h pavld=%0b pa=0x%07h",
              {1'b0, m_pending_req.va[38:0]}, {1'b0, cur_va[38:0]},
              vif.monitor_cb.mmu_ifu_pavld, vif.monitor_cb.mmu_ifu_pa))
          // Clear local pending and emit drop so downstream credit scoreboard
          // can compensate req-without-rsp accounting.
          m_has_pending = 1'b0;
          ap_drop.write(drop_tr);
        end
      end

    end
  endtask

endclass : ifu_monitor

`endif // IFU_MONITOR_SVH
