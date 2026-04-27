// =============================================================================
// MMU UVM Verification — testbench/cp0_agent/cp0_monitor.svh
// Phase 3: CP0/CSR monitor — observes CSR writes and TLBOper completions
// Analysis port feeds: ref_model.af_csr_write + invalidate_sb.af_cp0 (Phase 5)
// =============================================================================
`ifndef CP0_MONITOR_SVH
`define CP0_MONITOR_SVH

class cp0_monitor extends uvm_monitor;

  `uvm_component_utils(cp0_monitor)

  virtual cp0_if vif;

  // Single analysis port — broadcasts all observed transactions.
  // Downstream connections (Phase 5+):
  //   ap → invalidate_sb.af_cp0     (TLB invalidate events)
  //   ap → m_ref.af_csr_write       (CSR state update for ref_model)
  uvm_analysis_port #(cp0_txn) ap;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual cp0_if)::get(this, "", "CP0_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get CP0_VIF from config_db")
    ap = new("ap", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      _collect_csr_writes();
      _collect_tlb_done();
      _collect_satp_writes();
      _collect_level_changes();
    join_none
  endtask

  // ── Collect CSR write transactions (cp0_mmu_wreg=1) ─────────────────────
  protected task _collect_csr_writes();
    cp0_txn tr;
    forever begin
      // Wait for a write strobe
      @(vif.monitor_cb iff vif.monitor_cb.cp0_mmu_wreg);
      tr = cp0_txn::type_id::create("csr_wr_mon");
      // SATP writes do not use cp0_mmu_wreg; they are sampled separately from
      // cp0_mmu_satp_sel. Any cp0_mmu_wreg pulse is a MIR/MEL/MEH/MCIR access.
      tr.op = CP0_WRITE_REG;
      tr.reg_num   = vif.monitor_cb.cp0_mmu_reg_num;
      tr.satp_sel  = vif.monitor_cb.cp0_mmu_satp_sel;
      tr.wdata     = vif.monitor_cb.cp0_mmu_wdata;
      // Capture current permission context
      tr.mxr       = vif.monitor_cb.cp0_mmu_mxr;
      tr.sum       = vif.monitor_cb.cp0_mmu_sum;
      tr.mprv      = vif.monitor_cb.cp0_mmu_mprv;
      tr.mpp       = vif.monitor_cb.cp0_mmu_mpp;
      tr.ptw_en    = vif.monitor_cb.cp0_mmu_ptw_en;
      tr.no_op_req = vif.monitor_cb.cp0_mmu_no_op_req;
      tr.maee      = vif.monitor_cb.cp0_mmu_maee;
      tr.priv_mode = vif.monitor_cb.cp0_yy_priv_mode;
      tr.icg_en    = vif.monitor_cb.cp0_mmu_icg_en;
      tr.cskyee    = vif.monitor_cb.cp0_mmu_cskyee;
      // Wait for completion acknowledge (or timeout after 64 cycles)
      begin
        int unsigned timeout_cnt = 0;
        fork
          begin
            @(vif.monitor_cb iff vif.monitor_cb.mmu_cp0_cmplt);
            tr.cmplt = 1'b1;
            tr.rdata = vif.monitor_cb.mmu_cp0_data;
          end
          begin
            repeat (64) @(vif.monitor_cb);
          end
        join_any
        disable fork;
      end
      `uvm_info(get_type_name(), {"Observed CSR write: ", tr.convert2string()}, UVM_HIGH)
      ap.write(tr);
    end
  endtask

  // ── Collect TLBOper completion events ────────────────────────────────────
  protected task _collect_tlb_done();
    cp0_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.mmu_cp0_tlb_done);
      tr           = cp0_txn::type_id::create("tlb_done_mon");
      tr.op        = CP0_TLB_ALL_INV;
      tr.tlb_done  = 1'b1;
      tr.priv_mode = vif.monitor_cb.cp0_yy_priv_mode;
      `uvm_info(get_type_name(), "Observed TLB-done", UVM_HIGH)
      ap.write(tr);
    end
  endtask

  // ── Collect SATP write events (cp0_mmu_satp_sel pulse) ───────────────────
  // cp0_mmu_satp_sel is the SATP write-enable strobe (RTL has a single SATP
  // storage path).  Publish a dedicated CP0_WRITE_SATP event and include the
  // same-cycle CP0 context snapshot so ref_model can keep its mirror coherent
  // even when SATP / priv / no_op changes happen close together.
  protected task _collect_satp_writes();
    cp0_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.cp0_mmu_satp_sel);
      tr          = cp0_txn::type_id::create("satp_wr_mon");
      tr.op       = CP0_WRITE_SATP;
      tr.satp_sel = 1'b0;
      tr.wdata    = vif.monitor_cb.cp0_mmu_wdata;
      tr.mxr       = vif.monitor_cb.cp0_mmu_mxr;
      tr.sum       = vif.monitor_cb.cp0_mmu_sum;
      tr.mprv      = vif.monitor_cb.cp0_mmu_mprv;
      tr.mpp       = vif.monitor_cb.cp0_mmu_mpp;
      tr.ptw_en    = vif.monitor_cb.cp0_mmu_ptw_en;
      tr.no_op_req = vif.monitor_cb.cp0_mmu_no_op_req;
      tr.maee      = vif.monitor_cb.cp0_mmu_maee;
      tr.priv_mode = vif.monitor_cb.cp0_yy_priv_mode;
      tr.icg_en    = vif.monitor_cb.cp0_mmu_icg_en;
      tr.cskyee    = vif.monitor_cb.cp0_mmu_cskyee;
      `uvm_info(get_type_name(),
        $sformatf("Observed SATP write: wdata=0x%016h", tr.wdata), UVM_HIGH)
      ap.write(tr);
      // Edge detection: wait for satp_sel to deassert before next iteration
      @(vif.monitor_cb iff !vif.monitor_cb.cp0_mmu_satp_sel);
    end
  endtask

  // ── Collect level-signal changes ─────────────────────────────────────────
  // Monitors signals that are driven as persistent levels (not pulse/wreg):
  //   cp0_yy_priv_mode, cp0_mmu_ptw_en, cp0_mmu_mxr, cp0_mmu_sum,
  //   cp0_mmu_mprv, cp0_mmu_mpp, cp0_mmu_maee, cp0_mmu_no_op_req
  // On each change, publishes the corresponding cp0_txn so that the ref_model
  // TLM FIFO consumer (on_csr_write) can update its CSR mirror state.
  protected task _collect_level_changes();
    bit [1:0] prev_priv   = 2'b11;  // default M-mode (matches _drive_idle)
    bit       prev_ptw_en = 1'b1;
    bit       prev_mxr    = 1'b0;
    bit       prev_sum    = 1'b0;
    bit       prev_mprv   = 1'b0;
    bit [1:0] prev_mpp    = 2'b11;
    bit       prev_maee   = 1'b0;
    bit       prev_no_op  = 1'b0;
    cp0_txn tr;

    forever begin
      @(vif.monitor_cb);

      // priv_mode change → CP0_SET_PRIV
      if (vif.monitor_cb.cp0_yy_priv_mode !== prev_priv) begin
        tr = cp0_txn::type_id::create("priv_mon");
        tr.op        = CP0_SET_PRIV;
        tr.priv_mode = vif.monitor_cb.cp0_yy_priv_mode;
        prev_priv    = vif.monitor_cb.cp0_yy_priv_mode;
        `uvm_info(get_type_name(),
          $sformatf("Observed priv_mode change → %02b", tr.priv_mode), UVM_HIGH)
        ap.write(tr);
      end

      // ptw_en change → CP0_SET_PTW_EN
      if (vif.monitor_cb.cp0_mmu_ptw_en !== prev_ptw_en) begin
        tr = cp0_txn::type_id::create("ptwen_mon");
        tr.op     = CP0_SET_PTW_EN;
        tr.ptw_en = vif.monitor_cb.cp0_mmu_ptw_en;
        prev_ptw_en = vif.monitor_cb.cp0_mmu_ptw_en;
        ap.write(tr);
      end

      // mxr change → CP0_SET_MXR
      if (vif.monitor_cb.cp0_mmu_mxr !== prev_mxr) begin
        tr = cp0_txn::type_id::create("mxr_mon");
        tr.op  = CP0_SET_MXR;
        tr.mxr = vif.monitor_cb.cp0_mmu_mxr;
        prev_mxr = vif.monitor_cb.cp0_mmu_mxr;
        ap.write(tr);
      end

      // sum change → CP0_SET_SUM
      if (vif.monitor_cb.cp0_mmu_sum !== prev_sum) begin
        tr = cp0_txn::type_id::create("sum_mon");
        tr.op  = CP0_SET_SUM;
        tr.sum = vif.monitor_cb.cp0_mmu_sum;
        prev_sum = vif.monitor_cb.cp0_mmu_sum;
        ap.write(tr);
      end

      // mprv or mpp change → CP0_SET_MPRV_MPP
      if (vif.monitor_cb.cp0_mmu_mprv !== prev_mprv ||
          vif.monitor_cb.cp0_mmu_mpp  !== prev_mpp) begin
        tr = cp0_txn::type_id::create("mprv_mon");
        tr.op   = CP0_SET_MPRV_MPP;
        tr.mprv = vif.monitor_cb.cp0_mmu_mprv;
        tr.mpp  = vif.monitor_cb.cp0_mmu_mpp;
        prev_mprv = vif.monitor_cb.cp0_mmu_mprv;
        prev_mpp  = vif.monitor_cb.cp0_mmu_mpp;
        ap.write(tr);
      end

      // maee change → CP0_SET_MAEE
      if (vif.monitor_cb.cp0_mmu_maee !== prev_maee) begin
        tr = cp0_txn::type_id::create("maee_mon");
        tr.op   = CP0_SET_MAEE;
        tr.maee = vif.monitor_cb.cp0_mmu_maee;
        prev_maee = vif.monitor_cb.cp0_mmu_maee;
        ap.write(tr);
      end

      // no_op_req change → CP0_SET_NO_OP
      if (vif.monitor_cb.cp0_mmu_no_op_req !== prev_no_op) begin
        tr = cp0_txn::type_id::create("noop_mon");
        tr.op        = CP0_SET_NO_OP;
        tr.no_op_req = vif.monitor_cb.cp0_mmu_no_op_req;
        prev_no_op   = vif.monitor_cb.cp0_mmu_no_op_req;
        ap.write(tr);
      end

    end
  endtask

endclass : cp0_monitor

`endif // CP0_MONITOR_SVH
