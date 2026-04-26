// =============================================================================
// MMU UVM Verification — testbench/ifu_agent/ifu_covergroups.svh
// Phase 7: §10.1 黑盒 covergroup 对齐 BuildPlan 表（cg_ifu_req / cg_ifu_rsp）
// =============================================================================
`ifndef IFU_COVERGROUPS_SVH
`define IFU_COVERGROUPS_SVH

class ifu_cg_wrapper extends uvm_component;
  `uvm_component_utils(ifu_cg_wrapper)

  virtual ifu_if vif;

  // 采样：ifu_mmu_va_vld=1 的拍（BuildPlan: posedge clk iff ifu_mmu_va_vld）
  // cp_va_seg: va[62:39] 分四档（高位地址窗）
  // cp_abort: 取指放弃
  covergroup cg_ifu_req;
    option.per_instance = 1;
    cp_va_seg: coverpoint vif.ifu_mmu_va[62:39] {
      bins b0 = {[24'h0             : 24'h3F_FFFF]};
      bins b1 = {[24'h40_0000       : 24'h7F_FFFF]};
      bins b2 = {[24'h80_0000       : 24'hBF_FFFF]};
      bins b3 = {[24'hC0_0000       : 24'hFF_FFFF]};
    }
    cp_abort: coverpoint vif.ifu_mmu_abort;
  endgroup

  // 采样：mmu_ifu_pavld=1 的拍
  // cross(pgflt,deny) 与 cp_sec；cp_ca 对应 cacheable 维
  covergroup cg_ifu_rsp;
    option.per_instance = 1;
    cp_pgflt: coverpoint vif.mmu_ifu_pgflt;
    cp_deny : coverpoint vif.mmu_ifu_deny;
    cp_sec  : coverpoint vif.mmu_ifu_sec;
    cp_ca   : coverpoint vif.mmu_ifu_ca;
    cx_pgflt_deny: cross cp_pgflt, cp_deny;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_ifu_req = new();
    cg_ifu_rsp = new();
  endfunction

  virtual function void set_vif(virtual ifu_if v);
    vif = v;
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk_i);
      if (vif.rst_ni === 1'b0) continue;
      if (vif.ifu_mmu_va_vld) cg_ifu_req.sample();
      if (vif.mmu_ifu_pavld)  cg_ifu_rsp.sample();
    end
  endtask

endclass : ifu_cg_wrapper

`endif // IFU_COVERGROUPS_SVH
