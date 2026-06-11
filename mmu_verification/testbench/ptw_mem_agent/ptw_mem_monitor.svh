// =============================================================================
// MMU UVM Verification - testbench/ptw_mem_agent/ptw_mem_monitor.svh
// PTW memory channel monitor
//
// Observes both the DUT-initiated request and the TB-driven response:
//   ap_req:  fires when LSU accepts a PTW read (req&&grant)
//   ap_rsp:  fires when LSU returns data_vld or bus_error, matched by rsp_id
//   ap_drop: fires when reset clears pending requests or a held, ungranted
//            request is cancelled before it becomes outstanding
//
// Downstream consumers (connected in Phase 5 env.connect_phase):
//   ap_req  → credit_sb.af_ptw_req, perf.af_ptw_req
//   ap_rsp  → credit_sb.af_ptw_rsp, perf.af_ptw_rsp
//   ap_drop → credit_sb.af_ptw_drop
// =============================================================================
`ifndef PTW_MEM_MONITOR_SVH
`define PTW_MEM_MONITOR_SVH

class ptw_mem_monitor extends uvm_monitor;

  `uvm_component_utils(ptw_mem_monitor)

  virtual ptw_mem_if vif;
  virtual mmu_dut_probes_if v_probe;

  // Analysis ports
  uvm_analysis_port #(ptw_mem_txn) ap_req;   // DUT request (addr)
  uvm_analysis_port #(ptw_mem_txn) ap_rsp;   // TB response (PTE data / bus_error)
  uvm_analysis_port #(ptw_mem_txn) ap_drop;  // Pending req cancelled by reset

  protected ptw_mem_txn m_pending_by_id[16];
  protected bit         m_has_pending_by_id[16];
  protected bit         m_pending_abort_by_id[16];
  protected bit         m_pending_req_dropped_by_id[16];

  protected bit         m_hold_active;
  protected bit [39:0]  m_hold_addr;
  protected bit         m_hold_size;
  protected bit [3:0]   m_hold_id;
  protected int unsigned m_hold_wait_cycles;
  protected bit         m_hold_abort_seen;

  protected int unsigned m_cycle;
  protected int unsigned m_accept_order_next;
  protected int unsigned m_response_order_next;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    foreach (m_has_pending_by_id[i]) begin
      m_has_pending_by_id[i] = 1'b0;
      m_pending_abort_by_id[i] = 1'b0;
      m_pending_req_dropped_by_id[i] = 1'b0;
      m_pending_by_id[i] = null;
    end
    m_hold_active = 1'b0;
    m_hold_wait_cycles = 0;
    m_hold_abort_seen = 1'b0;
    m_cycle = 0;
    m_accept_order_next = 0;
    m_response_order_next = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ptw_mem_if)::get(this, "", "PTW_MEM_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get PTW_MEM_VIF from config_db")
    if (!uvm_config_db #(virtual mmu_dut_probes_if)::get(this, "", "MMU_DUT_PROBES_VIF", v_probe)) begin
      `uvm_info(get_type_name(),
        "MMU_DUT_PROBES_VIF unavailable; abort-drain response annotation disabled",
        UVM_LOW)
    end
    ap_req = new("ap_req", this);
    ap_rsp = new("ap_rsp", this);
    ap_drop = new("ap_drop", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    // Wait for reset
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    collect_channel();
  endtask

  protected function bit _is_legal_id(bit [3:0] id);
    return (id <= 4'd8);
  endfunction

  protected function bit _abort_or_drain_seen();
    if (v_probe == null)
      return 1'b0;
    return (v_probe.tlboper_ptw_abort === 1'b1)
        || (v_probe.ptw_abort_flop === 1'b1)
        || (v_probe.ptw_abort_drain === 1'b1);
  endfunction

  protected function void _mark_abort_for_pending();
    if (!_abort_or_drain_seen())
      return;
    foreach (m_has_pending_by_id[i]) begin
      if (m_has_pending_by_id[i])
        m_pending_abort_by_id[i] = 1'b1;
    end
    if (m_hold_active)
      m_hold_abort_seen = 1'b1;
  endfunction

  protected function void _clear_hold();
    m_hold_active = 1'b0;
    m_hold_wait_cycles = 0;
    m_hold_abort_seen = 1'b0;
  endfunction

  protected function void _publish_pending_drop(int unsigned id, string reason);
    ptw_mem_txn drop_tr;

    if ((id >= 16) || !m_has_pending_by_id[id])
      return;

    drop_tr = ptw_mem_txn::type_id::create($sformatf("ptw_%s_drop_id%0d", reason, id));
    drop_tr.copy(m_pending_by_id[id]);
    drop_tr.rsp_valid = 1'b0;
    drop_tr.abort_drain_rsp = m_pending_abort_by_id[id];
    `uvm_info(get_type_name(),
      $sformatf("[PTW_REQ_%s_DROP] pending req cleared: %s",
        reason, drop_tr.convert2string()),
      UVM_MEDIUM)
    ap_drop.write(drop_tr);
    m_has_pending_by_id[id] = 1'b0;
    m_pending_abort_by_id[id] = 1'b0;
    m_pending_req_dropped_by_id[id] = 1'b0;
    m_pending_by_id[id] = null;
  endfunction

  protected function void _publish_reset_drops();
    foreach (m_has_pending_by_id[i]) begin
      if (m_has_pending_by_id[i])
        _publish_pending_drop(i, "RESET");
    end
    if (m_hold_active) begin
      ptw_mem_txn drop_tr;

      drop_tr = ptw_mem_txn::type_id::create("ptw_reset_held_drop");
      drop_tr.addr = m_hold_addr;
      drop_tr.req_size = m_hold_size;
      drop_tr.req_id = m_hold_id;
      drop_tr.req_fire = 1'b0;
      drop_tr.aborted_before_grant = 1'b1;
      drop_tr.grant_wait_cycles = m_hold_wait_cycles;
      `uvm_info(get_type_name(),
        $sformatf("[PTW_REQ_RESET_DROP] held req cleared before grant: %s",
          drop_tr.convert2string()),
        UVM_MEDIUM)
      ap_drop.write(drop_tr);
    end
    _clear_hold();
  endfunction

  protected function void _handle_response();
    ptw_mem_txn tr;
    bit [3:0] rsp_id;

    rsp_id = vif.monitor_cb.lsu_mmu_data_id;
    tr = ptw_mem_txn::type_id::create("ptw_rsp");

    if (_is_legal_id(rsp_id) && m_has_pending_by_id[rsp_id]) begin
      tr.copy(m_pending_by_id[rsp_id]);
      tr.abort_drain_rsp = m_pending_abort_by_id[rsp_id];
      m_has_pending_by_id[rsp_id] = 1'b0;
      m_pending_abort_by_id[rsp_id] = 1'b0;
      m_pending_req_dropped_by_id[rsp_id] = 1'b0;
      m_pending_by_id[rsp_id] = null;
    end

    tr.pte_data  = vif.monitor_cb.lsu_mmu_data;
    tr.bus_error = vif.monitor_cb.lsu_mmu_bus_error;
    tr.rsp_valid = 1'b1;
    tr.rsp_id    = rsp_id;
    tr.rsp_id_invalid = !_is_legal_id(rsp_id);
    m_response_order_next++;
    tr.response_order = m_response_order_next;

    if (tr.rsp_id_invalid) begin
      tr.rsp_order = PTW_RSP_INVALID_ID;
      tr.rsp_kind = tr.bus_error ? PTW_RSP_BUS_ERR : PTW_RSP_NORMAL;
      `uvm_warning(get_type_name(),
        $sformatf("PTW response has invalid rsp_id=0x%0h: %s",
          rsp_id, tr.convert2string()))
    end else if (tr.req_fire !== 1'b1) begin
      tr.rsp_without_pending = 1'b1;
      tr.req_id = rsp_id;
      tr.rsp_order = tr.bus_error ? PTW_RSP_BUS_ERR_BY_ID : PTW_RSP_IN_ORDER;
      tr.rsp_kind = tr.bus_error ? PTW_RSP_BUS_ERR : PTW_RSP_NORMAL;
      `uvm_error(get_type_name(),
        $sformatf("PTW legal response without matching pending request: %s",
          tr.convert2string()))
    end else begin
      tr.rsp_is_ooo = (tr.response_order != tr.accept_order);
      if (tr.bus_error) begin
        tr.rsp_order = PTW_RSP_BUS_ERR_BY_ID;
        tr.rsp_kind = PTW_RSP_BUS_ERR;
      end else if (tr.rsp_is_ooo) begin
        tr.rsp_order = PTW_RSP_BY_ID_OOO;
        tr.rsp_kind = PTW_RSP_OOO;
      end else begin
        tr.rsp_order = PTW_RSP_IN_ORDER;
        tr.rsp_kind = PTW_RSP_NORMAL;
      end
    end

    `uvm_info(get_type_name(),
      $sformatf("PTW RSP: %s", tr.convert2string()),
      UVM_HIGH)
    ap_rsp.write(tr);
  endfunction

  protected function void _handle_request_fire(
    bit [39:0] cur_addr,
    bit        cur_size,
    bit [3:0]  cur_id
  );
    ptw_mem_txn tr;
    bit duplicate_id;
    bit legal_id;
    int unsigned grant_wait;

    legal_id = _is_legal_id(cur_id);
    duplicate_id = legal_id && m_has_pending_by_id[cur_id];
    grant_wait = 0;

    if (m_hold_active) begin
      grant_wait = m_hold_wait_cycles;
      if ((cur_addr !== m_hold_addr) || (cur_size !== m_hold_size)
          || (cur_id !== m_hold_id)) begin
        `uvm_error(get_type_name(),
          $sformatf("PTW held request changed before grant: old={addr=0x%010h size=%0b id=0x%0h} new={addr=0x%010h size=%0b id=0x%0h}",
            m_hold_addr, m_hold_size, m_hold_id, cur_addr, cur_size, cur_id))
      end
    end

    tr = ptw_mem_txn::type_id::create("ptw_req");
    tr.addr = cur_addr;
    tr.req_size = cur_size;
    tr.req_id = cur_id;
    tr.req_fire = 1'b1;
    tr.req_cycle = m_cycle;
    tr.grant_wait_cycles = grant_wait;
    tr.duplicate_id_error = duplicate_id;
    m_accept_order_next++;
    tr.accept_order = m_accept_order_next;
    tr.grant_mode = (grant_wait == 0) ? PTW_GRANT_ALWAYS_READY : PTW_GRANT_DELAY_FIXED;

    if (!legal_id) begin
      `uvm_error(get_type_name(),
        $sformatf("PTW request fire has illegal req_id=0x%0h: %s",
          cur_id, tr.convert2string()))
    end else if (duplicate_id) begin
      `uvm_error(get_type_name(),
        $sformatf("PTW duplicate outstanding request ID: id=0x%0h old={%s} new={%s}",
          cur_id, m_pending_by_id[cur_id].convert2string(), tr.convert2string()))
    end else begin
      m_pending_by_id[cur_id] = ptw_mem_txn::type_id::create(
        $sformatf("ptw_pending_id%0d", cur_id));
      m_pending_by_id[cur_id].copy(tr);
      m_has_pending_by_id[cur_id] = 1'b1;
      m_pending_abort_by_id[cur_id] = m_hold_abort_seen || _abort_or_drain_seen();
      m_pending_req_dropped_by_id[cur_id] = 1'b0;
    end

    `uvm_info(get_type_name(),
      $sformatf("PTW REQ ACCEPT: %s", tr.convert2string()),
      UVM_HIGH)
    ap_req.write(tr);
    _clear_hold();
  endfunction

  protected function void _handle_request_hold(
    bit [39:0] cur_addr,
    bit        cur_size,
    bit [3:0]  cur_id
  );
    if (!m_hold_active) begin
      m_hold_active = 1'b1;
      m_hold_addr = cur_addr;
      m_hold_size = cur_size;
      m_hold_id = cur_id;
      m_hold_wait_cycles = 1;
      m_hold_abort_seen = _abort_or_drain_seen();
      return;
    end

    if ((cur_addr !== m_hold_addr) || (cur_size !== m_hold_size)
        || (cur_id !== m_hold_id)) begin
      `uvm_error(get_type_name(),
        $sformatf("PTW request changed while grant was low: old={addr=0x%010h size=%0b id=0x%0h} new={addr=0x%010h size=%0b id=0x%0h}",
          m_hold_addr, m_hold_size, m_hold_id, cur_addr, cur_size, cur_id))
    end
    m_hold_wait_cycles++;
    m_hold_abort_seen |= _abort_or_drain_seen();
  endfunction

  protected function void _publish_held_cancel();
    ptw_mem_txn drop_tr;

    if (!m_hold_active)
      return;

    drop_tr = ptw_mem_txn::type_id::create("ptw_held_cancel_drop");
    drop_tr.addr = m_hold_addr;
    drop_tr.req_size = m_hold_size;
    drop_tr.req_id = m_hold_id;
    drop_tr.req_fire = 1'b0;
    drop_tr.req_cycle = m_cycle;
    drop_tr.grant_wait_cycles = m_hold_wait_cycles;
    drop_tr.aborted_before_grant = 1'b1;
    `uvm_info(get_type_name(),
      $sformatf("[PTW_REQ_ABORT_BEFORE_GRANT] held req cancelled before grant: %s",
        drop_tr.convert2string()),
      UVM_MEDIUM)
    ap_drop.write(drop_tr);
    _clear_hold();
  endfunction

  // Cycle-accurate ID-aware collector.  Response is processed before request
  // fire so a same-cycle response and new request on the same ID retires the
  // old pending entry before checking the new allocation.
  protected task collect_channel();
    forever begin
      bit         req_seen;
      bit         accept_seen;
      bit         rsp_seen;
      bit [39:0]  cur_addr;
      bit [3:0]   cur_id;
      bit         cur_size;

      @(vif.monitor_cb);
      m_cycle++;

      if (vif.rst_ni !== 1'b1) begin
        _publish_reset_drops();
        continue;
      end

      _mark_abort_for_pending();

      req_seen = (vif.monitor_cb.mmu_lsu_data_req  === 1'b1);
      accept_seen = (vif.monitor_cb.mmu_lsu_data_req_fire === 1'b1);
      rsp_seen = (vif.monitor_cb.lsu_mmu_data_vld  === 1'b1) ||
                 (vif.monitor_cb.lsu_mmu_bus_error === 1'b1);
      cur_addr = vif.monitor_cb.mmu_lsu_data_req_addr;
      cur_id = vif.monitor_cb.mmu_lsu_data_req_id;
      cur_size = vif.monitor_cb.mmu_lsu_data_req_size;

      if (rsp_seen)
        _handle_response();

      if (accept_seen) begin
        _handle_request_fire(cur_addr, cur_size, cur_id);
      end else if (req_seen && (vif.monitor_cb.lsu_mmu_data_req_grant !== 1'b1)) begin
        _handle_request_hold(cur_addr, cur_size, cur_id);
      end else if (!req_seen) begin
        _publish_held_cancel();
      end

      foreach (m_has_pending_by_id[i]) begin
        if (m_has_pending_by_id[i] && !m_pending_req_dropped_by_id[i]
            && !req_seen && !rsp_seen) begin
          m_pending_req_dropped_by_id[i] = 1'b1;
          `uvm_info(get_type_name(),
            $sformatf(
              "[PTW_REQ_ABORT_LATE_RSP] pending req no longer visible; keep waiting for accepted rsp: %s",
              m_pending_by_id[i].convert2string()),
            UVM_MEDIUM)
        end
      end
    end
  endtask

endclass : ptw_mem_monitor

`endif // PTW_MEM_MONITOR_SVH
