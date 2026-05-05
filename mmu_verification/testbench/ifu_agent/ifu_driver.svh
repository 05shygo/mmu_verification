// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_driver.svh
// Phase 5 (Engineer B): IFU driver — full handshake implementation
// Drives ifu_mmu_va_vld / ifu_mmu_va / ifu_mmu_abort via clocking block.
//
// Protocol:
//   1. Insert idle_cycles idle beats before asserting request
//   2. Assert ifu_mmu_va_vld=1 + va + abort
//   3. If abort==0, hold the same PC until mmu_ifu_pavld returns
//      (core miss-hold behavior: no new PC while the miss is pending)
//   4. If abort==1, deassert after one cycle
// =============================================================================
`ifndef IFU_DRIVER_SVH
`define IFU_DRIVER_SVH

class ifu_driver extends uvm_driver #(ifu_txn);

  `uvm_component_utils(ifu_driver)

  virtual ifu_if vif;
  protected bit m_drive_busy;
  protected bit m_end_quiesce;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_drive_busy  = 1'b0;
    m_end_quiesce = 1'b0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ifu_if)::get(this, "", "IFU_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get IFU_VIF from config_db")
  endfunction

  virtual function void set_end_quiesce(bit enable = 1'b1);
    m_end_quiesce = enable;
  endfunction

  virtual function bit is_idle();
    if (vif == null)
      return 1'b1;
    return (m_drive_busy == 1'b0)
        && (vif.ifu_mmu_va_vld !== 1'b1);
  endfunction

  virtual function string idle_snapshot();
    if (vif == null)
      return "vif=null";
    return $sformatf("busy=%0b va_vld=%0b pavld=%0b va=0x%010h",
      m_drive_busy, vif.ifu_mmu_va_vld, vif.mmu_ifu_pavld,
      {1'b0, vif.ifu_mmu_va[38:0]});
  endfunction

  virtual task wait_for_idle(
    string       ctx = "end-of-test",
    int unsigned max_cycles = 262144,
    int unsigned stable_cycles = 32
  );
    int unsigned wait_cycles;
    int unsigned stable_idle_cycles;

    if (vif == null)
      return;

    wait_cycles = 0;
    stable_idle_cycles = 0;
    while ((stable_idle_cycles < stable_cycles) &&
           (wait_cycles < max_cycles)) begin
      @(vif.driver_cb);
      wait_cycles++;
      if (is_idle())
        stable_idle_cycles++;
      else
        stable_idle_cycles = 0;
    end

    if (!is_idle()) begin
      `uvm_error(get_type_name(),
        $sformatf("IFU stimulus did not drain before %s after %0d cycles: stable_idle=%0d/%0d %s",
          ctx, wait_cycles, stable_idle_cycles, stable_cycles,
          idle_snapshot()))
    end else begin
      `uvm_info(get_type_name(),
        $sformatf("IFU stimulus idle before %s after %0d cycles (stable_idle=%0d)",
          ctx, wait_cycles, stable_idle_cycles),
        UVM_MEDIUM)
    end
  endtask

  virtual task run_phase(uvm_phase phase);
    ifu_txn tr;
    _drive_idle();
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(posedge vif.clk_i);
    forever begin
      seq_item_port.get_next_item(tr);
      if (m_end_quiesce) begin
        `uvm_warning(get_type_name(),
          $sformatf("Dropping IFU item after end-of-test quiesce was requested: %s",
            tr.convert2string()))
      end else begin
        m_drive_busy = 1'b1;
        `uvm_info(get_type_name(), {"Driving: ", tr.convert2string()}, UVM_HIGH)
        drive_one(tr);
        m_drive_busy = 1'b0;
      end
      seq_item_port.item_done();
    end
  endtask

  // ── Drive all outputs to safe de-asserted state ──────────────────────────
  protected task _drive_idle();
    vif.driver_cb.ifu_mmu_va_vld <= 1'b0;
    vif.driver_cb.ifu_mmu_va     <= 63'h0;
    vif.driver_cb.ifu_mmu_abort  <= 1'b0;
  endtask

  // ── Drive one IFU request transaction ────────────────────────────────────
  // IFU protocol: hold va_vld HIGH until DUT responds with pavld.
  // RTL: mmu_ifu_pavld is combinational from (ifu_mmu_va_vld && iutlb_addr_hit)
  //   among other paths.  After an L1 miss the refill FSM requests L2/PTW,
  //   and pavld fires only when the entry has been filled AND va_vld is held.
  //
  // IMPORTANT: Before asserting the new request we must wait one cycle with
  //   va_vld=0 so the combinational pavld from the PREVIOUS request is cleared.
  //   Without this guard the @(iff pavld===1) can trigger immediately on stale
  //   pavld → samples leftover PA (typically 0) from the previous de-assert
  //   window, producing a systematic "PA=0" mismatch for every IFU request.
  virtual task drive_one(ifu_txn tr);
    repeat (tr.idle_cycles) @(vif.driver_cb);

    // Ensure va_vld is LOW for at least one cycle before the new request.
    // This clears any residual combinational pavld from the prior transaction.
    vif.driver_cb.ifu_mmu_va_vld <= 1'b0;
    @(vif.driver_cb);

    // Assert the new request
    vif.driver_cb.ifu_mmu_va_vld <= 1'b1;
    vif.driver_cb.ifu_mmu_va     <= tr.va >> 1;
    vif.driver_cb.ifu_mmu_abort  <= tr.abort;
    `uvm_info(get_type_name(),
      $sformatf("[IFU_DRV_REQ_DBG] drive req: va=0x%010h abort=%0b pavld_now=%0b pa_now=0x%07h",
        {1'b0, tr.va[38:0]}, tr.abort, vif.driver_cb.mmu_ifu_pavld, vif.driver_cb.mmu_ifu_pa),
      UVM_DEBUG)

    if (tr.abort == 1'b1) begin
      @(vif.driver_cb);
      vif.driver_cb.ifu_mmu_va_vld <= 1'b0;
      vif.driver_cb.ifu_mmu_abort  <= 1'b0;
    end else begin
      @(vif.driver_cb);
      fork
        begin : wait_ifu_rsp
          // Hit responses can be visible immediately after the request cycle.
          // Miss responses require holding the same PC until pavld returns.
          if (vif.driver_cb.mmu_ifu_pavld !== 1'b1)
            @(vif.driver_cb iff vif.driver_cb.mmu_ifu_pavld === 1'b1);
          `uvm_info(get_type_name(),
            $sformatf("[IFU_DRV_RSP_EDGE_DBG] rsp edge: va=0x%010h pavld=%0b pa=0x%07h pgflt=%0b deny=%0b",
              {1'b0, tr.va[38:0]}, vif.driver_cb.mmu_ifu_pavld, vif.driver_cb.mmu_ifu_pa,
              vif.driver_cb.mmu_ifu_pgflt, vif.driver_cb.mmu_ifu_deny),
            UVM_DEBUG)
          tr.pa      = vif.driver_cb.mmu_ifu_pa;
          tr.pgflt   = vif.driver_cb.mmu_ifu_pgflt;
          tr.deny    = vif.driver_cb.mmu_ifu_deny;
          tr.sec     = vif.driver_cb.mmu_ifu_sec;
          tr.ca      = vif.driver_cb.mmu_ifu_ca;
          tr.buf_bit = vif.driver_cb.mmu_ifu_buf;
          tr.pavld   = 1'b1;
        end
        begin : wait_ifu_timeout
          repeat (4000) @(vif.driver_cb);
          `uvm_warning(get_type_name(),
            $sformatf("IFU response timeout: va=0x%016h va_vld=%0b pavld=%0b pa=0x%07h",
              {1'b0, tr.va}, vif.ifu_mmu_va_vld,
              vif.driver_cb.mmu_ifu_pavld, vif.driver_cb.mmu_ifu_pa))
        end
      join_any
      disable fork;
      @(vif.driver_cb);
      vif.driver_cb.ifu_mmu_va_vld <= 1'b0;
    end
  endtask

endclass : ifu_driver

`endif // IFU_DRIVER_SVH
