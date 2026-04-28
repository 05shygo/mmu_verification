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
  bit          wb_ptw_ready;
  bit          wb_ptw_ready_prev;
  bit          wb_ptw_ready_prev_valid;
  bit          wb_ptw_ready_hist_valid;
  logic [3:0]  wb_twu_idle_vec;
  logic [3:0]  wb_twu_mask_vec;
  int unsigned wb_twu_idle_cnt;
  int unsigned wb_twu_mask_cnt;
  int unsigned wb_twu_idle_mask_ovlp;
  int unsigned wb_twu_ref_cnt;
  int unsigned wb_twu_pgflt_cnt;
  int unsigned wb_twu_acc_err_cnt;
  int unsigned wb_twu_ready_s0;
  int unsigned wb_twu_ready_s1;
  int unsigned wb_twu_ready_s2;
  int unsigned wb_mbuf_have_cnt;
  bit          wb_ptw_pgflt_vld;
  bit          wb_ptw_acc_err_vld;
  bit          wb_arb_ptw_grant;
  bit          wb_arb_busy;
  bit          wb_ptw_activity;
  bit          wb_ptw_vpn_tag_match;
  bit          wb_ptw_cp0_maee;
  logic [1:0]  wb_twu_except_kind;
  logic [1:0]  wb_arb_grant_type;
  logic [2:0]  wb_ptw_arb_pgs;
  logic [2:0]  wb_maee_leaf_vec;
  logic [1:0]  wb_maee_path;
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

  // --- Phase 12: cg_ptw_ready_transition -------------------------------------
  covergroup cg_ptw_ready_transition;
    option.per_instance = 1;
    cp_ready_transition: coverpoint {wb_ptw_ready_prev, wb_ptw_ready}
                         iff (wb_ptw_ready_hist_valid) {
      bins stay_low  = {2'b00};
      bins rise      = {2'b01};
      bins fall      = {2'b10};
      bins stay_high = {2'b11};
    }
  endgroup

  // --- Phase 12: cg_twu_idle_vs_mask_state -----------------------------------
  covergroup cg_twu_idle_vs_mask_state;
    option.per_instance = 1;
    cp_idle_cnt: coverpoint wb_twu_idle_cnt { bins z = {0}; bins some = {[1:3]}; bins all = {4}; }
    cp_mask_cnt: coverpoint wb_twu_mask_cnt { bins z = {0}; bins some = {[1:3]}; bins all = {4}; }
    cp_have_cnt: coverpoint wb_mbuf_have_cnt { bins z = {0}; bins one = {1}; bins few = {[2:3]}; bins all = {4}; }
    cp_idle_mask_overlap: coverpoint wb_twu_idle_mask_ovlp { bins clean = {0}; bins overlap = {[1:4]}; }
    cx_idle_mask: cross cp_idle_cnt, cp_mask_cnt;
  endgroup

  // --- Phase 12: cg_xbar_hit_level -------------------------------------------
  covergroup cg_xbar_hit_level;
    option.per_instance = 1;
    cp_hit_level: coverpoint wb_xbar_hit iff (wb_ptw_activity) {
      bins lvl0 = {2'd0};
      bins lvl1 = {2'd1};
      bins lvl2 = {2'd2};
      bins lvl3 = {2'd3};
    }
  endgroup

  // --- Phase 12: cg_twu_except_while_arb_busy --------------------------------
  covergroup cg_twu_except_while_arb_busy;
    option.per_instance = 1;
    cp_arb_busy: coverpoint wb_arb_busy { bins idle = {0}; bins busy = {1}; }
    cp_except_kind: coverpoint wb_twu_except_kind {
      bins none   = {2'd0};
      bins pgflt  = {2'd1};
      bins accerr = {2'd2};
      bins mixed  = {2'd3};
    }
    cx_except_busy: cross cp_arb_busy, cp_except_kind iff (wb_twu_except_kind != 2'd0);
  endgroup

  // --- Phase 12: cg_twu_data_ready_per_stage ---------------------------------
  covergroup cg_twu_data_ready_per_stage;
    option.per_instance = 1;
    cp_stage0: coverpoint wb_twu_ready_s0 { bins z = {0}; bins one = {1}; bins few = {[2:3]}; bins all = {4}; }
    cp_stage1: coverpoint wb_twu_ready_s1 { bins z = {0}; bins one = {1}; bins few = {[2:3]}; bins all = {4}; }
    cp_stage2: coverpoint wb_twu_ready_s2 { bins z = {0}; bins one = {1}; bins few = {[2:3]}; bins all = {4}; }
    cp_have_cnt: coverpoint wb_mbuf_have_cnt { bins z = {0}; bins one = {1}; bins few = {[2:3]}; bins all = {4}; }
  endgroup

  // Grant type is inferred from PTW priority outputs:
  // acc_err_vld > pgflt_vld > arb_ptw_grant(refill).
  covergroup cg_arb_grant_type;
    option.per_instance = 1;
    cp_grant_type: coverpoint wb_arb_grant_type
                   iff (wb_ptw_acc_err_vld || wb_ptw_pgflt_vld || wb_arb_ptw_grant) {
      bins refill = {2'd1};
      bins pgflt  = {2'd2};
      bins accerr = {2'd3};
    }
  endgroup

  // --- Phase 12: cg_ptw_arb_pgs_type -----------------------------------------
  covergroup cg_ptw_arb_pgs_type;
    option.per_instance = 1;
    cp_pgs_type: coverpoint wb_ptw_arb_pgs iff (wb_arb_ptw_grant) { bins pgs[] = {[0:7]}; }
    cp_vpn_match: coverpoint wb_ptw_vpn_tag_match iff (wb_arb_ptw_grant) { bins miss = {0}; bins match = {1}; }
    cx_pgs_vpn: cross cp_pgs_type, cp_vpn_match;
  endgroup

  // Leaf/path is inferred from per-TWU leaf request outputs to avoid deeper
  // whitebox control decoding in the coverage package.
  covergroup cg_maee_leaf_level;
    option.per_instance = 1;
    cp_leaf_level: coverpoint wb_maee_leaf_vec iff (wb_maee_leaf_vec != 3'b000) {
      bins lvl1    = {3'b001};
      bins lvl2    = {3'b010};
      bins lvl3    = {3'b100};
      bins mixed[] = {3'b011, 3'b101, 3'b110, 3'b111};
    }
    cp_maee_mode: coverpoint wb_ptw_cp0_maee { bins maee0 = {0}; bins maee1 = {1}; }
  endgroup

  covergroup cg_maee_path;
    option.per_instance = 1;
    cp_path: coverpoint wb_maee_path iff (wb_maee_path != 2'd0) {
      bins csr_only    = {2'd1};
      bins refill_only = {2'd2};
      bins mixed       = {2'd3};
    }
    cp_maee_mode: coverpoint wb_ptw_cp0_maee { bins maee0 = {0}; bins maee1 = {1}; }
    cx_path_mode: cross cp_path, cp_maee_mode;
  endgroup

  function int unsigned umin(int unsigned a, int b);
    return (a < b) ? a : b;
  endfunction

  function int unsigned cnt4(input logic [3:0] v);
    return $countones(v);
  endfunction

  function int unsigned cnt16(input logic [31:0] v);
    return umin($countones(v), 16);
  endfunction

  function int unsigned cnt_twu_stage(input logic [3:0][2:0] v, input int unsigned stage);
    return int'(v[0][stage]) + int'(v[1][stage]) + int'(v[2][stage]) + int'(v[3][stage]);
  endfunction

  function logic [1:0] f_twu_except_kind(input logic [3:0] pgflt_vec, input logic [3:0] accerr_vec);
    bit has_pgflt;
    bit has_accerr;

    has_pgflt  = |pgflt_vec;
    has_accerr = |accerr_vec;
    case ({has_accerr, has_pgflt})
      2'b01: return 2'd1;
      2'b10: return 2'd2;
      2'b11: return 2'd3;
      default: return 2'd0;
    endcase
  endfunction

  function logic [1:0] f_arb_grant_type(input bit accerr_vld, input bit pgflt_vld, input bit refill_grant);
    if (accerr_vld)  return 2'd3;
    if (pgflt_vld)   return 2'd2;
    if (refill_grant) return 2'd1;
    return 2'd0;
  endfunction

  function logic [1:0] f_maee_path(input bit csr_path_hit, input bit refill_path_hit);
    case ({refill_path_hit, csr_path_hit})
      2'b01: return 2'd1;
      2'b10: return 2'd2;
      2'b11: return 2'd3;
      default: return 2'd0;
    endcase
  endfunction

  function new(string name, uvm_component parent);
    super.new(name, parent);
    cg_ptw_walk                  = new();
    cg_l2tlb_bank                = new();
    cg_l1itlb                    = new();
    cg_l1dtlb                    = new();
    cg_l2_reqq                   = new();
    cg_tlboper_fsm               = new();
    cg_ptw_ready_transition      = new();
    cg_twu_idle_vs_mask_state    = new();
    cg_xbar_hit_level            = new();
    cg_twu_except_while_arb_busy = new();
    cg_twu_data_ready_per_stage  = new();
    cg_arb_grant_type            = new();
    cg_ptw_arb_pgs_type          = new();
    cg_maee_leaf_level           = new();
    cg_maee_path                 = new();
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
      cg_ptw_ready_transition.sample();
      cg_twu_idle_vs_mask_state.sample();
      cg_xbar_hit_level.sample();
      cg_twu_except_while_arb_busy.sample();
      cg_twu_data_ready_per_stage.sample();
      cg_arb_grant_type.sample();
      cg_ptw_arb_pgs_type.sample();
      cg_maee_leaf_level.sample();
      cg_maee_path.sample();
    end
  endtask

  virtual function void sample_dut;
    wb_ptw_ready_hist_valid = wb_ptw_ready_prev_valid;
    wb_ptw_ready_prev       = wb_ptw_ready;
    wb_ptw_ready            = v_probe.ptw_jtlb_ready;
    wb_ptw_ready_prev_valid = 1'b1;
    wb_itlb_ent    = cnt16(v_probe.l1i_entry_vld);
    wb_itlb_fsm    = v_probe.l1i_ref_fsm;
    wb_itlb_credit = v_probe.l1i_credit_cnt;
    wb_dtlb_mb_occ  = $countones(v_probe.l1d_mb_vld);
    wb_dtlb_mb0_st  = v_probe.l1d_mb_st0;
    wb_l2_b0        = v_probe.l2_bank0;
    wb_l2_w0        = f_first_onehot3(v_probe.l2_final_way_hit);
    wb_l2_pgs0      = v_probe.l2_raw_pre_pgs0;
    wb_reqq_dep = $countones(v_probe.l2_reqq_vld_vec);
    wb_reqq_iss = v_probe.l2_reqq_qid;
    wb_xbar_hit = v_probe.ptw_xbar_hit_lvl;
    wb_mbuf_lvl = v_probe.ptw_mbuf_twu_lvl;
    wb_ptw_flt  = v_probe.ptw_fault_any;
    wb_twu_idle_vec         = v_probe.ptw_twu_idle;
    wb_twu_mask_vec         = v_probe.ptw_twu_mask;
    wb_twu_idle_cnt         = cnt4(v_probe.ptw_twu_idle);
    wb_twu_mask_cnt         = cnt4(v_probe.ptw_twu_mask);
    wb_twu_idle_mask_ovlp   = cnt4(v_probe.ptw_twu_idle & v_probe.ptw_twu_mask);
    wb_twu_ref_cnt          = cnt4(v_probe.ptw_twu_ref_req);
    wb_twu_pgflt_cnt        = cnt4(v_probe.ptw_twu_pgflt_vec);
    wb_twu_acc_err_cnt      = cnt4(v_probe.ptw_twu_acc_err_vec);
    wb_twu_ready_s0         = cnt_twu_stage(v_probe.ptw_twu_data_ready, 0);
    wb_twu_ready_s1         = cnt_twu_stage(v_probe.ptw_twu_data_ready, 1);
    wb_twu_ready_s2         = cnt_twu_stage(v_probe.ptw_twu_data_ready, 2);
    wb_mbuf_have_cnt        = cnt4(v_probe.ptw_mbuf_twu_have);
    wb_ptw_pgflt_vld        = v_probe.ptw_pgflt_vld;
    wb_ptw_acc_err_vld      = v_probe.ptw_acc_err_vld;
    wb_arb_ptw_grant        = v_probe.arb_ptw_grant;
    wb_arb_busy             = v_probe.arb_l2tlb_req;
    wb_ptw_vpn_tag_match    = (v_probe.ptw_arb_vpn == v_probe.ptw_arb_ref_tag_din[46:20]);
    wb_ptw_cp0_maee         = v_probe.ptw_cp0_maee;
    wb_twu_except_kind      = f_twu_except_kind(v_probe.ptw_twu_pgflt_vec, v_probe.ptw_twu_acc_err_vec);
    wb_arb_grant_type       = f_arb_grant_type(wb_ptw_acc_err_vld, wb_ptw_pgflt_vld, wb_arb_ptw_grant);
    wb_ptw_arb_pgs          = v_probe.ptw_arb_pgs;
    wb_maee_leaf_vec        = {v_probe.maee_leaf_lvl3_hit, v_probe.maee_leaf_lvl2_hit, v_probe.maee_leaf_lvl1_hit};
    wb_maee_path            = f_maee_path(v_probe.maee_csr_path_hit, v_probe.maee_refill_path_hit);
    wb_ptw_activity         = (wb_twu_ref_cnt != 0)
                            || (wb_twu_pgflt_cnt != 0)
                            || (wb_twu_acc_err_cnt != 0)
                            || (wb_twu_ready_s0 != 0)
                            || (wb_twu_ready_s1 != 0)
                            || (wb_twu_ready_s2 != 0)
                            || (wb_mbuf_lvl != 0)
                            || (wb_twu_idle_cnt != 4);
    wb_tlbiva               = v_probe.tlbiva_cur_st;
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
