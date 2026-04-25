// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_driver.svh
// Phase 5 (Engineer B): IFU driver — full handshake implementation
// Drives ifu_mmu_va_vld / ifu_mmu_va / ifu_mmu_abort via clocking block.
//
// Protocol:
//   1. Insert idle_cycles idle beats before asserting request
//   2. Assert ifu_mmu_va_vld=1 + va + abort for exactly 1 cycle
//   3. De-assert va_vld / abort
//   4. If abort==0: fork { wait mmu_ifu_pavld → fill response fields }
//                       / { 2000-cycle timeout → UVM_WARNING }
//                  join_any; disable fork
// =============================================================================
`ifndef IFU_DRIVER_SVH
`define IFU_DRIVER_SVH

class ifu_driver extends uvm_driver #(ifu_txn);

  `uvm_component_utils(ifu_driver)

  virtual ifu_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual ifu_if)::get(this, "", "IFU_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get IFU_VIF from config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    ifu_txn tr;
    _drive_idle();
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(posedge vif.clk_i);
    forever begin
      seq_item_port.get_next_item(tr);
      `uvm_info(get_type_name(), {"Driving: ", tr.convert2string()}, UVM_HIGH)
      drive_one(tr);
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
      UVM_MEDIUM)

    if (tr.abort == 1'b1) begin
      @(vif.driver_cb);
      vif.driver_cb.ifu_mmu_va_vld <= 1'b0;
      vif.driver_cb.ifu_mmu_abort  <= 1'b0;
    end else begin
      @(vif.driver_cb);
      fork
        begin : wait_ifu_rsp
          // Avoid level-sensitive false trigger on stale pavld=1:
          // first wait until pavld is observed low, then wait for next high.
          // This enforces one clean low->high response edge per request.
          @(vif.driver_cb iff vif.driver_cb.mmu_ifu_pavld === 1'b0);
          @(vif.driver_cb iff vif.driver_cb.mmu_ifu_pavld === 1'b1);
          `uvm_info(get_type_name(),
            $sformatf("[IFU_DRV_RSP_EDGE_DBG] rsp edge: va=0x%010h pavld=%0b pa=0x%07h pgflt=%0b deny=%0b",
              {1'b0, tr.va[38:0]}, vif.driver_cb.mmu_ifu_pavld, vif.driver_cb.mmu_ifu_pa,
              vif.driver_cb.mmu_ifu_pgflt, vif.driver_cb.mmu_ifu_deny),
            UVM_MEDIUM)
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
