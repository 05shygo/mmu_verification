// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_covergroups.svh
// Phase 7: §10.1 — cg_lsu_pipe0/1/2, cg_lsu_inv, cg_lsu_inv_done（延迟）
// =============================================================================
`ifndef LSU_COVERGROUPS_SVH
`define LSU_COVERGROUPS_SVH

class lsu_cg_wrapper extends uvm_component;
  `uvm_component_utils(lsu_cg_wrapper)

  virtual lsu_if vif;

  int unsigned cyc;
  int unsigned inv_start_cyc;
  bit          inv_pending;

  // 在 sample 前由 run_phase 写入
  int unsigned p_inv_kind;   // 0 va_all, 1 all_all, 2 asid_all, 3 va_asid
  bit          p_during_ptw;
  int unsigned p_inv_lat;    // 到 inv_done 的周期差（0=同拍/首拍即完成窗口）

  // pipe0/1/2: BuildPlan 表 2016-17
  covergroup cg_lsu_pipe0;
    option.per_instance = 1;
    cp_op_ld: coverpoint (vif.lsu_mmu_st_inst0 === 1'b0) { bins is_ld  = {1};
                                                           bins is_st = {0};
                                                         }
    cp_st_inst: coverpoint vif.lsu_mmu_st_inst0;
    cp_abort: coverpoint vif.lsu_mmu_abort0;
    cp_stall: coverpoint vif.mmu_lsu_stall0;
    cp_pa_vld: coverpoint vif.mmu_lsu_pa0_vld;
    cp_pgflt: coverpoint vif.mmu_lsu_page_fault0;
    cp_access_fault: coverpoint vif.mmu_lsu_access_fault0;
    cx_op_flt: cross cp_op_ld, cp_pgflt, cp_access_fault;
  endgroup

  covergroup cg_lsu_pipe1;
    option.per_instance = 1;
    cp_op_ld: coverpoint (vif.lsu_mmu_st_inst1 === 1'b0) { bins is_ld  = {1};
                                                           bins is_st = {0};
                                                         }
    cp_st_inst: coverpoint vif.lsu_mmu_st_inst1;
    cp_abort: coverpoint vif.lsu_mmu_abort1;
    cp_stall: coverpoint vif.mmu_lsu_stall1;
    cp_pa_vld: coverpoint vif.mmu_lsu_pa1_vld;
    cp_pgflt: coverpoint vif.mmu_lsu_page_fault1;
    cp_access_fault: coverpoint vif.mmu_lsu_access_fault1;
    cx_op_flt: cross cp_op_ld, cp_pgflt, cp_access_fault;
  endgroup

  covergroup cg_lsu_pipe2;
    option.per_instance = 1;
    cp_va2_vld: coverpoint vif.lsu_mmu_va2_vld;
    cp_pa2_vld: coverpoint vif.mmu_lsu_pa2_vld;
    cp_pa2_err: coverpoint vif.mmu_lsu_pa2_err;
    cp_share2: coverpoint vif.mmu_lsu_share2;
    cp_sec2: coverpoint vif.mmu_lsu_sec2;
  endgroup

  // inv 请求拍： kind + during ptw 代理
  covergroup cg_lsu_inv;
    option.per_instance = 1;
    cp_kind: coverpoint p_inv_kind { bins b_va_all   = {0};
                                     bins b_all_all  = {1};
                                     bins b_asid_all = {2};
                                     bins b_va_asid  = {3};
                                   }
    cp_during_ptw: coverpoint p_during_ptw;
    cx_k_busy: cross cp_kind, cp_during_ptw;
  endgroup

  // inv 完成拍： 延迟
  covergroup cg_lsu_inv_done;
    option.per_instance = 1;
    cp_inv_done_latency: coverpoint p_inv_lat { bins d0   = {0};
                                                bins d1_3 = {[1:3]};
                                                bins d4_7 = {[4:7]};
                                                bins d8p  = {[8:31]};
                                                bins d32p = {[32:4095]};
                                              }
  endgroup

  function int unsigned enc_inv_kind();
    // 互斥模式优先最具体：VA+ASID > ASID-only > VA,all asid > all
    if (vif.lsu_mmu_tlb_va_asid_inv) return 3;
    if (vif.lsu_mmu_tlb_asid_all_inv) return 2;
    if (vif.lsu_mmu_tlb_va_all_inv) return 0;
    if (vif.lsu_mmu_tlb_all_inv) return 1;
    return 0;
  endfunction

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_lsu_pipe0  = new();
    cg_lsu_pipe1  = new();
    cg_lsu_pipe2  = new();
    cg_lsu_inv    = new();
    cg_lsu_inv_done = new();
  endfunction

  virtual function void set_vif(virtual lsu_if v);
    vif = v;
  endfunction

  virtual task run_phase(uvm_phase phase);
    cyc = 0;
    forever begin
      @(posedge vif.clk_i);
      if (vif.rst_ni === 1'b0) begin
        cyc = 0;
        inv_pending = 0;
        continue;
      end
      cyc++;

      if (vif.lsu_mmu_va0_vld) cg_lsu_pipe0.sample();
      if (vif.lsu_mmu_va1_vld) cg_lsu_pipe1.sample();
      if (vif.lsu_mmu_va2_vld | vif.mmu_lsu_pa2_vld) cg_lsu_pipe2.sample();

      if (vif.lsu_mmu_tlb_all_inv | vif.lsu_mmu_tlb_va_all_inv
          | vif.lsu_mmu_tlb_asid_all_inv | vif.lsu_mmu_tlb_va_asid_inv) begin
        p_inv_kind   = enc_inv_kind();
        p_during_ptw = vif.mmu_lsu_tlb_busy;
        cg_lsu_inv.sample();
        inv_start_cyc = cyc;
        inv_pending   = 1'b1;
      end
      if (vif.mmu_lsu_tlb_inv_done && inv_pending) begin
        p_inv_lat = cyc - inv_start_cyc;
        cg_lsu_inv_done.sample();
        inv_pending = 0;
      end
    end
  endtask

endclass : lsu_cg_wrapper

`endif // LSU_COVERGROUPS_SVH
