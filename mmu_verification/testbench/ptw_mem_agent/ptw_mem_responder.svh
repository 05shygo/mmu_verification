// =============================================================================
// MMU UVM Verification — testbench/ptw_mem_agent/ptw_mem_responder.svh
// Phase 4: PTW memory channel responder
//
// Protocol summary (BuildPlan §2.4 Group 7):
//   · DUT asserts mmu_lsu_data_req=1 and holds addr stable until TB responds
//   · TB drives lsu_mmu_data_vld=1 (with PTE data) for exactly one cycle,
//     then deasserts.  OR drives lsu_mmu_bus_error=1 for one cycle.
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

  protected task _drive_idle_outputs();
    vif.driver_cb.lsu_mmu_data_vld  <= 1'b0;
    vif.driver_cb.lsu_mmu_data      <= 64'b0;
    vif.driver_cb.lsu_mmu_bus_error <= 1'b0;
  endtask

  // ── Main protocol loop ────────────────────────────────────────────────────
  virtual task run_phase(uvm_phase phase);
    // Initialise TB-driven outputs to safe state
    _drive_idle_outputs();

    // Wait for reset de-assertion
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(vif.driver_cb);

    // Strictly serial: at most one PTW memory request is outstanding, but req
    // is not required to pulse low between adjacent requests. After a response,
    // the DUT may keep req high and present the next address on the following
    // cycle. Re-arm on the next sampled req-high cycle instead of waiting for
    // a req-low bubble.
    forever begin
      @(vif.driver_cb iff vif.driver_cb.mmu_lsu_data_req === 1'b1);
      handle_request(vif.driver_cb.mmu_lsu_data_req_addr);
    end
  endtask

  // ── Handle a single PTW memory request ───────────────────────────────────
  // addr: the 40-bit physical address of the PTE to read
  virtual task handle_request(bit [39:0] addr);
    bit [63:0] pte;
    int        delay;
    bit        inject_err;

    // Look up PTE from the shadow page table
    if (m_pt != null) begin
      pte = 64'(m_pt.read_pte_at(pa_t'(addr)));
    end else begin
      // No page table configured — return invalid PTE (V=0) → DUT page fault
      pte = 64'h0;
      `uvm_warning(get_type_name(),
        $sformatf("handle_request: m_pt is null, returning 0 for addr=0x%010h", addr))
    end

    // Decide whether to inject a bus error for this transaction
    inject_err = (m_bus_error_rate_permille > 0) &&
                 ($urandom_range(0, 999) < m_bus_error_rate_permille);

    // Random response delay
    delay = $urandom_range(m_rsp_delay_min, m_rsp_delay_max);
    repeat (delay) begin
      @(vif.driver_cb);
      if (vif.rst_ni !== 1'b1) begin
        _drive_idle_outputs();
        return;
      end
    end

    if (inject_err) begin
      // ── Bus error response ─────────────────────────────────────────────
      vif.driver_cb.lsu_mmu_bus_error <= 1'b1;
      `uvm_info(get_type_name(),
        $sformatf("PTW BUS_ERR: addr=0x%010h delay=%0d", addr, delay), UVM_MEDIUM)
      @(vif.driver_cb);
      if (vif.rst_ni !== 1'b1) begin
        _drive_idle_outputs();
        return;
      end
      vif.driver_cb.lsu_mmu_bus_error <= 1'b0;
    end else begin
      // ── Normal data response ───────────────────────────────────────────
      vif.driver_cb.lsu_mmu_data_vld <= 1'b1;
      vif.driver_cb.lsu_mmu_data     <= pte;
      `uvm_info(get_type_name(),
        $sformatf("PTW RSP: addr=0x%010h pte=0x%016h delay=%0d", addr, pte, delay),
        UVM_HIGH)
      @(vif.driver_cb);
      if (vif.rst_ni !== 1'b1) begin
        _drive_idle_outputs();
        return;
      end
      vif.driver_cb.lsu_mmu_data_vld <= 1'b0;
      vif.driver_cb.lsu_mmu_data     <= 64'b0;
    end
  endtask

endclass : ptw_mem_responder

`endif // PTW_MEM_RESPONDER_SVH
