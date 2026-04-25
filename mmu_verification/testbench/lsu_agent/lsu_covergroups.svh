// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_covergroups.svh
// Phase 3 (Engineer B): LSU functional coverage (skeleton)
// Full coverpoint bins and cross coverage added in Phase 7.
// =============================================================================
`ifndef LSU_COVERGROUPS_SVH
`define LSU_COVERGROUPS_SVH

class lsu_cg_wrapper extends uvm_component;
  `uvm_component_utils(lsu_cg_wrapper)

  virtual lsu_if vif;

  // ── Pipe 0 request coverage ──────────────────────────────────────────────
  covergroup cg_pipe0_req;
    cp_va_high   : coverpoint vif.lsu_mmu_va0[38];  // user vs kernel
    cp_st_inst0  : coverpoint vif.lsu_mmu_st_inst0;
    cp_abort0    : coverpoint vif.lsu_mmu_abort0;
    cx_st_abort  : cross cp_st_inst0, cp_abort0;
  endgroup

  // ── Pipe 0 response coverage ─────────────────────────────────────────────
  covergroup cg_pipe0_rsp;
    cp_pgflt0    : coverpoint vif.mmu_lsu_page_fault0;
    cp_afault0   : coverpoint vif.mmu_lsu_access_fault0;
    cp_stall0    : coverpoint vif.mmu_lsu_stall0;
    cx_fault_stall : cross cp_pgflt0, cp_stall0;
  endgroup

  // ── Pipe 1 request coverage ──────────────────────────────────────────────
  covergroup cg_pipe1_req;
    cp_va_high1  : coverpoint vif.lsu_mmu_va1[38];
    cp_st_inst1  : coverpoint vif.lsu_mmu_st_inst1;
    cp_abort1    : coverpoint vif.lsu_mmu_abort1;
  endgroup

  // ── Pipe 2 (prefetch) coverage ───────────────────────────────────────────
  covergroup cg_pipe2;
    cp_pa2_vld  : coverpoint vif.mmu_lsu_pa2_vld;
    cp_pa2_err  : coverpoint vif.mmu_lsu_pa2_err;
    cp_share2   : coverpoint vif.mmu_lsu_share2;
  endgroup

  // ── TLB invalidation coverage ────────────────────────────────────────────
  covergroup cg_inv;
    cp_all_inv      : coverpoint vif.lsu_mmu_tlb_all_inv;
    cp_va_all_inv   : coverpoint vif.lsu_mmu_tlb_va_all_inv;
    cp_asid_all_inv : coverpoint vif.lsu_mmu_tlb_asid_all_inv;
    cp_va_asid_inv  : coverpoint vif.lsu_mmu_tlb_va_asid_inv;
    cp_inv_done     : coverpoint vif.mmu_lsu_tlb_inv_done;
  endgroup

  // ── L1DTLB→LSU broadcast coverage ───────────────────────────────────────
  covergroup cg_tlb_status;
    cp_tlb_busy   : coverpoint vif.mmu_lsu_tlb_busy;
    cp_wakeup_kind : coverpoint vif.mmu_lsu_tlb_wakeup {
      bins none      = {12'h000};
      bins broadcast = {12'hfff};
      bins targeted  = {[12'h001:12'hffe]};
    }
    cp_mmu_en     : coverpoint vif.mmu_lsu_mmu_en;
    cx_busy_en    : cross cp_tlb_busy, cp_mmu_en;
    cx_busy_wakeup : cross cp_tlb_busy, cp_wakeup_kind;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_pipe0_req  = new();
    cg_pipe0_rsp  = new();
    cg_pipe1_req  = new();
    cg_pipe2      = new();
    cg_inv        = new();
    cg_tlb_status = new();
  endfunction

  // Call from lsu_agent.connect_phase AFTER vif is assigned
  virtual function void set_vif(virtual lsu_if v);
    vif = v;
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk_i);
      if (vif.lsu_mmu_va0_vld)        cg_pipe0_req.sample();
      if (vif.mmu_lsu_pa0_vld)        cg_pipe0_rsp.sample();
      if (vif.lsu_mmu_va1_vld)        cg_pipe1_req.sample();
      if (vif.lsu_mmu_va2_vld |
          vif.mmu_lsu_pa2_vld)        cg_pipe2.sample();
      if (vif.lsu_mmu_tlb_all_inv      |
          vif.lsu_mmu_tlb_va_all_inv   |
          vif.lsu_mmu_tlb_asid_all_inv |
          vif.lsu_mmu_tlb_va_asid_inv) cg_inv.sample();
      cg_tlb_status.sample();
    end
  endtask

endclass : lsu_cg_wrapper

`endif // LSU_COVERGROUPS_SVH
