// =============================================================================
// MMU UVM Verification — testbench/pmp_agent/pmp_driver.svh
// Phase 3: PMP responder driver — drives 8 × pmp_mmu_flg{0..7} via CB
// The PMP agent is a Responder: it drives flag inputs into the DUT and
// observes the DUT's PA outputs / fetch enables.
// =============================================================================
`ifndef PMP_DRIVER_SVH
`define PMP_DRIVER_SVH

class pmp_driver extends uvm_driver #(pmp_txn);

  `uvm_component_utils(pmp_driver)

  virtual pmp_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual pmp_if)::get(this, "", "PMP_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get PMP_VIF from config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    pmp_txn tr;
    _drive_idle();
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(posedge vif.clk_i);
    forever begin
      seq_item_port.get_next_item(tr);
      `uvm_info(get_type_name(), {"Driving PMP: ", tr.convert2string()}, UVM_HIGH)
      _drive_flg(tr);
      seq_item_port.item_done();
    end
  endtask

  // R/W/X allow on lower bits; 4'h0 denies PTW table loads in S-mode (twu PMP)
  protected task _drive_idle();
    vif.driver_cb.pmp_mmu_flg0 <= 4'h7;
    vif.driver_cb.pmp_mmu_flg1 <= 4'h7;
    vif.driver_cb.pmp_mmu_flg2 <= 4'h7;
    vif.driver_cb.pmp_mmu_flg3 <= 4'h7;
    vif.driver_cb.pmp_mmu_flg4 <= 4'h7;
    vif.driver_cb.pmp_mmu_flg5 <= 4'h7;
    vif.driver_cb.pmp_mmu_flg6 <= 4'h7;
    vif.driver_cb.pmp_mmu_flg7 <= 4'h7;
  endtask

  // ── Drive all 8 flag ports from transaction ───────────────────────────────
  protected task _drive_flg(pmp_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.pmp_mmu_flg0 <= tr.flg[0];
    vif.driver_cb.pmp_mmu_flg1 <= tr.flg[1];
    vif.driver_cb.pmp_mmu_flg2 <= tr.flg[2];
    vif.driver_cb.pmp_mmu_flg3 <= tr.flg[3];
    vif.driver_cb.pmp_mmu_flg4 <= tr.flg[4];
    vif.driver_cb.pmp_mmu_flg5 <= tr.flg[5];
    vif.driver_cb.pmp_mmu_flg6 <= tr.flg[6];
    vif.driver_cb.pmp_mmu_flg7 <= tr.flg[7];
  endtask

endclass : pmp_driver

`endif // PMP_DRIVER_SVH
