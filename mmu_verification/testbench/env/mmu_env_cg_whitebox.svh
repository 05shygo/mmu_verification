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
  virtual lsu_if            lsu_vif;
  virtual ifu_if            ifu_vif;

  int unsigned wb_itlb_ent;
  logic [2:0]  wb_itlb_fsm;
  bit          wb_itlb_credit;
  int unsigned wb_dtlb_mb_occ;
  int unsigned wb_dtlb_entry_occ;
  logic [2:0]  wb_dtlb_mb_state_obs;
  logic [1:0]  wb_dtlb_dual_kind;
  logic [1:0]  wb_dtlb_refill_src;
  bit          wb_dtlb_refill_vld;
  logic [2:0]  wb_dtlb_refill_pgs;
  bit          wb_dtlb_hit_any;
  logic [2:0]  wb_dtlb_hit_pgs;
  bit          wb_dtlb_one_free_dual_diff;
  logic [1:0]  wb_dtlb_stamo_kind;
  logic [1:0]  wb_dtlb_direct_kind;
  bit          wb_dtlb_l2_req;
  logic [2:0]  wb_dtlb_l2_req_eid;
  bit          wb_dtlb_l2_req_load;
  int unsigned wb_dtlb_credit_cnt;
  logic [2:0]  wb_l2_b0;
  logic [2:0]  wb_l2_w0;
  logic [2:0]  wb_l2_pgs0;
  logic [3:0]  wb_reqq_iss;
  int unsigned wb_reqq_dep;
  logic [1:0]  wb_xbar_hit;
  logic [2:0]  wb_mbuf_lvl;
  bit          wb_ptw_flt;
  bit          wb_ptw_ready;
  bit          wb_ptw_ready_prev;
  bit          wb_ptw_ready_prev_valid;
  bit          wb_ptw_ready_hist_valid;
  bit          wb_twu_idle_vec;
  bit          wb_twu_mask_vec;
  int unsigned wb_twu_idle_cnt;
  int unsigned wb_twu_mask_cnt;
  int unsigned wb_twu_idle_mask_ovlp;
  int unsigned wb_twu_ref_cnt;
  int unsigned wb_twu_pgflt_cnt;
  int unsigned wb_twu_acc_err_cnt;
  // twu_reconstruct Phase 2: scalar ready replaces per-stage s0/s1/s2
  bit          wb_twu_ready_scalar;
  int unsigned wb_twu_ready_low_cycles;
  int unsigned wb_twu_ready_s0;       // DEPRECATED compat
  int unsigned wb_twu_ready_s1;       // DEPRECATED compat
  int unsigned wb_twu_ready_s2;       // DEPRECATED compat
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
  logic [1:0]  wb_tlbop_tlbp;
  logic [1:0]  wb_tlbop_tlbr;
  logic [1:0]  wb_tlbop_tlbwi;
  logic [1:0]  wb_tlbop_tlbwr;
  logic [2:0]  wb_tlbop_tlbiasid;
  bit          wb_tlbop_tlbiall;
  int unsigned wb_sample_cycles;

  // Phase 1: Permission fault and exception-CAM variables (AUD-016~018, 026~029)
  bit          wb_lsu_p0_pa_vld;
  bit          wb_lsu_p1_pa_vld;
  logic [1:0]  wb_dtlb_p0_perm_fault_kind;
  logic [1:0]  wb_dtlb_p1_perm_fault_kind;
  logic [1:0]  wb_dtlb_expt_wr_src;
  logic [1:0]  wb_dtlb_expt_wr_type;
  logic [1:0]  wb_dtlb_expt_match_kind;
  int unsigned wb_dtlb_expt_hit_cnt;

  // Phase 2: Invalidate variables (AUD-034~038)
  logic [2:0]  wb_dtlb_inv_kind;        // 3'b001=INV_ALL, 3'b010=INV_VA, 3'b100=INV_ASID
  logic [1:0]  wb_dtlb_inv_race;        // 2'b00=无竞争, 2'b01=hit同拍, 2'b10=install同拍, 2'b11=双重竞争

  // Phase 4: Install arbitration and wakeup variables (AUD-009/010/024)
  logic [1:0]  wb_dtlb_install_arb_sel;     // 2'd1=PTW, 2'd2=L2, 2'd3=WFI
  bit          wb_dtlb_install_arb_conflict; // ≥2 install_req simultaneously = 1
  bit          wb_dtlb_wakeup_active;        // l1d_expt_wakeup != 0

  // Phase 5: TLBOP operation type classification (TP_034~044)
  //   Inferred from TLBOP FSM states at tlbop_l2_tlboper_cmplt (or tlboper_ptw_abort)
  //   Encoding: 4'd1=TLBP, 4'd2=TLBR, 4'd3=TLBWI, 4'd4=TLBWR,
  //             4'd5=INVVA_ALL, 4'd6=INVASID, 4'd7=INVVA_ASID, 4'd8=INVALL, 4'd9=ABORT
  logic [3:0]  wb_tlboper_op_type;

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
    cp_pgs: coverpoint wb_l2_pgs0 {
      bins idle = {3'b000};
      bins pgs_4k = {3'b001};
      bins pgs_2m = {3'b010};
      bins pgs_1g = {3'b100};
      ignore_bins reserved = {3'b011, 3'b101, 3'b110, 3'b111};
    }
    cx_bw: cross cp_bank, cp_way;
  endgroup

  // --- cg_l2tlb_arbiter (Phase 5: TP_009~011) --------------------------------
  covergroup cg_l2tlb_arbiter;
    option.per_instance = 1;
    // ── TP_009: Read vs Write ─────────────────────────────────────────────
    cp_arb_req_type: coverpoint v_probe.l2_arb_write iff (v_probe.l2_arb_req) {
      bins read  = {0};
      bins write = {1};
    }
    // ── TP_010: Access type (l2_arb_acc_type 3-bit encoding) ──────────────
    //   3'b010 = load      (DTLB load)
    //   3'b110 = store     (DTLB store)
    //   3'b011 = fetch     (ITLB instruction fetch)
    //   3'b100 = prefetch  (PFU prefetch)
    //   3'b001 = tlbop     (TLB operation: TLBP/TLBR/TLBWI/TLBWR/INV*)
    //   3'b101 = ptw_refill (PTW page table walk refill write-back)
    //   3'b000, 3'b111 = other / reserved
    cp_arb_acc_type: coverpoint v_probe.l2_arb_acc_type iff (v_probe.l2_arb_req) {
      bins load       = {3'b010};
      bins store      = {3'b110};
      bins fetch      = {3'b011};
      bins prefetch   = {3'b100};
      bins tlbop      = {3'b001};
      bins ptw_refill = {3'b101};
      bins other      = default;
    }
    // ── TP_011: Bank selection count ──────────────────────────────────────
    //   l2_arb_bank_sel is 8-bit onehot; $countones gives number of banks selected
    cp_arb_bank_sel_cnt: coverpoint $countones(v_probe.l2_arb_bank_sel) iff (v_probe.l2_arb_req) {
      bins one   = {1};
      bins two   = {2};
      bins four  = {4};
      bins eight = {8};
      illegal_bins invalid = {0, 3, [5:7]};  // 8-bit onehot only allows power-of-two counts
    }
    // ── Stall detection ───────────────────────────────────────────────────
    //   NOTE: l2_arb_req and arb_l2tlb_req map to the same wire in current RTL
    //   (both = u_dut.arb_l2tlb_req).  The stalled bin (2'b10) may not be hit
    //   unless the probe mapping is split in a future revision.
    cp_arb_stall: coverpoint {v_probe.l2_arb_req, v_probe.arb_l2tlb_req}
                  iff (v_probe.l2_arb_req) {
      bins normal_flow = {2'b11};  // req + grant same cycle
      bins stalled     = {2'b10};  // req high but grant low (reserved for future probe split)
    }
    // ── Request source ────────────────────────────────────────────────────
    //   Inferred from per-source active signals:
    //     2'd1 = reqq       (l2_reqq_issue_valid)
    //     2'd2 = pfu        (l2_pfu_req_vld)
    //     2'd3 = ptw_refill (ptw_arb_req)
    //     2'd4 = tlbop      (tlbop_arb_req)
    cp_arb_source: coverpoint {
      v_probe.l2_reqq_issue_valid ? 2'd1 :
      v_probe.l2_pfu_req_vld      ? 2'd2 :
      v_probe.ptw_arb_req         ? 2'd3 :
      v_probe.tlbop_arb_req       ? 2'd4 : 2'd0
    } iff (v_probe.l2_arb_req) {
      bins reqq       = {2'd1};
      bins pfu        = {2'd2};
      bins ptw_refill = {2'd3};
      bins tlbop      = {2'd4};
    }
    // ── TP_011 cross: source × acc_type ───────────────────────────────────
    cx_arb_src_type: cross cp_arb_source, cp_arb_acc_type;
  endgroup

  // --- cg_l2tlb_lookup (Phase 3: TP_012~016) --------------------------------
  covergroup cg_l2tlb_lookup;
    option.per_instance = 1;
    cp_lookup_result: coverpoint {v_probe.l2_final_vld, v_probe.l2_final_tlb_hit} iff (1'b1) {
      bins idle = {2'b00, 2'b01};
      bins hit  = {2'b11};
      bins miss = {2'b10};
    }
    cp_lookup_pgs: coverpoint v_probe.l2_raw_pre_pgs0
                   iff (v_probe.l2_final_vld && v_probe.l2_final_tlb_hit) {
      bins pgs_4k = {3'b001};
      bins pgs_2m = {3'b010};
      bins pgs_1g = {3'b100};
      ignore_bins reserved = {3'b000, 3'b011, 3'b101, 3'b110, 3'b111};
    }
    // Source encoding: {l2_final_is_dtlb, acc_type == 3'b100 (prefetch)}
    //   2'b00: ITLB  (!is_dtlb, !is_pfu)
    //   2'b10: DTLB  ( is_dtlb, !is_pfu)
    //   2'b01,11: PFU  (is_pfu, regardless of is_dtlb)
    cp_lookup_source: coverpoint {v_probe.l2_final_is_dtlb,
                                   (v_probe.l2_final_acc_type == 3'b100)}
                      iff (v_probe.l2_final_vld) {
      bins itlb = {2'b00};
      bins dtlb = {2'b10};
      bins pfu  = {2'b01, 2'b11};
    }
    cp_lookup_acc_type: coverpoint v_probe.l2_final_acc_type iff (v_probe.l2_final_vld) {
      bins load     = {3'b010};
      bins store    = {3'b110};
      bins fetch    = {3'b011};
      bins prefetch = {3'b100};
      bins other    = default;
    }
    cp_lookup_way_hit_cnt: coverpoint $countones(v_probe.l2_final_way_hit)
                           iff (v_probe.l2_final_vld && v_probe.l2_final_tlb_hit) {
      bins single    = {1};
      bins multi_hit = {[2:8]};
    }
    cx_lookup_src_res: cross cp_lookup_source, cp_lookup_result;
    cx_lookup_pgs_src: cross cp_lookup_pgs, cp_lookup_source;
  endgroup

  // --- cg_l2tlb_pfu (Phase 3: TP_028~033) -----------------------------------
  covergroup cg_l2tlb_pfu;
    option.per_instance = 1;
    // PFU fault kind encoding (priority: deny > acc_fault > flag_fault > pass)
    cp_pfu_fault_kind: coverpoint {
      v_probe.pfu_l2tlb_deny       ? 3'd3 :
      v_probe.pfu_l2tlb_acc_fault  ? 3'd2 :
      v_probe.pfu_l2tlb_flag_fault ? 3'd1 : 3'd0
    } iff (v_probe.l2_pfu_rsp_vld) {
      bins pass       = {3'd0};
      bins flag_fault = {3'd1};
      bins acc_fault  = {3'd2};
      bins deny       = {3'd3};
    }
  endgroup

  // --- cg_l2tlb_ptw_if (Phase 3: TP_023~027) --------------------------------
  covergroup cg_l2tlb_ptw_if;
    option.per_instance = 1;
    cp_ptw_req: coverpoint v_probe.l2tlb_ptw_req iff (1'b1) {
      bins not_issued = {0};
      bins issued     = {1};
    }
    // l2tlb_ptw_type: 3'b011=fetch(ITLB), 3'b010=load(DTLB), 3'b110=store(DTLB), 3'b100=prefetch(PFU)
    cp_ptw_req_type: coverpoint v_probe.l2tlb_ptw_type iff (v_probe.l2tlb_ptw_req) {
      bins itlb = {3'b011};
      bins dtlb = {3'b010, 3'b110};
      bins pfu  = {3'b100};
      ignore_bins others = default;
    }
    // Completion type: cmplt=1 + data_vld=1 → data_valid
    //                 cmplt=1 + pgflt=1   → page_fault
    //                 cmplt=1 + acc_err=1 → access_err
    cp_ptw_cmplt_type: coverpoint {
      v_probe.ptw_l2tlb_cmplt && v_probe.ptw_l2tlb_ref_data_vld ? 2'd1 :
      v_probe.ptw_l2tlb_cmplt && v_probe.ptw_l2tlb_ref_pgflt   ? 2'd2 :
      v_probe.ptw_l2tlb_cmplt && v_probe.ptw_l2tlb_ref_acc_err  ? 2'd3 : 2'd0
    } iff (v_probe.ptw_l2tlb_cmplt) {
      bins data_valid = {2'd1};
      bins page_fault = {2'd2};
      bins access_err = {2'd3};
      illegal_bins illegal_idle = {2'd0};
    }
  endgroup

  // --- cg_l1itlb ------------------------------------------------------------
  covergroup cg_l1itlb;
    option.per_instance = 1;
    cp_entry_vld_count: coverpoint wb_itlb_ent {
      bins c0_4 = {[0:4]}; bins c5_8 = {[5:8]}; bins c9_12 = {[9:12]}; bins c13_16 = {[13:16]};
    }
    cp_credit_remain: coverpoint wb_itlb_credit;
    cp_fsm_state: coverpoint wb_itlb_fsm {
      bins idle  = {3'b000};
      bins wfg   = {3'b001};
      bins wfc   = {3'b010};
      bins abt   = {3'b011};
      bins pgflt = {3'b100};
      ignore_bins unreachable_or_reserved = {3'b101, 3'b110, 3'b111};
    }
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
    cp_fsm_state: coverpoint wb_dtlb_mb_state_obs {
      bins idle  = {3'b000};
      bins wfg   = {3'b001};
      bins wfc   = {3'b010};
      bins pgflt = {3'b011};
      bins acflt = {3'b100};
      bins abt   = {3'b101};
      bins wfi   = {3'b110};
      ignore_bins reserved = {3'b111};
    }
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
    cp_refill_pgs: coverpoint wb_dtlb_refill_pgs iff (wb_dtlb_refill_vld) {
      bins pgs_4k = {3'b001};
      bins pgs_2m = {3'b010};
      bins pgs_1g = {3'b100};
    }
    cp_hit_pgs: coverpoint wb_dtlb_hit_pgs iff (wb_dtlb_hit_any) {
      bins hit_4k = {3'b001};
      bins hit_2m = {3'b010};
      bins hit_1g = {3'b100};
    }
    cp_one_free_dual_diff: coverpoint wb_dtlb_one_free_dual_diff {
      bins no = {0};
      bins yes = {1};
    }
    cp_stamo_kind: coverpoint wb_dtlb_stamo_kind {
      bins none = {2'd0};
      bins pipe1_bypass = {2'd1};
      bins pipe0_negative = {2'd2};
      bins pulse_only = {2'd3};
    }
    cp_direct_kind: coverpoint wb_dtlb_direct_kind {
      bins none = {2'd0};
      bins mmu_off_no_side_effect = {2'd1};
      bins mmu_off_with_l2_or_mb_change = {2'd2};
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
    // ── Phase 1: Permission fault (AUD-016/017/018) ──────────────────────
    cp_perm_fault_p0: coverpoint wb_dtlb_p0_perm_fault_kind iff (wb_lsu_p0_pa_vld) {
      bins none    = {2'b00};
      bins pgflt   = {2'b01};
      bins acflt   = {2'b10};
      bins both    = {2'b11};
    }
    cp_perm_fault_p1: coverpoint wb_dtlb_p1_perm_fault_kind iff (wb_lsu_p1_pa_vld) {
      bins none    = {2'b00};
      bins pgflt   = {2'b01};
      bins acflt   = {2'b10};
      bins both    = {2'b11};
    }
    // ── Phase 1: Exception-CAM write source (AUD-026) ────────────────────
    cp_expt_wr_src: coverpoint wb_dtlb_expt_wr_src iff (wb_dtlb_expt_wr_src != 2'd0) {
      bins single_p0 = {2'd1};
      bins single_p1 = {2'd2};
      bins dual      = {2'd3};
    }
    // ── Phase 1: Exception-CAM write type (AUD-027) ──────────────────────
    cp_expt_wr_type: coverpoint wb_dtlb_expt_wr_type iff (wb_dtlb_expt_wr_type != 2'd0) {
      bins pgflt     = {2'd1};
      bins acflt     = {2'd2};
      bins dual_fault = {2'd3};
    }
    // ── Phase 1: Exception-CAM match kind (AUD-028) ──────────────────────
    cp_expt_match: coverpoint wb_dtlb_expt_match_kind iff (wb_dtlb_expt_match_kind != 2'd0) {
      bins p0_match = {2'd1};
      bins p1_match = {2'd2};
      bins dual_match = {2'd3};
    }
    // ── Phase 1: Exception-CAM hit count (AUD-029) ───────────────────────
    cp_expt_hit_cnt: coverpoint wb_dtlb_expt_hit_cnt iff (1'b1) {
      bins zero  = {0};
      bins one   = {1};
      bins multi = {[2:8]};
    }
    // ── Phase 2: Invalidate type (AUD-034/035/036) ──────────────────────
    cp_inv_type: coverpoint wb_dtlb_inv_kind iff (wb_dtlb_inv_kind != 3'd0) {
      bins inv_all  = {3'b001};
      bins inv_va   = {3'b010};
      bins inv_asid = {3'b100};
    }
    // ── Phase 2: Invalidate race with hit/install (AUD-037/038) ─────────
    cp_inv_race: coverpoint wb_dtlb_inv_race iff (wb_dtlb_inv_kind != 3'd0) {
      bins no_race       = {2'd0};
      bins hit_race      = {2'd1};
      bins install_race  = {2'd2};
      bins double_race   = {2'd3};
    }
    // ── Phase 4: Install arbitration selection (AUD-024) ──────────────────
    // Selection priority matches RTL: WFI > PTW > L2
    //   (see l1dtlb_function_description.txt line 40-46)
    cp_install_arb_sel: coverpoint wb_dtlb_install_arb_sel iff (wb_dtlb_refill_vld) {
      bins ptw = {2'd1};
      bins l2  = {2'd2};
      bins wfi = {2'd3};
    }
    // ── Phase 4: Install arbitration conflict (AUD-024) ────────────────────
    // Detects ≥2 install_req simultaneously asserted in same cycle
    cp_install_arb_conflict: coverpoint wb_dtlb_install_arb_conflict iff (wb_dtlb_refill_vld) {
      bins no_conflict = {0};
      bins conflict    = {1};
    }
    // ── Phase 4: Wakeup signal state (AUD-009/010) ─────────────────────────
    // l1d_expt_wakeup[11:0] broadcast: all-0=inactive, all-1=active
    // RTL wakeup semantics: active during refill OR when MB has pgflt/acflt entry
    cp_wakeup: coverpoint wb_dtlb_wakeup_active {
      bins inactive = {0};
      bins active   = {1};
    }
  endgroup

  // --- cg_l2_reqq -----------------------------------------------------------
  covergroup cg_l2_reqq;
    option.per_instance = 1;
    cp_alloc_idx: coverpoint wb_reqq_iss { bins id[] = {[0:8]}; }
    cp_depth: coverpoint wb_reqq_dep { bins d0 = {0}; bins d1_4 = {[1:4]}; bins d5_9 = {[5:9]}; }
  endgroup

  // --- cg_tlboper_fsm -------------------------------------------------------
  covergroup cg_tlboper_fsm;
    option.per_instance = 1;
    // Current ct_mmu_tlboper implements a compact INVVA FSM:
    // IDLE/RD/CMP/WR/WT/CMPLT.  The old per-page-size 2M/1G states are
    // commented out in RTL and must not be counted as stimulus holes.
    cp_invva_state: coverpoint wb_tlbiva {
      bins idle  = {4'd0};
      bins rd    = {4'd2};
      bins cmp   = {4'd3};
      bins wr    = {4'd4};
      bins wt    = {4'd5};
      bins cmplt = {4'd14};
      ignore_bins reserved_or_legacy = {4'd1, [4'd6:4'd13], 4'd15};
    }
    cp_tlbp_state: coverpoint wb_tlbop_tlbp {
      bins idle = {2'd0};
      bins wfg  = {2'd1};
      bins wfc  = {2'd3};
      ignore_bins reserved = {2'd2};
    }
    cp_tlbr_state: coverpoint wb_tlbop_tlbr {
      bins idle = {2'd0};
      bins wfg  = {2'd1};
      bins wfc  = {2'd3};
      ignore_bins reserved = {2'd2};
    }
    cp_tlbwi_state: coverpoint wb_tlbop_tlbwi {
      bins idle = {2'd0};
      bins wfg  = {2'd1};
      bins wfc  = {2'd3};
      ignore_bins reserved = {2'd2};
    }
    cp_tlbwr_state: coverpoint wb_tlbop_tlbwr {
      bins idle = {2'd0};
      bins wfg  = {2'd2};
      bins tag  = {2'd1};
      bins wfc  = {2'd3};
    }
    cp_invasid_state: coverpoint wb_tlbop_tlbiasid {
      bins idle = {3'd0};
      bins rd   = {3'd1};
      bins wfc  = {3'd2};
      bins wt   = {3'd3};
      bins nwt  = {3'd4};
      ignore_bins reserved = {[3'd5:3'd7]};
    }
    cp_invall_state: coverpoint wb_tlbop_tlbiall {
      bins idle = {1'b0};
      bins wfc  = {1'b1};
    }
    // ── Phase 5: TLBOP operation type (TP_034~044) ────────────────────────
    //   iff: wb_tlboper_op_type != 0 (sampled when any TLBOP completes or aborts)
    //
    //   wb_tlboper_op_type encoding (inferred from TLBOP FSM states at completion):
    //     4'd1 = TLBP        (tlbop_tlbp_fsm     != IDLE when tlbop_l2_tlboper_cmplt)
    //     4'd2 = TLBR        (tlbop_tlbr_fsm     != IDLE when ...)
    //     4'd3 = TLBWI       (tlbop_tlbwi_fsm    != IDLE when ...)
    //     4'd4 = TLBWR       (tlbop_tlbwr_fsm    != IDLE when ...)
    //     4'd5 = INVVA_ALL   (tlbiva_cur_st      != IVA_IDLE, VA-hit path)
    //     4'd6 = INVASID     (tlbop_tlbiasid_fsm != IDLE when ...)
    //     4'd7 = INVVA_ASID  (tlbiva_cur_st      != IVA_IDLE, ASID-hit path)
    //     4'd8 = INVALL      (tlbop_tlbiall_fsm  != IDLE when ...)
    //     4'd9 = ABORT       (tlboper_ptw_abort asserted)
    //   The undersampled tlbop_l2_tlboper_sel (8-bit way-select, not opcode) is
    //   supplemented by FSM state inference to disambiguate operation type.
    //   Reference: ct_mmu_tlboper.v §tlboper_sel (L2TLB way-select for write ops).
    cp_op_type: coverpoint wb_tlboper_op_type iff (wb_tlboper_op_type != 4'd0) {
      bins tlbp       = {4'd1};
      bins tlbr       = {4'd2};
      bins tlbwi      = {4'd3};
      bins tlbwr      = {4'd4};
      bins invva_all  = {4'd5};
      bins invasid    = {4'd6};
      bins invva_asid = {4'd7};
      bins invall     = {4'd8};
      bins abort_op   = {4'd9};
    }
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
    cp_idle_cnt: coverpoint wb_twu_idle_cnt { bins z = {0}; bins one = {1}; }
    cp_mask_cnt: coverpoint wb_twu_mask_cnt { bins z = {0}; bins one = {1}; }
    cp_have_cnt: coverpoint wb_mbuf_have_cnt { bins z = {0}; bins one = {1}; }
    cp_idle_mask_overlap: coverpoint wb_twu_idle_mask_ovlp { bins clean = {0}; bins overlap = {1}; }
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

  // --- twu_reconstruct Phase 2: cg_twu_scalar_ready_by_return_level -------------
  covergroup cg_twu_scalar_ready_by_return_level;
    option.per_instance = 1;
    cp_ready_state: coverpoint wb_twu_ready_scalar { bins high = {1}; bins low = {0}; }
    cp_returned_level: coverpoint wb_mbuf_lvl iff (wb_mbuf_lvl != 3'b000) {
      bins fst = {3'b100}; bins scd = {3'b010}; bins thd = {3'b001};
    }
    cp_have_cnt: coverpoint wb_mbuf_have_cnt { bins z = {0}; bins one = {1}; }
    cx_ready_level: cross cp_ready_state, cp_returned_level;
  endgroup

  // DEPRECATED — kept for legacy reference only; not used for signoff
  covergroup cg_twu_data_ready_per_stage;
    option.per_instance = 1;
    cp_stage0: coverpoint wb_twu_ready_s0 { bins z = {0}; bins one = {1}; }
    cp_stage1: coverpoint wb_twu_ready_s1 { bins z = {0}; bins one = {1}; }
    cp_stage2: coverpoint wb_twu_ready_s2 { bins z = {0}; bins one = {1}; }
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

  // twu_reconstruct Phase 2: unified PMP unit level×result covergroup
  covergroup cg_pmp_unit_level_result with function sample(int unsigned level, int unsigned result, bit mbuf_req);
    option.per_instance = 1;
    cp_level: coverpoint level { bins fst = {0}; bins scd = {1}; bins thd = {2}; }
    cp_result: coverpoint result { bins pass = {1}; bins deny = {2}; bins wait_seen = {3}; }
    cp_mbuf: coverpoint mbuf_req { bins issued = {1}; }
    cx_level_result: cross cp_level, cp_result;
  endgroup

  // DEPRECATED — kept for legacy reference; replaced by cg_pmp_unit_level_result
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
    cp_mask_cnt: coverpoint mask_cnt { bins one = {1}; }
    cp_all_mask: coverpoint all_mask { bins no = {0}; bins yes = {1}; }
  endgroup

  // ── twu_reconstruct Phase 2: cg_l1pmpflg_payload_path ──────────────────
  covergroup cg_l1pmpflg_payload_path with function sample(
    bit pde_hit, bit xbar_valid, bit pmp_consume, bit mbuf_payload
  );
    option.per_instance = 1;
    cp_pde_hit:    coverpoint pde_hit    { bins hit = {1}; }
    cp_xbar_valid: coverpoint xbar_valid { bins valid = {1}; }
    cp_pmp_consume: coverpoint pmp_consume { bins consumed = {1}; }
    cp_mbuf_payload: coverpoint mbuf_payload { bins valid = {1}; }
    cx_path: cross cp_pde_hit, cp_xbar_valid, cp_pmp_consume;
  endgroup

  // ── twu_reconstruct Phase 2: cg_twu_visible_class_mutex ────────────────
  covergroup cg_twu_visible_class_mutex with function sample(
    bit pmp_accerr, bit chk_pgflt, bit chk_refill, bit csr_refill,
    bit mbuf_bus_error, bit pde_direct
  );
    option.per_instance = 1;
    cp_pmp_accerr:    coverpoint pmp_accerr    { bins fire = {1}; }
    cp_chk_pgflt:     coverpoint chk_pgflt     { bins fire = {1}; }
    cp_chk_refill:    coverpoint chk_refill    { bins fire = {1}; }
    cp_csr_refill:    coverpoint csr_refill    { bins fire = {1}; }
    cp_mbuf_buserror: coverpoint mbuf_bus_error { bins fire = {1}; }
    cp_pde_direct:    coverpoint pde_direct    { bins fire = {1}; }
  endgroup

  covergroup cg_ptw_pmp_port_map with function sample(int unsigned twu_idx, int unsigned port_id, bit pa_seen, int unsigned acc_kind, bit fetch_sideband);
    option.per_instance = 1;
    cp_twu: coverpoint twu_idx { bins one = {0}; }
    cp_port: coverpoint port_id { bins p3 = {3}; }
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
    cp_active_cnt: coverpoint active_cnt { bins one = {1}; }
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

  function int unsigned cnt_twu_stage(input logic [2:0] v, input int unsigned stage);
    return int'(v[stage]);
  endfunction

  function logic [1:0] f_twu_except_kind(input logic pgflt_vec, input logic accerr_vec);
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

  function new(string name, uvm_component parent);
    super.new(name, parent);
    wb_sample_cycles               = 0;
    cg_ptw_walk                  = new();
    cg_l2tlb_bank                = new();
    cg_l2tlb_arbiter             = new();
    cg_l2tlb_lookup              = new();
    cg_l2tlb_pfu                 = new();
    cg_l2tlb_ptw_if              = new();
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
    cg_pmp_unit_level_result     = new();
    cg_twu_scalar_ready_by_return_level = new();
    cg_l1pmpflg_payload_path     = new();
    cg_twu_visible_class_mutex   = new();
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
    if (!uvm_config_db#(virtual lsu_if)::get(this, "", "LSU_VIF", lsu_vif)) begin
      `uvm_info(get_type_name(), "LSU_VIF not in config_db - L1DTLB LSU-driven whitebox bins will use DUT probes only", UVM_LOW)
    end
    if (!uvm_config_db#(virtual ifu_if)::get(this, "", "IFU_VIF", ifu_vif)) begin
      `uvm_info(get_type_name(), "IFU_VIF not in config_db - L1ITLB full-state whitebox bins will use DUT probes only", UVM_LOW)
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
      cg_l2tlb_arbiter.sample();
      cg_l2tlb_lookup.sample();
      cg_l2tlb_pfu.sample();
      cg_l2tlb_ptw_if.sample();
      cg_l1itlb.sample();
      sample_l1dtlb_covergroup();
      cg_l2_reqq.sample();
      cg_tlboper_fsm.sample();
      cg_ptw_ready_transition.sample();
      cg_twu_idle_vs_mask_state.sample();
      cg_xbar_hit_level.sample();
      cg_twu_except_while_arb_busy.sample();
      // twu_reconstruct Phase 2: scalar ready replaces per-stage
      cg_twu_scalar_ready_by_return_level.sample();
      cg_twu_data_ready_per_stage.sample();  // DEPRECATED compat
      cg_arb_grant_type.sample();
      cg_ptw_arb_pgs_type.sample();
      cg_maee_leaf_level.sample();
      cg_maee_path.sample();
      sample_phase13_covergroups();
      sample_reconstruct_covergroups();
      // ── Phase 1: Independent sampling of L1DTLB permission fault & expt-CAM coverpoints ──
      // Permission fault coverpoints require lsu_vif for page_fault/access_fault signals
      if (lsu_vif != null) begin
        cg_l1dtlb.sample();
      end
      // Exception-CAM coverpoints use v_probe only, always sample
      cg_l1dtlb.sample();
      // ── Phase 2: Independent sampling of L1DTLB invalidate coverpoints (AUD-034~038) ──
      cg_l1dtlb.sample();
      // ── Phase 4: Independent sampling of L1DTLB install arbitration & wakeup coverpoints ──
      cg_l1dtlb.sample();
      wb_sample_cycles++;
    end
  endtask

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    `uvm_info(get_type_name(),
      $sformatf("whitebox_cg summary: sampled_cycles=%0d ptw_ready=%0.2f twu_idle_mask=%0.2f xbar_hit=%0.2f twu_except_busy=%0.2f twu_scalar_ready=%0.2f arb_grant=%0.2f arb_pgs=%0.2f maee_leaf=%0.2f maee_path=%0.2f l2tlb_arbiter=%0.2f l2tlb_lookup=%0.2f l2tlb_pfu=%0.2f l2tlb_ptw_if=%0.2f",
        wb_sample_cycles,
        cg_ptw_ready_transition.get_inst_coverage(),
        cg_twu_idle_vs_mask_state.get_inst_coverage(),
        cg_xbar_hit_level.get_inst_coverage(),
        cg_twu_except_while_arb_busy.get_inst_coverage(),
        cg_twu_scalar_ready_by_return_level.get_inst_coverage(),
        cg_arb_grant_type.get_inst_coverage(),
        cg_ptw_arb_pgs_type.get_inst_coverage(),
        cg_maee_leaf_level.get_inst_coverage(),
        cg_maee_path.get_inst_coverage(),
        cg_l2tlb_arbiter.get_inst_coverage(),
        cg_l2tlb_lookup.get_inst_coverage(),
        cg_l2tlb_pfu.get_inst_coverage(),
        cg_l2tlb_ptw_if.get_inst_coverage()),
      UVM_LOW)
    `uvm_info(get_type_name(),
      $sformatf("phase13_whitebox_cg summary: pmp_result=%0.2f pmp_unit_level=%0.2f pmp_grant=%0.2f pmp_pa=%0.2f pmp_deny=%0.2f twu_mask=%0.2f pmp_port=%0.2f sysmap_flg=%0.2f cross1g=%0.2f cross2m=%0.2f degrade=%0.2f sysmap_pa=%0.2f sysmap_4twu=%0.2f default=%0.2f rec_l1pmpflg=%0.2f rec_visible_mutex=%0.2f",
        cg_pmp_per_level_result.get_inst_coverage(),
        cg_pmp_unit_level_result.get_inst_coverage(),
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
        cg_sysmap_default_flag.get_inst_coverage(),
        cg_l1pmpflg_payload_path.get_inst_coverage(),
        cg_twu_visible_class_mutex.get_inst_coverage()),
      UVM_LOW)
  endfunction

  virtual function void sample_phase13_covergroups();
    int unsigned active_sysmap_cnt;
    bit          sysmap_port_map_ok;
    logic [2:0]  vld;
    logic [2:0]  grant;
    logic [2:0]  deny;
    logic [2:0]  wait_v;
    logic [2:0]  mbuf_req;
    int unsigned region;
    bit          hit_any;
    bit          refill_match;
    int unsigned before_pgs;
    int unsigned after_pgs;

    active_sysmap_cnt = 0;
    sysmap_port_map_ok = 1'b1;

    vld      = v_probe.p13_pmp_vld_vec;
    grant    = v_probe.p13_pmp_grant_vec;
    deny     = v_probe.p13_pmp_deny_vec;
    wait_v   = v_probe.p13_pmp_wait_vec;
    mbuf_req = v_probe.p13_pmp_mbuf_req_vec;

    if ((vld != 3'b000) || (grant != 3'b000))
      cg_pmp_grant_level.sample(grant);

    if ((vld != 3'b000) || (grant != 3'b000) || (v_probe.p13_pmp_pa_vec != 28'h0))
      cg_ptw_pmp_port_map.sample(
        0, 3,
        (v_probe.p13_pmp_pa_vec != 28'h0),
        f_p13_selected_pmp_acc_kind(grant, v_probe.p13_pmp_type_vec),
        v_probe.p13_pmp_fetch_vec);

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
          f_p13_pmp_align_class(level, v_probe.p13_pmp_pa_vec));
      end

      if (deny[bit_idx]) begin
        acc_kind = f_p13_acc_kind(v_probe.p13_pmp_type_vec[bit_idx]);
        cg_pmp_deny_by_level.sample(level, acc_kind);
      end

      if (wait_v[bit_idx])
        cg_twu_mask_cause.sample(level, int'(v_probe.ptw_twu_mask), v_probe.ptw_twu_mask);
    end

    region = f_p13_region_idx(v_probe.p13_sysmap_hit_vec);
    hit_any = (v_probe.p13_sysmap_hit_vec != 8'h00);
    refill_match = v_probe.p13_csr_refill_req_vec
                 && (v_probe.p13_csr_refill_data_vec[13:9] == v_probe.p13_sysmap_flg_vec);

    if (hit_any || v_probe.p13_csr_refill_req_vec)
      cg_sysmap_flg_per_region.sample(region, v_probe.p13_sysmap_flg_vec, refill_match);

    if (v_probe.p13_twu_crs2_1g_vec)
      cg_sysmap_cross_1g.sample(
        v_probe.p13_twu_csr_cross_vec,
        region,
        hit_any);

    if (v_probe.p13_twu_crs2_2m_vec)
      cg_sysmap_cross_2m.sample(
        v_probe.p13_twu_csr_cross_vec,
        region,
        hit_any);

    before_pgs = 0;
    if (v_probe.p13_twu_crs2_1g_vec)
      before_pgs = 4;
    else if (v_probe.p13_twu_crs2_2m_vec)
      before_pgs = 2;
    else
      before_pgs = f_p13_pgs_class(v_probe.p13_csr_refill_pgs_vec);
    after_pgs = f_p13_pgs_class(v_probe.p13_csr_refill_pgs_vec);
    if ((before_pgs != 0) && (after_pgs != 0))
      cg_sysmap_degrade_pgs.sample(before_pgs, after_pgs);

    if (hit_any || v_probe.p13_csr_refill_req_vec) begin
      cg_sysmap_pa_align.sample(
        (after_pgs != 0) ? after_pgs : 1,
        f_p13_sysmap_align_class(
          (after_pgs == 4) ? 3'b100 : ((after_pgs == 2) ? 3'b010 : 3'b001),
          v_probe.p13_sysmap_pa_vec,
          v_probe.p13_twu_sysmap_adder_vec));
    end

    if (hit_any || v_probe.p13_csr_refill_req_vec || v_probe.p13_twu_crs2_chk_vec) begin
      if (!hit_any)
        cg_sysmap_default_flag.sample(
          1'b1,
          v_probe.p13_sysmap_flg_vec,
          v_probe.p13_csr_refill_req_vec
            && (v_probe.p13_csr_refill_data_vec[13:9] == 5'b10011));
      else
        cg_sysmap_default_flag.sample(1'b0, v_probe.p13_sysmap_flg_vec, 1'b0);
    end

    if (hit_any || v_probe.p13_csr_refill_req_vec || v_probe.p13_twu_crs2_chk_vec)
      active_sysmap_cnt++;
    if (hit_any && (v_probe.p13_sysmap_pa_vec != v_probe.p13_twu_sysmap_adder_vec[39:12]))
      sysmap_port_map_ok = 1'b0;

    if (active_sysmap_cnt != 0)
      cg_sysmap_4twu_concurrent.sample(active_sysmap_cnt, sysmap_port_map_ok);

    // twu_reconstruct Phase 2: also sample unified PMP unit result
    if ((v_probe.twu_pmp_unit_vld === 1'b1) || (v_probe.twu_pmp_unit_wait === 1'b1)) begin
      int unsigned u_level;
      int unsigned u_result;
      u_level = (v_probe.twu_pmp_unit_lvl[2]) ? 0 :
                (v_probe.twu_pmp_unit_lvl[1]) ? 1 : 2;
      u_result = 0;
      if (v_probe.twu_pmp_unit_wait)
        u_result = 3;
      else if (v_probe.twu_pmp_unit_deny)
        u_result = 2;
      else if (v_probe.twu_pmp_unit_vld)
        u_result = 1;
      if (u_result != 0)
        cg_pmp_unit_level_result.sample(u_level, u_result, v_probe.twu_pmp_unit_mbuf_req);
    end
  endfunction

  // ── twu_reconstruct Phase 2: unified reconstruct coverage sampling ─────
  virtual function void sample_reconstruct_covergroups();
    // l1pmpflg payload path
    cg_l1pmpflg_payload_path.sample(
      (v_probe.pde_l1_hit_vld === 1'b1),
      (v_probe.xbar_twu_l1pmpflg != 4'h0),
      (v_probe.twu_pmp_unit_l1pmpflg != 4'h0),
      (v_probe.ptw_twu_mbuf_pmpflg != 8'h00)
    );

    // visible class mutex
    cg_twu_visible_class_mutex.sample(
      v_probe.twu_access_src_pmp_unit,
      (v_probe.twu_chk_unit_page_flt === 1'b1),
      (v_probe.twu_chk_unit_refill_req === 1'b1),
      (v_probe.p13_csr_refill_req_vec === 1'b1),
      v_probe.ptw_access_src_mbuf_bus_error,
      v_probe.ptw_access_src_pde_direct
    );
  endfunction

  function logic [6:0] f_l1d_mb_states_seen(
    input logic [7:0]      vld,
    input logic [7:0][2:0] state
  );
    logic [6:0] seen;
    seen = '0;
    for (int unsigned i = 0; i < 8; i++) begin
      if (!$isunknown({vld[i], state[i]})) begin
        if (!vld[i])
          seen[0] = 1'b1;
        else if (state[i] < 3'd7)
          seen[state[i]] = 1'b1;
      end
    end
    return seen;
  endfunction

  function void sample_l1dtlb_covergroup();
    logic [6:0] states_seen;

    states_seen = f_l1d_mb_states_seen(v_probe.l1d_mb_vld, v_probe.l1d_mb_state);
    if (states_seen == 7'b0)
      states_seen[0] = 1'b1;

    for (int unsigned st = 0; st < 7; st++) begin
      if (states_seen[st]) begin
        wb_dtlb_mb_state_obs = 3'(st);
        cg_l1dtlb.sample();
      end
    end
  endfunction

  virtual function void sample_dut;
    bit lsu_p0_req;
    bit lsu_p1_req;
    bit lsu_p0_pa_vld;
    bit lsu_p1_pa_vld;
    bit stamo_vld;
    logic [27:0] lsu_p0_pa;
    logic [27:0] lsu_p1_pa;
    logic [27:0] stamo_pa;

    lsu_p0_req = 1'b0;
    lsu_p1_req = 1'b0;
    lsu_p0_pa_vld = 1'b0;
    lsu_p1_pa_vld = 1'b0;
    lsu_p0_pa = '0;
    lsu_p1_pa = '0;
    stamo_vld  = 1'b0;
    stamo_pa   = '0;
    if (lsu_vif != null) begin
      lsu_p0_req = lsu_vif.monitor_cb.lsu_mmu_va0_vld && !lsu_vif.monitor_cb.lsu_mmu_abort0;
      lsu_p1_req = lsu_vif.monitor_cb.lsu_mmu_va1_vld && !lsu_vif.monitor_cb.lsu_mmu_abort1;
      lsu_p0_pa_vld = lsu_vif.monitor_cb.mmu_lsu_pa0_vld;
      lsu_p1_pa_vld = lsu_vif.monitor_cb.mmu_lsu_pa1_vld;
      lsu_p0_pa = lsu_vif.monitor_cb.mmu_lsu_pa0;
      lsu_p1_pa = lsu_vif.monitor_cb.mmu_lsu_pa1;
      stamo_vld  = lsu_vif.monitor_cb.lsu_mmu_stamo_vld;
      stamo_pa   = lsu_vif.monitor_cb.lsu_mmu_stamo_pa;
    end

    wb_ptw_ready_hist_valid = wb_ptw_ready_prev_valid;
    wb_ptw_ready_prev       = wb_ptw_ready;
    wb_ptw_ready            = v_probe.ptw_jtlb_ready;
    wb_ptw_ready_prev_valid = 1'b1;
    wb_itlb_ent    = cnt16(v_probe.l1i_entry_vld);
    wb_itlb_fsm    = (ifu_vif != null) ? ifu_vif.monitor_cb.dbg_iutlb_ref_cur_st
                                        : {1'b0, v_probe.l1i_ref_fsm};
    wb_itlb_credit = v_probe.l1i_credit_cnt;
    wb_dtlb_mb_occ  = $countones(v_probe.l1d_mb_vld);
    wb_dtlb_entry_occ = $countones(v_probe.l1d_entry_vld);
    wb_dtlb_mb_state_obs  = 3'b000;
    wb_dtlb_refill_src = v_probe.l1d_refill_vld ? v_probe.l1d_refill_src : 2'd0;
    wb_dtlb_refill_vld = v_probe.l1d_refill_vld;
    wb_dtlb_refill_pgs = v_probe.l1d_refill_pgs;
    wb_dtlb_l2_req = v_probe.l1d_l2_req_vld;
    wb_dtlb_l2_req_eid = v_probe.l1d_l2_req_eid;
    wb_dtlb_l2_req_load = v_probe.l1d_l2_req_is_load;
    wb_dtlb_credit_cnt = v_probe.l1d_sched_credit_cnt;
    wb_dtlb_hit_any = v_probe.l1d_p0_hit_vld || v_probe.l1d_p1_hit_vld;
    wb_dtlb_hit_pgs = v_probe.l1d_p0_hit_vld ? v_probe.l1d_p0_hit_pgs :
                      v_probe.l1d_p1_hit_vld ? v_probe.l1d_p1_hit_pgs : 3'b000;
    wb_dtlb_one_free_dual_diff = v_probe.l1d_alloc_req0_vld && v_probe.l1d_alloc_req1_vld
                              && ($countones(v_probe.l1d_mb_vld) == 7)
                              && (v_probe.l1d_miss0_vpn_q != v_probe.l1d_miss1_vpn_q);
    if (!stamo_vld)
      wb_dtlb_stamo_kind = 2'd0;
    else if (lsu_p1_req && lsu_p1_pa_vld && (lsu_p1_pa == stamo_pa))
      wb_dtlb_stamo_kind = 2'd1;
    else if (lsu_p0_req && !lsu_p1_req && lsu_p0_pa_vld && (lsu_p0_pa != stamo_pa))
      wb_dtlb_stamo_kind = 2'd2;
    else
      wb_dtlb_stamo_kind = 2'd3;
    if ((lsu_vif != null) && (lsu_vif.monitor_cb.mmu_lsu_mmu_en === 1'b0) && (lsu_p0_req || lsu_p1_req))
      wb_dtlb_direct_kind = (v_probe.l1d_l2_req_vld || (v_probe.l1d_mb_vld != 8'h00)
                          || v_probe.l1d_refill_vld) ? 2'd2 : 2'd1;
    else
      wb_dtlb_direct_kind = 2'd0;
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
    wb_twu_idle_cnt         = int'(v_probe.ptw_twu_idle);
    wb_twu_mask_cnt         = int'(v_probe.ptw_twu_mask);
    wb_twu_idle_mask_ovlp   = int'(v_probe.ptw_twu_idle & v_probe.ptw_twu_mask);
    wb_twu_ref_cnt          = int'(v_probe.ptw_twu_ref_req);
    wb_twu_pgflt_cnt        = int'(v_probe.ptw_twu_pgflt_vec);
    wb_twu_acc_err_cnt      = int'(v_probe.ptw_twu_acc_err_vec);
    // twu_reconstruct Phase 2: scalar ready replaces per-stage
    wb_twu_ready_scalar     = (v_probe.ptw_twu_data_ready === 1'b1);
    wb_twu_ready_s0         = cnt_twu_stage(v_probe.ptw_twu_data_ready_legacy_vec, 0);
    wb_twu_ready_s1         = cnt_twu_stage(v_probe.ptw_twu_data_ready_legacy_vec, 1);
    wb_twu_ready_s2         = cnt_twu_stage(v_probe.ptw_twu_data_ready_legacy_vec, 2);
    wb_mbuf_have_cnt        = int'(v_probe.ptw_mbuf_twu_have);
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
                            || !wb_twu_ready_scalar
                            || (wb_twu_ready_s0 != 0)
                            || (wb_twu_ready_s1 != 0)
                            || (wb_twu_ready_s2 != 0)
                            || (wb_mbuf_lvl != 0)
                            || (wb_twu_idle_cnt != 1);
    wb_tlbiva               = v_probe.tlbiva_cur_st;
    wb_tlbop_tlbp           = v_probe.tlbop_tlbp_fsm;
    wb_tlbop_tlbr           = v_probe.tlbop_tlbr_fsm;
    wb_tlbop_tlbwi          = v_probe.tlbop_tlbwi_fsm;
    wb_tlbop_tlbwr          = v_probe.tlbop_tlbwr_fsm;
    wb_tlbop_tlbiasid       = v_probe.tlbop_tlbiasid_fsm;
    wb_tlbop_tlbiall        = v_probe.tlbop_tlbiall_fsm;

    // ── Phase 1: Permission fault (AUD-016/017/018) ────────────────────────
    wb_lsu_p0_pa_vld = lsu_p0_pa_vld;
    wb_lsu_p1_pa_vld = lsu_p1_pa_vld;
    wb_dtlb_p0_perm_fault_kind = 2'd0;
    wb_dtlb_p1_perm_fault_kind = 2'd0;
    if (lsu_vif != null) begin
      // mmu_lsu_page_fault0/1 & mmu_lsu_access_fault0/1 are on lsu_vif.monitor_cb
      case ({lsu_vif.monitor_cb.mmu_lsu_access_fault0, lsu_vif.monitor_cb.mmu_lsu_page_fault0})
        2'b01: wb_dtlb_p0_perm_fault_kind = 2'd1;  // pgflt only
        2'b10: wb_dtlb_p0_perm_fault_kind = 2'd2;  // acflt only
        2'b11: wb_dtlb_p0_perm_fault_kind = 2'd3;  // both
        default: ; // 2'b00 → none
      endcase
      case ({lsu_vif.monitor_cb.mmu_lsu_access_fault1, lsu_vif.monitor_cb.mmu_lsu_page_fault1})
        2'b01: wb_dtlb_p1_perm_fault_kind = 2'd1;
        2'b10: wb_dtlb_p1_perm_fault_kind = 2'd2;
        2'b11: wb_dtlb_p1_perm_fault_kind = 2'd3;
        default: ;
      endcase
    end

    // ── Phase 1: Exception-CAM write source (AUD-026) ──────────────────────
    if (v_probe.l1d_expt_wr0_vld && v_probe.l1d_expt_wr1_vld)
      wb_dtlb_expt_wr_src = 2'd3;  // dual
    else if (v_probe.l1d_expt_wr0_vld)
      wb_dtlb_expt_wr_src = 2'd1;  // single_p0
    else if (v_probe.l1d_expt_wr1_vld)
      wb_dtlb_expt_wr_src = 2'd2;  // single_p1
    else
      wb_dtlb_expt_wr_src = 2'd0;  // none

    // ── Phase 1: Exception-CAM write type (AUD-027) ────────────────────────
    wb_dtlb_expt_wr_type = 2'd0;
    if (v_probe.l1d_expt_wr0_vld || v_probe.l1d_expt_wr1_vld) begin
      bit has_pgflt, has_acflt;
      has_pgflt = (v_probe.l1d_expt_wr0_vld && v_probe.l1d_expt_wr0_pgflt)
               || (v_probe.l1d_expt_wr1_vld && v_probe.l1d_expt_wr1_pgflt);
      has_acflt = (v_probe.l1d_expt_wr0_vld && v_probe.l1d_expt_wr0_acflt)
               || (v_probe.l1d_expt_wr1_vld && v_probe.l1d_expt_wr1_acflt);
      case ({has_acflt, has_pgflt})
        2'b01: wb_dtlb_expt_wr_type = 2'd1;  // pgflt only
        2'b10: wb_dtlb_expt_wr_type = 2'd2;  // acflt only
        2'b11: wb_dtlb_expt_wr_type = 2'd3;  // dual_fault
        default: ;
      endcase
    end

    // ── Phase 1: Exception-CAM match kind (AUD-028) ────────────────────────
    if (v_probe.l1d_p0_expt_match && v_probe.l1d_p1_expt_match)
      wb_dtlb_expt_match_kind = 2'd3;  // dual match
    else if (v_probe.l1d_p0_expt_match)
      wb_dtlb_expt_match_kind = 2'd1;  // p0 match
    else if (v_probe.l1d_p1_expt_match)
      wb_dtlb_expt_match_kind = 2'd2;  // p1 match
    else
      wb_dtlb_expt_match_kind = 2'd0;  // none

    // ── Phase 1: Exception-CAM hit count (AUD-029) ─────────────────────────
    wb_dtlb_expt_hit_cnt = $countones(v_probe.l1d_expt_hit_vec);

    // ── Phase 2: Invalidate type and race detection (AUD-034~038) ────────
    // INV_ASID inference:
    //   When entries are cleared (l1d_entry_clr != 0) but neither
    //   tlboper_utlb_clr (INV_ALL) nor tlboper_utlb_inv_va_req (INV_VA)
    //   is active, the operation is inferred as INV_ASID — an ASID-based
    //   invalidate that clears only entries matching a specific ASID,
    //   observable as bulk l1d_entry_vld clearing.
    //   Dependencies: tlboper_utlb_clr, tlboper_utlb_inv_va_req,
    //                 l1d_entry_clr, l1d_entry_vld.
    wb_dtlb_inv_kind = 3'd0;
    if (v_probe.tlboper_utlb_clr)
      wb_dtlb_inv_kind = 3'b001;  // INV_ALL: clear all entries
    else if (v_probe.tlboper_utlb_inv_va_req)
      wb_dtlb_inv_kind = 3'b010;  // INV_VA: clear entry matching VA
    else if (|v_probe.l1d_entry_clr)
      wb_dtlb_inv_kind = 3'b100;  // INV_ASID: inferred from entry_vld bulk clearing
                                  //   when INV_ALL/INV_VA signals are inactive
    // Race detection: check if hit or install occurs in same cycle as invalidate
    if (wb_dtlb_inv_kind != 3'd0) begin
      bit inv_hit_race, inv_install_race;
      inv_hit_race     = v_probe.l1d_p0_hit_vld || v_probe.l1d_p1_hit_vld;
      inv_install_race = v_probe.l1d_refill_vld;
      case ({inv_install_race, inv_hit_race})
        2'b01: wb_dtlb_inv_race = 2'd1;  // hit same-cycle
        2'b10: wb_dtlb_inv_race = 2'd2;  // install same-cycle
        2'b11: wb_dtlb_inv_race = 2'd3;  // double race (hit + install)
        default: wb_dtlb_inv_race = 2'd0; // no race
      endcase
    end else begin
      wb_dtlb_inv_race = 2'd0;
    end

    // ── Phase 4: Install arbitration selection (AUD-024) ────────────────────
    // RTL install arbitration priority: WFI > PTW > L2
    //   (l1dtlb_function_description.txt line 40-46)
    // Probe signals l1d_install_sel_* encode the RTL arbitration result directly.
    if (v_probe.l1d_install_sel_wfi)
      wb_dtlb_install_arb_sel = 2'd3;
    else if (v_probe.l1d_install_sel_l2)
      wb_dtlb_install_arb_sel = 2'd2;
    else if (v_probe.l1d_install_sel_ptw)
      wb_dtlb_install_arb_sel = 2'd1;
    else
      wb_dtlb_install_arb_sel = 2'd0;

    // ── Phase 4: Install arbitration conflict (AUD-024) ─────────────────────
    // Detects ≥2 install_req simultaneously asserted in same cycle
    wb_dtlb_install_arb_conflict = (int'(v_probe.l1d_install_req_ptw)
                                  + int'(v_probe.l1d_install_req_l2)
                                  + int'(v_probe.l1d_install_req_wfi)) >= 2;

    // ── Phase 4: Wakeup signal state (AUD-009/010) ──────────────────────────
    // l1d_expt_wakeup[11:0] is broadcast: all-0 or all-1
    // RTL wakeup source: (a) refill/install of TLB entry
    //                    (b) OR MB contains pgflt/acflt entry
    wb_dtlb_wakeup_active = (v_probe.l1d_expt_wakeup != 12'b0);

    // ── Phase 5: TLBOP operation type classification (TP_034~044) ────────
    //   Inferred from TLBOP FSM states when tlbop_l2_tlboper_cmplt fires,
    //   or when tlboper_ptw_abort is asserted.
    //   Reference: ct_mmu_tlboper.v line 1118-1132 (completion/abort signals)
    wb_tlboper_op_type = 4'd0;
    if (v_probe.tlbop_l2_tlboper_cmplt) begin
      // TLBP: FSM leaves IDLE (2'd0) → WFG (2'd1) → WFC (2'd3; 2'd2 reserved)
      if (v_probe.tlbop_tlbp_fsm != 2'd0)
        wb_tlboper_op_type = 4'd1;
      // TLBR: same FSM pattern as TLBP
      else if (v_probe.tlbop_tlbr_fsm != 2'd0)
        wb_tlboper_op_type = 4'd2;
      // TLBWI: same FSM pattern
      else if (v_probe.tlbop_tlbwi_fsm != 2'd0)
        wb_tlboper_op_type = 4'd3;
      // TLBWR: IDLE(0)→TAG(1)→WFG(2)→WFC(3)
      else if (v_probe.tlbop_tlbwr_fsm != 2'd0)
        wb_tlboper_op_type = 4'd4;
      // INVVA: IDLE→RD→CMP→WR→WT→CMPLT (tlbiva_cur_st)
      else if (v_probe.tlbiva_cur_st != 4'd0) begin
        // INVVA subtypes: ASID-hit path vs VA-hit (all-entries) path
        if (v_probe.tlbop_l2_asid_hit)
          wb_tlboper_op_type = 4'd7;  // INVVA_ASID: ASID-based selective invalidate
        else
          wb_tlboper_op_type = 4'd5;  // INVVA_ALL: VA-based all-entries invalidate
      end
      // INVASID: IDLE→RD→WFC→WT→NWT
      else if (v_probe.tlbop_tlbiasid_fsm != 3'd0)
        wb_tlboper_op_type = 4'd6;
      // INVALL: IDLE(0)→WFC(1)
      else if (v_probe.tlbop_tlbiall_fsm != 1'b0)
        wb_tlboper_op_type = 4'd8;
    end
    // ABORT: detected when tlboper_ptw_abort fires (PTW abort during LSU TLB op)
    //   cf. ct_mmu_tlboper.v line 1132: tlboper_ptw_abort = tlb_lsu_oper && !tlb_lsu_oper_flop
    if (v_probe.tlboper_ptw_abort)
      wb_tlboper_op_type = 4'd9;

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
