// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_driver.svh
// Phase 3 (Engineer B): IFU driver skeleton
// Drives ifu_mmu_va_vld / ifu_mmu_va / ifu_mmu_abort via clocking block.
//
// Phase 3 implementation: single-cycle va_vld pulse (skeleton).
// TODO (Phase 5): Implement full handshake protocol:
//   1. Insert idle_cycles idle beats before asserting request
//   2. Assert ifu_mmu_va_vld + present VA; hold until mmu_ifu_pavld/pgflt/deny
//   3. De-assert valid after response
//   4. Handle abort: assert ifu_mmu_abort one cycle to cancel in-flight request
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
    // Insert inter-request idle gap
    repeat (tr.idle_cycles) @(vif.driver_cb);
    // Assert request for one cycle
    @(vif.driver_cb);
    vif.driver_cb.ifu_mmu_va_vld <= 1'b1;
    vif.driver_cb.ifu_mmu_va     <= tr.va;
    vif.driver_cb.ifu_mmu_abort  <= tr.abort;
    @(vif.driver_cb);
    // De-assert
    vif.driver_cb.ifu_mmu_va_vld <= 1'b0;
    vif.driver_cb.ifu_mmu_abort  <= 1'b0;
    // TODO (Phase 5): wait for mmu_ifu_pavld and fill tr.pa / tr.pgflt / tr.deny
  endtask

endclass : ifu_driver

`endif // IFU_DRIVER_SVH
