// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_responder.svh
// Phase 4: PTW memory channel responder
//
// Protocol summary (BuildPlan §2.4 Group 7):
//   · DUT asserts mmu_lsu_data_req=1 and normally holds addr stable until TB
//     responds; invalidate/abort may drop the visible request after the memory
//     read was accepted, but the response still returns to retire PTW cleanup
//   · mmu_lsu_data_req_accept is the TB whitebox view of the RTL grant pulse;
//     the responder services exactly one accepted read per pulse.
//   · TB drives lsu_mmu_data_vld=1 for exactly one cycle, then deasserts.
//     lsu_mmu_bus_error qualifies that same response beat: data_vld=1 and
//     bus_error=0 is a normal PTE response; data_vld=1 and bus_error=1 is a
//     bus-error response.
//   · At most 1 outstanding request at any time (no tag/ID)
//   · m_rsp_delay_min/max: random per-request delay in clock cycles
//   · m_bus_error_rate_permille: probability (‰) of injecting bus_error
//
// After set_page_table() is called from the env, every request is looked up
// in the page_table_builder associative array.  Unknown addresses return 0
// (V=0 invalid PTE), which causes the DUT to generate a page fault.
// =============================================================================
`ifndef PTW_MEM_RESPONDER_SVH
`define PTW_MEM_RESPONDER_SVH

