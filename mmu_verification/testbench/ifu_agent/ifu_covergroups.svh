// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_covergroups.svh
// Phase 3 (Engineer B): IFU functional coverage (skeleton)
// Full coverpoint bins and cross coverage added in Phase 7.
// =============================================================================
`ifndef IFU_COVERGROUPS_SVH
`define IFU_COVERGROUPS_SVH

class ifu_cg_wrapper extends uvm_component;
  `uvm_component_utils(ifu_cg_wrapper)

  virtual ifu_if vif;

  // ── IFU request coverage ─────────────────────────────────────────────────
  // Sampled on each ifu_mmu_va_vld assertion
  covergroup cg_ifu_req;
    // VA canonical bit[38]: 0 = user space, 1 = kernel space
    cp_va_high   : coverpoint vif.ifu_mmu_va[38] {
      bins user   = {1'b0};
      bins kernel = {1'b1};
    }
    // Abort during fetch
    cp_abort     : coverpoint vif.ifu_mmu_abort;
    // VPN[1] zero (may indicate huge-page boundary)
    cp_vpn1_zero : coverpoint (vif.ifu_mmu_va[29:21] == 9'h0);
  endgroup

  // ── IFU response coverage ────────────────────────────────────────────────
  // Sampled on each mmu_ifu_pavld assertion
  covergroup cg_ifu_rsp;
    cp_pgflt : coverpoint vif.mmu_ifu_pgflt;
    cp_deny  : coverpoint vif.mmu_ifu_deny;
    cp_sec   : coverpoint vif.mmu_ifu_sec;
    cp_ca    : coverpoint vif.mmu_ifu_ca;
    // Both pgflt and deny (deny wins in DUT priority)
    cx_fault_deny : cross cp_pgflt, cp_deny;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_ifu_req = new();
    cg_ifu_rsp = new();
  endfunction

  // Call from ifu_agent.connect_phase AFTER vif is assigned
  virtual function void set_vif(virtual ifu_if v);
    vif = v;
  endfunction

  // Manual sample hooks (also called from run_phase)
  virtual function void sample_req();
    if (cg_ifu_req != null) cg_ifu_req.sample();
  endfunction

  virtual function void sample_rsp();
    if (cg_ifu_rsp != null) cg_ifu_rsp.sample();
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk_i);
      if (vif.ifu_mmu_va_vld) sample_req();
      if (vif.mmu_ifu_pavld)  sample_rsp();
    end
  endtask

endclass : ifu_cg_wrapper

`endif // IFU_COVERGROUPS_SVH
