// =============================================================================
// MMU UVM Verification — testbench/cp0_agent/cp0_covergroups.svh
// Phase 3: CP0 functional coverage (skeleton — full coverpoints in Phase 7)
// =============================================================================
`ifndef CP0_COVERGROUPS_SVH
`define CP0_COVERGROUPS_SVH

class cp0_cg_wrapper extends uvm_component;
  `uvm_component_utils(cp0_cg_wrapper)

  virtual cp0_if vif;

  // ── CSR write operations ─────────────────────────────────────────────────
  // Sampled manually via sample_csr_write()
  covergroup cg_cp0_ops;
    cp_reg_num   : coverpoint vif.cp0_mmu_reg_num;
    cp_satp_sel  : coverpoint vif.cp0_mmu_satp_sel;
    cp_priv_mode : coverpoint vif.cp0_yy_priv_mode {
      bins U = {2'b00}; bins S = {2'b01}; bins M = {2'b11};
    }
    cx_op_priv   : cross cp_reg_num, cp_priv_mode;
  endgroup

  // ── Permission CSR bit combinations ──────────────────────────────────────
  covergroup cg_cp0_perms;
    cp_mxr    : coverpoint vif.cp0_mmu_mxr;
    cp_sum    : coverpoint vif.cp0_mmu_sum;
    cp_mprv   : coverpoint vif.cp0_mmu_mprv;
    cp_ptw_en : coverpoint vif.cp0_mmu_ptw_en;
    cp_maee   : coverpoint vif.cp0_mmu_maee;
    cx_mxr_sum : cross cp_mxr, cp_sum;
  endgroup

  // ── Global enable broadcast ───────────────────────────────────────────────
  covergroup cg_cp0_global;
    cp_mmu_en    : coverpoint vif.mmu_xx_mmu_en;
    cp_no_op     : coverpoint vif.mmu_yy_xx_no_op;
    cp_tlb_done  : coverpoint vif.mmu_cp0_tlb_done;
    cx_en_no_op  : cross cp_mmu_en, cp_no_op;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // Call from cp0_agent.connect_phase AFTER vif is assigned
  virtual function void set_vif(virtual cp0_if v);
    vif         = v;
    cg_cp0_ops   = new();
    cg_cp0_perms = new();
    cg_cp0_global= new();
  endfunction

  // Manual sample hooks (called from run_phase or analysis write)
  virtual function void sample_csr_write();
    if (cg_cp0_ops   != null) cg_cp0_ops.sample();
    if (cg_cp0_perms != null) cg_cp0_perms.sample();
  endfunction

  virtual function void sample_global();
    if (cg_cp0_global != null) cg_cp0_global.sample();
  endfunction

  virtual task run_phase(uvm_phase phase);
    // Periodic global sampling (every 10 cycles to track enable state)
    forever begin
      @(posedge vif.clk_i);
      sample_global();
    end
  endtask

endclass : cp0_cg_wrapper

`endif // CP0_COVERGROUPS_SVH
