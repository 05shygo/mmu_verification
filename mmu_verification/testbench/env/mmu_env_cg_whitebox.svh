// =============================================================================
// MMU UVM Verification — testbench/env/mmu_env_cg_whitebox.svh
// Phase 7 §10.2：白盒 covergroup — 仅通过 virtual mmu_dut_probes_if 采样
//（层次信号在 tb_top 内 assign 到 mmu_dut_probes_if，禁止在 package 内 $root）
// P7-B-09b：§10.3/§10.4 gap CG 不纳入 — 见 doc/MMU_Progress.md Phase 7
// =============================================================================
`ifndef MMU_ENV_CG_WHITEBOX_SVH
`define MMU_ENV_CG_WHITEBOX_SVH

class mmu_env_cg_whitebox extends uvm_component;
  `uvm_component_utils(mmu_env_cg_whitebox)

  virtual mmu_dut_probes_if v_probe;

  int unsigned wb_itlb_ent;
  logic [1:0]  wb_itlb_fsm;
  bit          wb_itlb_credit;
  int unsigned wb_dtlb_mb_occ;
  logic [2:0]  wb_dtlb_mb0_st;
  logic [2:0]  wb_l2_b0;
  logic [2:0]  wb_l2_w0;
  logic [2:0]  wb_l2_pgs0;
  logic [2:0]  wb_reqq_iss;
  int unsigned wb_reqq_dep;
  logic [1:0]  wb_xbar_hit;
  logic [2:0]  wb_mbuf_lvl;
  bit          wb_ptw_flt;
  logic [3:0]  wb_tlbiva;

  // --- §10.2: cg_ptw_walk ----------------------------------------------------
  covergroup cg_ptw_walk;
    option.per_instance = 1;
    cp_walk_depth: coverpoint wb_mbuf_lvl { bins one = {3'd1}; bins two = {3'd2}; bins thr = {3'd3}; bins o = default; }
    cp_leaf_level: coverpoint wb_xbar_hit;
    cp_fault: coverpoint wb_ptw_flt;
    cx: cross cp_walk_depth, cp_fault;
  endgroup

  // --- cg_l2tlb_bank ---------------------------------------------------------
  covergroup cg_l2tlb_bank;
    option.per_instance = 1;
    cp_bank: coverpoint wb_l2_b0 { bins b[] = {[0:7]}; }
    cp_way: coverpoint wb_l2_w0 { bins w[] = {[0:7]}; }
    cp_pgs: coverpoint wb_l2_pgs0;
    cx_bw: cross cp_bank, cp_way;
  endgroup

  // --- cg_l1itlb ------------------------------------------------------------
  covergroup cg_l1itlb;
    option.per_instance = 1;
    cp_entry_vld_count: coverpoint wb_itlb_ent {
      bins c0_4 = {[0:4]}; bins c5_8 = {[5:8]}; bins c9_12 = {[9:12]}; bins c13_16 = {[13:16]};
    }
    cp_credit_remain: coverpoint wb_itlb_credit;
    cp_fsm_state: coverpoint wb_itlb_fsm;
  endgroup

  // --- cg_l1dtlb ------------------------------------------------------------
  covergroup cg_l1dtlb;
    option.per_instance = 1;
    cp_mb_occupancy: coverpoint wb_dtlb_mb_occ { bins z = {0}; bins low = {[1:3]}; bins mid = {[4:7]}; }
    cp_fsm_state: coverpoint wb_dtlb_mb0_st;
  endgroup

  // --- cg_l2_reqq -----------------------------------------------------------
  covergroup cg_l2_reqq;
    option.per_instance = 1;
    cp_alloc_idx: coverpoint wb_reqq_iss { bins id[] = {[0:7]}; }
    cp_depth: coverpoint wb_reqq_dep { bins d0 = {0}; bins d1_4 = {[1:4]}; bins d5_9 = {[5:9]}; }
  endgroup

  // --- cg_tlboper_fsm -------------------------------------------------------
  covergroup cg_tlboper_fsm;
    option.per_instance = 1;
    cp_fsm_state: coverpoint wb_tlbiva { bins s[] = {[0:15]}; }
  endgroup

  function int unsigned umin(int unsigned a, int b);
    return (a < b) ? a : b;
  endfunction

  function int unsigned cnt16(input logic [31:0] v);
    return umin($countones(v), 16);
  endfunction

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_ptw_walk     = new();
    cg_l2tlb_bank   = new();
    cg_l1itlb       = new();
    cg_l1dtlb       = new();
    cg_l2_reqq      = new();
    cg_tlboper_fsm  = new();
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mmu_dut_probes_if)::get(this, "", "MMU_DUT_PROBES_VIF", v_probe)) begin
      `uvm_info(get_type_name(), "MMU_DUT_PROBES_VIF not in config_db — mmu_env_cg_whitebox will idle", UVM_LOW)
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    if (v_probe == null) begin
      `uvm_info(get_type_name(), "DUT probes vif not bound — whitebox CG idle (fix tb_top assign + set)", UVM_LOW)
      return;
    end
    forever begin
      @(posedge v_probe.clk_i);
      if (v_probe.rst_ni === 1'b0) continue;
      sample_dut;
      cg_ptw_walk.sample();
      cg_l2tlb_bank.sample();
      cg_l1itlb.sample();
      cg_l1dtlb.sample();
      cg_l2_reqq.sample();
      cg_tlboper_fsm.sample();
    end
  endtask

  virtual function void sample_dut;
    wb_itlb_ent    = cnt16(v_probe.l1i_entry_vld);
    wb_itlb_fsm    = v_probe.l1i_ref_fsm;
    wb_itlb_credit = v_probe.l1i_credit_cnt;
    wb_dtlb_mb_occ  = $countones(v_probe.l1d_mb_vld);
    wb_dtlb_mb0_st  = v_probe.l1d_mb_st0;
    wb_l2_b0  = v_probe.l2_bank0;
    wb_l2_w0  = f_first_onehot3(v_probe.l2_final_way_hit);
    wb_l2_pgs0= v_probe.l2_raw_pre_pgs0;
    wb_reqq_dep = $countones(v_probe.l2_reqq_vld_vec);
    wb_reqq_iss = v_probe.l2_reqq_qid;
    wb_xbar_hit = v_probe.ptw_xbar_hit_lvl;
    wb_mbuf_lvl = v_probe.ptw_mbuf_twu_lvl;
    wb_ptw_flt  = v_probe.ptw_fault_any;
    wb_tlbiva   = v_probe.tlbiva_cur_st;
  endfunction

  function logic [2:0] f_first_onehot3(input logic [7:0] oh);
    if (oh[0]) return 3'd0;
    if (oh[1]) return 3'd1;
    if (oh[2]) return 3'd2;
    if (oh[3]) return 3'd3;
    if (oh[4]) return 3'd4;
    if (oh[5]) return 3'd5;
    if (oh[6]) return 3'd6;
    if (oh[7]) return 3'd7;
    return 3'd0;
  endfunction

endclass : mmu_env_cg_whitebox

`endif // MMU_ENV_CG_WHITEBOX_SVH
