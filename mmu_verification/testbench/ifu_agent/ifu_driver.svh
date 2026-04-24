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
  virtual task drive_one(ifu_txn tr);
    // 1. Insert inter-request idle gap
    repeat (tr.idle_cycles) @(vif.driver_cb);

    // 2. Assert request and HOLD va_vld until MMU responds (or abort)
    //    RTL IFU-MMU protocol: va_vld must remain high while MMU processes
    //    the request (especially during TLB miss + PTW).  This mirrors the
    //    LSU hold-until-pa_vld protocol.  De-assert occurs after pavld fires.
    @(vif.driver_cb);
    vif.driver_cb.ifu_mmu_va_vld <= 1'b1;
    vif.driver_cb.ifu_mmu_va     <= tr.va >> 1;  // ifu_mmu_va = VA[63:1]; DUT extracts VPN = va[37:11] = VA[38:12]
    vif.driver_cb.ifu_mmu_abort  <= tr.abort;

    // 3. Wait for MMU response (skip if this is an abort transaction)
    if (tr.abort == 1'b0) begin
      fork
        begin : wait_ifu_rsp
          @(vif.driver_cb iff vif.driver_cb.mmu_ifu_pavld === 1'b1);
          tr.pa      = vif.driver_cb.mmu_ifu_pa;
          tr.pgflt   = vif.driver_cb.mmu_ifu_pgflt;
          tr.deny    = vif.driver_cb.mmu_ifu_deny;
          tr.sec     = vif.driver_cb.mmu_ifu_sec;
          tr.ca      = vif.driver_cb.mmu_ifu_ca;
          tr.buf_bit = vif.driver_cb.mmu_ifu_buf;
          tr.pavld   = 1'b1;
        end
        begin : wait_ifu_timeout
          repeat (2000) @(vif.driver_cb);
          `uvm_warning(get_type_name(),
            $sformatf("IFU response timeout: va=0x%016h", {1'b0, tr.va}))
        end
      join_any
      disable fork;
    end

    // 4. De-assert va_vld one cycle after response received (or after abort)
    @(vif.driver_cb);
    vif.driver_cb.ifu_mmu_va_vld <= 1'b0;
    vif.driver_cb.ifu_mmu_abort  <= 1'b0;
  endtask

endclass : ifu_driver

`endif // IFU_DRIVER_SVH
