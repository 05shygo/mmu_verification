// =============================================================================
// MMU UVM Verification — testbench/misc_agent/misc_driver.svh
// Phase 5 (Engineer A): Misc driver
//
// Drives four groups of misc_if output signals via driver_cb clocking block:
//   RTU:  rtu_yy_xx_flush (single-cycle pulse), rtu_mmu_expt_vld + bad_vpn
//   HPCP: hpcp_mmu_cnt_en (level, default 1)
//   DFT:  pad_yy_icg_scan_en (level, default 0 — tie low in simulation)
//         biu_mmu_smp_disable (level, default 0)
//   IDLE: no signal change, advance one cycle
//
// Design note (D5-misc-1): biu_mmu_smp_disable and pad_yy_icg_scan_en are
// "static configuration" signals — they are driven once at startup and held
// until an explicit MISC_SMP_DISABLE / MISC_DFT_SCAN_EN transaction changes
// them.  The driver does NOT pulse them.
//
// Design note (D5-misc-2): rtu_yy_xx_flush is a single-cycle pulse.
// The driver asserts it for exactly one driver_cb cycle, then deasserts.
// =============================================================================
`ifndef MISC_DRIVER_SVH
`define MISC_DRIVER_SVH

class misc_driver extends uvm_driver #(misc_txn);

  `uvm_component_utils(misc_driver)

  virtual misc_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual misc_if)::get(this, "", "MISC_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get MISC_VIF from config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    misc_txn tr;
    _drive_idle();
    // Wait for reset de-assertion
    @(posedge vif.clk_i);
    wait (vif.rst_ni === 1'b1);
    @(posedge vif.clk_i);
    forever begin
      seq_item_port.get_next_item(tr);
      `uvm_info(get_type_name(), {"Driving: ", tr.convert2string()}, UVM_HIGH)
      drive_op(tr);
      seq_item_port.item_done();
    end
  endtask

  // ── Drive all outputs to safe default state ───────────────────────────────
  // Called once at startup (before reset de-assertion).
  // hpcp_cnt_en = 1 : keep performance counters enabled by default.
  // smp_disable  = 0 : no SMP bus attribute override.
  // scan_en      = 0 : DFT scan disabled in normal simulation.
  // flush / expt = 0 : no RTU events pending.
  protected task _drive_idle();
    vif.driver_cb.rtu_yy_xx_flush   <= 1'b0;
    vif.driver_cb.rtu_mmu_expt_vld  <= 1'b0;
    vif.driver_cb.rtu_mmu_bad_vpn   <= 27'h0;
    vif.driver_cb.hpcp_mmu_cnt_en   <= 1'b1;  // keep perf counters enabled
    vif.driver_cb.pad_yy_icg_scan_en<= 1'b0;  // DFT off in sim
    vif.driver_cb.biu_mmu_smp_disable<= 1'b0; // SMP coherent
  endtask

  // ── Dispatch based on operation type ─────────────────────────────────────
  virtual task drive_op(misc_txn tr);
    case (tr.op)
      MISC_RTU_FLUSH   : _do_rtu_flush(tr);
      MISC_RTU_EXPT    : _do_rtu_expt(tr);
      MISC_SMP_DISABLE : _do_smp_disable(tr);
      MISC_HPCP_CNT_EN : _do_hpcp_cnt_en(tr);
      MISC_DFT_SCAN_EN : _do_dft_scan_en(tr);
      MISC_IDLE        : _do_idle();
      default: `uvm_warning(get_type_name(),
                  $sformatf("Unknown misc_op_e: %0d", tr.op))
    endcase
  endtask

  // ── RTU pipeline flush (single-cycle pulse) ───────────────────────────────
  // Assert rtu_yy_xx_flush for one cycle when tr.flush_pulse=1.
  // Keep expt path untouched so tests can intentionally create flush/expt
  // misalignment through separate transactions.
  protected task _do_rtu_flush(misc_txn tr);
    @(vif.driver_cb);
    if (tr.flush_pulse) begin
      vif.driver_cb.rtu_yy_xx_flush <= 1'b1;
      @(vif.driver_cb);
      vif.driver_cb.rtu_yy_xx_flush <= 1'b0;
    end else begin
      // Allow "no-pulse" transaction to keep sequencing alignment without drive.
      vif.driver_cb.rtu_yy_xx_flush <= 1'b0;
    end
    // Keep one settle cycle for deterministic cleanup.
    @(vif.driver_cb);
  endtask

  // ── RTU exception injection (single-cycle pulse) ──────────────────────────
  // Assert rtu_mmu_expt_vld + bad_vpn for one cycle when tr.expt_vld=1.
  // If tr.expt_vld=0, keep the exception channel explicitly idle.
  protected task _do_rtu_expt(misc_txn tr);
    @(vif.driver_cb);
    if (tr.expt_vld) begin
      vif.driver_cb.rtu_mmu_expt_vld <= 1'b1;
      vif.driver_cb.rtu_mmu_bad_vpn  <= tr.bad_vpn;
      @(vif.driver_cb);
    end
    vif.driver_cb.rtu_mmu_expt_vld <= 1'b0;
    vif.driver_cb.rtu_mmu_bad_vpn  <= 27'h0;
    @(vif.driver_cb);  // settle cycle
  endtask

  // ── SMP disable (static level) ────────────────────────────────────────────
  // Drives biu_mmu_smp_disable to tr.smp_disable and holds the level.
  // Subsequent transactions keep the level until another MISC_SMP_DISABLE op.
  protected task _do_smp_disable(misc_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.biu_mmu_smp_disable <= tr.smp_disable;
    // No additional cycle needed; level is held until next transaction
  endtask

  // ── HPCP counter enable (level signal) ────────────────────────────────────
  protected task _do_hpcp_cnt_en(misc_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.hpcp_mmu_cnt_en <= tr.hpcp_cnt_en;
  endtask

  // ── DFT scan enable (normally 0; only used in DFT-specific tests) ─────────
  protected task _do_dft_scan_en(misc_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.pad_yy_icg_scan_en <= tr.dft_scan_en;
  endtask

  // ── Idle (no-op, advance one cycle) ───────────────────────────────────────
  protected task _do_idle();
    @(vif.driver_cb);
  endtask

endclass : misc_driver

`endif // MISC_DRIVER_SVH
