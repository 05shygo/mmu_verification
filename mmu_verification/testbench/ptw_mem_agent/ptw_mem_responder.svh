// =============================================================================
// MMU UVM Verification - testbench/ptw_mem_agent/ptw_mem_responder.svh
// PTW memory channel responder
//
// The responder models the LSU side of the PTW PTE load channel:
//   - grant/accept is controlled by lsu_mmu_data_req_grant
//   - accepted requests are tracked by mmu_lsu_data_req_id
//   - responses return lsu_mmu_data_id and may complete out of order when
//     directed by a test
//
// Phase3 replaces the previous single-slot blocking responder with an
// ID-indexed outstanding table.  The monitor and downstream scoreboards are
// advanced in later phases, so this class keeps the existing directed-control
// API names while adding the new ID/grant/order controls.
// =============================================================================
`ifndef PTW_MEM_RESPONDER_SVH
`define PTW_MEM_RESPONDER_SVH

class ptw_mem_responder extends uvm_component;

  `uvm_component_utils(ptw_mem_responder)

  typedef struct {
    bit              valid;
    bit [3:0]        id;
    bit [39:0]       addr;
    bit              size;
    bit [63:0]       pte;
    bit              bus_error;
    int unsigned     accept_order;
    int unsigned     target_rsp_cycle;
    int unsigned     grant_wait_cycles;
    int              delay;
    bit              abort_seen_after_accept;
  } ptw_outstanding_s;

  virtual ptw_mem_if vif;
  virtual mmu_dut_probes_if v_probe;
  page_table_builder m_pt;

  // Public legacy knobs used directly by existing virtual sequences.
  int unsigned m_rsp_delay_min           = 1;
  int unsigned m_rsp_delay_max           = 8;
  int unsigned m_bus_error_rate_permille = 0;

  protected int unsigned m_forced_delay_by_addr [longint unsigned];
  protected int unsigned m_forced_delay_by_count [int unsigned];
  protected int unsigned m_forced_delay_by_id [int unsigned];
  protected int unsigned m_forced_grant_delay_by_count [int unsigned];
  protected int unsigned m_forced_grant_delay_by_id [int unsigned];
  protected bit          m_forced_bus_error_by_addr [longint unsigned];
  protected bit          m_forced_bus_error_by_count [int unsigned];
  protected bit          m_forced_bus_error_by_id [int unsigned];
  protected bit          m_same_cycle_abort_data_by_count [int unsigned];
  protected bit          m_same_cycle_abort_bus_error_by_count [int unsigned];
  protected int unsigned m_chk_not_ready_slow_cycles;

  protected ptw_rsp_order_e m_response_order_mode;
  protected ptw_grant_mode_e m_grant_mode;
  protected int unsigned m_max_outstanding;

  protected bit          m_force_next_response_id_valid;
  protected bit [3:0]    m_force_next_response_id;
  protected bit          m_force_invalid_response_id_valid;
  protected bit [3:0]    m_force_invalid_response_id;

  protected ptw_outstanding_s m_outstanding_by_id[16];
  protected int unsigned      m_legal_outstanding_count;
  protected int unsigned      m_accept_count;
  protected int unsigned      m_response_count;

  // Legacy/debug counters and state names retained for timeout diagnostics.
  protected int unsigned m_rsp_count;
  protected int unsigned m_buserr_count;
  protected bit          m_active_req;
  protected time         m_active_start_time;
  protected bit [39:0]   m_active_addr;
  protected bit          m_active_size;
  protected bit [3:0]    m_active_id;
  protected bit [63:0]   m_active_pte;
  protected int          m_active_delay;
  protected time         m_last_accept_time;
  protected bit [39:0]   m_last_accept_addr;
  protected bit          m_last_accept_size;
  protected bit [3:0]    m_last_accept_id;
  protected string       m_last_accept_ctx;
  protected time         m_last_rsp_time;
  protected bit [39:0]   m_last_rsp_addr;
  protected bit          m_last_rsp_size;
  protected bit [3:0]    m_last_rsp_id;
  protected bit [63:0]   m_last_rsp_pte;
  protected int          m_last_rsp_delay;
  protected time         m_last_buserr_time;
  protected bit [39:0]   m_last_buserr_addr;
  protected bit          m_last_buserr_size;
  protected bit [3:0]    m_last_buserr_id;
  protected bit          m_trace_enabled;

  protected int unsigned m_cycle;
  protected bit          m_hold_active;
  protected bit [39:0]   m_hold_addr;
  protected bit          m_hold_size;
  protected bit [3:0]    m_hold_id;
  protected int unsigned m_hold_accept_count;
  protected int unsigned m_hold_grant_wait_remaining;
  protected int unsigned m_hold_wait_cycles;
  protected bit          m_hold_drop_logged;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_response_order_mode = PTW_RSP_IN_ORDER;
    m_grant_mode = PTW_GRANT_ALWAYS_READY;
    m_max_outstanding = 9;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ptw_mem_if)::get(this, "", "PTW_MEM_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get PTW_MEM_VIF from config_db")
    if (!uvm_config_db #(virtual mmu_dut_probes_if)::get(this, "", "MMU_DUT_PROBES_VIF", v_probe)) begin
      `uvm_info(get_type_name(),
        "MMU_DUT_PROBES_VIF unavailable; accepted-after-abort annotation disabled",
        UVM_LOW)
    end
    m_trace_enabled = $test$plusargs("PTW_RESP_TRACE");
  endfunction

  virtual function void set_page_table(page_table_builder pt);
    m_pt = pt;
  endfunction

  virtual function void clear_directed_controls();
    m_forced_delay_by_addr.delete();
    m_forced_delay_by_count.delete();
    m_forced_delay_by_id.delete();
    m_forced_grant_delay_by_count.delete();
    m_forced_grant_delay_by_id.delete();
    m_forced_bus_error_by_addr.delete();
    m_forced_bus_error_by_count.delete();
    m_forced_bus_error_by_id.delete();
    m_same_cycle_abort_data_by_count.delete();
    m_same_cycle_abort_bus_error_by_count.delete();
    m_chk_not_ready_slow_cycles = 0;
    m_bus_error_rate_permille = 0;
    m_response_order_mode = PTW_RSP_IN_ORDER;
    m_grant_mode = PTW_GRANT_ALWAYS_READY;
    m_max_outstanding = 9;
    m_force_next_response_id_valid = 1'b0;
    m_force_invalid_response_id_valid = 1'b0;
    m_accept_count = 0;
    m_response_count = 0;
    m_rsp_count = 0;
    m_buserr_count = 0;
    `uvm_info(get_type_name(), "PTW responder directed controls cleared", UVM_MEDIUM)
  endfunction

  virtual function void set_delay_range(int unsigned min_delay, int unsigned max_delay);
    if (max_delay < min_delay)
      max_delay = min_delay;
    m_rsp_delay_min = min_delay;
    m_rsp_delay_max = max_delay;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder delay range set to [%0d:%0d]", min_delay, max_delay),
      UVM_MEDIUM)
  endfunction

  virtual function void set_delay_for_addr(bit [39:0] addr, int unsigned delay);
    m_forced_delay_by_addr[longint'(addr)] = delay;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder forced response delay by addr: addr=0x%010h delay=%0d",
        addr, delay),
      UVM_MEDIUM)
  endfunction

  virtual function void set_delay_for_count(int unsigned count, int unsigned delay);
    if (count == 0) begin
      `uvm_warning(get_type_name(), "set_delay_for_count ignored count=0; accept counts start at 1")
      return;
    end
    m_forced_delay_by_count[count] = delay;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder forced response delay by count: count=%0d delay=%0d",
        count, delay),
      UVM_MEDIUM)
  endfunction

  virtual function void set_delay_for_id(bit [3:0] id, int unsigned delay);
    if (id > 4'd8) begin
      `uvm_warning(get_type_name(),
        $sformatf("set_delay_for_id ignored illegal PTW request id=0x%0h", id))
      return;
    end
    m_forced_delay_by_id[int'(id)] = delay;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder forced response delay by id: id=0x%0h delay=%0d",
        id, delay),
      UVM_MEDIUM)
  endfunction

  virtual function void set_grant_delay_for_count(int unsigned count, int unsigned cycles);
    if (count == 0) begin
      `uvm_warning(get_type_name(), "set_grant_delay_for_count ignored count=0; accept counts start at 1")
      return;
    end
    m_forced_grant_delay_by_count[count] = cycles;
    m_grant_mode = (cycles == 0) ? m_grant_mode : PTW_GRANT_DELAY_FIXED;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder forced grant delay by count: count=%0d cycles=%0d",
        count, cycles),
      UVM_MEDIUM)
  endfunction

  virtual function void set_grant_delay_for_id(bit [3:0] id, int unsigned cycles);
    if (id > 4'd8) begin
      `uvm_warning(get_type_name(),
        $sformatf("set_grant_delay_for_id ignored illegal PTW request id=0x%0h", id))
      return;
    end
    m_forced_grant_delay_by_id[int'(id)] = cycles;
    m_grant_mode = (cycles == 0) ? m_grant_mode : PTW_GRANT_DELAY_FIXED;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder forced grant delay by id: id=0x%0h cycles=%0d",
        id, cycles),
      UVM_MEDIUM)
  endfunction

  virtual function void set_bus_error_for_addr(bit [39:0] addr, bit enable = 1'b1);
    if (enable)
      m_forced_bus_error_by_addr[longint'(addr)] = 1'b1;
    else
      m_forced_bus_error_by_addr.delete(longint'(addr));
    `uvm_info(get_type_name(),
      $sformatf("PTW responder forced bus error by addr: addr=0x%010h enable=%0b",
        addr, enable),
      UVM_MEDIUM)
  endfunction

  virtual function void set_bus_error_for_count(int unsigned count, bit enable = 1'b1);
    if (count == 0) begin
      `uvm_warning(get_type_name(), "set_bus_error_for_count ignored count=0; accept counts start at 1")
      return;
    end
    if (enable)
      m_forced_bus_error_by_count[count] = 1'b1;
    else
      m_forced_bus_error_by_count.delete(count);
    `uvm_info(get_type_name(),
      $sformatf("PTW responder forced bus error by count: count=%0d enable=%0b",
        count, enable),
      UVM_MEDIUM)
  endfunction

  virtual function void set_bus_error_for_id(bit [3:0] id, bit enable = 1'b1);
    if (id > 4'd8) begin
      `uvm_warning(get_type_name(),
        $sformatf("set_bus_error_for_id ignored illegal PTW request id=0x%0h", id))
      return;
    end
    if (enable)
      m_forced_bus_error_by_id[int'(id)] = 1'b1;
    else
      m_forced_bus_error_by_id.delete(int'(id));
    `uvm_info(get_type_name(),
      $sformatf("PTW responder forced bus error by id: id=0x%0h enable=%0b",
        id, enable),
      UVM_MEDIUM)
  endfunction

  virtual function void set_response_order_mode(ptw_rsp_order_e mode);
    m_response_order_mode = mode;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder response order mode set to %s", mode.name()),
      UVM_MEDIUM)
  endfunction

  virtual function void force_next_response_id(bit [3:0] id);
    if (id > 4'd8) begin
      force_invalid_response_id(id);
      return;
    end
    m_force_next_response_id = id;
    m_force_next_response_id_valid = 1'b1;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder will force next legal response id=0x%0h", id),
      UVM_MEDIUM)
  endfunction

  virtual function void force_invalid_response_id(bit [3:0] id_9_to_15);
    if (id_9_to_15 < 4'd9) begin
      `uvm_warning(get_type_name(),
        $sformatf("force_invalid_response_id ignored legal id=0x%0h", id_9_to_15))
      return;
    end
    m_force_invalid_response_id = id_9_to_15;
    m_force_invalid_response_id_valid = 1'b1;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder will force invalid response id=0x%0h", id_9_to_15),
      UVM_MEDIUM)
  endfunction

  virtual function void set_max_outstanding(int unsigned depth);
    if (depth > 9)
      depth = 9;
    m_max_outstanding = depth;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder max outstanding set to %0d", m_max_outstanding),
      UVM_MEDIUM)
  endfunction

  virtual function void set_same_cycle_abort_data_for_count(int unsigned count);
    if (count == 0) begin
      `uvm_warning(get_type_name(), "set_same_cycle_abort_data_for_count ignored count=0")
      return;
    end
    m_same_cycle_abort_data_by_count[count] = 1'b1;
    m_forced_delay_by_count[count] = 0;
    m_forced_bus_error_by_count.delete(count);
    `uvm_info(get_type_name(),
      $sformatf("PTW responder same-cycle abort/data window registered for count=%0d",
        count),
      UVM_MEDIUM)
  endfunction

  virtual function void set_same_cycle_abort_bus_error_for_count(int unsigned count);
    if (count == 0) begin
      `uvm_warning(get_type_name(), "set_same_cycle_abort_bus_error_for_count ignored count=0")
      return;
    end
    m_same_cycle_abort_bus_error_by_count[count] = 1'b1;
    m_forced_delay_by_count[count] = 0;
    m_forced_bus_error_by_count[count] = 1'b1;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder same-cycle abort/bus-error window registered for count=%0d",
        count),
      UVM_MEDIUM)
  endfunction

  virtual function void set_chk_not_ready_slow_response(int unsigned delay_cycles);
    m_chk_not_ready_slow_cycles = delay_cycles;
    `uvm_info(get_type_name(),
      $sformatf("PTW responder CHK-not-ready slow-response delay set to %0d cycles",
        delay_cycles),
      UVM_MEDIUM)
  endfunction

  protected function bit _is_legal_id(bit [3:0] id);
    return (id <= 4'd8);
  endfunction

  protected function bit [63:0] _lookup_pte(bit [39:0] addr);
    if (m_pt != null)
      return 64'(m_pt.read_pte_at(pa_t'(addr)));
    `uvm_warning(get_type_name(),
      $sformatf("lookup_pte: m_pt is null, returning 0 for addr=0x%010h", addr))
    return 64'h0;
  endfunction

  protected function int _select_delay(bit [39:0] addr, bit [3:0] id, int unsigned accept_count);
    longint unsigned addr_key;
    int unsigned dmin;
    int unsigned dmax;

    addr_key = longint'(addr);
    if (m_forced_delay_by_count.exists(accept_count))
      return int'(m_forced_delay_by_count[accept_count]);
    if (m_forced_delay_by_id.exists(int'(id)))
      return int'(m_forced_delay_by_id[int'(id)]);
    if (m_forced_delay_by_addr.exists(addr_key))
      return int'(m_forced_delay_by_addr[addr_key]);
    if (m_chk_not_ready_slow_cycles != 0)
      return int'(m_chk_not_ready_slow_cycles);

    dmin = m_rsp_delay_min;
    dmax = (m_rsp_delay_max < dmin) ? dmin : m_rsp_delay_max;
    return int'($urandom_range(dmin, dmax));
  endfunction

  protected function bit _select_bus_error(bit [39:0] addr, bit [3:0] id, int unsigned accept_count);
    longint unsigned addr_key;

    addr_key = longint'(addr);
    if (m_forced_bus_error_by_count.exists(accept_count))
      return m_forced_bus_error_by_count[accept_count];
    if (m_forced_bus_error_by_id.exists(int'(id)))
      return m_forced_bus_error_by_id[int'(id)];
    if (m_forced_bus_error_by_addr.exists(addr_key))
      return m_forced_bus_error_by_addr[addr_key];
    return (m_bus_error_rate_permille > 0)
        && ($urandom_range(0, 999) < m_bus_error_rate_permille);
  endfunction

  protected function int unsigned _select_grant_delay(bit [3:0] id, int unsigned next_accept_count);
    int unsigned delay;

    delay = 0;
    if (m_forced_grant_delay_by_count.exists(next_accept_count)) begin
      delay = m_forced_grant_delay_by_count[next_accept_count];
      m_forced_grant_delay_by_count.delete(next_accept_count);
      return delay;
    end
    if (m_forced_grant_delay_by_id.exists(int'(id)))
      return m_forced_grant_delay_by_id[int'(id)];
    case (m_grant_mode)
      PTW_GRANT_DELAY_RANDOM: return $urandom_range(1, 8);
      PTW_GRANT_HOLD_UNTIL_ABORT: return 32'h7fff_ffff;
      default: return 0;
    endcase
  endfunction

  protected function bit _idle_grant_should_be_low();
    int unsigned next_accept_count;

    next_accept_count = m_accept_count + 1;
    if (m_max_outstanding == 0)
      return 1'b1;
    if (m_legal_outstanding_count >= m_max_outstanding)
      return 1'b1;
    if (m_forced_grant_delay_by_count.exists(next_accept_count)
        && (m_forced_grant_delay_by_count[next_accept_count] != 0))
      return 1'b1;
    if (m_forced_grant_delay_by_id.num() != 0)
      return 1'b1;
    if ((m_grant_mode == PTW_GRANT_DELAY_RANDOM)
        || (m_grant_mode == PTW_GRANT_HOLD_UNTIL_ABORT))
      return 1'b1;
    return 1'b0;
  endfunction

  protected function string _outstanding_snapshot();
    string s;

    s = "";
    foreach (m_outstanding_by_id[i]) begin
      if (m_outstanding_by_id[i].valid) begin
        s = {s,
          $sformatf("{id:%0d addr:0x%010h order:%0d target:%0d buserr:%0b} ",
            i,
            m_outstanding_by_id[i].addr,
            m_outstanding_by_id[i].accept_order,
            m_outstanding_by_id[i].target_rsp_cycle,
            m_outstanding_by_id[i].bus_error)};
      end
    end
    if (s == "")
      s = "none";
    return s;
  endfunction

  protected function void _refresh_active_debug();
    m_active_req = (m_legal_outstanding_count != 0);
    if (!m_active_req)
      return;
    foreach (m_outstanding_by_id[i]) begin
      if (m_outstanding_by_id[i].valid) begin
        m_active_start_time = m_last_accept_time;
        m_active_addr = m_outstanding_by_id[i].addr;
        m_active_size = m_outstanding_by_id[i].size;
        m_active_id = m_outstanding_by_id[i].id;
        m_active_pte = m_outstanding_by_id[i].pte;
        m_active_delay = m_outstanding_by_id[i].delay;
        return;
      end
    end
  endfunction

  protected function void _clear_outstanding_state();
    foreach (m_outstanding_by_id[i])
      m_outstanding_by_id[i].valid = 1'b0;
    m_legal_outstanding_count = 0;
    m_active_req = 1'b0;
    m_hold_active = 1'b0;
    m_hold_grant_wait_remaining = 0;
    m_hold_wait_cycles = 0;
    m_hold_drop_logged = 1'b0;
  endfunction

  protected function bit _abort_or_drain_seen();
    if (v_probe == null)
      return 1'b0;
    return (v_probe.tlboper_ptw_abort === 1'b1)
        || (v_probe.ptw_abort_flop === 1'b1)
        || (v_probe.ptw_abort_drain === 1'b1);
  endfunction

  protected function void _mark_abort_for_outstanding();
    if (!_abort_or_drain_seen())
      return;
    foreach (m_outstanding_by_id[i]) begin
      if (m_outstanding_by_id[i].valid
          && !m_outstanding_by_id[i].abort_seen_after_accept) begin
        m_outstanding_by_id[i].abort_seen_after_accept = 1'b1;
        if (m_trace_enabled) begin
          $display("[PTW_RESP_TRACE][ABORT_AFTER_ACCEPT] t=%0t id=0x%0h addr=0x%010h order=%0d",
            $time,
            m_outstanding_by_id[i].id,
            m_outstanding_by_id[i].addr,
            m_outstanding_by_id[i].accept_order);
        end
      end
    end
  endfunction

  protected task _drive_initial_outputs();
    vif.driver_cb.lsu_mmu_data_req_grant <= 1'b1;
    vif.driver_cb.lsu_mmu_data_vld       <= 1'b0;
    vif.driver_cb.lsu_mmu_data           <= 64'b0;
    vif.driver_cb.lsu_mmu_bus_error      <= 1'b0;
    vif.driver_cb.lsu_mmu_data_id        <= 4'b0;
  endtask

  protected task _drive_response_idle();
    vif.driver_cb.lsu_mmu_data_vld  <= 1'b0;
    vif.driver_cb.lsu_mmu_data      <= 64'b0;
    vif.driver_cb.lsu_mmu_bus_error <= 1'b0;
    vif.driver_cb.lsu_mmu_data_id   <= 4'b0;
  endtask

  protected function void _record_accept(
    bit [39:0] addr,
    bit req_size,
    bit [3:0] req_id,
    int delay,
    bit inject_err,
    int unsigned grant_wait_cycles,
    string ctx
  );
    m_last_accept_time = $time;
    m_last_accept_addr = addr;
    m_last_accept_size = req_size;
    m_last_accept_id   = req_id;
    m_last_accept_ctx  = ctx;
    if (m_trace_enabled) begin
      $display({"[PTW_RESP_TRACE][ACCEPT] t=%0t ctx=%s cnt=%0d addr=0x%010h ",
                "size=%0b id=0x%0h delay=%0d bus_err=%0b grant_wait=%0d ",
                "outstanding=%0d snapshot=%s"},
        $time, ctx, m_accept_count, addr, req_size, req_id, delay, inject_err,
        grant_wait_cycles, m_legal_outstanding_count, _outstanding_snapshot());
    end
  endfunction

  protected function void _accept_request(
    bit [39:0] addr,
    bit req_size,
    bit [3:0] req_id,
    int unsigned grant_wait_cycles
  );
    ptw_outstanding_s entry;
    bit [63:0] pte;
    int delay;
    bit inject_err;

    if (!_is_legal_id(req_id)) begin
      `uvm_error(get_type_name(),
        $sformatf("PTW request accepted with illegal id=0x%0h addr=0x%010h", req_id, addr))
      return;
    end
    if (m_outstanding_by_id[req_id].valid) begin
      `uvm_error(get_type_name(),
        $sformatf("PTW duplicate request id accepted: id=0x%0h old_addr=0x%010h new_addr=0x%010h",
          req_id, m_outstanding_by_id[req_id].addr, addr))
      return;
    end
    if (m_legal_outstanding_count >= m_max_outstanding) begin
      `uvm_error(get_type_name(),
        $sformatf("PTW request accepted while outstanding full: depth=%0d max=%0d addr=0x%010h id=0x%0h",
          m_legal_outstanding_count, m_max_outstanding, addr, req_id))
      return;
    end

    m_accept_count++;
    pte = _lookup_pte(addr);
    delay = _select_delay(addr, req_id, m_accept_count);
    inject_err = _select_bus_error(addr, req_id, m_accept_count);

    entry.valid = 1'b1;
    entry.id = req_id;
    entry.addr = addr;
    entry.size = req_size;
    entry.pte = pte;
    entry.bus_error = inject_err;
    entry.accept_order = m_accept_count;
    entry.target_rsp_cycle = m_cycle + int'(delay);
    entry.grant_wait_cycles = grant_wait_cycles;
    entry.delay = delay;
    entry.abort_seen_after_accept = 1'b0;
    m_outstanding_by_id[req_id] = entry;
    m_legal_outstanding_count++;

    _record_accept(addr, req_size, req_id, delay, inject_err, grant_wait_cycles, "grant_thread");
    _refresh_active_debug();

    `uvm_info(get_type_name(),
      $sformatf("PTW ACCEPT: addr=0x%010h size=%0b id=0x%0h order=%0d delay=%0d bus_err=%0b outstanding=%0d",
        addr, req_size, req_id, m_accept_count, delay, inject_err,
        m_legal_outstanding_count),
      UVM_HIGH)
  endfunction

  protected function bit _select_response_id(output bit [3:0] selected_id);
    bit found;
    bit oldest_found;
    bit [3:0] oldest_id;
    bit [3:0] oldest_ready_id;
    bit [3:0] newest_id;
    int unsigned oldest_order;
    int unsigned oldest_ready_order;
    int unsigned newest_order;
    int unsigned eligible_count;

    if (m_force_next_response_id_valid) begin
      selected_id = m_force_next_response_id;
      m_force_next_response_id_valid = 1'b0;
      if (_is_legal_id(selected_id) && m_outstanding_by_id[selected_id].valid)
        return 1'b1;
      `uvm_warning(get_type_name(),
        $sformatf("Forced response id=0x%0h has no outstanding request; force consumed",
          selected_id))
      return 1'b0;
    end

    found = 1'b0;
    oldest_found = 1'b0;
    oldest_order = 32'hffff_ffff;
    oldest_ready_order = 32'hffff_ffff;
    newest_order = 0;
    eligible_count = 0;
    foreach (m_outstanding_by_id[i]) begin
      if (m_outstanding_by_id[i].valid) begin
        if (!oldest_found || (m_outstanding_by_id[i].accept_order < oldest_order)) begin
          oldest_order = m_outstanding_by_id[i].accept_order;
          oldest_id = i[3:0];
          oldest_found = 1'b1;
        end
        if (m_outstanding_by_id[i].target_rsp_cycle <= m_cycle) begin
          eligible_count++;
          if (!found || (m_outstanding_by_id[i].accept_order < oldest_ready_order)) begin
            oldest_ready_order = m_outstanding_by_id[i].accept_order;
            oldest_ready_id = i[3:0];
          end
          if (!found || (m_outstanding_by_id[i].accept_order >= newest_order)) begin
            newest_order = m_outstanding_by_id[i].accept_order;
            newest_id = i[3:0];
          end
          found = 1'b1;
        end
      end
    end

    if (!found)
      return 1'b0;

    if (m_response_order_mode != PTW_RSP_BY_ID_OOO) begin
      if (m_outstanding_by_id[oldest_id].target_rsp_cycle > m_cycle)
        return 1'b0;
      selected_id = oldest_id;
    end else if (eligible_count > 1) begin
      selected_id = newest_id;
    end else begin
      selected_id = oldest_ready_id;
    end
    return 1'b1;
  endfunction

  protected function void _drive_response(bit [3:0] id, bit invalid_id);
    ptw_outstanding_s entry;
    bit [63:0] pte;
    bit bus_error;
    int delay;

    if (invalid_id) begin
      pte = 64'h0;
      bus_error = 1'b0;
      delay = 0;
      vif.driver_cb.lsu_mmu_data_vld  <= 1'b1;
      vif.driver_cb.lsu_mmu_data      <= pte;
      vif.driver_cb.lsu_mmu_bus_error <= bus_error;
      vif.driver_cb.lsu_mmu_data_id   <= id;
      m_response_count++;
      m_rsp_count++;
      m_last_rsp_time = $time;
      m_last_rsp_addr = 40'h0;
      m_last_rsp_size = 1'b0;
      m_last_rsp_id = id;
      m_last_rsp_pte = pte;
      m_last_rsp_delay = delay;
      if (m_trace_enabled)
        $display("[PTW_RESP_TRACE][INVALID_RSP] t=%0t rsp_cnt=%0d id=0x%0h outstanding=%s",
          $time, m_response_count, id, _outstanding_snapshot());
      `uvm_info(get_type_name(),
        $sformatf("PTW INVALID RSP: id=0x%0h outstanding=%s",
          id, _outstanding_snapshot()),
        UVM_MEDIUM)
      return;
    end

    entry = m_outstanding_by_id[id];
    pte = entry.pte;
    bus_error = entry.bus_error;
    delay = entry.delay;

    vif.driver_cb.lsu_mmu_data_vld  <= 1'b1;
    vif.driver_cb.lsu_mmu_data      <= pte;
    vif.driver_cb.lsu_mmu_bus_error <= bus_error;
    vif.driver_cb.lsu_mmu_data_id   <= id;
    m_response_count++;
    m_rsp_count++;

    if (bus_error) begin
      m_buserr_count++;
      m_last_buserr_time = $time;
      m_last_buserr_addr = entry.addr;
      m_last_buserr_size = entry.size;
      m_last_buserr_id = id;
    end else begin
      m_last_rsp_time = $time;
      m_last_rsp_addr = entry.addr;
      m_last_rsp_size = entry.size;
      m_last_rsp_id = id;
      m_last_rsp_pte = pte;
      m_last_rsp_delay = delay;
    end

    if (m_trace_enabled) begin
      $display({"[PTW_RESP_TRACE][RSP] t=%0t rsp_cnt=%0d addr=0x%010h ",
                "size=%0b id=0x%0h order=%0d pte=0x%016h delay=%0d ",
                "bus_err=%0b abort_after_accept=%0b mode=%s outstanding_before=%0d"},
        $time, m_response_count, entry.addr, entry.size, id,
        entry.accept_order, pte, delay, bus_error,
        entry.abort_seen_after_accept, m_response_order_mode.name(),
        m_legal_outstanding_count);
    end

    `uvm_info(get_type_name(),
      $sformatf("PTW RSP: addr=0x%010h id=0x%0h pte=0x%016h delay=%0d bus_err=%0b abort_after_accept=%0b",
        entry.addr, id, pte, delay, bus_error, entry.abort_seen_after_accept),
      UVM_MEDIUM)

    m_outstanding_by_id[id].valid = 1'b0;
    if (m_legal_outstanding_count != 0)
      m_legal_outstanding_count--;
    _refresh_active_debug();
  endfunction

  virtual function void print_timeout_debug(string ctx = "timeout");
    if (vif == null) begin
      $display("[MMU_TIMEOUT_DBG] PTW_RESP ctx=%s vif=null", ctx);
      return;
    end
    $display({"[MMU_TIMEOUT_DBG] PTW_RESP ctx=%s delay_min=%0d delay_max=%0d ",
              "bus_err_permille=%0d accept_cnt=%0d rsp_cnt=%0d buserr_cnt=%0d ",
              "outstanding_cnt=%0d max_outstanding=%0d order_mode=%s grant_mode=%s ",
              "hold_active=%0b hold_id=0x%0h hold_addr=0x%010h hold_size=%0b hold_rem=%0d hold_wait=%0d ",
              "active=%0b active_start=%0t active_addr=0x%010h active_size=%0b active_id=0x%0h active_pte=0x%016h active_delay=%0d ",
              "last_accept_t=%0t last_accept_ctx=%s last_accept_addr=0x%010h last_accept_size=%0b last_accept_id=0x%0h ",
              "last_rsp_t=%0t last_rsp_addr=0x%010h last_rsp_size=%0b last_rsp_id=0x%0h last_rsp_pte=0x%016h last_rsp_delay=%0d ",
              "last_buserr_t=%0t last_buserr_addr=0x%010h last_buserr_size=%0b last_buserr_id=0x%0h ",
              "directed={addr_delay:%0d count_delay:%0d id_delay:%0d grant_count:%0d grant_id:%0d addr_buserr:%0d count_buserr:%0d id_buserr:%0d chk_slow:%0d force_rsp:%0b force_invalid:%0b} ",
              "req=%0b grant=%0b fire=%0b req_addr=0x%010h req_size=%0b req_id=0x%0h data_vld=%0b bus_error=%0b rsp_id=0x%0h data=0x%016h pt_configured=%0b outstanding=%s"},
      ctx,
      m_rsp_delay_min,
      m_rsp_delay_max,
      m_bus_error_rate_permille,
      m_accept_count,
      m_rsp_count,
      m_buserr_count,
      m_legal_outstanding_count,
      m_max_outstanding,
      m_response_order_mode.name(),
      m_grant_mode.name(),
      m_hold_active,
      m_hold_id,
      m_hold_addr,
      m_hold_size,
      m_hold_grant_wait_remaining,
      m_hold_wait_cycles,
      m_active_req,
      m_active_start_time,
      m_active_addr,
      m_active_size,
      m_active_id,
      m_active_pte,
      m_active_delay,
      m_last_accept_time,
      m_last_accept_ctx,
      m_last_accept_addr,
      m_last_accept_size,
      m_last_accept_id,
      m_last_rsp_time,
      m_last_rsp_addr,
      m_last_rsp_size,
      m_last_rsp_id,
      m_last_rsp_pte,
      m_last_rsp_delay,
      m_last_buserr_time,
      m_last_buserr_addr,
      m_last_buserr_size,
      m_last_buserr_id,
      m_forced_delay_by_addr.num(),
      m_forced_delay_by_count.num(),
      m_forced_delay_by_id.num(),
      m_forced_grant_delay_by_count.num(),
      m_forced_grant_delay_by_id.num(),
      m_forced_bus_error_by_addr.num(),
      m_forced_bus_error_by_count.num(),
      m_forced_bus_error_by_id.num(),
      m_chk_not_ready_slow_cycles,
      m_force_next_response_id_valid,
      m_force_invalid_response_id_valid,
      vif.mmu_lsu_data_req,
      vif.lsu_mmu_data_req_grant,
      vif.mmu_lsu_data_req_fire,
      vif.mmu_lsu_data_req_addr,
      vif.mmu_lsu_data_req_size,
      vif.mmu_lsu_data_req_id,
      vif.lsu_mmu_data_vld,
      vif.lsu_mmu_bus_error,
      vif.lsu_mmu_data_id,
      vif.lsu_mmu_data,
      (m_pt != null),
      _outstanding_snapshot());
  endfunction

  virtual task run_phase(uvm_phase phase);
    _drive_initial_outputs();
    _clear_outstanding_state();
    m_cycle = 0;

    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(vif.driver_cb);

    fork
      grant_request_thread();
      response_scheduler_thread();
    join
  endtask

  protected task grant_request_thread();
    forever begin
      bit         req_seen;
      bit         fire_seen;
      bit [39:0]  req_addr;
      bit         req_size;
      bit [3:0]   req_id;
      bit         next_grant;

      @(vif.driver_cb);
      m_cycle++;

      if (vif.rst_ni !== 1'b1) begin
        _clear_outstanding_state();
        vif.driver_cb.lsu_mmu_data_req_grant <= 1'b1;
        continue;
      end

      _mark_abort_for_outstanding();

      req_seen = (vif.driver_cb.mmu_lsu_data_req === 1'b1);
      fire_seen = (vif.driver_cb.mmu_lsu_data_req_fire === 1'b1);
      req_addr = vif.driver_cb.mmu_lsu_data_req_addr;
      req_size = vif.driver_cb.mmu_lsu_data_req_size;
      req_id = vif.driver_cb.mmu_lsu_data_req_id;

      if (fire_seen) begin
        _accept_request(req_addr, req_size, req_id, m_hold_active ? m_hold_wait_cycles : 0);
        m_hold_active = 1'b0;
        m_hold_grant_wait_remaining = 0;
        m_hold_wait_cycles = 0;
        m_hold_drop_logged = 1'b0;
      end else if (req_seen) begin
        if (!m_hold_active) begin
          m_hold_active = 1'b1;
          m_hold_addr = req_addr;
          m_hold_size = req_size;
          m_hold_id = req_id;
          m_hold_accept_count = m_accept_count + 1;
          m_hold_grant_wait_remaining = _select_grant_delay(req_id, m_hold_accept_count);
          m_hold_wait_cycles = 0;
          m_hold_drop_logged = 1'b0;
          if (m_trace_enabled) begin
            $display("[PTW_RESP_TRACE][HOLD_START] t=%0t next_cnt=%0d addr=0x%010h size=%0b id=0x%0h grant_delay=%0d",
              $time, m_hold_accept_count, req_addr, req_size, req_id,
              m_hold_grant_wait_remaining);
          end
        end else if ((req_addr !== m_hold_addr) || (req_size !== m_hold_size)
                     || (req_id !== m_hold_id)) begin
          `uvm_error(get_type_name(),
            $sformatf("PTW held request changed before grant: old={addr=0x%010h size=%0b id=0x%0h} new={addr=0x%010h size=%0b id=0x%0h}",
              m_hold_addr, m_hold_size, m_hold_id, req_addr, req_size, req_id))
        end
      end else if (m_hold_active) begin
        if (!m_hold_drop_logged) begin
          `uvm_info(get_type_name(),
            $sformatf("[PTW_REQ_ABORT_BEFORE_GRANT] held req dropped before grant: addr=0x%010h size=%0b id=0x%0h wait=%0d",
              m_hold_addr, m_hold_size, m_hold_id, m_hold_wait_cycles),
            UVM_MEDIUM)
          m_hold_drop_logged = 1'b1;
        end
        m_hold_active = 1'b0;
        m_hold_grant_wait_remaining = 0;
        m_hold_wait_cycles = 0;
      end

      if (!req_seen) begin
        next_grant = !_idle_grant_should_be_low();
      end else if (!_is_legal_id(req_id)) begin
        next_grant = 1'b0;
      end else if (m_outstanding_by_id[req_id].valid) begin
        next_grant = 1'b0;
      end else if (m_legal_outstanding_count >= m_max_outstanding) begin
        next_grant = 1'b0;
      end else if (m_hold_active
                   && (m_grant_mode == PTW_GRANT_HOLD_UNTIL_ABORT)) begin
        next_grant = 1'b0;
        m_hold_wait_cycles++;
      end else if (m_hold_active && (m_hold_grant_wait_remaining != 0)) begin
        next_grant = 1'b0;
        m_hold_grant_wait_remaining--;
        m_hold_wait_cycles++;
      end else begin
        next_grant = 1'b1;
      end

      if (req_seen && !_is_legal_id(req_id)) begin
        `uvm_error(get_type_name(),
          $sformatf("PTW request id out of legal MBUF range: id=0x%0h addr=0x%010h",
            req_id, req_addr))
      end

      vif.driver_cb.lsu_mmu_data_req_grant <= next_grant;
    end
  endtask

  protected task response_scheduler_thread();
    forever begin
      bit [3:0] selected_id;

      @(vif.driver_cb);
      if (vif.rst_ni !== 1'b1) begin
        _drive_response_idle();
        continue;
      end

      _drive_response_idle();

      if (m_force_invalid_response_id_valid) begin
        selected_id = m_force_invalid_response_id;
        m_force_invalid_response_id_valid = 1'b0;
        _drive_response(selected_id, 1'b1);
      end else if (_select_response_id(selected_id)) begin
        _drive_response(selected_id, 1'b0);
      end
    end
  endtask

endclass : ptw_mem_responder

`endif // PTW_MEM_RESPONDER_SVH
