// =============================================================================
// MMU UVM Verification — testbench/cp0_agent/cp0_driver.svh
// Phase 3: CP0/CSR driver — drives all cp0_mmu_* signals via clocking block
// =============================================================================
`ifndef CP0_DRIVER_SVH
`define CP0_DRIVER_SVH

class cp0_driver extends uvm_driver #(cp0_txn);

  `uvm_component_utils(cp0_driver)

  virtual cp0_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual cp0_if)::get(this, "", "CP0_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get CP0_VIF from config_db")
  endfunction

  virtual task run_phase(uvm_phase phase);
    cp0_txn tr;
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

  // ── Drive all outputs to safe default state ─────────────────────────────
  protected task _drive_idle();
    vif.driver_cb.cp0_mmu_wreg        <= 1'b0;
    vif.driver_cb.cp0_mmu_reg_num     <= 2'b00;
    vif.driver_cb.cp0_mmu_satp_sel    <= 1'b0;
    vif.driver_cb.cp0_mmu_wdata       <= 64'h0;
    vif.driver_cb.cp0_mmu_cskyee      <= 1'b0;
    vif.driver_cb.cp0_mmu_icg_en      <= 1'b1;  // keep clocks running
    vif.driver_cb.cp0_mmu_maee        <= 1'b0;
    vif.driver_cb.cp0_mmu_mpp         <= 2'b11; // default M-mode
    vif.driver_cb.cp0_mmu_mprv        <= 1'b0;
    vif.driver_cb.cp0_mmu_mxr         <= 1'b0;
    vif.driver_cb.cp0_mmu_no_op_req   <= 1'b0;
    vif.driver_cb.cp0_mmu_ptw_en      <= 1'b1;  // PTW enabled
    vif.driver_cb.cp0_mmu_sum         <= 1'b0;
    vif.driver_cb.cp0_mmu_tlb_all_inv <= 1'b0;
    vif.driver_cb.cp0_yy_priv_mode    <= 2'b11; // M-mode
  endtask

  // ── Dispatch based on operation type ─────────────────────────────────────
  virtual task drive_op(cp0_txn tr);
    case (tr.op)
      CP0_WRITE_SATP   : _do_write_satp(tr);
      CP0_READ_SATP    : _do_read_satp(tr);
      CP0_WRITE_REG    : _do_write_reg(tr);
      CP0_READ_REG     : _do_read_reg(tr);
      CP0_SET_PRIV     : _do_set_priv(tr);
      CP0_SET_MXR      : _do_set_mxr(tr);
      CP0_SET_SUM      : _do_set_sum(tr);
      CP0_SET_MPRV_MPP : _do_set_mprv_mpp(tr);
      CP0_SET_PTW_EN   : _do_set_ptw_en(tr);
      CP0_SET_NO_OP    : _do_set_no_op(tr);
      CP0_SET_MAEE     : _do_set_maee(tr);
      CP0_SET_ICG_EN   : _do_set_icg_en(tr);
      CP0_SET_CSKYEE   : _do_set_cskyee(tr);
      CP0_TLB_ALL_INV  : _do_tlb_all_inv(tr);
      default: `uvm_warning(get_type_name(),
                  $sformatf("Unknown cp0_op_e: %0d", tr.op))
    endcase
  endtask

  // ── SATP Write ───────────────────────────────────────────────────────────
  // RTL: satp_write_en = cp0_mmu_satp_sel  (line 225 of ct_mmu_regs.v)
  // SATP is written by asserting cp0_mmu_satp_sel=1 for ONE cycle with
  // cp0_mmu_wdata valid.  cp0_mmu_wreg / reg_num are NOT involved in SATP
  // writes (reg_num 0-3 address MIR/MEL/MEH/MCIR, not SATP).
  // No cmplt pulse is generated — wait one settle cycle after de-assert.
  protected task _do_write_satp(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_satp_sel <= 1'b1;   // write-enable: satp_write_en=1
    vif.driver_cb.cp0_mmu_wdata    <= tr.wdata;
    @(vif.driver_cb);                          // gated clock fires, SATP latched
    vif.driver_cb.cp0_mmu_satp_sel <= 1'b0;   // de-assert write-enable
    vif.driver_cb.cp0_mmu_wdata    <= 64'h0;
    @(vif.driver_cb);                          // settle cycle
    tr.cmplt = 1'b1;
  endtask

  // ── SATP Read (sample read-back) ─────────────────────────────────────────
  protected task _do_read_satp(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_satp_sel <= tr.satp_sel;
    @(vif.driver_cb);
    tr.rdata = vif.driver_cb.mmu_cp0_satp_data;
    tr.cmplt = 1'b1;
  endtask

  // ── Generic Register Write (mir/mel/meh/mcir) ───────────────────────────
  // RTL mmu_cp0_cmplt = tlboper_regs_cmplt | mcir_no_op
  // Only MCIR (reg_num==3) writes generate cmplt. MIR/MEL/MEH writes latch
  // combinationally and never assert cmplt — waiting for it hangs forever.
  protected task _do_write_reg(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_wreg    <= 1'b1;
    vif.driver_cb.cp0_mmu_reg_num <= tr.reg_num;
    vif.driver_cb.cp0_mmu_wdata   <= tr.wdata;
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_wreg    <= 1'b0;
    if (tr.reg_num == 2'd3) begin  // MCIR — RTL generates cmplt
      @(vif.driver_cb iff vif.driver_cb.mmu_cp0_cmplt);
    end else begin                 // MIR/MEL/MEH — one settle cycle only
      @(vif.driver_cb);
    end
    tr.cmplt = 1'b1;
    tr.rdata = vif.driver_cb.mmu_cp0_data;
  endtask

  // ── Generic Register Read ─────────────────────────────────────────────────
  protected task _do_read_reg(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_reg_num <= tr.reg_num;
    @(vif.driver_cb);
    tr.rdata = vif.driver_cb.mmu_cp0_data;
    tr.cmplt = 1'b1;
  endtask

  // ── Level-change setters (take effect from next cycle) ───────────────────
  protected task _do_set_priv(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_yy_priv_mode <= tr.priv_mode;
  endtask

  protected task _do_set_mxr(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_mxr <= tr.mxr;
  endtask

  protected task _do_set_sum(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_sum <= tr.sum;
  endtask

  protected task _do_set_mprv_mpp(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_mprv <= tr.mprv;
    vif.driver_cb.cp0_mmu_mpp  <= tr.mpp;
  endtask

  protected task _do_set_ptw_en(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_ptw_en <= tr.ptw_en;
  endtask

  protected task _do_set_no_op(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_no_op_req <= tr.no_op_req;
  endtask

  protected task _do_set_maee(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_maee <= tr.maee;
  endtask

  protected task _do_set_icg_en(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_icg_en <= tr.icg_en;
  endtask

  protected task _do_set_cskyee(cp0_txn tr);
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_cskyee <= tr.cskyee;
  endtask

  // ── CP0-path TLB global invalidate (pulse + wait for tlb_done) ───────────
  // RTL: tlb_invall_cmplt fires when state==IALL_WFC && tlb_inv_cnt==0.
  // Guard with 512-cycle timeout in case the state machine was not idle
  // (e.g., concurrent LSU invalidate) and the pulse was missed.
  protected task _do_tlb_all_inv(cp0_txn tr);
    bit done;
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_tlb_all_inv <= 1'b1;
    @(vif.driver_cb);
    vif.driver_cb.cp0_mmu_tlb_all_inv <= 1'b0;
    done = 0;
    fork
      begin
        @(vif.driver_cb iff vif.driver_cb.mmu_cp0_tlb_done);
        done = 1;
      end
      begin
        repeat (512) @(vif.driver_cb);
      end
    join_any
    disable fork;
    if (!done)
      `uvm_warning(get_type_name(),
        "_do_tlb_all_inv: mmu_cp0_tlb_done not seen within 512 cycles — TLB SM may have missed the pulse")
    tr.tlb_done = done;
  endtask

endclass : cp0_driver

`endif // CP0_DRIVER_SVH
