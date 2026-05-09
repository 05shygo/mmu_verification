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
  int unsigned wb_dtlb_entry_occ;
  logic [2:0]  wb_dtlb_mb0_st;
  logic [1:0]  wb_dtlb_dual_kind;
  logic [1:0]  wb_dtlb_refill_src;
  bit          wb_dtlb_l2_req;
  logic [2:0]  wb_dtlb_l2_req_eid;
  bit          wb_dtlb_l2_req_load;
  int unsigned wb_dtlb_credit_cnt;
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
  bit          wb_ptw_pgflt_rsp;
  bit          wb_ptw_acc_err_rsp;
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
  int unsigned wb_sample_cycles;

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
    cp_entry_occupancy: coverpoint wb_dtlb_entry_occ {
      bins c0 = {0};
      bins low = {[1:4]};
      bins mid = {[5:12]};
      bins high = {[13:15]};
      bins full = {16};
    }
    cp_mb_occupancy: coverpoint wb_dtlb_mb_occ {
      bins z = {0};
      bins low = {[1:3]};
      bins mid = {[4:7]};
      bins full = {8};
    }
    cp_fsm_state: coverpoint wb_dtlb_mb0_st;
    cp_dual_lookup: coverpoint wb_dtlb_dual_kind {
      bins none_or_single = {2'd0};
      bins dual_hit = {2'd1};
      bins hit_miss = {2'd2};
      bins dual_miss = {2'd3};
    }
    cp_refill_src: coverpoint wb_dtlb_refill_src {
      bins none = {2'd0};
      bins ptw  = {2'd1};
      bins l2   = {2'd2};
      bins wfi  = {2'd3};
    }
    cp_l2_req: coverpoint wb_dtlb_l2_req;
    cp_l2_req_eid: coverpoint wb_dtlb_l2_req_eid iff (wb_dtlb_l2_req) {
      bins eid[] = {[0:7]};
    }
    cp_l2_req_type: coverpoint wb_dtlb_l2_req_load iff (wb_dtlb_l2_req) {
      bins load = {1};
      bins store = {0};
    }
    cp_credit_cnt: coverpoint wb_dtlb_credit_cnt {
      bins zero = {0};
      bins low = {[1:3]};
      bins mid = {[4:7]};
      bins full = {8};
    }
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
    cp_except_kind: coverpoint wb_twu_except_kind iff (wb_twu_except_kind != 2'd0) {
      bins pgflt  = {2'd1};
      bins accerr = {2'd2};
      bins mixed  = {2'd3};
    }
    // Use an encoded coverpoint instead of cross+ignore_bins.  VCS/URG T-2022.06
    // can produce unreadable VDBs for this hot Phase12 exception cross.
    cp_except_busy: coverpoint {wb_arb_busy, wb_twu_except_kind} iff (wb_twu_except_kind != 2'd0) {
      bins pgflt_idle  = {3'b0_01};
      bins pgflt_busy  = {3'b1_01};
      bins accerr_idle = {3'b0_10};
      bins accerr_busy = {3'b1_10};
      bins mixed_any[] = {3'b0_11, 3'b1_11};
    }
  endgroup

  // --- Phase 12: cg_twu_data_ready_per_stage ---------------------------------
  covergroup cg_twu_data_ready_per_stage;
    option.per_instance = 1;
    cp_stage0: coverpoint wb_twu_ready_s0 { bins z = {0}; bins one = {1}; bins few = {[2:3]}; bins all = {4}; }
    cp_stage1: coverpoint wb_twu_ready_s1 { bins z = {0}; bins one = {1}; bins few = {[2:3]}; bins all = {4}; }
    cp_stage2: coverpoint wb_twu_ready_s2 { bins z = {0}; bins one = {1}; bins few = {[2:3]}; bins all = {4}; }
    cp_have_cnt: coverpoint wb_mbuf_have_cnt { bins z = {0}; bins one = {1}; bins few = {[2:3]}; bins all = {4}; }
  endgroup

  // Grant type is inferred from PTW priority and response outputs:
  // acc_err > pgflt > refill.  The response bits are included because the
  // pre-grant exception vld window can be narrower than the final PTW response
  // pulse seen by L1/L2 TLB consumers.
  covergroup cg_arb_grant_type;
    option.per_instance = 1;
    cp_grant_type: coverpoint wb_arb_grant_type
                   iff (wb_ptw_acc_err_vld || wb_ptw_acc_err_rsp
                     || wb_ptw_pgflt_vld || wb_ptw_pgflt_rsp
                     || wb_arb_ptw_grant) {
      bins refill = {2'd1};
      bins pgflt  = {2'd2};
      bins accerr = {2'd3};
    }
  endgroup

  // --- Phase 12: cg_ptw_arb_pgs_type -----------------------------------------
  covergroup cg_ptw_arb_pgs_type;
    option.per_instance = 1;
    cp_pgs_type: coverpoint wb_ptw_arb_pgs iff (wb_arb_ptw_grant) {
      bins pgs_4k = {3'b001};
      bins pgs_2m = {3'b010};
      bins pgs_1g = {3'b100};
    }
    cp_vpn_match: coverpoint wb_ptw_vpn_tag_match iff (wb_arb_ptw_grant) {
      bins match = {1};
      illegal_bins mismatch = {0};
    }
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

  // --- Phase 13: PMP/TWU and SysMap/TWU covergroups -------------------------
  covergroup cg_pmp_per_level_result with function sample(int unsigned level, int unsigned result);
    option.per_instance = 1;
    cp_level: coverpoint level { bins fst = {0}; bins scd = {1}; bins thd = {2}; }
    cp_result: coverpoint result { bins pass = {1}; bins deny = {2}; bins wait_seen = {3}; }
    cx_level_result: cross cp_level, cp_result;
  endgroup

  covergroup cg_pmp_grant_level with function sample(logic [2:0] grant);
    option.per_instance = 1;
    cp_grant: coverpoint grant {
      bins none = {3'b000};
      bins thd  = {3'b001};
      bins scd  = {3'b010};
      bins fst  = {3'b100};
      ignore_bins multi = {3'b011, 3'b101, 3'b110, 3'b111};
    }
  endgroup

  covergroup cg_pmp_pa_format with function sample(int unsigned pgs_class, int unsigned align_class);
    option.per_instance = 1;
    cp_pgs: coverpoint pgs_class { bins pgs_4k = {1}; bins pgs_2m = {2}; bins pgs_1g = {4}; }
    cp_align: coverpoint align_class { bins bad = {1}; bins ok_4k = {2}; bins ok_2m = {3}; bins ok_1g = {4}; }
    cx_pgs_align: cross cp_pgs, cp_align;
  endgroup

  covergroup cg_pmp_deny_by_level with function sample(int unsigned level, int unsigned acc_kind);
    option.per_instance = 1;
    cp_level: coverpoint level { bins fst = {0}; bins scd = {1}; bins thd = {2}; }
    cp_acc: coverpoint acc_kind { bins load = {1}; bins store = {2}; bins fetch = {3}; bins pref = {4}; bins other = {7}; }
    cx_level_acc: cross cp_level, cp_acc;
  endgroup

  covergroup cg_twu_mask_cause with function sample(int unsigned level, int unsigned mask_cnt, bit all_mask);
    option.per_instance = 1;
    cp_level: coverpoint level { bins fst = {0}; bins scd = {1}; bins thd = {2}; }
    cp_mask_cnt: coverpoint mask_cnt { bins one = {1}; bins some = {[2:3]}; bins all = {4}; }
    cp_all_mask: coverpoint all_mask { bins no = {0}; bins yes = {1}; }
  endgroup

  covergroup cg_ptw_pmp_port_map with function sample(int unsigned twu_idx, int unsigned port_id, bit pa_seen, int unsigned acc_kind, bit fetch_sideband);
    option.per_instance = 1;
    cp_twu: coverpoint twu_idx { bins one = {0}; bins two = {1}; bins three = {2}; bins four = {3}; }
    cp_port: coverpoint port_id { bins p3 = {3}; bins p5 = {5}; bins p6 = {6}; bins p7 = {7}; }
    cp_pa_seen: coverpoint pa_seen { bins idle = {0}; bins active = {1}; }
    cp_acc: coverpoint acc_kind { bins load = {1}; bins store = {2}; bins fetch = {3}; bins pref = {4}; bins other = {7}; }
    cp_fetch_sideband: coverpoint fetch_sideband { bins data_origin = {0}; bins fetch_origin = {1}; }
    cx_twu_port: cross cp_twu, cp_port;
    cx_acc_fetch: cross cp_acc, cp_fetch_sideband;
  endgroup

  covergroup cg_sysmap_flg_per_region with function sample(int unsigned region, logic [4:0] flg, bit refill_match);
    option.per_instance = 1;
    cp_region: coverpoint region { bins low = {[0:3]}; bins high = {[4:7]}; bins no_hit = {8}; }
    cp_flg: coverpoint flg {
      bins normal = {5'b01111};
      bins device = {5'b10011};
      ignore_bins other_low = {[0:14]};
      ignore_bins other_mid = {[16:18]};
      ignore_bins other_high = {[20:31]};
    }
    cp_refill_match: coverpoint refill_match { bins no = {0}; bins yes = {1}; }
  endgroup

  covergroup cg_sysmap_cross_1g with function sample(bit cross_seen, int unsigned region, bit hit_any);
    option.per_instance = 1;
    cp_cross: coverpoint cross_seen { bins no = {0}; bins yes = {1}; }
    cp_hit_any: coverpoint hit_any { bins no = {0}; bins yes = {1}; }
  endgroup

  covergroup cg_sysmap_cross_2m with function sample(bit cross_seen, int unsigned region, bit hit_any);
    option.per_instance = 1;
    cp_cross: coverpoint cross_seen { bins no = {0}; bins yes = {1}; }
    cp_hit_any: coverpoint hit_any { bins no = {0}; bins yes = {1}; }
  endgroup

  covergroup cg_sysmap_degrade_pgs with function sample(int unsigned before_pgs, int unsigned after_pgs);
    option.per_instance = 1;
    cp_before: coverpoint before_pgs { bins pgs_4k = {1}; bins pgs_2m = {2}; bins pgs_1g = {4}; }
    cp_after: coverpoint after_pgs { bins pgs_4k = {1}; bins pgs_2m = {2}; bins pgs_1g = {4}; }
    cx_degrade: cross cp_before, cp_after;
  endgroup

  covergroup cg_sysmap_pa_align with function sample(int unsigned pgs_class, int unsigned align_class);
    option.per_instance = 1;
    cp_pgs: coverpoint pgs_class { bins pgs_4k = {1}; bins pgs_2m = {2}; bins pgs_1g = {4}; }
    cp_align: coverpoint align_class { bins mismatch = {1}; bins ok_4k = {2}; bins ok_2m = {3}; bins ok_1g = {4}; }
    cx_pgs_align: cross cp_pgs, cp_align;
  endgroup

  covergroup cg_sysmap_4twu_concurrent with function sample(int unsigned active_cnt, bit port_map_ok);
    option.per_instance = 1;
    cp_active_cnt: coverpoint active_cnt { bins partial = {[1:3]}; bins four = {4}; }
    cp_port_map_ok: coverpoint port_map_ok { bins yes = {1}; ignore_bins no = {0}; }
  endgroup

  covergroup cg_sysmap_default_flag with function sample(bit no_hit, logic [4:0] flg, bit propagated);
    option.per_instance = 1;
    cp_no_hit: coverpoint no_hit { bins hit = {0}; bins no_hit = {1}; }
    cp_default_flg: coverpoint flg {
      bins default_10011 = {5'b10011};
      ignore_bins other_low = {[0:18]};
      ignore_bins other_high = {[20:31]};
    }
    cp_propagated: coverpoint propagated { bins no = {0}; bins yes = {1}; }
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

  function int unsigned f_p13_stage_bit(input int unsigned level);
    case (level)
      0: return 2; // FST
      1: return 1; // SCD
      default: return 0; // THD
    endcase
  endfunction

  function int unsigned f_p13_stage_pgs(input int unsigned level);
    case (level)
      0: return 4; // 1G
      1: return 2; // 2M
      default: return 1; // 4K
    endcase
  endfunction

  function int unsigned f_p13_pgs_class(input logic [2:0] pgs);
    case (pgs)
      3'b001: return 1;
      3'b010: return 2;
      3'b100: return 4;
      default: return 0;
    endcase
  endfunction

  function int unsigned f_p13_acc_kind(input logic [2:0] typ);
    case (typ)
      3'b010: return 1; // load
      3'b110: return 2; // store
      3'b011: return 3; // fetch
      3'b100: return 4; // prefetch
      default: return 7;
    endcase
  endfunction

  function int unsigned f_p13_selected_pmp_acc_kind(
    input logic [2:0] grant,
    input logic [2:0][2:0] typ_vec
  );
    if (grant[2]) return f_p13_acc_kind(typ_vec[2]);
    if (grant[1]) return f_p13_acc_kind(typ_vec[1]);
    if (grant[0]) return f_p13_acc_kind(typ_vec[0]);
    return 7;
  endfunction

  function int unsigned f_p13_pmp_align_class(input int unsigned level, input logic [27:0] pa);
    if (pa == 28'h0) return 0;
    case (level)
      0: return (pa[17:0] == 18'h0) ? 4 : 1;
      1: return (pa[8:0] == 9'h0) ? 3 : 1;
      default: return 2;
    endcase
  endfunction

  function int unsigned f_p13_sysmap_align_class(
    input logic [2:0] pgs,
    input logic [27:0] sysmap_pa,
    input logic [39:0] adder
  );
    int unsigned pgs_class;
    pgs_class = f_p13_pgs_class(pgs);
    if (sysmap_pa != adder[39:12]) return 1;
    case (pgs_class)
      4: return (sysmap_pa[17:0] == 18'h0) ? 4 : 1;
      2: return (sysmap_pa[8:0] == 9'h0) ? 3 : 1;
      1: return 2;
      default: return 0;
    endcase
  endfunction

  function int unsigned f_p13_region_idx(input logic [7:0] hit);
    for (int unsigned i = 0; i < 8; i++)
      if (hit[i]) return i;
    return 8;
  endfunction

  function int unsigned f_p13_port_id(input int unsigned twu_idx);
    case (twu_idx)
      0: return 3;
      1: return 5;
      2: return 6;
      default: return 7;
    endcase
  endfunction

  function new(string name, uvm_component parent);
    super.new(name, parent);
    wb_sample_cycles               = 0;
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
    cg_pmp_per_level_result      = new();
    cg_pmp_grant_level           = new();
    cg_pmp_pa_format             = new();
    cg_pmp_deny_by_level         = new();
    cg_twu_mask_cause            = new();
    cg_ptw_pmp_port_map          = new();
    cg_sysmap_flg_per_region     = new();
    cg_sysmap_cross_1g           = new();
    cg_sysmap_cross_2m           = new();
    cg_sysmap_degrade_pgs        = new();
    cg_sysmap_pa_align           = new();
    cg_sysmap_4twu_concurrent    = new();
    cg_sysmap_default_flag       = new();
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
      sample_phase13_covergroups();
      wb_sample_cycles++;
    end
  endtask

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    `uvm_info(get_type_name(),
      $sformatf("whitebox_cg summary: sampled_cycles=%0d ptw_ready=%0.2f twu_idle_mask=%0.2f xbar_hit=%0.2f twu_except_busy=%0.2f twu_stage_ready=%0.2f arb_grant=%0.2f arb_pgs=%0.2f maee_leaf=%0.2f maee_path=%0.2f",
        wb_sample_cycles,
        cg_ptw_ready_transition.get_inst_coverage(),
        cg_twu_idle_vs_mask_state.get_inst_coverage(),
        cg_xbar_hit_level.get_inst_coverage(),
        cg_twu_except_while_arb_busy.get_inst_coverage(),
        cg_twu_data_ready_per_stage.get_inst_coverage(),
        cg_arb_grant_type.get_inst_coverage(),
        cg_ptw_arb_pgs_type.get_inst_coverage(),
        cg_maee_leaf_level.get_inst_coverage(),
        cg_maee_path.get_inst_coverage()),
      UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("phase13_whitebox_cg summary: pmp_result=%0.2f pmp_grant=%0.2f pmp_pa=%0.2f pmp_deny=%0.2f twu_mask=%0.2f pmp_port=%0.2f sysmap_flg=%0.2f cross1g=%0.2f cross2m=%0.2f degrade=%0.2f sysmap_pa=%0.2f sysmap_4twu=%0.2f default=%0.2f",
        cg_pmp_per_level_result.get_inst_coverage(),
        cg_pmp_grant_level.get_inst_coverage(),
        cg_pmp_pa_format.get_inst_coverage(),
        cg_pmp_deny_by_level.get_inst_coverage(),
        cg_twu_mask_cause.get_inst_coverage(),
        cg_ptw_pmp_port_map.get_inst_coverage(),
        cg_sysmap_flg_per_region.get_inst_coverage(),
        cg_sysmap_cross_1g.get_inst_coverage(),
        cg_sysmap_cross_2m.get_inst_coverage(),
        cg_sysmap_degrade_pgs.get_inst_coverage(),
        cg_sysmap_pa_align.get_inst_coverage(),
        cg_sysmap_4twu_concurrent.get_inst_coverage(),
        cg_sysmap_default_flag.get_inst_coverage()),
      UVM_LOW)
  endfunction

  virtual function void sample_phase13_covergroups();
    int unsigned active_sysmap_cnt;
    bit          sysmap_port_map_ok;

    active_sysmap_cnt = 0;
    sysmap_port_map_ok = 1'b1;

    for (int unsigned t = 0; t < 4; t++) begin
      logic [2:0] vld;
      logic [2:0] grant;
      logic [2:0] deny;
      logic [2:0] wait_v;
      logic [2:0] mbuf_req;
      int unsigned region;
      bit hit_any;
      bit refill_match;
      int unsigned before_pgs;
      int unsigned after_pgs;

      vld      = v_probe.p13_pmp_vld_vec[t];
      grant    = v_probe.p13_pmp_grant_vec[t];
      deny     = v_probe.p13_pmp_deny_vec[t];
      wait_v   = v_probe.p13_pmp_wait_vec[t];
      mbuf_req = v_probe.p13_pmp_mbuf_req_vec[t];

      if ((vld != 3'b000) || (grant != 3'b000))
        cg_pmp_grant_level.sample(grant);

      if ((vld != 3'b000) || (grant != 3'b000) || (v_probe.p13_pmp_pa_vec[t] != 28'h0))
        cg_ptw_pmp_port_map.sample(
          t, f_p13_port_id(t),
          (v_probe.p13_pmp_pa_vec[t] != 28'h0),
          f_p13_selected_pmp_acc_kind(grant, v_probe.p13_pmp_type_vec[t]),
          v_probe.p13_pmp_fetch_vec[t]);

      for (int unsigned level = 0; level < 3; level++) begin
        int unsigned bit_idx;
        int unsigned result;
        int unsigned acc_kind;

        bit_idx = f_p13_stage_bit(level);
        result = 0;
        if (wait_v[bit_idx])
          result = 3;
        else if (grant[bit_idx] && deny[bit_idx])
          result = 2;
        else if ((grant[bit_idx] && !deny[bit_idx]) || mbuf_req[bit_idx])
          result = 1;

        if ((vld[bit_idx] || grant[bit_idx] || wait_v[bit_idx] || mbuf_req[bit_idx]) && (result != 0)) begin
          cg_pmp_per_level_result.sample(level, result);
          cg_pmp_pa_format.sample(
            f_p13_stage_pgs(level),
            f_p13_pmp_align_class(level, v_probe.p13_pmp_pa_vec[t]));
        end

        if (deny[bit_idx]) begin
          acc_kind = f_p13_acc_kind(v_probe.p13_pmp_type_vec[t][bit_idx]);
          cg_pmp_deny_by_level.sample(level, acc_kind);
        end

        if (wait_v[bit_idx])
          cg_twu_mask_cause.sample(level, cnt4(v_probe.ptw_twu_mask), (&v_probe.ptw_twu_mask));
      end

      region = f_p13_region_idx(v_probe.p13_sysmap_hit_vec[t]);
      hit_any = (v_probe.p13_sysmap_hit_vec[t] != 8'h00);
      refill_match = v_probe.p13_csr_refill_req_vec[t]
                   && (v_probe.p13_csr_refill_data_vec[t][13:9] == v_probe.p13_sysmap_flg_vec[t]);

      if (hit_any || v_probe.p13_csr_refill_req_vec[t])
        cg_sysmap_flg_per_region.sample(region, v_probe.p13_sysmap_flg_vec[t], refill_match);

      if (v_probe.p13_twu_crs2_1g_vec[t])
        cg_sysmap_cross_1g.sample(
          v_probe.p13_twu_csr_cross_vec[t],
          region,
          hit_any);

      if (v_probe.p13_twu_crs2_2m_vec[t])
        cg_sysmap_cross_2m.sample(
          v_probe.p13_twu_csr_cross_vec[t],
          region,
          hit_any);

      before_pgs = 0;
      if (v_probe.p13_twu_crs2_1g_vec[t])
        before_pgs = 4;
      else if (v_probe.p13_twu_crs2_2m_vec[t])
        before_pgs = 2;
      else
        before_pgs = f_p13_pgs_class(v_probe.p13_csr_refill_pgs_vec[t]);
      after_pgs = f_p13_pgs_class(v_probe.p13_csr_refill_pgs_vec[t]);
      if ((before_pgs != 0) && (after_pgs != 0))
        cg_sysmap_degrade_pgs.sample(before_pgs, after_pgs);

      if (hit_any || v_probe.p13_csr_refill_req_vec[t]) begin
        cg_sysmap_pa_align.sample(
          (after_pgs != 0) ? after_pgs : 1,
          f_p13_sysmap_align_class(
            (after_pgs == 4) ? 3'b100 : ((after_pgs == 2) ? 3'b010 : 3'b001),
            v_probe.p13_sysmap_pa_vec[t],
            v_probe.p13_twu_sysmap_adder_vec[t]));
      end

      if (hit_any || v_probe.p13_csr_refill_req_vec[t] || v_probe.p13_twu_crs2_chk_vec[t]) begin
        if (!hit_any)
          cg_sysmap_default_flag.sample(
            1'b1,
            v_probe.p13_sysmap_flg_vec[t],
            v_probe.p13_csr_refill_req_vec[t]
              && (v_probe.p13_csr_refill_data_vec[t][13:9] == 5'b10011));
        else
          cg_sysmap_default_flag.sample(1'b0, v_probe.p13_sysmap_flg_vec[t], 1'b0);
      end

      if (hit_any || v_probe.p13_csr_refill_req_vec[t] || v_probe.p13_twu_crs2_chk_vec[t])
        active_sysmap_cnt++;
      if (hit_any && (v_probe.p13_sysmap_pa_vec[t] != v_probe.p13_twu_sysmap_adder_vec[t][39:12]))
        sysmap_port_map_ok = 1'b0;
    end

    if (active_sysmap_cnt != 0)
      cg_sysmap_4twu_concurrent.sample(active_sysmap_cnt, sysmap_port_map_ok);
  endfunction

  virtual function void sample_dut;
    wb_ptw_ready_hist_valid = wb_ptw_ready_prev_valid;
    wb_ptw_ready_prev       = wb_ptw_ready;
    wb_ptw_ready            = v_probe.ptw_jtlb_ready;
    wb_ptw_ready_prev_valid = 1'b1;
    wb_itlb_ent    = cnt16(v_probe.l1i_entry_vld);
    wb_itlb_fsm    = v_probe.l1i_ref_fsm;
    wb_itlb_credit = v_probe.l1i_credit_cnt;
    wb_dtlb_mb_occ  = $countones(v_probe.l1d_mb_vld);
    wb_dtlb_entry_occ = $countones(v_probe.l1d_entry_vld);
    wb_dtlb_mb0_st  = v_probe.l1d_mb_st0;
    wb_dtlb_refill_src = v_probe.l1d_refill_vld ? v_probe.l1d_refill_src : 2'd0;
    wb_dtlb_l2_req = v_probe.l1d_l2_req_vld;
    wb_dtlb_l2_req_eid = v_probe.l1d_l2_req_eid;
    wb_dtlb_l2_req_load = v_probe.l1d_l2_req_is_load;
    wb_dtlb_credit_cnt = v_probe.l1d_sched_credit_cnt;
    if ((v_probe.l1d_p0_hit_vld && v_probe.l1d_p1_hit_vld))
      wb_dtlb_dual_kind = 2'd1;
    else if ((v_probe.l1d_p0_hit_vld && v_probe.l1d_p1_miss_vld)
          || (v_probe.l1d_p1_hit_vld && v_probe.l1d_p0_miss_vld))
      wb_dtlb_dual_kind = 2'd2;
    else if (v_probe.l1d_p0_miss_vld && v_probe.l1d_p1_miss_vld)
      wb_dtlb_dual_kind = 2'd3;
    else
      wb_dtlb_dual_kind = 2'd0;
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
    wb_ptw_pgflt_rsp        = v_probe.ptw_l2tlb_ref_pgflt;
    wb_ptw_acc_err_rsp      = v_probe.ptw_l2tlb_ref_acc_err;
    wb_arb_ptw_grant        = v_probe.arb_ptw_grant;
    wb_arb_busy             = v_probe.arb_l2tlb_req;
    wb_ptw_vpn_tag_match    = (v_probe.ptw_arb_vpn == v_probe.ptw_arb_ref_tag_din[46:20]);
    wb_ptw_cp0_maee         = v_probe.ptw_cp0_maee;
    wb_twu_except_kind      = f_twu_except_kind(v_probe.ptw_twu_pgflt_vec, v_probe.ptw_twu_acc_err_vec);
    wb_arb_grant_type       = f_arb_grant_type(
                                wb_ptw_acc_err_vld || wb_ptw_acc_err_rsp,
                                wb_ptw_pgflt_vld || wb_ptw_pgflt_rsp,
                                wb_arb_ptw_grant);
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
