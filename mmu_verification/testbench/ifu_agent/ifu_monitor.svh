// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_monitor.svh
// Phase 3 (Engineer B): IFU monitor skeleton
// Observes IFU↔MMU interface; publishes req/rsp/drop analysis events.
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
  // After a response, the request bus may remain HIGH for one or more sampled
  // cycles before it deasserts or turns over to a new VA. Suppress reopen
  // while the retiring request signature is still visible on the bus.
  protected bit     m_rsp_tail_hold;
  protected va_t    m_rsp_tail_va;
  protected bit     m_rsp_tail_abort;
  // After a non-abort drop, block reopen for two sampled cycles so a late
  // response from the dropped transaction cannot be rebound onto a retry.
  protected int unsigned m_drop_reopen_block;
  protected va_t         m_drop_reopen_va;
  protected bit          m_drop_reopen_abort;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_has_pending    = 1'b0;
    m_rsp_tail_hold  = 1'b0;
    m_rsp_tail_va    = '0;
    m_rsp_tail_abort = 1'b0;
    m_drop_reopen_block = 0;
    m_drop_reopen_va    = '0;
    m_drop_reopen_abort = 1'b0;
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
  // One request can be outstanding at a time. Responses are consumed against
  // the currently pending request; after completion, the monitor suppresses
  // any reopen while the bus is still showing the retiring request signature.
  // This avoids tail-cycle duplicate opens when the driver or DUT deasserts
  // ifu_mmu_va_vld one sampled cycle after pavld.
  //
  // Ordering each cycle:
  //   1. Release any post-rsp holdoff once req deasserts or turns over.
  //   2. Honor any post-drop reopen barrier before accepting a retry.
  //   3. Open new request if the bus shows a true new request and we are idle.
  //   4. Consume pavld (same-cycle hit remains legal: open first, then rsp).
  //   5. If req disappears without rsp, emit ap_drop for compensation.
  protected task _collect();
    ifu_txn req_tr, rsp_tr, drop_tr;
    va_t cur_va;
    bit  req_seen;
    bit  rsp_seen;
    bit  cur_abort;
    bit  drop_blocks_reopen;
    bit  hold_blocks_reopen;
    forever begin
      @(vif.monitor_cb);

      if (vif.rst_ni !== 1'b1) begin
        m_has_pending    = 1'b0;
        m_rsp_tail_hold  = 1'b0;
        m_rsp_tail_va    = '0;
        m_rsp_tail_abort = 1'b0;
        m_drop_reopen_block = 0;
        m_drop_reopen_va    = '0;
        m_drop_reopen_abort = 1'b0;
        continue;
      end

      // ifu_mmu_va is VA[63:1] on interface, restore byte-address form VA[63:0].
      cur_va    = va_t'({vif.monitor_cb.ifu_mmu_va, 1'b0});
      req_seen  = (vif.monitor_cb.ifu_mmu_va_vld === 1'b1);
      rsp_seen  = (vif.monitor_cb.mmu_ifu_pavld  === 1'b1);
      cur_abort = (vif.monitor_cb.ifu_mmu_abort  === 1'b1);

      // 1) Clear the post-rsp holdoff once the retiring request disappears or
      //    the bus turns over to a new request signature.
      if (m_rsp_tail_hold) begin
        if (!req_seen) begin
          m_rsp_tail_hold = 1'b0;
        end else if ((cur_va !== m_rsp_tail_va) || (cur_abort !== m_rsp_tail_abort)) begin
          `uvm_info(get_type_name(),
            $sformatf("[IFU_MON_REQ_TURNOVER] retired_va=0x%010h cur_va=0x%010h retired_abort=%0b cur_abort=%0b",
              {1'b0, m_rsp_tail_va[38:0]}, {1'b0, cur_va[38:0]},
              m_rsp_tail_abort, cur_abort),
            UVM_DEBUG)
          m_rsp_tail_hold = 1'b0;
        end
      end

      drop_blocks_reopen = (m_drop_reopen_block != 0);
      hold_blocks_reopen = m_rsp_tail_hold
                        && req_seen
                        && (cur_va === m_rsp_tail_va)
                        && (cur_abort === m_rsp_tail_abort);
      hold_blocks_reopen = hold_blocks_reopen || drop_blocks_reopen;

      // 2/3) Open request whenever the bus is presenting a true new request and
      //    we have no outstanding req. Same-cycle req+rsp hits remain legal.
      if (req_seen && !m_has_pending && !hold_blocks_reopen) begin
        req_tr       = ifu_txn::type_id::create("ifu_req_mon");
        req_tr.va    = cur_va;
        req_tr.abort = cur_abort;
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

      // 3) Consume response.
      if (rsp_seen) begin
        if (!m_has_pending) begin
          if (drop_blocks_reopen) begin
            `uvm_warning(get_type_name(),
              $sformatf("[IFU_LATE_RSP_AFTER_DROP] ignore rsp during drop barrier: dropped_va=0x%010h cur_va=0x%010h dropped_abort=%0b cur_abort=%0b pa=0x%07h pgflt=%0b deny=%0b",
                {1'b0, m_drop_reopen_va[38:0]}, {1'b0, cur_va[38:0]},
                m_drop_reopen_abort, cur_abort,
                vif.monitor_cb.mmu_ifu_pa,
                vif.monitor_cb.mmu_ifu_pgflt,
                vif.monitor_cb.mmu_ifu_deny))
            m_drop_reopen_block = 0;
            m_drop_reopen_va    = '0;
            m_drop_reopen_abort = 1'b0;
          end else begin
            `uvm_warning(get_type_name(),
              $sformatf("IFU rsp observed without pending req: pa=0x%07h pgflt=%0b deny=%0b",
                vif.monitor_cb.mmu_ifu_pa,
                vif.monitor_cb.mmu_ifu_pgflt,
                vif.monitor_cb.mmu_ifu_deny))
          end
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
          rsp_tr.dbg_iutlb_acc_flt = vif.monitor_cb.dbg_iutlb_acc_flt;
          rsp_tr.dbg_iutlb_pmp_deny = vif.monitor_cb.dbg_iutlb_pmp_deny;
          rsp_tr.dbg_iutlb_ref_pgflt = vif.monitor_cb.dbg_iutlb_ref_pgflt;
          rsp_tr.dbg_jtlb_acc_fault_flop = vif.monitor_cb.dbg_jtlb_acc_fault_flop;
          rsp_tr.va      = m_pending_req.va;
          rsp_tr.abort   = m_pending_req.abort;
          `uvm_info(get_type_name(),
            $sformatf("[IFU_MON_RSP_DBG] bind rsp: pending_va=0x%010h cur_va=0x%010h pa=0x%07h pavld=%0b pgflt=%0b deny=%0b dbg_pmp_deny=%0b dbg_accerr=%0b dbg_ref_pgflt=%0b dbg_jtlb_accflt_flop=%0b",
              {1'b0, m_pending_req.va[38:0]}, {1'b0, cur_va[38:0]}, rsp_tr.pa,
              vif.monitor_cb.mmu_ifu_pavld, rsp_tr.pgflt, rsp_tr.deny,
              rsp_tr.dbg_iutlb_pmp_deny, rsp_tr.dbg_iutlb_acc_flt,
              rsp_tr.dbg_iutlb_ref_pgflt,
              rsp_tr.dbg_jtlb_acc_fault_flop),
            UVM_DEBUG)
          m_rsp_tail_hold  = req_seen;
          m_rsp_tail_va    = m_pending_req.va;
          m_rsp_tail_abort = m_pending_req.abort;
          m_has_pending    = 1'b0;
          `uvm_info(get_type_name(), {"IFU RSP: ", rsp_tr.convert2string()}, UVM_HIGH)
          ap_rsp.write(rsp_tr);
        end
      end

      // Protocol sanity: VA should stay stable while request is outstanding
      // and before response returns.
      if (m_has_pending && req_seen && !rsp_seen &&
          ((cur_va !== m_pending_req.va) || (cur_abort !== m_pending_req.abort))) begin
        `uvm_error(get_type_name(),
          $sformatf("[IFU_HOLD_PROTOCOL] req changed before rsp: pending_va=0x%010h cur_va=0x%010h pending_abort=%0b cur_abort=%0b",
            {1'b0, m_pending_req.va[38:0]}, {1'b0, cur_va[38:0]},
            m_pending_req.abort, cur_abort))
      end

      // If request disappears without a response:
      // - abort req: close immediately (expected cancel path)
      // - non-abort req: treat as monitor-visible drop (e.g. driver timeout),
      //   close with warning and publish ap_drop for credit compensation.
      if (!rsp_seen && m_has_pending && !req_seen) begin
        if (m_pending_req.abort) begin
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
          drop_tr       = ifu_txn::type_id::create("ifu_drop_mon");
          drop_tr.va    = m_pending_req.va;
          drop_tr.abort = m_pending_req.abort;
          `uvm_warning(get_type_name(),
            $sformatf("[IFU_REQ_DROP] non-abort pending req closed before rsp (likely timeout/retry): pending_va=0x%010h cur_va=0x%010h pavld=%0b pa=0x%07h",
              {1'b0, m_pending_req.va[38:0]}, {1'b0, cur_va[38:0]},
              vif.monitor_cb.mmu_ifu_pavld, vif.monitor_cb.mmu_ifu_pa))
          // Clear local pending and emit drop so downstream credit scoreboard
          // can compensate req-without-rsp accounting. Hold reopen long enough
          // to absorb a near-tail late rsp before rebinding any retry.
          m_has_pending       = 1'b0;
          m_drop_reopen_block = 2;
          m_drop_reopen_va    = drop_tr.va;
          m_drop_reopen_abort = drop_tr.abort;
          ap_drop.write(drop_tr);
        end
      end

      if (drop_blocks_reopen && (m_drop_reopen_block != 0)) begin
        m_drop_reopen_block--;
        if (m_drop_reopen_block == 0) begin
          m_drop_reopen_va    = '0;
          m_drop_reopen_abort = 1'b0;
        end
      end

    end
  endtask

endclass : ifu_monitor

`endif // IFU_MONITOR_SVH
