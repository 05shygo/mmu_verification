// =============================================================================
// MMU UVM Verification — testbench/pmp_agent/pmp_covergroups.svh
// Phase 7: §10.1 — cg_pmp：8 端口 flg[0] 为「有效/命中」代理 + acc + violation
// flg[3:0] 见 pmp_if 注释 {execute, write, read, valid} 系编码；此处按 valid 为 bit0。
// =============================================================================
`ifndef PMP_COVERGROUPS_SVH
`define PMP_COVERGROUPS_SVH

class pmp_cg_wrapper extends uvm_component;
  `uvm_component_utils(pmp_cg_wrapper)

  virtual pmp_if vif;

  // 聚合到单周期样本（run_phase 写 shadow 后 .sample()）
  bit          h0, h1, h2, h3, h4, h5, h6, h7;  // entry「有效」= flg[0]
  bit [2:0]    acc0;  // 对 port0 的 R/W/X 编码代理
  bit          viol0; // port0: !valid
  int unsigned ent8;  // 0-7 哪一路参与 cross（以首个 valid 的端口）

  covergroup cg_pmp;
    option.per_instance = 1;
    cp_e0: coverpoint h0; cp_e1: coverpoint h1; cp_e2: coverpoint h2; cp_e3: coverpoint h3;
    cp_e4: coverpoint h4; cp_e5: coverpoint h5; cp_e6: coverpoint h6; cp_e7: coverpoint h7;
    cp_entry_any: coverpoint ent8 { bins p[] = {[0:7]}; }
    cp_acc_type: coverpoint acc0;
    cp_violation: coverpoint viol0;
    cx_e_acc: cross cp_entry_any, cp_acc_type;
  endgroup

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_pmp = new();
  endfunction

  virtual function void set_vif(virtual pmp_if v);
    vif = v;
  endfunction

  // flg: bit0=valid；acc 用 [3:1]
  function void shadow_from_vif;
    h0 = vif.pmp_mmu_flg0[0];
    h1 = vif.pmp_mmu_flg1[0];
    h2 = vif.pmp_mmu_flg2[0];
    h3 = vif.pmp_mmu_flg3[0];
    h4 = vif.pmp_mmu_flg4[0];
    h5 = vif.pmp_mmu_flg5[0];
    h6 = vif.pmp_mmu_flg6[0];
    h7 = vif.pmp_mmu_flg7[0];
    acc0   = vif.pmp_mmu_flg0[3:1];
    viol0  = !vif.pmp_mmu_flg0[0];
    ent8 = first_valid_port();
  endfunction

  function int unsigned first_valid_port();
    if (h0) return 0;
    if (h1) return 1;
    if (h2) return 2;
    if (h3) return 3;
    if (h4) return 4;
    if (h5) return 5;
    if (h6) return 6;
    if (h7) return 7;
    return 0;
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vif.clk_i);
      if (vif.rst_ni === 1'b0) continue;
      shadow_from_vif();
      cg_pmp.sample();
    end
  endtask

endclass : pmp_cg_wrapper

`endif // PMP_COVERGROUPS_SVH