class ptw_mem_responder extends uvm_component;

  `uvm_component_utils(ptw_mem_responder)

  // ── Virtual interface ─────────────────────────────────────────────────────
  virtual ptw_mem_if vif;

  // ── Shared page table (set by env.build_phase via set_page_table()) ───────
  page_table_builder m_pt;

  // ── Configuration knobs (writable by sequences / test) ───────────────────
  int unsigned m_rsp_delay_min          = 1;
  int unsigned m_rsp_delay_max          = 8;
  int unsigned m_bus_error_rate_permille = 0;  // 0 = never inject bus error
  protected int unsigned m_forced_delay_by_addr [longint unsigned];
  protected int unsigned m_forced_delay_by_count [int unsigned];
  protected bit          m_forced_bus_error_by_addr [longint unsigned];
  protected bit          m_forced_bus_error_by_count [int unsigned];
  protected bit          m_same_cycle_abort_data_by_count [int unsigned];
  protected bit          m_same_cycle_abort_bus_error_by_count [int unsigned];
  protected int unsigned m_chk_not_ready_slow_cycles;
  protected bit        m_has_accepted_req;
  protected bit [39:0] m_accepted_addr;
  protected bit        m_accepted_size;
  protected int unsigned m_accept_count;
  protected int unsigned m_rsp_count;
  protected int unsigned m_buserr_count;
  protected bit          m_active_req;
  protected time         m_active_start_time;
  protected bit [39:0]   m_active_addr;
  protected bit          m_active_size;
  protected bit [63:0]   m_active_pte;
  protected int          m_active_delay;
  protected time         m_last_accept_time;
  protected bit [39:0]   m_last_accept_addr;
  protected bit          m_last_accept_size;
  protected string       m_last_accept_ctx;
  protected time         m_last_rsp_time;
  protected bit [39:0]   m_last_rsp_addr;
  protected bit          m_last_rsp_size;
  protected bit [63:0]   m_last_rsp_pte;
  protected int          m_last_rsp_delay;
  protected time         m_last_buserr_time;
  protected bit [39:0]   m_last_buserr_addr;
  protected bit          m_last_buserr_size;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ptw_mem_if)::get(this, "", "PTW_MEM_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get PTW_MEM_VIF from config_db")
  endfunction

  // Called by env.build_phase to connect the shared page table
  virtual function void set_page_table(page_table_builder pt);
    m_pt = pt;
  endfunction

  virtual function void clear_directed_controls();
    m_forced_delay_by_addr.delete();
    m_forced_delay_by_count.delete();
    m_forced_bus_error_by_addr.delete();
    m_forced_bus_error_by_count.delete();
    m_same_cycle_abort_data_by_count.delete();
    m_same_cycle_abort_bus_error_by_count.delete();
    m_chk_not_ready_slow_cycles = 0;
    m_bus_error_rate_permille = 0;
    m_accept_count = 0;
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
      $sformatf("PTW responder forced delay by addr: addr=0x%010h delay=%0d",
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
      $sformatf("PTW responder forced delay by count: count=%0d delay=%0d",
        count, delay),
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

  protected function int _select_delay(bit [39:0] addr, int unsigned accept_count);
    longint unsigned addr_key;

    addr_key = longint'(addr);
    if (m_forced_delay_by_count.exists(accept_count))
      return int'(m_forced_delay_by_count[accept_count]);
    if (m_forced_delay_by_addr.exists(addr_key))
      return int'(m_forced_delay_by_addr[addr_key]);
    if (m_chk_not_ready_slow_cycles != 0)
      return int'(m_chk_not_ready_slow_cycles);
    return int'($urandom_range(m_rsp_delay_min, m_rsp_delay_max));
  endfunction

  protected function bit _select_bus_error(bit [39:0] addr, int unsigned accept_count);
    longint unsigned addr_key;

    addr_key = longint'(addr);
    if (m_forced_bus_error_by_count.exists(accept_count))
      return m_forced_bus_error_by_count[accept_count];
    if (m_forced_bus_error_by_addr.exists(addr_key))
      return m_forced_bus_error_by_addr[addr_key];
    return (m_bus_error_rate_permille > 0)
        && ($urandom_range(0, 999) < m_bus_error_rate_permille);
  endfunction

  virtual function void print_timeout_debug(string ctx = "timeout");
    if (vif == null) begin
      $display("[MMU_TIMEOUT_DBG] PTW_RESP ctx=%s vif=null", ctx);
      return;
    end
    $display({"[MMU_TIMEOUT_DBG] PTW_RESP ctx=%s delay_min=%0d delay_max=%0d ",
              "bus_err_permille=%0d accept_cnt=%0d rsp_cnt=%0d buserr_cnt=%0d ",
              "active=%0b active_start=%0t active_addr=0x%010h active_size=%0b active_pte=0x%016h active_delay=%0d ",
              "last_accept_t=%0t last_accept_ctx=%s last_accept_addr=0x%010h last_accept_size=%0b ",
              "last_rsp_t=%0t last_rsp_addr=0x%010h last_rsp_size=%0b last_rsp_pte=0x%016h last_rsp_delay=%0d ",
              "last_buserr_t=%0t last_buserr_addr=0x%010h last_buserr_size=%0b ",
              "has_accepted=%0b accepted_addr=0x%010h accepted_size=%0b ",
              "directed={addr_delay:%0d count_delay:%0d addr_buserr:%0d count_buserr:%0d chk_slow:%0d} ",
              "req=%0b accept=%0b req_addr=0x%010h req_size=%0b data_vld=%0b bus_error=%0b data=0x%016h pt_configured=%0b"},
      ctx,
      m_rsp_delay_min,
      m_rsp_delay_max,
      m_bus_error_rate_permille,
      m_accept_count,
      m_rsp_count,
      m_buserr_count,
      m_active_req,
      m_active_start_time,
      m_active_addr,
      m_active_size,
      m_active_pte,
      m_active_delay,
      m_last_accept_time,
      m_last_accept_ctx,
      m_last_accept_addr,
      m_last_accept_size,
      m_last_rsp_time,
      m_last_rsp_addr,
      m_last_rsp_size,
      m_last_rsp_pte,
      m_last_rsp_delay,
      m_last_buserr_time,
      m_last_buserr_addr,
      m_last_buserr_size,
      m_has_accepted_req,
      m_accepted_addr,
      m_accepted_size,
      m_forced_delay_by_addr.num(),
      m_forced_delay_by_count.num(),
      m_forced_bus_error_by_addr.num(),
      m_forced_bus_error_by_count.num(),
      m_chk_not_ready_slow_cycles,
      vif.mmu_lsu_data_req,
      vif.mmu_lsu_data_req_accept,
      vif.mmu_lsu_data_req_addr,
      vif.mmu_lsu_data_req_size,
      vif.lsu_mmu_data_vld,
      vif.lsu_mmu_bus_error,
      vif.lsu_mmu_data,
      (m_pt != null));
  endfunction

  protected function void _record_accept(bit [39:0] addr, bit req_size, string ctx);
    m_accept_count++;
    m_last_accept_time = $time;
    m_last_accept_addr = addr;
    m_last_accept_size = req_size;
    m_last_accept_ctx  = ctx;
    $display("[PTW_RESP_TRACE][ACCEPT] t=%0t ctx=%s cnt=%0d addr=0x%010h size=%0b req=%0b accept=%0b",
      $time, ctx, m_accept_count, addr, req_size,
      vif.driver_cb.mmu_lsu_data_req,
      vif.driver_cb.mmu_lsu_data_req_accept);
  endfunction

  protected task _drive_idle_outputs();
    vif.driver_cb.lsu_mmu_data_vld  <= 1'b0;
    vif.driver_cb.lsu_mmu_data      <= 64'b0;
    vif.driver_cb.lsu_mmu_bus_error <= 1'b0;
  endtask

  protected function void _stash_accept_if_seen(string ctx);
    if (vif.driver_cb.mmu_lsu_data_req_accept === 1'b1) begin
      if (m_has_accepted_req) begin
        `uvm_error(get_type_name(),
          $sformatf("%s: PTW accept queue already occupied: old_addr=0x%010h new_addr=0x%010h",
            ctx, m_accepted_addr, vif.driver_cb.mmu_lsu_data_req_addr))
      end
      m_accepted_addr    = vif.driver_cb.mmu_lsu_data_req_addr;
      m_accepted_size    = vif.driver_cb.mmu_lsu_data_req_size;
      m_has_accepted_req = 1'b1;
      _record_accept(m_accepted_addr, m_accepted_size, ctx);
      `uvm_info(get_type_name(),
        $sformatf("%s: stashed back-to-back PTW accept addr=0x%010h size=%0b",
          ctx, m_accepted_addr, m_accepted_size),
        UVM_HIGH)
    end
  endfunction

  // ── Main protocol loop ────────────────────────────────────────────────────
  virtual task run_phase(uvm_phase phase);
    // Initialise TB-driven outputs to safe state
    _drive_idle_outputs();
    m_has_accepted_req = 1'b0;
    m_active_req = 1'b0;

    // Wait for reset de-assertion
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(vif.driver_cb);

    // Strictly serial: at most one PTW memory request is outstanding. The
    // responder handles exactly one accepted request per loop iteration and
    // blocks until its response is completed. The visible req level can remain
    // high after a response; the RTL grant pulse disambiguates real new reads
    // from the tail of an already-serviced request.
    forever begin
      bit [39:0] req_addr;
      bit        req_size;

      if (m_has_accepted_req) begin
        req_addr = m_accepted_addr;
        req_size = m_accepted_size;
        m_has_accepted_req = 1'b0;
        handle_request(req_addr, req_size);
        continue;
      end

      @(vif.driver_cb);

      if (vif.rst_ni !== 1'b1) begin
        _drive_idle_outputs();
        m_has_accepted_req = 1'b0;
        m_active_req = 1'b0;
        continue;
      end

      if (vif.driver_cb.mmu_lsu_data_req_accept !== 1'b1)
        continue;

      req_addr = vif.driver_cb.mmu_lsu_data_req_addr;
      req_size = vif.driver_cb.mmu_lsu_data_req_size;
      _record_accept(req_addr, req_size, "main");
      handle_request(req_addr, req_size);
    end
  endtask

  // ── Handle a single PTW memory request ───────────────────────────────────
  // addr: the 40-bit physical address of the PTE to read
  virtual task handle_request(bit [39:0] addr, bit req_size);
    bit [63:0] pte;
    bit [27:0] pte_ppn;
    int        delay;
    bit        inject_err;
    int unsigned accept_idx;
    bit        logged_req_drop;
    bit        logged_req_replace;

    // Look up PTE from the shadow page table
    if (m_pt != null) begin
      pte = 64'(m_pt.read_pte_at(pa_t'(addr)));
    end else begin
      // No page table configured — return invalid PTE (V=0) → DUT page fault
      pte = 64'h0;
      `uvm_warning(get_type_name(),
        $sformatf("handle_request: m_pt is null, returning 0 for addr=0x%010h", addr))
    end
    pte_ppn = pte[37:10];

    accept_idx = m_accept_count;
    delay      = _select_delay(addr, accept_idx);
    inject_err = _select_bus_error(addr, accept_idx);
    logged_req_drop = 1'b0;
    logged_req_replace = 1'b0;
    m_active_req        = 1'b1;
    m_active_start_time = $time;
    m_active_addr       = addr;
    m_active_size       = req_size;
    m_active_pte        = pte;
    m_active_delay      = delay;
    $display("[PTW_RESP_TRACE][START] t=%0t accept_cnt=%0d addr=0x%010h size=%0b pte=0x%016h pte_ppn=0x%07h delay=%0d bus_err=%0b same_cycle_abort_data=%0b same_cycle_abort_buserr=%0b",
      $time, accept_idx, addr, req_size, pte, pte_ppn, delay, inject_err,
      m_same_cycle_abort_data_by_count.exists(accept_idx),
      m_same_cycle_abort_bus_error_by_count.exists(accept_idx));
    repeat (delay) begin
      @(vif.driver_cb);
      if (vif.rst_ni !== 1'b1) begin
        _drive_idle_outputs();
        m_has_accepted_req = 1'b0;
        m_active_req = 1'b0;
        return;
      end
      if (vif.driver_cb.mmu_lsu_data_req !== 1'b1) begin
        if (!logged_req_drop) begin
          $display("[PTW_RESP_TRACE][REQ_DROP_BEFORE_RSP] t=%0t addr=0x%010h size=%0b delay=%0d",
            $time, addr, req_size, delay);
          `uvm_info(get_type_name(),
            $sformatf(
              "[PTW_REQ_ABORT_LATE_RSP] req dropped before rsp; keep accepted response pending: addr=0x%010h size=%0b",
              addr, req_size),
            UVM_MEDIUM)
          logged_req_drop = 1'b1;
        end
      end else if ((vif.driver_cb.mmu_lsu_data_req_addr !== addr) ||
                   (vif.driver_cb.mmu_lsu_data_req_size !== req_size)) begin
        if (!logged_req_replace) begin
          $display("[PTW_RESP_TRACE][REQ_REPLACE_BEFORE_RSP] t=%0t exp_addr=0x%010h cur_addr=0x%010h exp_size=%0b cur_size=%0b delay=%0d",
            $time, addr, vif.driver_cb.mmu_lsu_data_req_addr, req_size,
            vif.driver_cb.mmu_lsu_data_req_size, delay);
          `uvm_info(get_type_name(),
            $sformatf(
              "[PTW_REQ_REPLACE_LATE_RSP] req changed before rsp; keep accepted response pending: exp_addr=0x%010h cur_addr=0x%010h exp_size=%0b cur_size=%0b",
              addr, vif.driver_cb.mmu_lsu_data_req_addr, req_size,
              vif.driver_cb.mmu_lsu_data_req_size),
            UVM_MEDIUM)
          logged_req_replace = 1'b1;
        end
      end
    end

    if (inject_err) begin
      // ── Bus error response ─────────────────────────────────────────────
      vif.driver_cb.lsu_mmu_data_vld  <= 1'b1;
      vif.driver_cb.lsu_mmu_data      <= pte;
      vif.driver_cb.lsu_mmu_bus_error <= 1'b1;
      m_buserr_count++;
      m_last_buserr_time = $time;
      m_last_buserr_addr = addr;
      m_last_buserr_size = req_size;
      $display("[PTW_RESP_TRACE][BUS_ERR] t=%0t cnt=%0d addr=0x%010h size=%0b delay=%0d",
        $time, m_buserr_count, addr, req_size, delay);
      `uvm_info(get_type_name(),
        $sformatf("PTW BUS_ERR: addr=0x%010h delay=%0d", addr, delay), UVM_MEDIUM)
      @(vif.driver_cb);
      if (vif.rst_ni !== 1'b1) begin
        _drive_idle_outputs();
        m_has_accepted_req = 1'b0;
        m_active_req = 1'b0;
        return;
      end
      vif.driver_cb.lsu_mmu_data_vld  <= 1'b0;
      vif.driver_cb.lsu_mmu_data      <= 64'b0;
      vif.driver_cb.lsu_mmu_bus_error <= 1'b0;
      m_active_req = 1'b0;
      _stash_accept_if_seen("PTW_BUS_ERR_DONE");
    end else begin
      // ── Normal data response ───────────────────────────────────────────
      vif.driver_cb.lsu_mmu_data_vld <= 1'b1;
      vif.driver_cb.lsu_mmu_data     <= pte;
      m_rsp_count++;
      m_last_rsp_time  = $time;
      m_last_rsp_addr  = addr;
      m_last_rsp_size  = req_size;
      m_last_rsp_pte   = pte;
      m_last_rsp_delay = delay;
      $display("[PTW_RESP_TRACE][RSP] t=%0t cnt=%0d addr=0x%010h size=%0b pte=0x%016h pte_ppn=0x%07h delay=%0d",
        $time, m_rsp_count, addr, req_size, pte, pte_ppn, delay);
      `uvm_info(get_type_name(),
        $sformatf("PTW RSP: addr=0x%010h pte=0x%016h pte_ppn=0x%07h delay=%0d", addr, pte, pte_ppn, delay),
        UVM_MEDIUM)
      @(vif.driver_cb);
      if (vif.rst_ni !== 1'b1) begin
        _drive_idle_outputs();
        m_has_accepted_req = 1'b0;
        m_active_req = 1'b0;
        return;
      end
      vif.driver_cb.lsu_mmu_data_vld <= 1'b0;
      vif.driver_cb.lsu_mmu_data     <= 64'b0;
      m_active_req = 1'b0;
      _stash_accept_if_seen("PTW_RSP_DONE");
    end
  endtask

endclass : ptw_mem_responder

`endif // PTW_MEM_RESPONDER_SVH
