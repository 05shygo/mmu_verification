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
    join_none
  endtask

  // ── Collect CSR write transactions (cp0_mmu_wreg=1) ─────────────────────
  protected task _collect_csr_writes();
    cp0_txn tr;
    forever begin
      // Wait for a write strobe
      @(vif.monitor_cb iff vif.monitor_cb.cp0_mmu_wreg);
      tr = cp0_txn::type_id::create("csr_wr_mon");
      // Determine op type from reg_num
      if (vif.monitor_cb.cp0_mmu_reg_num == 2'b00)
        tr.op = CP0_WRITE_SATP;
      else
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

endclass : cp0_monitor

`endif // CP0_MONITOR_SVH
