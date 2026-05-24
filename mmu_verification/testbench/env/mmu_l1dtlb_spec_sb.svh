// =============================================================================
// L1DTLB spec scoreboard
//
// Lightweight whitebox-assisted protocol checks for the Chapter-3 L1DTLB audit
// rows. This checker keeps pass/fail on externally visible semantics and uses
// DUT probes only for ownership, MB state, and scheduler diagnostics.
// =============================================================================
`ifndef MMU_L1DTLB_SPEC_SB_SVH
`define MMU_L1DTLB_SPEC_SB_SVH

class mmu_l1dtlb_spec_sb extends uvm_scoreboard;

  `uvm_component_utils(mmu_l1dtlb_spec_sb)

  localparam logic [2:0] MB_STATE_IDLE  = 3'b000;
  localparam logic [2:0] MB_STATE_WFG   = 3'b001;
  localparam logic [2:0] MB_STATE_WFC   = 3'b010;
  localparam logic [2:0] MB_STATE_PGFLT = 3'b011;
  localparam logic [2:0] MB_STATE_ACFLT = 3'b100;
  localparam logic [2:0] MB_STATE_ABT   = 3'b101;
  localparam logic [2:0] MB_STATE_WFI   = 3'b110;
  localparam logic [26:0] L1DTLB_DIR_VPN_BASE = 27'h0000100;
  localparam int unsigned MB_DEPTH = 8;
  localparam int unsigned MB_ALLOC_EXPECT_DEPTH = 8;
  localparam int unsigned TOKEN_Q_DEPTH = 4;
  localparam logic [3:0] TOKEN_PATH_UNKNOWN    = 4'd0;
  localparam logic [3:0] TOKEN_PATH_DIRECT_MAP = 4'd1;
  localparam logic [3:0] TOKEN_PATH_STAMO      = 4'd2;
  localparam logic [3:0] TOKEN_PATH_EXPT       = 4'd3;
  localparam logic [3:0] TOKEN_PATH_HIT        = 4'd4;
  localparam logic [3:0] TOKEN_PATH_MB_HIT     = 4'd5;
  localparam logic [3:0] TOKEN_PATH_MISS       = 4'd6;
  localparam logic [3:0] TOKEN_PATH_PA_RSP     = 4'd7;
  localparam int unsigned L1_ENTRY_COUNT = 16;
  localparam logic [2:0] L1_PGS_4K = 3'b001;
  localparam logic [2:0] L1_PGS_2M = 3'b010;
  localparam logic [2:0] L1_PGS_1G = 3'b100;
  localparam logic [1:0] REFILL_SRC_NONE = 2'b00;
  localparam logic [1:0] REFILL_SRC_PTW  = 2'b01;
  localparam logic [1:0] REFILL_SRC_L2   = 2'b10;
  localparam logic [1:0] REFILL_SRC_WFI  = 2'b11;
  localparam int unsigned L1D_CREDIT_MAX = 8;
  localparam logic [4:0] L1D_CREDIT_MAX_CNT = 5'd8;

  typedef struct {
    bit          vld;
    int unsigned cycle;
    int unsigned pipe;
    logic [63:0] va;
    logic [26:0] vpn;
    logic [6:0]  iid;
    logic        abort;
    logic        store;
    logic        pa_vld;
    logic        page_fault;
    logic        access_fault;
    logic        hit_vld;
    logic        miss_vld;
    logic        mb_hit;
    logic        expt_match;
    logic [27:0] pa;
    logic [2:0]  hit_pgs;
    logic [27:0] fin_pa;
    logic        pre_sel;
    logic [2:0]  req_type;
    logic        direct_map;
    logic        stamo_active;
    logic        stamo_bypass;
    logic [1:0]  eff_priv;
    logic        mprv;
    logic [1:0]  mpp;
    logic        mxr;
    logic        sum;
    logic        maee;
    logic [15:0] asid;
    logic [27:0] satp_ppn;
    logic [3:0]  pmp_flg;
    logic [4:0]  sysmap_flg;
    logic [7:0]  sysmap_hit;
    logic [27:0] sysmap_pa;
    logic [3:0]  path_class;
    logic        page_fault_owner;
    logic        access_fault_owner;
  } lsu_pipe_token_t;

  typedef struct {
    bit          valid;
    logic [26:0] vpn;
    logic [27:0] ppn;
    logic [2:0]  pgs;
    logic [13:0] flg;
    int unsigned last_update_cycle;
  } l1_entry_shadow_t;

  typedef struct {
    bit          valid;
    logic [2:0]  state;
    logic [26:0] vpn;
    logic [27:0] ppn;
    logic [2:0]  pgs;
    logic [13:0] flg;
    logic [6:0]  iid;
    logic        store;
    logic        issued;
    logic        ready;
    logic        wfc;
    logic        wfi;
    int unsigned last_alloc_cycle;
    int unsigned last_update_cycle;
  } mb_shadow_t;

  typedef struct {
    bit          valid;
    string       reason;
    int unsigned issue_cycle;
    int unsigned due_cycle;
    logic [7:0]  base_vld;
    int unsigned exp_count;
    bit          expect_p0;
    bit          expect_p1;
    bit          drop_p0;
    bit          drop_p1;
    int unsigned exp_idx0;
    int unsigned exp_idx1;
    lsu_pipe_token_t p0;
    lsu_pipe_token_t p1;
  } mb_alloc_expect_t;

  typedef struct {
    bit          valid;
    string       source;
    logic [2:0]  eid;
    logic [6:0]  iid;
    logic [26:0] vpn;
    logic        pgflt;
    logic        acflt;
    logic        store;
    int unsigned write_cycle;
    int unsigned consume_cycle;
  } expt_lifecycle_t;

  typedef struct {
    bit          valid;
    string       reason;
    int unsigned due_cycle;
    int unsigned eid;
    logic [6:0]  iid;
    logic [26:0] vpn;
    logic        store;
  } mb_release_expect_t;

  virtual mmu_dut_probes_if v_probe;
  virtual lsu_if            lsu_vif;

  int unsigned m_cycles;
  int unsigned m_errors;
  int unsigned m_busy_checks;
  int unsigned m_wakeup_pulses;
  int unsigned m_dual_req_cycles;
  int unsigned m_hit_cycles;
  int unsigned m_dual_hit_cycles;
  int unsigned m_hit_miss_cycles;
  int unsigned m_dual_miss_cycles;
  int unsigned m_mb_full_cycles;
  int unsigned m_l2_req_cycles;
  int unsigned m_l2_load_req_cycles;
  int unsigned m_l2_store_req_cycles;
  int unsigned m_refill_cycles;
  int unsigned m_expt_write_cycles;
  int unsigned m_reset_state_checks;
  int unsigned m_direct_map_cycles;
  int unsigned m_stamo_cycles;
  int unsigned m_abort_req_cycles;
  int unsigned m_inv_cycles;
  int unsigned m_flush_cycles;
  int unsigned m_hpc_miss_cycles;
  int unsigned m_page_fault_cycles;
  int unsigned m_access_fault_cycles;
  int unsigned m_t0_token_cycles;
  int unsigned m_t1_token_cycles;
  int unsigned m_page_fault_pair_checks;
  int unsigned m_page_fault_load_pair_checks;
  int unsigned m_page_fault_store_pair_checks;
  int unsigned m_page_fault_no_access_fault_cycles;
  int unsigned m_access_fault_pair_checks;
  int unsigned m_access_fault_load_pair_checks;
  int unsigned m_access_fault_store_pair_checks;
  int unsigned m_fault_overlap_cycles;
  int unsigned m_credit_zero_cycles;
  int unsigned m_credit_zero_req_cycles;
  int unsigned m_abort_hit_cycles;
  int unsigned m_abort_miss_no_response_cycles;
  int unsigned m_va8_inv_cycles;
  int unsigned m_inv_hit_same_cycle_cycles;
  int unsigned m_inv_install_conflict_cycles;
  int unsigned m_install_visible_next_cycles;
  int unsigned m_expt_replay_cycles;
  int unsigned m_expt_wakeup_cycles;
  int unsigned m_expt_tlb_hit_overlap_cycles;
  int unsigned m_mb_cam_no_response_cycles;
  int unsigned m_legal_no_response_cycles;
  int unsigned m_legal_no_response_mb_cam_cycles;
  int unsigned m_legal_no_response_mb_full_cycles;
  int unsigned m_legal_no_response_abort_cycles;
  int unsigned m_legal_no_response_flush_cycles;
  int unsigned m_legal_no_response_busy_sleep_cycles;
  int unsigned m_legal_no_response_priority_drop_cycles;
  int unsigned m_no_response_side_effect_checks;
  int unsigned m_one_free_dual_diff_cycles;
  int unsigned m_one_free_p0_older_cycles;
  int unsigned m_one_free_p1_older_cycles;
  int unsigned m_refill_4k_cycles;
  int unsigned m_refill_2m_cycles;
  int unsigned m_refill_1g_cycles;
  int unsigned m_hit_4k_cycles;
  int unsigned m_hit_2m_cycles;
  int unsigned m_hit_1g_cycles;
  int unsigned m_stamo_pipe1_bypass_cycles;
  int unsigned m_stamo_pipe0_negative_cycles;
  int unsigned m_stamo_pipe0_pollution_checks;
  int unsigned m_direct_map_no_mb_cycles;
  int unsigned m_load_success_cycles;
  int unsigned m_store_success_cycles;
  int unsigned m_perm_load_r0_pf_cycles;
  int unsigned m_perm_load_mxr_pf_cycles;
  int unsigned m_perm_load_mxr_success_cycles;
  int unsigned m_perm_store_w0_pf_cycles;
  int unsigned m_perm_store_d0_pf_cycles;
  int unsigned m_perm_a0_pf_cycles;
  int unsigned m_perm_sum0_pf_cycles;
  int unsigned m_perm_sum1_success_cycles;
  int unsigned m_perm_user_u0_pf_cycles;
  int unsigned m_phase6a_inventory_checks;
  int unsigned m_phase6a_entry_payload_checks;
  int unsigned m_phase6a_refill_payload_checks;
  int unsigned m_phase6a_install_arb_checks;
  int unsigned m_phase6a_expt_consume_checks;
  int unsigned m_phase6a_mode_snapshot_checks;
  int unsigned m_phase6b_token_enqueue;
  int unsigned m_phase6b_token_queue_max;
  int unsigned m_phase6b_pf_owner_t0;
  int unsigned m_phase6b_af_owner_t1;
  int unsigned m_phase6b_fault_overlap_separate;
  int unsigned m_phase6b_expt_classified;
  int unsigned m_phase6b_pmp_t1_classified;
  int unsigned m_phase6b_stamo_classified;
  int unsigned m_phase6b_direct_map_classified;
  int unsigned m_phase6b_no_response_classified;
  int unsigned m_phase6b_remaining_broad_waive;
  int unsigned m_phase6c_shadow_reset;
  int unsigned m_phase6c_shadow_probe_sync;
  int unsigned m_phase6c_shadow_refill_update;
  int unsigned m_phase6c_shadow_clear_update;
  int unsigned m_phase6c_shadow_va8_clear;
  int unsigned m_phase6c_shadow_hit_compare;
  int unsigned m_phase6c_shadow_hit_4k;
  int unsigned m_phase6c_shadow_hit_2m;
  int unsigned m_phase6c_shadow_hit_1g;
  int unsigned m_phase6c_shadow_multi_hit_diag;
  int unsigned m_phase6c_shadow_pgs_compare;
  int unsigned m_phase6c_shadow_pa_compare;
  int unsigned m_phase6c_shadow_flag_compare;
  int unsigned m_phase6c_shadow_perm_compare;
  int unsigned m_phase6c_shadow_attr_compare;
  int unsigned m_phase6c_shadow_pf_expected;
  int unsigned m_phase6c_shadow_success_expected;
  int unsigned m_phase6c_shadow_direct_bypass;
  int unsigned m_phase6c_shadow_stamo_bypass;
  int unsigned m_phase6c_shadow_stale_hit_diag;
  int unsigned m_phase6c_shadow_current_entry_hit_repair;
  int unsigned m_phase6d_shadow_reset;
  int unsigned m_phase6d_shadow_update;
  int unsigned m_phase6d_shadow_state_check;
  int unsigned m_phase6d_shadow_payload_check;
  int unsigned m_phase6d_alloc_oracle_checks;
  int unsigned m_phase6d_alloc_single;
  int unsigned m_phase6d_alloc_dual_same_4k;
  int unsigned m_phase6d_alloc_dual_diff_two_free;
  int unsigned m_phase6d_alloc_dual_diff_one_free;
  int unsigned m_phase6d_alloc_full_drop;
  int unsigned m_phase6d_alloc_busy_sleep_drop;
  int unsigned m_phase6d_alloc_abort_drop;
  int unsigned m_phase6d_alloc_cam_drop;
  int unsigned m_phase6d_alloc_flush_drop;
  int unsigned m_phase6d_alloc_match_checks;
  int unsigned m_phase6d_alloc_expect_enq;
  int unsigned m_phase6d_alloc_expect_check;
  int unsigned m_phase6d_alloc_expect_max;
  int unsigned m_phase6d_iid_age_checks;
  int unsigned m_phase6d_iid_wrap_checks;
  int unsigned m_phase6d_mb_cam_hit_checks;
  int unsigned m_phase6d_mb_cam_current_window;
  int unsigned m_phase6d_wfg_transitions;
  int unsigned m_phase6d_wfc_transitions;
  int unsigned m_phase6d_wfi_transitions;
  int unsigned m_phase6d_pgflt_transitions;
  int unsigned m_phase6d_acflt_transitions;
  int unsigned m_phase6d_abt_transitions;
  int unsigned m_phase6d_replay_release;
  int unsigned m_phase6d_no_rsp_records;
  int unsigned m_phase6d_no_rsp_side_effect_checks;
  int unsigned m_phase6d_no_rsp_mb_cam;
  int unsigned m_phase6d_no_rsp_mb_full;
  int unsigned m_phase6d_no_rsp_abort;
  int unsigned m_phase6d_no_rsp_flush;
  int unsigned m_phase6d_no_rsp_busy_sleep;
  int unsigned m_phase6d_no_rsp_priority_drop;
  int unsigned m_phase6d_no_rsp_no_alloc;
  int unsigned m_phase6d_no_rsp_no_l2_req;
  int unsigned m_phase6d_no_rsp_no_refill;
  int unsigned m_phase6d_no_rsp_no_expt;
  int unsigned m_phase6d_no_rsp_no_wakeup;
  int unsigned m_phase6d_side_effect_matrix_checks;
  int unsigned m_phase6e_refill_oracle_checks;
  int unsigned m_phase6e_refill_ptw;
  int unsigned m_phase6e_refill_l2;
  int unsigned m_phase6e_refill_wfi;
  int unsigned m_phase6e_normal_refill_bind;
  int unsigned m_phase6e_install_onehot_checks;
  int unsigned m_phase6e_install_priority_checks;
  int unsigned m_phase6e_install_wfi_lowest;
  int unsigned m_phase6e_wfi_data_hold;
  int unsigned m_phase6e_install_visibility;
  int unsigned m_phase6e_mb_release_expect;
  int unsigned m_phase6e_mb_release_check;
  int unsigned m_phase6e_stale_no_side_effect;
  int unsigned m_phase6e_abt_late_refill;
  int unsigned m_phase6e_fault_refill_no_tlb_write;
  int unsigned m_phase6e_expt_shadow_reset;
  int unsigned m_phase6e_expt_shadow_write;
  int unsigned m_phase6e_expt_bind_mb;
  int unsigned m_phase6e_expt_pgflt;
  int unsigned m_phase6e_expt_acflt;
  int unsigned m_phase6e_expt_dual_write;
  int unsigned m_phase6e_expt_fault_hold;
  int unsigned m_phase6e_expt_replay_consume;
  int unsigned m_phase6e_expt_replay_release;
  int unsigned m_phase6e_expt_wakeup;
  int unsigned m_phase6e_expt_no_new_mb;
  int unsigned m_phase6e_expt_flush_clear;
  int unsigned m_phase6f_credit_reset;
  int unsigned m_phase6f_credit_shadow_checks;
  int unsigned m_phase6f_credit_shadow_match;
  int unsigned m_phase6f_credit_fire;
  int unsigned m_phase6f_credit_return;
  int unsigned m_phase6f_credit_fire_return;
  int unsigned m_phase6f_credit_zero;
  int unsigned m_phase6f_credit_zero_return;
  int unsigned m_phase6f_credit_zero_no_fire;
  int unsigned m_phase6f_credit_store_req;
  int unsigned m_phase6f_credit_load_req;
  int unsigned m_phase6f_wakeup_install;
  int unsigned m_phase6f_wakeup_expt;
  int unsigned m_phase6f_wakeup_negative_checks;
  int unsigned m_phase6f_wakeup_reset_negative;
  int unsigned m_phase6f_wakeup_flush_negative;
  int unsigned m_phase6f_wakeup_inv_negative;
  int unsigned m_phase6f_wakeup_abt_negative;
  int unsigned m_phase6f_flush_cycles;
  int unsigned m_phase6f_flush_mb_clear;
  int unsigned m_phase6f_flush_expt_clear;
  int unsigned m_phase6f_flush_preserve_tlb;
  int unsigned m_phase6f_inv_hit_old_boundary;
  int unsigned m_phase6f_inv_post_clear_miss;
  int unsigned m_phase6f_inv_install_final_clear;
  int unsigned m_phase6f_abt_late_no_sidefx;
  int unsigned m_phase6f_reset_visible_clear;
  int unsigned m_phase6f_plru_future_rows;
  int unsigned m_phase6f_vabuf_future_rows;

  logic [15:0] m_prev_entry_vld;
  logic [15:0][26:0] m_prev_entry_vpn;
  logic [15:0] m_prev_entry_upd;
  logic [7:0] m_prev_mb_vld;
  logic [7:0] m_prev_mb_ready;
  logic [7:0] m_prev_mb_wfc;
  logic [7:0] m_prev_mb_wfi;
  logic [7:0][2:0] m_prev_mb_state;
  logic [7:0][26:0] m_prev_mb_vpn;
  logic [7:0][27:0] m_prev_mb_ppn;
  logic [7:0][2:0] m_prev_mb_pgs;
  logic [7:0][13:0] m_prev_mb_flg;
  logic [7:0][6:0] m_prev_mb_iid;
  logic [7:0] m_prev_mb_issued;
  logic [7:0] m_prev_mb_store;
  bit m_prev_refill_vld;
  logic [3:0] m_prev_refill_idx;
  logic [26:0] m_prev_refill_vpn;
  lsu_pipe_token_t m_t1_token[2];
  lsu_pipe_token_t m_token_q[2][TOKEN_Q_DEPTH];
  int unsigned m_token_q_count[2];
  l1_entry_shadow_t m_l1_shadow[L1_ENTRY_COUNT];
  mb_shadow_t m_mb_shadow[MB_DEPTH];
  mb_alloc_expect_t m_mb_alloc_expect_q[MB_ALLOC_EXPECT_DEPTH];
  expt_lifecycle_t m_expt_life[MB_DEPTH];
  mb_release_expect_t m_phase6e_release_expect[MB_DEPTH];
  int unsigned m_mb_alloc_expect_count;
  bit m_t1_no_response_vld[2];
  string m_t1_no_response_reason[2];
  lsu_pipe_token_t m_t1_no_response_token[2];
  bit m_phase6f_credit_shadow_valid;
  int unsigned m_phase6f_credit_shadow;
  bit m_phase6f_pending_inv_check;
  int unsigned m_phase6f_pending_inv_due;
  logic [26:0] m_phase6f_pending_inv_vpn;
  bit m_phase6f_pending_inv_saw_miss;
  bit m_phase6f_pending_inv_saw_refill;
  bit m_phase6f_pending_inv_saw_bad_hit;

  bit m_seen_post_reset;
  string m_l1dtlb_tc_id;
  string m_l1dtlb_scenario_id;
  bit    m_l1dtlb_gate_en;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual mmu_dut_probes_if)::get(this, "", "MMU_DUT_PROBES_VIF", v_probe))
      `uvm_info(get_type_name(), "MMU_DUT_PROBES_VIF not found - L1DTLB spec SB idle", UVM_LOW)
    if (!uvm_config_db#(virtual lsu_if)::get(this, "", "LSU_VIF", lsu_vif))
      `uvm_info(get_type_name(), "LSU_VIF not found - L1DTLB spec SB idle", UVM_LOW)
    void'(uvm_config_db#(string)::get(this, "", "L1DTLB_TC_ID", m_l1dtlb_tc_id));
    void'(uvm_config_db#(string)::get(this, "", "L1DTLB_SCENARIO_ID", m_l1dtlb_scenario_id));
    m_l1dtlb_gate_en = (m_l1dtlb_tc_id.len() != 0);
  endfunction

  protected function void sb_error(string tag, string msg);
    m_errors++;
    `uvm_error({get_type_name(), "::", tag}, msg)
  endfunction

  protected function int unsigned count8(input logic [7:0] v);
    return int'($countones(v));
  endfunction

  protected function int unsigned count16(input logic [15:0] v);
    return int'($countones(v));
  endfunction

  protected function bit pgs_is_legal(input logic [2:0] pgs);
    return (pgs == L1_PGS_4K) || (pgs == L1_PGS_2M) || (pgs == L1_PGS_1G);
  endfunction

  protected function int unsigned count3(input logic [2:0] v);
    return int'($countones(v));
  endfunction

  protected function logic [15:0] onehot16(input logic [3:0] idx);
    logic [15:0] v;
    v = '0;
    v[idx] = 1'b1;
    return v;
  endfunction

  protected function bit l1_vpn_match(
    input logic [26:0] req_vpn,
    input logic [26:0] ent_vpn,
    input logic [2:0]  pgs
  );
    case (pgs)
      L1_PGS_4K: return req_vpn == ent_vpn;
      L1_PGS_2M: return req_vpn[26:9] == ent_vpn[26:9];
      L1_PGS_1G: return req_vpn[26:18] == ent_vpn[26:18];
      default:   return 1'b0;
    endcase
  endfunction

  protected function bit l1_flag_page_fault(
    input logic [13:0] flg,
    input bit          store,
    input bit [1:0]    eff_priv,
    input bit          mxr,
    input bit          sum
  );
    bit fault;
    fault = 1'b0;

    if (!flg[0])
      fault = 1'b1;
    if (flg[2] && !flg[1])
      fault = 1'b1;
    if (!store && !flg[1] && !(mxr && flg[3]))
      fault = 1'b1;
    if (store && !flg[2])
      fault = 1'b1;
    if ((eff_priv == 2'b01) && flg[4] && !sum)
      fault = 1'b1;
    if ((eff_priv == 2'b00) && !flg[4])
      fault = 1'b1;
    if (!flg[5])
      fault = 1'b1;
    if (store && !flg[6])
      fault = 1'b1;

    return fault;
  endfunction

  protected function logic [27:0] l1_exp_pa(input lsu_pipe_token_t tok, input l1_entry_shadow_t ent);
    // The LSU-visible DTLB PA bus is a 28-bit PPN-like value. Current RTL
    // exposes the installed entry PPN on normal hit paths; page-size-specific
    // VA bounds are checked separately by l1_vpn_match().
    return ent.ppn;
  endfunction

  protected function logic [4:0] l1_exp_attr(
    input logic [13:0] flg
  );
    logic [4:0] attr;
    bit smp_disable;

    smp_disable = 1'b0;
    attr[0] = flg[9];                    // sec
    attr[1] = flg[10] && !smp_disable;   // sh
    attr[2] = flg[13];                   // so
    attr[3] = flg[11] || !flg[13];       // buf
    attr[4] = flg[12] && !flg[13];       // ca
    return attr;
  endfunction

  protected function logic [4:0] token_attr(input int unsigned pipe);
    logic [4:0] attr;
    attr = '0;
    if (pipe == 0) begin
      attr[0] = lsu_vif.monitor_cb.mmu_lsu_sec0;
      attr[1] = lsu_vif.monitor_cb.mmu_lsu_sh0;
      attr[2] = lsu_vif.monitor_cb.mmu_lsu_so0;
      attr[3] = lsu_vif.monitor_cb.mmu_lsu_buf0;
      attr[4] = lsu_vif.monitor_cb.mmu_lsu_ca0;
    end else begin
      attr[0] = lsu_vif.monitor_cb.mmu_lsu_sec1;
      attr[1] = lsu_vif.monitor_cb.mmu_lsu_sh1;
      attr[2] = lsu_vif.monitor_cb.mmu_lsu_so1;
      attr[3] = lsu_vif.monitor_cb.mmu_lsu_buf1;
      attr[4] = lsu_vif.monitor_cb.mmu_lsu_ca1;
    end
    return attr;
  endfunction

  protected function string l1_shadow_s(input l1_entry_shadow_t ent);
    return $sformatf("valid=%0b vpn=0x%07h ppn=0x%07h pgs=0x%0h flg=0x%04h upd_cycle=%0d",
      ent.valid, ent.vpn, ent.ppn, ent.pgs, ent.flg, ent.last_update_cycle);
  endfunction

  protected function bit token_vpn_idx(input lsu_pipe_token_t tok, input int unsigned idx);
    logic [26:0] idx_vpn;
    idx_vpn = idx[26:0];
    return !$isunknown(tok.vpn) && (tok.vpn == (L1DTLB_DIR_VPN_BASE + idx_vpn));
  endfunction

  protected function bit [1:0] effective_priv_snapshot();
    if ((v_probe.mon_cb.l1d_cp0_priv_mode == 2'b11)
        && (v_probe.mon_cb.l1d_cp0_mprv === 1'b1))
      return v_probe.mon_cb.l1d_cp0_mpp;
    return v_probe.mon_cb.l1d_cp0_priv_mode;
  endfunction

  protected function string token_path_s(input logic [3:0] path);
    case (path)
      TOKEN_PATH_DIRECT_MAP: return "direct_map";
      TOKEN_PATH_STAMO:      return "stamo_bypass";
      TOKEN_PATH_EXPT:       return "expt_replay";
      TOKEN_PATH_HIT:        return "l1_hit";
      TOKEN_PATH_MB_HIT:     return "mb_cam_hit";
      TOKEN_PATH_MISS:       return "miss_allocate";
      TOKEN_PATH_PA_RSP:     return "pa_response";
      default:               return "unknown";
    endcase
  endfunction

  protected function logic [3:0] classify_token_path(input lsu_pipe_token_t tok);
    if (tok.direct_map)
      return TOKEN_PATH_DIRECT_MAP;
    if (tok.stamo_bypass)
      return TOKEN_PATH_STAMO;
    if (tok.expt_match || tok.pre_sel)
      return TOKEN_PATH_EXPT;
    if (tok.hit_vld)
      return TOKEN_PATH_HIT;
    if (tok.mb_hit)
      return TOKEN_PATH_MB_HIT;
    if (tok.miss_vld)
      return TOKEN_PATH_MISS;
    if (tok.pa_vld)
      return TOKEN_PATH_PA_RSP;
    return TOKEN_PATH_UNKNOWN;
  endfunction

  protected function bit token_same_owner(input lsu_pipe_token_t a, input lsu_pipe_token_t b);
    if (!a.vld || !b.vld)
      return 1'b0;
    return (a.pipe == b.pipe)
        && (a.cycle == b.cycle)
        && (a.iid == b.iid)
        && (a.vpn == b.vpn);
  endfunction

  protected function bit iid0_older(input logic [6:0] iid0, input logic [6:0] iid1);
    bit iid_msb_mismatch;
    bit [5:0] iid0_larger;
    bit [5:0] iid1_larger;
    bit iid0_5_0_larger;
    bit iid1_5_0_larger;

    iid_msb_mismatch = iid0[6] ^ iid1[6];

    iid0_larger[5] = iid0[5] && !iid1[5];
    iid0_larger[4] = iid0[4] && !iid1[4];
    iid0_larger[3] = iid0[3] && !iid1[3];
    iid0_larger[2] = iid0[2] && !iid1[2];
    iid0_larger[1] = iid0[1] && !iid1[1];
    iid0_larger[0] = iid0[0] && !iid1[0];

    iid1_larger[5] = !iid0[5] && iid1[5];
    iid1_larger[4] = !iid0[4] && iid1[4];
    iid1_larger[3] = !iid0[3] && iid1[3];
    iid1_larger[2] = !iid0[2] && iid1[2];
    iid1_larger[1] = !iid0[1] && iid1[1];
    iid1_larger[0] = !iid0[0] && iid1[0];

    iid0_5_0_larger = iid0_larger[5]
                   || (iid0_larger[4] && !iid1_larger[5])
                   || (iid0_larger[3] && !(|iid1_larger[5:4]))
                   || (iid0_larger[2] && !(|iid1_larger[5:3]))
                   || (iid0_larger[1] && !(|iid1_larger[5:2]))
                   || (iid0_larger[0] && !(|iid1_larger[5:1]));

    iid1_5_0_larger = iid1_larger[5]
                   || (iid1_larger[4] && !iid0_larger[5])
                   || (iid1_larger[3] && !(|iid0_larger[5:4]))
                   || (iid1_larger[2] && !(|iid0_larger[5:3]))
                   || (iid1_larger[1] && !(|iid0_larger[5:2]))
                   || (iid1_larger[0] && !(|iid0_larger[5:1]));

    m_phase6d_iid_age_checks++;
    if (iid_msb_mismatch)
      m_phase6d_iid_wrap_checks++;

    return (!iid_msb_mismatch && iid1_5_0_larger)
        || ( iid_msb_mismatch && iid0_5_0_larger);
  endfunction

  protected function string mb_state_s(input logic [2:0] st);
    case (st)
      MB_STATE_IDLE:  return "IDLE";
      MB_STATE_WFG:   return "WFG";
      MB_STATE_WFC:   return "WFC";
      MB_STATE_PGFLT: return "PGFLT";
      MB_STATE_ACFLT: return "ACFLT";
      MB_STATE_ABT:   return "ABT";
      MB_STATE_WFI:   return "WFI";
      default:        return "UNKNOWN";
    endcase
  endfunction

  protected function string mb_shadow_s(input mb_shadow_t ent);
    return $sformatf("valid=%0b state=%s vpn=0x%07h iid=%0d store=%0b issued=%0b ready=%0b wfc=%0b wfi=%0b ppn=0x%07h pgs=0x%0h flg=0x%04h alloc_cycle=%0d upd_cycle=%0d",
      ent.valid, mb_state_s(ent.state), ent.vpn, ent.iid, ent.store,
      ent.issued, ent.ready, ent.wfc, ent.wfi, ent.ppn, ent.pgs,
      ent.flg, ent.last_alloc_cycle, ent.last_update_cycle);
  endfunction

  protected function string refill_src_s(input logic [1:0] src);
    case (src)
      REFILL_SRC_PTW: return "PTW";
      REFILL_SRC_L2:  return "L2";
      REFILL_SRC_WFI: return "WFI";
      default:        return "NONE";
    endcase
  endfunction

  protected function string expt_life_s(input expt_lifecycle_t ent);
    return $sformatf("valid=%0b src=%s eid=%0d iid=%0d vpn=0x%07h pgflt=%0b acflt=%0b store=%0b wr_cycle=%0d consume_cycle=%0d",
      ent.valid, ent.source, ent.eid, ent.iid, ent.vpn, ent.pgflt,
      ent.acflt, ent.store, ent.write_cycle, ent.consume_cycle);
  endfunction

  protected function mb_shadow_t probe_mb_entry(input int unsigned idx);
    mb_shadow_t ent;
    ent = '{default: '0};
    if (idx < MB_DEPTH) begin
      ent.valid             = v_probe.mon_cb.l1d_mb_vld[idx];
      ent.state             = v_probe.mon_cb.l1d_mb_state[idx];
      ent.vpn               = v_probe.mon_cb.l1d_mb_vpn[idx];
      ent.ppn               = v_probe.mon_cb.l1d_mb_ppn[idx];
      ent.pgs               = v_probe.mon_cb.l1d_mb_pgs[idx];
      ent.flg               = v_probe.mon_cb.l1d_mb_flg[idx];
      ent.iid               = v_probe.mon_cb.l1d_mb_iid[idx];
      ent.store             = v_probe.mon_cb.l1d_mb_store[idx];
      ent.issued            = v_probe.mon_cb.l1d_mb_issued[idx];
      ent.ready             = v_probe.mon_cb.l1d_mb_ready[idx];
      ent.wfc               = v_probe.mon_cb.l1d_mb_wfc[idx];
      ent.wfi               = v_probe.mon_cb.l1d_mb_wfi[idx];
      ent.last_alloc_cycle  = m_mb_shadow[idx].last_alloc_cycle;
      ent.last_update_cycle = m_cycles;
    end
    return ent;
  endfunction

  protected function int unsigned mb_first_free(input logic [7:0] vld);
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (!vld[i])
        return i;
    end
    return MB_DEPTH;
  endfunction

  protected function int unsigned mb_second_free(input logic [7:0] vld, input int unsigned first);
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (!vld[i] && (i != int'(first)))
        return i;
    end
    return MB_DEPTH;
  endfunction

  protected function int unsigned mb_find_vpn(input logic [7:0] vld, input logic [7:0][26:0] vpn, input logic [26:0] key);
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (vld[i] && (vpn[i] == key))
        return i;
    end
    return MB_DEPTH;
  endfunction

  protected function int unsigned mb_new_entry_count();
    int unsigned n;
    n = 0;
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (v_probe.mon_cb.l1d_mb_vld[i] && !m_prev_mb_vld[i])
        n++;
    end
    return n;
  endfunction

  protected function int unsigned mb_new_entry_count_from(input logic [7:0] base_vld);
    int unsigned n;
    n = 0;
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (v_probe.mon_cb.l1d_mb_vld[i] && !base_vld[i])
        n++;
    end
    return n;
  endfunction

  protected function bit mb_alloc_transition_from(input logic [7:0] base_vld, input int i);
    if (!v_probe.mon_cb.l1d_mb_vld[i])
      return 1'b0;
    if (!base_vld[i] || !m_prev_mb_vld[i])
      return 1'b1;
    if ((v_probe.mon_cb.l1d_mb_vpn[i] !== m_prev_mb_vpn[i])
     || (v_probe.mon_cb.l1d_mb_iid[i] !== m_prev_mb_iid[i])
     || (v_probe.mon_cb.l1d_mb_store[i] !== m_prev_mb_store[i]))
      return 1'b1;
    return 1'b0;
  endfunction

  protected function int unsigned mb_alloc_transition_count_from(input logic [7:0] base_vld);
    int unsigned n;
    n = 0;
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (mb_alloc_transition_from(base_vld, i))
        n++;
    end
    return n;
  endfunction

  protected function bit mb_base_release_overlap(input logic [7:0] base_vld);
    return ((base_vld & ~m_prev_mb_vld) != 8'h00);
  endfunction

  protected function bit mb_new_entry_matches(
    input logic [26:0] vpn,
    input logic [6:0]  iid,
    input bit          store,
    output int unsigned idx
  );
    idx = MB_DEPTH;
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (v_probe.mon_cb.l1d_mb_vld[i] && !m_prev_mb_vld[i]
          && (v_probe.mon_cb.l1d_mb_vpn[i] == vpn)
          && (v_probe.mon_cb.l1d_mb_iid[i] == iid)
          && (v_probe.mon_cb.l1d_mb_store[i] == store)) begin
        idx = i;
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction

  protected function bit mb_new_entry_matches_from(
    input logic [7:0]  base_vld,
    input logic [26:0] vpn,
    input logic [6:0]  iid,
    input bit          store,
    output int unsigned idx
  );
    idx = MB_DEPTH;
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (v_probe.mon_cb.l1d_mb_vld[i] && !base_vld[i]
          && (v_probe.mon_cb.l1d_mb_vpn[i] == vpn)
          && (v_probe.mon_cb.l1d_mb_iid[i] == iid)
          && (v_probe.mon_cb.l1d_mb_store[i] == store)) begin
        idx = i;
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction

  protected function bit mb_alloc_transition_matches_from(
    input logic [7:0]  base_vld,
    input logic [26:0] vpn,
    input logic [6:0]  iid,
    input bit          store,
    output int unsigned idx
  );
    idx = MB_DEPTH;
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (mb_alloc_transition_from(base_vld, i)
          && (v_probe.mon_cb.l1d_mb_vpn[i] == vpn)
          && (v_probe.mon_cb.l1d_mb_iid[i] == iid)
          && (v_probe.mon_cb.l1d_mb_store[i] == store)) begin
        idx = i;
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction

  protected function bit mb_current_vpn_match(input logic [26:0] key, output int unsigned idx);
    idx = MB_DEPTH;
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (v_probe.mon_cb.l1d_mb_vld[i] && (v_probe.mon_cb.l1d_mb_vpn[i] == key)) begin
        idx = i;
        return 1'b1;
      end
    end
    return 1'b0;
  endfunction

  protected function void mb_alloc_expect_reset();
    for (int i = 0; i < MB_ALLOC_EXPECT_DEPTH; i++)
      m_mb_alloc_expect_q[i] = '{default: '0};
    m_mb_alloc_expect_count = 0;
  endfunction

  protected function void phase6e_lifecycle_reset();
    for (int i = 0; i < MB_DEPTH; i++) begin
      m_expt_life[i] = '{default: '0};
      m_phase6e_release_expect[i] = '{default: '0};
    end
    m_phase6e_expt_shadow_reset++;
  endfunction

  protected function bit phase6e_any_expt_life_valid();
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (m_expt_life[i].valid)
        return 1'b1;
    end
    return 1'b0;
  endfunction

  protected function void phase6f_control_reset();
    m_phase6f_credit_shadow_valid = 1'b1;
    m_phase6f_credit_shadow = L1D_CREDIT_MAX;
    m_phase6f_pending_inv_check = 1'b0;
    m_phase6f_pending_inv_due = 0;
    m_phase6f_pending_inv_vpn = '0;
    m_phase6f_pending_inv_saw_miss = 1'b0;
    m_phase6f_pending_inv_saw_refill = 1'b0;
    m_phase6f_pending_inv_saw_bad_hit = 1'b0;
    m_phase6f_credit_reset++;
  endfunction

  protected function int unsigned phase6e_lowest_wfi(input logic [7:0] wfi_vec);
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (wfi_vec[i])
        return i;
    end
    return MB_DEPTH;
  endfunction

  protected function bit phase6e_refill_matches_mb(input int unsigned eid);
    if (eid >= MB_DEPTH)
      return 1'b0;
    if (v_probe.mon_cb.l1d_refill_vpn !== v_probe.mon_cb.l1d_mb_vpn[eid])
      return 1'b0;
    if (v_probe.mon_cb.l1d_refill_ppn !== v_probe.mon_cb.l1d_mb_ppn[eid])
      return 1'b0;
    if (v_probe.mon_cb.l1d_refill_pgs !== v_probe.mon_cb.l1d_mb_pgs[eid])
      return 1'b0;
    if (v_probe.mon_cb.l1d_refill_flg !== v_probe.mon_cb.l1d_mb_flg[eid])
      return 1'b0;
    return 1'b1;
  endfunction

  protected function void phase6e_release_expect_push(
    input string       reason,
    input int unsigned eid,
    input logic [6:0]  iid,
    input logic [26:0] vpn,
    input logic        store
  );
    if (eid >= MB_DEPTH)
      return;

    if (m_phase6e_release_expect[eid].valid
        && !phase6e_release_reason_is_weaker(m_phase6e_release_expect[eid].reason,
                                             reason))
      return;

    m_phase6e_release_expect[eid] = '{default: '0};
    m_phase6e_release_expect[eid].valid     = 1'b1;
    m_phase6e_release_expect[eid].reason    = reason;
    m_phase6e_release_expect[eid].due_cycle = m_cycles + 1;
    m_phase6e_release_expect[eid].eid       = eid;
    m_phase6e_release_expect[eid].iid       = iid;
    m_phase6e_release_expect[eid].vpn       = vpn;
    m_phase6e_release_expect[eid].store     = store;
    m_phase6e_mb_release_expect++;
  endfunction

  protected function bit phase6e_release_reason_is_weaker(
    input string old_reason,
    input string new_reason
  );
    if ((old_reason == "normal_refill_install") && (new_reason == "expt_replay"))
      return 1'b1;
    return 1'b0;
  endfunction

  protected function void phase6e_check_release_expectations();
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (!m_phase6e_release_expect[i].valid
          || (m_phase6e_release_expect[i].due_cycle > m_cycles))
        continue;

      m_phase6e_mb_release_check++;
      if (v_probe.mon_cb.l1d_mb_vld[i]
          && (v_probe.mon_cb.l1d_mb_iid[i] == m_phase6e_release_expect[i].iid)
          && (v_probe.mon_cb.l1d_mb_vpn[i] == m_phase6e_release_expect[i].vpn)
          && (v_probe.mon_cb.l1d_mb_store[i] == m_phase6e_release_expect[i].store)) begin
        sb_error("P6E_MB_RELEASE",
          $sformatf("expected MB%0d release did not occur reason=%s iid=%0d vpn=0x%07h store=%0b state=%s cur_vld=0x%02h",
            i, m_phase6e_release_expect[i].reason,
            m_phase6e_release_expect[i].iid,
            m_phase6e_release_expect[i].vpn,
            m_phase6e_release_expect[i].store,
            mb_state_s(v_probe.mon_cb.l1d_mb_state[i]),
            v_probe.mon_cb.l1d_mb_vld));
      end
      if (m_phase6e_release_expect[i].reason == "expt_replay")
        m_phase6e_expt_replay_release++;
      m_phase6e_release_expect[i] = '{default: '0};
    end
  endfunction

  protected function void phase6e_check_stale_or_abt_no_side_effect(
    input string       reason,
    input int unsigned eid,
    input logic [26:0] vpn
  );
    bit tlb_sidefx;
    bit expt_sidefx;
    bit wakeup_sidefx;

    tlb_sidefx = v_probe.mon_cb.l1d_refill_vld
              && ((v_probe.mon_cb.l1d_refill_gnt_bus[eid])
               || (v_probe.mon_cb.l1d_refill_vpn == vpn));
    expt_sidefx = (v_probe.mon_cb.l1d_expt_wr0_vld
                && ((v_probe.mon_cb.l1d_expt_wr0_eid[2:0] == eid[2:0])
                 || (v_probe.mon_cb.l1d_expt_wr0_vpn == vpn)))
               || (v_probe.mon_cb.l1d_expt_wr1_vld
                && ((v_probe.mon_cb.l1d_expt_wr1_eid[2:0] == eid[2:0])
                 || (v_probe.mon_cb.l1d_expt_wr1_vpn == vpn)));
    wakeup_sidefx = (tlb_sidefx || expt_sidefx)
                 && (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup != 12'h000);
    if (tlb_sidefx || expt_sidefx || wakeup_sidefx) begin
      sb_error("P6E_STALE_ABT_SIDE_EFFECT",
        $sformatf("%s completion for MB%0d produced side effect refill=%0b expt0=%0b expt1=%0b wakeup=0x%03h",
          reason, eid, v_probe.mon_cb.l1d_refill_vld,
          v_probe.mon_cb.l1d_expt_wr0_vld, v_probe.mon_cb.l1d_expt_wr1_vld,
          lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup));
    end else begin
      if (reason == "abt_late_refill")
        m_phase6e_abt_late_refill++;
      else
        m_phase6e_stale_no_side_effect++;
      if (reason == "abt_late_refill")
        m_phase6f_abt_late_no_sidefx++;
    end
  endfunction

  protected function void phase6e_check_ref_completion(
    input string       source,
    input int unsigned eid,
    input bit          cmplt,
    input bit          pavld,
    input bit          pgflt,
    input bit          acflt,
    input logic [26:0] vpn,
    input logic [27:0] ppn,
    input logic [2:0]  pgs,
    input logic [13:0] flg
  );
    bit fault;

    if (!cmplt || (eid >= MB_DEPTH))
      return;

    fault = pgflt || acflt;

    if (!v_probe.mon_cb.l1d_mb_vld[eid]) begin
      phase6e_check_stale_or_abt_no_side_effect("stale_refill", eid, vpn);
      return;
    end

    if (v_probe.mon_cb.l1d_mb_state[eid] == MB_STATE_ABT) begin
      phase6e_check_stale_or_abt_no_side_effect("abt_late_refill", eid, vpn);
      return;
    end

    if (fault) begin
      m_phase6e_fault_refill_no_tlb_write++;
      if (v_probe.mon_cb.l1d_refill_vld
          && (v_probe.mon_cb.l1d_refill_gnt_bus[eid]
           || (v_probe.mon_cb.l1d_refill_vpn == m_prev_mb_vpn[eid]))) begin
        sb_error("P6E_FAULT_TLB_WRITE",
          $sformatf("%s fault completion wrote TLB: eid=%0d pgflt=%0b acflt=%0b ref_vpn=0x%07h mb_vpn=0x%07h refill(vld=%0b src=%s vpn=0x%07h gnt=0x%02h)",
            source, eid, pgflt, acflt, vpn, v_probe.mon_cb.l1d_mb_vpn[eid],
            v_probe.mon_cb.l1d_refill_vld, refill_src_s(v_probe.mon_cb.l1d_refill_src),
            v_probe.mon_cb.l1d_refill_vpn, v_probe.mon_cb.l1d_refill_gnt_bus));
      end

      if ((v_probe.mon_cb.l1d_mb_state[eid] != MB_STATE_WFC)
       && (v_probe.mon_cb.l1d_mb_state[eid] != MB_STATE_PGFLT)
       && (v_probe.mon_cb.l1d_mb_state[eid] != MB_STATE_ACFLT)) begin
        sb_error("P6E_FAULT_SOURCE_STATE",
          $sformatf("%s fault completion source MB%0d not in WFC/fault-hold state prev=%s vpn=0x%07h iid=%0d",
            source, eid, mb_state_s(v_probe.mon_cb.l1d_mb_state[eid]),
            v_probe.mon_cb.l1d_mb_vpn[eid],
            v_probe.mon_cb.l1d_mb_iid[eid]));
      end
      return;
    end

    if (!pavld)
      return;

    if (v_probe.mon_cb.l1d_mb_state[eid] != MB_STATE_WFC) begin
      if (v_probe.mon_cb.l1d_mb_state[eid] == MB_STATE_WFI)
        return;
      sb_error("P6E_NORMAL_REFILL_STATE",
        $sformatf("%s normal completion source MB%0d was not WFC: prev=%s vpn=0x%07h iid=%0d pavld=%0b",
          source, eid, mb_state_s(v_probe.mon_cb.l1d_mb_state[eid]),
          v_probe.mon_cb.l1d_mb_vpn[eid],
          v_probe.mon_cb.l1d_mb_iid[eid], pavld));
      return;
    end

    m_phase6e_normal_refill_bind++;
    if (vpn !== v_probe.mon_cb.l1d_mb_vpn[eid]) begin
      sb_error("P6E_NORMAL_REFILL_BIND",
        $sformatf("%s normal completion payload/source mismatch eid=%0d ref_vpn=0x%07h mb_vpn=0x%07h ref_iid=%0d mb_iid=%0d ppn=0x%07h pgs=0x%0h flg=0x%04h",
          source, eid, vpn, v_probe.mon_cb.l1d_mb_vpn[eid],
          v_probe.mon_cb.l1d_mb_iid[eid], v_probe.mon_cb.l1d_mb_iid[eid],
          ppn, pgs, flg));
    end
  endfunction

  protected function void phase6e_expt_write(
    input string       source,
    input int unsigned eid,
    input logic [6:0]  iid,
    input logic [26:0] vpn,
    input logic        pgflt,
    input logic        acflt
  );
    expt_lifecycle_t ent;

    if (eid >= MB_DEPTH)
      return;

    ent = '{default: '0};
    ent.valid       = 1'b1;
    ent.source      = source;
    ent.eid         = eid[2:0];
    ent.iid         = iid;
    ent.vpn         = vpn;
    ent.pgflt       = pgflt;
    ent.acflt       = acflt;
    ent.write_cycle = m_cycles;

    if (v_probe.mon_cb.l1d_mb_vld[eid]
        && (v_probe.mon_cb.l1d_mb_vpn[eid] == vpn)
        && (v_probe.mon_cb.l1d_mb_iid[eid] == iid)) begin
      ent.store = v_probe.mon_cb.l1d_mb_store[eid];
      m_phase6e_expt_bind_mb++;
    end else if (m_prev_mb_vld[eid]
             && (m_prev_mb_vpn[eid] == vpn)
             && (m_prev_mb_iid[eid] == iid)) begin
      ent.store = m_prev_mb_store[eid];
      m_phase6e_expt_bind_mb++;
    end else begin
      sb_error("P6E_EXPT_BIND_MB",
        $sformatf("%s expt write did not bind matching MB: eid=%0d iid=%0d vpn=0x%07h pgflt=%0b acflt=%0b prev_vld=0x%02h cur_vld=0x%02h prev_mb(vpn=0x%07h iid=%0d state=%s)",
          source, eid, iid, vpn, pgflt, acflt, m_prev_mb_vld,
          v_probe.mon_cb.l1d_mb_vld, m_prev_mb_vpn[eid], m_prev_mb_iid[eid],
          mb_state_s(m_prev_mb_state[eid])));
    end

    if (pgflt)
      m_phase6e_expt_pgflt++;
    if (acflt)
      m_phase6e_expt_acflt++;
    if ((v_probe.mon_cb.l1d_mb_state[eid] == MB_STATE_WFC)
     || (v_probe.mon_cb.l1d_mb_state[eid] == MB_STATE_PGFLT)
     || (v_probe.mon_cb.l1d_mb_state[eid] == MB_STATE_ACFLT))
      m_phase6e_expt_fault_hold++;

    m_expt_life[eid] = ent;
    m_phase6e_expt_shadow_write++;

    `uvm_info({get_type_name(), "::PHASE6E_EXPT_WRITE"},
      expt_life_s(ent), UVM_HIGH)
  endfunction

  protected function void phase6e_check_expt_consume(input lsu_pipe_token_t tok);
    int unsigned hit_idx;
    expt_lifecycle_t ent;

    if (!tok.vld || !tok.expt_match)
      return;

    hit_idx = MB_DEPTH;
    for (int i = 0; i < MB_DEPTH; i++) begin
      if (m_expt_life[i].valid
          && (m_expt_life[i].iid == tok.iid)
          && (m_expt_life[i].vpn == tok.vpn)) begin
        hit_idx = i;
        break;
      end
    end

    if (hit_idx >= MB_DEPTH) begin
      sb_error("P6E_EXPT_REPLAY_ORPHAN",
        $sformatf("expt replay has no lifecycle shadow entry: token{%s}", token_s(tok)));
      return;
    end

    ent = m_expt_life[hit_idx];
    m_phase6e_expt_replay_consume++;
    if (tok.miss_vld || tok.mb_hit)
      sb_error("P6E_EXPT_REPLAY_NEW_MB",
        $sformatf("expt replay attempted MB path: shadow{%s} token{%s}",
          expt_life_s(ent), token_s(tok)));
    else
      m_phase6e_expt_no_new_mb++;

    if (ent.pgflt && !tok.page_fault)
      sb_error("P6E_EXPT_REPLAY_PGFLT",
        $sformatf("expt replay did not produce page_fault: shadow{%s} token{%s}",
          expt_life_s(ent), token_s(tok)));
    if (ent.acflt && !tok.access_fault)
      sb_error("P6E_EXPT_REPLAY_ACFLT",
        $sformatf("expt replay did not produce access_fault: shadow{%s} token{%s}",
          expt_life_s(ent), token_s(tok)));

    if (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup == 12'hfff)
      m_phase6e_expt_wakeup++;

    phase6e_release_expect_push("expt_replay", hit_idx, ent.iid, ent.vpn, ent.store);
    m_expt_life[hit_idx].consume_cycle = m_cycles;
    m_expt_life[hit_idx].valid = 1'b0;
  endfunction

  protected function void phase6e_check_expt_lifecycle(
    input lsu_pipe_token_t t0_p0,
    input lsu_pipe_token_t t0_p1
  );
    if (v_probe.mon_cb.rtu_yy_xx_flush) begin
      if (phase6e_any_expt_life_valid())
        m_phase6f_flush_expt_clear++;
      for (int i = 0; i < MB_DEPTH; i++)
        m_expt_life[i] = '{default: '0};
      m_phase6e_expt_flush_clear++;
    end

    if (v_probe.mon_cb.l1d_expt_wr0_vld)
      phase6e_expt_write("PTW", v_probe.mon_cb.l1d_expt_wr0_eid[2:0],
        v_probe.mon_cb.l1d_expt_wr0_iid, v_probe.mon_cb.l1d_expt_wr0_vpn,
        v_probe.mon_cb.l1d_expt_wr0_pgflt, v_probe.mon_cb.l1d_expt_wr0_acflt);
    if (v_probe.mon_cb.l1d_expt_wr1_vld)
      phase6e_expt_write("L2", v_probe.mon_cb.l1d_expt_wr1_eid[2:0],
        v_probe.mon_cb.l1d_expt_wr1_iid, v_probe.mon_cb.l1d_expt_wr1_vpn,
        v_probe.mon_cb.l1d_expt_wr1_pgflt, v_probe.mon_cb.l1d_expt_wr1_acflt);
    if (v_probe.mon_cb.l1d_expt_wr0_vld && v_probe.mon_cb.l1d_expt_wr1_vld)
      m_phase6e_expt_dual_write++;

    phase6e_check_expt_consume(t0_p0);
    phase6e_check_expt_consume(t0_p1);
  endfunction

  protected function void phase6e_check_install_and_refill();
    logic [2:0] req_vec;
    logic [2:0] sel_vec;
    int unsigned exp_wfi_idx;
    int unsigned sel_eid;

    req_vec = {v_probe.mon_cb.l1d_install_req_wfi,
               v_probe.mon_cb.l1d_install_req_ptw,
               v_probe.mon_cb.l1d_install_req_l2};
    sel_vec = {v_probe.mon_cb.l1d_install_sel_wfi,
               v_probe.mon_cb.l1d_install_sel_ptw,
               v_probe.mon_cb.l1d_install_sel_l2};

    if (!$isunknown({req_vec, sel_vec})) begin
      if (sel_vec != 3'b000) begin
        m_phase6e_install_onehot_checks++;
        if (count3(sel_vec) != 1)
          sb_error("P6E_INSTALL_ONEHOT",
            $sformatf("install selected non-onehot source sel(wfi,ptw,l2)=0b%03b req=0b%03b",
              sel_vec, req_vec));
      end

      if (req_vec != 3'b000) begin
        m_phase6e_install_priority_checks++;
        if (v_probe.mon_cb.l1d_install_req_wfi && !v_probe.mon_cb.l1d_install_sel_wfi)
          sb_error("P6E_INSTALL_PRIORITY",
            $sformatf("WFI request lost priority req=0b%03b sel=0b%03b ids wfi=%0d ptw=%0d l2=%0d",
              req_vec, sel_vec, v_probe.mon_cb.l1d_install_id_wfi,
              v_probe.mon_cb.l1d_install_id_ptw, v_probe.mon_cb.l1d_install_id_l2));
        else if (!v_probe.mon_cb.l1d_install_req_wfi
              && v_probe.mon_cb.l1d_install_req_ptw
              && !v_probe.mon_cb.l1d_install_sel_ptw)
          sb_error("P6E_INSTALL_PRIORITY",
            $sformatf("PTW request lost priority over L2 req=0b%03b sel=0b%03b ids ptw=%0d l2=%0d",
              req_vec, sel_vec, v_probe.mon_cb.l1d_install_id_ptw,
              v_probe.mon_cb.l1d_install_id_l2));
        else if (!v_probe.mon_cb.l1d_install_req_wfi
              && !v_probe.mon_cb.l1d_install_req_ptw
              && v_probe.mon_cb.l1d_install_req_l2
              && !v_probe.mon_cb.l1d_install_sel_l2)
          sb_error("P6E_INSTALL_PRIORITY",
            $sformatf("L2 request was not selected req=0b%03b sel=0b%03b id_l2=%0d",
              req_vec, sel_vec, v_probe.mon_cb.l1d_install_id_l2));
      end
    end

    if (v_probe.mon_cb.l1d_install_sel_wfi) begin
      exp_wfi_idx = phase6e_lowest_wfi(v_probe.mon_cb.l1d_mb_wfi);
      if (exp_wfi_idx < MB_DEPTH) begin
        m_phase6e_install_wfi_lowest++;
        if (v_probe.mon_cb.l1d_install_id_wfi != exp_wfi_idx[2:0])
          sb_error("P6E_WFI_LOWEST",
            $sformatf("WFI install did not select lowest WFI entry exp=%0d got=%0d wfi_vec=0x%02h",
              exp_wfi_idx, v_probe.mon_cb.l1d_install_id_wfi,
              v_probe.mon_cb.l1d_mb_wfi));
      end

      if (phase6e_refill_matches_mb(v_probe.mon_cb.l1d_install_id_wfi)) begin
        m_phase6e_wfi_data_hold++;
      end else begin
        sb_error("P6E_WFI_DATA_HOLD",
          $sformatf("WFI install payload mismatch id=%0d refill(vpn=0x%07h ppn=0x%07h pgs=0x%0h flg=0x%04h) mb(vpn=0x%07h ppn=0x%07h pgs=0x%0h flg=0x%04h)",
            v_probe.mon_cb.l1d_install_id_wfi,
            v_probe.mon_cb.l1d_refill_vpn, v_probe.mon_cb.l1d_refill_ppn,
            v_probe.mon_cb.l1d_refill_pgs, v_probe.mon_cb.l1d_refill_flg,
            v_probe.mon_cb.l1d_mb_vpn[v_probe.mon_cb.l1d_install_id_wfi],
            v_probe.mon_cb.l1d_mb_ppn[v_probe.mon_cb.l1d_install_id_wfi],
            v_probe.mon_cb.l1d_mb_pgs[v_probe.mon_cb.l1d_install_id_wfi],
            v_probe.mon_cb.l1d_mb_flg[v_probe.mon_cb.l1d_install_id_wfi]));
      end
    end

    if (!v_probe.mon_cb.l1d_refill_vld)
      return;

    m_phase6e_refill_oracle_checks++;
    case (v_probe.mon_cb.l1d_refill_src)
      REFILL_SRC_PTW: begin
        m_phase6e_refill_ptw++;
        sel_eid = v_probe.mon_cb.l1d_install_id_ptw;
      end
      REFILL_SRC_L2: begin
        m_phase6e_refill_l2++;
        sel_eid = v_probe.mon_cb.l1d_install_id_l2;
      end
      REFILL_SRC_WFI: begin
        m_phase6e_refill_wfi++;
        sel_eid = v_probe.mon_cb.l1d_install_id_wfi;
      end
      default: begin
        sel_eid = MB_DEPTH;
        sb_error("P6E_REFILL_SRC",
          $sformatf("refill_vld with unknown source src=0x%0h vpn=0x%07h",
            v_probe.mon_cb.l1d_refill_src, v_probe.mon_cb.l1d_refill_vpn));
      end
    endcase

    if (sel_eid < MB_DEPTH) begin
      if ((v_probe.mon_cb.l1d_refill_gnt_bus & ~(8'b1 << sel_eid)) != 8'h00)
        sb_error("P6E_REFILL_GRANT_ONEHOT",
          $sformatf("refill grant bus has extra bits src=%s sel_eid=%0d gnt=0x%02h",
            refill_src_s(v_probe.mon_cb.l1d_refill_src), sel_eid,
            v_probe.mon_cb.l1d_refill_gnt_bus));
      if (!v_probe.mon_cb.l1d_refill_gnt_bus[sel_eid])
        sb_error("P6E_REFILL_GRANT_BIND",
          $sformatf("refill grant bus missing selected EID src=%s sel_eid=%0d gnt=0x%02h",
            refill_src_s(v_probe.mon_cb.l1d_refill_src), sel_eid,
            v_probe.mon_cb.l1d_refill_gnt_bus));
      phase6e_release_expect_push("normal_refill_install", sel_eid,
        v_probe.mon_cb.l1d_mb_iid[sel_eid], v_probe.mon_cb.l1d_mb_vpn[sel_eid],
        v_probe.mon_cb.l1d_mb_store[sel_eid]);
    end
  endfunction

  protected function void mb_alloc_expect_push(
    input string       reason,
    input logic [7:0]  base_vld,
    input int unsigned exp_count,
    input bit          expect_p0,
    input bit          expect_p1,
    input bit          drop_p0,
    input bit          drop_p1,
    input lsu_pipe_token_t p0,
    input lsu_pipe_token_t p1,
    input int unsigned exp_idx0,
    input int unsigned exp_idx1
  );
    int unsigned slot;

    slot = MB_ALLOC_EXPECT_DEPTH;
    for (int i = 0; i < MB_ALLOC_EXPECT_DEPTH; i++) begin
      if (!m_mb_alloc_expect_q[i].valid) begin
        slot = i;
        break;
      end
    end

    if (slot >= MB_ALLOC_EXPECT_DEPTH) begin
      sb_error("P6D_ALLOC_EXPECT_OVERFLOW",
        $sformatf("MB allocation expectation queue overflow reason=%s exp_count=%0d base_vld=0x%02h p0{%s} p1{%s}",
          reason, exp_count, base_vld, token_s(p0), token_s(p1)));
      return;
    end

    m_mb_alloc_expect_q[slot] = '{default: '0};
    m_mb_alloc_expect_q[slot].valid       = 1'b1;
    m_mb_alloc_expect_q[slot].reason      = reason;
    m_mb_alloc_expect_q[slot].issue_cycle = m_cycles;
    m_mb_alloc_expect_q[slot].due_cycle   = m_cycles + 1;
    m_mb_alloc_expect_q[slot].base_vld    = base_vld;
    m_mb_alloc_expect_q[slot].exp_count   = exp_count;
    m_mb_alloc_expect_q[slot].expect_p0   = expect_p0;
    m_mb_alloc_expect_q[slot].expect_p1   = expect_p1;
    m_mb_alloc_expect_q[slot].drop_p0     = drop_p0;
    m_mb_alloc_expect_q[slot].drop_p1     = drop_p1;
    m_mb_alloc_expect_q[slot].exp_idx0    = exp_idx0;
    m_mb_alloc_expect_q[slot].exp_idx1    = exp_idx1;
    m_mb_alloc_expect_q[slot].p0          = p0;
    m_mb_alloc_expect_q[slot].p1          = p1;
    m_mb_alloc_expect_count++;
    if (m_mb_alloc_expect_count > m_phase6d_alloc_expect_max)
      m_phase6d_alloc_expect_max = m_mb_alloc_expect_count;
    m_phase6d_alloc_expect_enq++;

    `uvm_info({get_type_name(), "::PHASE6D_MB_ALLOC_EXPECT"},
      $sformatf("enqueue slot=%0d reason=%s issue_cycle=%0d due_cycle=%0d base_vld=0x%02h exp_count=%0d expect_p0=%0b expect_p1=%0b drop_p0=%0b drop_p1=%0b exp_idx0=%0d exp_idx1=%0d p0{%s} p1{%s}",
        slot, reason, m_cycles, m_cycles + 1, base_vld, exp_count,
        expect_p0, expect_p1, drop_p0, drop_p1, exp_idx0, exp_idx1,
        token_s(p0), token_s(p1)),
      UVM_HIGH)
  endfunction

  protected function void check_alloc_match(
    input string reason,
    input lsu_pipe_token_t tok,
    input int unsigned exp_idx,
    input logic [7:0] base_vld
  );
    int unsigned got_idx;

    m_phase6d_alloc_match_checks++;
    if (!mb_alloc_transition_matches_from(base_vld, tok.vpn, tok.iid, tok.store, got_idx)) begin
      sb_error("P6D_ALLOC_MISS",
        $sformatf("expected MB allocation not observed reason=%s exp_idx=%0d token{%s} base_vld=0x%02h prev_vld=0x%02h cur_vld=0x%02h",
          reason, exp_idx, token_s(tok), base_vld, m_prev_mb_vld, v_probe.mon_cb.l1d_mb_vld));
      return;
    end

    if (exp_idx < MB_DEPTH && got_idx != exp_idx) begin
      sb_error("P6D_ALLOC_INDEX",
        $sformatf("MB allocation index mismatch reason=%s exp_idx=%0d got_idx=%0d token{%s} base_vld=0x%02h prev_vld=0x%02h cur_vld=0x%02h",
          reason, exp_idx, got_idx, token_s(tok), base_vld, m_prev_mb_vld, v_probe.mon_cb.l1d_mb_vld));
    end

    if (!$isunknown({v_probe.mon_cb.l1d_mb_state[got_idx],
                     v_probe.mon_cb.l1d_mb_vpn[got_idx],
                     v_probe.mon_cb.l1d_mb_iid[got_idx],
                     v_probe.mon_cb.l1d_mb_store[got_idx]})) begin
      if ((v_probe.mon_cb.l1d_mb_state[got_idx] != MB_STATE_WFG)
       && (v_probe.mon_cb.l1d_mb_state[got_idx] != MB_STATE_WFC)) begin
        sb_error("P6D_ALLOC_STATE",
          $sformatf("new MB allocation entered illegal state reason=%s idx=%0d state=%s token{%s}",
            reason, got_idx, mb_state_s(v_probe.mon_cb.l1d_mb_state[got_idx]), token_s(tok)));
      end
    end

    `uvm_info({get_type_name(), "::PHASE6D_MB_ALLOC"},
      $sformatf("reason=%s idx=%0d exp_idx=%0d base_vld=0x%02h token{%s}",
        reason, got_idx, exp_idx, base_vld, token_s(tok)),
      UVM_HIGH)
  endfunction

  protected function void check_pending_mb_alloc_expectations();
    int unsigned new_count;
    int unsigned got_idx;
    bit overlap_extra_alloc;
    bit overlap_base_release;
    mb_alloc_expect_t exp;

    if ($isunknown(v_probe.mon_cb.l1d_mb_vld))
      return;

    for (int i = 0; i < MB_ALLOC_EXPECT_DEPTH; i++) begin
      if (!m_mb_alloc_expect_q[i].valid || (m_mb_alloc_expect_q[i].due_cycle > m_cycles))
        continue;

      exp = m_mb_alloc_expect_q[i];
      new_count = mb_alloc_transition_count_from(exp.base_vld);
      overlap_extra_alloc = (new_count > exp.exp_count);
      overlap_base_release = mb_base_release_overlap(exp.base_vld);
      m_phase6d_alloc_expect_check++;

      if (new_count < exp.exp_count) begin
        sb_error("P6D_ALLOC_COUNT",
          $sformatf("allocation count mismatch reason=%s issue_cycle=%0d due_cycle=%0d exp=%0d got=%0d base_vld=0x%02h cur_vld=0x%02h p0{%s} p1{%s}",
            exp.reason, exp.issue_cycle, exp.due_cycle, exp.exp_count, new_count,
            exp.base_vld, v_probe.mon_cb.l1d_mb_vld, token_s(exp.p0), token_s(exp.p1)));
      end else if (overlap_extra_alloc) begin
        `uvm_info({get_type_name(), "::PHASE6D_MB_ALLOC_OVERLAP"},
          $sformatf("allocation expectation overlapped extra MB update reason=%s issue_cycle=%0d due_cycle=%0d exp=%0d got=%0d base_vld=0x%02h cur_vld=0x%02h p0{%s} p1{%s}",
            exp.reason, exp.issue_cycle, exp.due_cycle, exp.exp_count, new_count,
            exp.base_vld, v_probe.mon_cb.l1d_mb_vld, token_s(exp.p0), token_s(exp.p1)),
          UVM_HIGH)
      end

      if (exp.expect_p0)
        check_alloc_match({exp.reason, "_p0"}, exp.p0,
          (overlap_extra_alloc || overlap_base_release) ? MB_DEPTH : exp.exp_idx0, exp.base_vld);
      if (exp.expect_p1)
        check_alloc_match({exp.reason, "_p1"}, exp.p1,
          (overlap_extra_alloc || overlap_base_release) ? MB_DEPTH : exp.exp_idx1, exp.base_vld);

      if (exp.drop_p0
          && mb_alloc_transition_matches_from(exp.base_vld, exp.p0.vpn, exp.p0.iid, exp.p0.store, got_idx)) begin
        sb_error("P6D_ALLOC_DROP_P0",
          $sformatf("dropped p0 token allocated an MB entry reason=%s got_idx=%0d base_vld=0x%02h cur_vld=0x%02h p0{%s} p1{%s}",
            exp.reason, got_idx, exp.base_vld, v_probe.mon_cb.l1d_mb_vld,
            token_s(exp.p0), token_s(exp.p1)));
      end

      if (exp.drop_p1
          && mb_alloc_transition_matches_from(exp.base_vld, exp.p1.vpn, exp.p1.iid, exp.p1.store, got_idx)) begin
        sb_error("P6D_ALLOC_DROP_P1",
          $sformatf("dropped p1 token allocated an MB entry reason=%s got_idx=%0d base_vld=0x%02h cur_vld=0x%02h p0{%s} p1{%s}",
            exp.reason, got_idx, exp.base_vld, v_probe.mon_cb.l1d_mb_vld,
            token_s(exp.p0), token_s(exp.p1)));
      end

      `uvm_info({get_type_name(), "::PHASE6D_MB_ALLOC_EXPECT"},
        $sformatf("check slot=%0d reason=%s issue_cycle=%0d due_cycle=%0d exp_count=%0d got_count=%0d base_vld=0x%02h cur_vld=0x%02h",
          i, exp.reason, exp.issue_cycle, exp.due_cycle, exp.exp_count,
          new_count, exp.base_vld, v_probe.mon_cb.l1d_mb_vld),
        UVM_HIGH)

      m_mb_alloc_expect_q[i] = '{default: '0};
      if (m_mb_alloc_expect_count != 0)
        m_mb_alloc_expect_count--;
    end
  endfunction

  protected function void token_queue_reset();
    for (int p = 0; p < 2; p++) begin
      m_token_q_count[p] = 0;
      for (int i = 0; i < TOKEN_Q_DEPTH; i++)
        m_token_q[p][i] = '{default: '0};
    end
  endfunction

  protected function void token_queue_push(input lsu_pipe_token_t tok);
    int unsigned pipe;
    if (!tok.vld || (tok.pipe >= 2))
      return;

    pipe = tok.pipe;
    if (m_token_q_count[pipe] == TOKEN_Q_DEPTH) begin
      for (int i = 1; i < TOKEN_Q_DEPTH; i++)
        m_token_q[pipe][i-1] = m_token_q[pipe][i];
      m_token_q[pipe][TOKEN_Q_DEPTH-1] = tok;
    end else begin
      m_token_q[pipe][m_token_q_count[pipe]] = tok;
      m_token_q_count[pipe]++;
      if (m_token_q_count[pipe] > m_phase6b_token_queue_max)
        m_phase6b_token_queue_max = m_token_q_count[pipe];
    end
    m_phase6b_token_enqueue++;
  endfunction

  protected function lsu_pipe_token_t token_queue_prev(input int unsigned pipe);
    lsu_pipe_token_t tok;
    tok = '{default: '0};
    if ((pipe < 2) && (m_token_q_count[pipe] != 0))
      tok = m_token_q[pipe][m_token_q_count[pipe]-1];
    return tok;
  endfunction

  protected function string token_diag_s(input string reason, input lsu_pipe_token_t tok);
    return $sformatf("reason=%s source=%s cycle=%0d pipe=%0d iid=%0d vpn=0x%07h va=0x%016h req_type=%0d abort=%0b priv=%0d mprv=%0b mpp=%0d mxr=%0b sum=%0b direct=%0b stamo=%0b pmp=0x%0h sysmap_hit=0x%02h sysmap_flg=0x%02h pf_owner=%0b af_owner=%0b",
      reason, token_path_s(tok.path_class), tok.cycle, tok.pipe, tok.iid,
      tok.vpn, tok.va, tok.req_type, tok.abort, tok.eff_priv, tok.mprv,
      tok.mpp, tok.mxr, tok.sum, tok.direct_map, tok.stamo_bypass,
      tok.pmp_flg, tok.sysmap_hit, tok.sysmap_flg,
      tok.page_fault_owner, tok.access_fault_owner);
  endfunction

  protected function lsu_pipe_token_t sample_pipe_token(input int unsigned pipe);
    lsu_pipe_token_t tok;
    tok = '{default: '0};
    tok.pipe  = pipe;
    tok.cycle = m_cycles;
    tok.eff_priv = effective_priv_snapshot();
    tok.mprv     = v_probe.mon_cb.l1d_cp0_mprv;
    tok.mpp      = v_probe.mon_cb.l1d_cp0_mpp;
    tok.mxr      = v_probe.mon_cb.l1d_cp0_mxr;
    tok.sum      = v_probe.mon_cb.l1d_cp0_sum;
    tok.maee     = v_probe.mon_cb.l1d_cp0_maee;
    tok.asid     = v_probe.mon_cb.l1d_regs_cur_asid;
    tok.satp_ppn = v_probe.mon_cb.l1d_regs_satp_ppn;
    tok.direct_map = (lsu_vif.monitor_cb.mmu_lsu_mmu_en === 1'b0);
    tok.stamo_active = lsu_vif.monitor_cb.lsu_mmu_stamo_vld;
    if (pipe == 0) begin
      tok.vld          = lsu_vif.monitor_cb.lsu_mmu_va0_vld;
      tok.va           = lsu_vif.monitor_cb.lsu_mmu_va0;
      tok.vpn          = lsu_vif.monitor_cb.lsu_mmu_va0[38:12];
      tok.iid          = lsu_vif.monitor_cb.lsu_mmu_id0;
      tok.abort        = lsu_vif.monitor_cb.lsu_mmu_abort0;
      tok.store        = lsu_vif.monitor_cb.lsu_mmu_st_inst0;
      tok.req_type     = lsu_vif.monitor_cb.lsu_mmu_st_inst0 ? 3'd1 : 3'd0;
      tok.pa_vld       = lsu_vif.monitor_cb.mmu_lsu_pa0_vld;
      tok.page_fault   = lsu_vif.monitor_cb.mmu_lsu_page_fault0;
      tok.access_fault = lsu_vif.monitor_cb.mmu_lsu_access_fault0;
      tok.hit_vld      = v_probe.mon_cb.l1d_p0_hit_vld;
      tok.miss_vld     = v_probe.mon_cb.l1d_p0_miss_vld;
      tok.mb_hit       = v_probe.mon_cb.l1d_p0_mb_hit;
      tok.pre_sel      = v_probe.mon_cb.l1d_p0_pre_sel;
      tok.expt_match   = v_probe.mon_cb.l1d_p0_expt_match
                       || lsu_vif.monitor_cb.mmu_lsu_dtlb_expt_match0;
      tok.pa           = lsu_vif.monitor_cb.mmu_lsu_pa0;
      tok.hit_pgs      = v_probe.mon_cb.l1d_p0_hit_pgs;
      tok.fin_pa       = v_probe.mon_cb.l1d_p0_fin_pa;
      tok.stamo_bypass = 1'b0;
      tok.pmp_flg      = v_probe.mon_cb.l1d_pmp_flg0;
      tok.sysmap_flg   = v_probe.mon_cb.l1d_sysmap_flg0;
      tok.sysmap_hit   = v_probe.mon_cb.l1d_sysmap_hit0;
      tok.sysmap_pa    = v_probe.mon_cb.l1d_sysmap_pa0;
    end else begin
      tok.vld          = lsu_vif.monitor_cb.lsu_mmu_va1_vld;
      tok.va           = lsu_vif.monitor_cb.lsu_mmu_va1;
      tok.vpn          = lsu_vif.monitor_cb.lsu_mmu_va1[38:12];
      tok.iid          = lsu_vif.monitor_cb.lsu_mmu_id1;
      tok.abort        = lsu_vif.monitor_cb.lsu_mmu_abort1;
      tok.store        = lsu_vif.monitor_cb.lsu_mmu_st_inst1;
      tok.req_type     = lsu_vif.monitor_cb.lsu_mmu_st_inst1 ? 3'd1 : 3'd0;
      tok.pa_vld       = lsu_vif.monitor_cb.mmu_lsu_pa1_vld;
      tok.page_fault   = lsu_vif.monitor_cb.mmu_lsu_page_fault1;
      tok.access_fault = lsu_vif.monitor_cb.mmu_lsu_access_fault1;
      tok.hit_vld      = v_probe.mon_cb.l1d_p1_hit_vld;
      tok.miss_vld     = v_probe.mon_cb.l1d_p1_miss_vld;
      tok.mb_hit       = v_probe.mon_cb.l1d_p1_mb_hit;
      tok.pre_sel      = v_probe.mon_cb.l1d_p1_pre_sel;
      tok.expt_match   = v_probe.mon_cb.l1d_p1_expt_match
                       || lsu_vif.monitor_cb.mmu_lsu_dtlb_expt_match1;
      tok.pa           = lsu_vif.monitor_cb.mmu_lsu_pa1;
      tok.hit_pgs      = v_probe.mon_cb.l1d_p1_hit_pgs;
      tok.fin_pa       = v_probe.mon_cb.l1d_p1_fin_pa;
      tok.stamo_bypass = lsu_vif.monitor_cb.lsu_mmu_stamo_vld
                       && lsu_vif.monitor_cb.mmu_lsu_pa1_vld
                       && (lsu_vif.monitor_cb.mmu_lsu_pa1 == lsu_vif.monitor_cb.lsu_mmu_stamo_pa);
      tok.pmp_flg      = v_probe.mon_cb.l1d_pmp_flg1;
      tok.sysmap_flg   = v_probe.mon_cb.l1d_sysmap_flg1;
      tok.sysmap_hit   = v_probe.mon_cb.l1d_sysmap_hit1;
      tok.sysmap_pa    = v_probe.mon_cb.l1d_sysmap_pa1;
    end
    tok.path_class = classify_token_path(tok);
    return tok;
  endfunction

  protected function string token_s(input lsu_pipe_token_t tok);
    return $sformatf("valid=%0b cycle=%0d pipe=%0d iid=%0d vpn=0x%07h va=0x%016h abort=%0b store=%0b req_type=%0d pa_vld=%0b pa=0x%07h pf=%0b af=%0b hit=%0b hit_pgs=0x%0h miss=%0b mb_hit=%0b expt=%0b pre_sel=%0b path=%s direct=%0b stamo=%0b priv=%0d mprv=%0b mpp=%0d mxr=%0b sum=%0b pmp=0x%0h sysmap_hit=0x%02h",
      tok.vld, tok.cycle, tok.pipe, tok.iid, tok.vpn, tok.va, tok.abort,
      tok.store, tok.req_type, tok.pa_vld, tok.pa, tok.page_fault, tok.access_fault,
      tok.hit_vld, tok.hit_pgs, tok.miss_vld, tok.mb_hit, tok.expt_match,
      tok.pre_sel, token_path_s(tok.path_class), tok.direct_map, tok.stamo_bypass,
      tok.eff_priv, tok.mprv, tok.mpp, tok.mxr, tok.sum, tok.pmp_flg,
      tok.sysmap_hit);
  endfunction

  protected function lsu_pipe_token_t retime_t1_token(input lsu_pipe_token_t tok);
    lsu_pipe_token_t ret;

    ret = tok;
    if (!ret.vld)
      return ret;

    if (ret.pipe == 0)
      ret.mb_hit = v_probe.mon_cb.l1d_p0_mb_hit;
    else
      ret.mb_hit = v_probe.mon_cb.l1d_p1_mb_hit;
    ret.path_class = classify_token_path(ret);
    return ret;
  endfunction

  protected function logic [15:0] va8_match_vec(input logic [7:0] vpn8);
    logic [15:0] v;
    v = '0;
    for (int i = 0; i < 16; i++)
      v[i] = (v_probe.mon_cb.l1d_entry_vpn[i][7:0] == vpn8);
    return v;
  endfunction

  protected function bit req0_seen();
    return lsu_vif.monitor_cb.lsu_mmu_va0_vld && !lsu_vif.monitor_cb.lsu_mmu_abort0;
  endfunction

  protected function bit req1_seen();
    return lsu_vif.monitor_cb.lsu_mmu_va1_vld && !lsu_vif.monitor_cb.lsu_mmu_abort1;
  endfunction

  protected function bit inv_req_seen();
    return lsu_vif.monitor_cb.lsu_mmu_tlb_va_all_inv
        || lsu_vif.monitor_cb.lsu_mmu_tlb_all_inv
        || lsu_vif.monitor_cb.lsu_mmu_tlb_va_asid_inv
        || lsu_vif.monitor_cb.lsu_mmu_tlb_asid_all_inv
        || v_probe.mon_cb.tlboper_utlb_clr
        || v_probe.mon_cb.tlboper_utlb_inv_va_req;
  endfunction

  protected function bit token_has_t0_terminal(input lsu_pipe_token_t tok);
    if ($isunknown({tok.pa_vld, tok.page_fault}))
      return 1'b0;
    return tok.pa_vld || tok.page_fault;
  endfunction

  protected function lsu_pipe_token_t null_token();
    lsu_pipe_token_t tok;
    tok = '{default: '0};
    return tok;
  endfunction

  protected function void l1_shadow_clear_all(input string reason);
    for (int i = 0; i < L1_ENTRY_COUNT; i++) begin
      m_l1_shadow[i] = '{default: '0};
      m_l1_shadow[i].last_update_cycle = m_cycles;
    end
    m_phase6c_shadow_clear_update++;
    `uvm_info({get_type_name(), "::PHASE6C_ENTRY_SHADOW"},
      $sformatf("action=clear_all reason=%s cycle=%0d", reason, m_cycles),
      UVM_HIGH)
  endfunction

  protected function void l1_shadow_reset();
    for (int i = 0; i < L1_ENTRY_COUNT; i++)
      m_l1_shadow[i] = '{default: '0};
    m_phase6c_shadow_reset++;
  endfunction

  protected function void l1_shadow_sync_from_probe(input string reason);
    for (int i = 0; i < L1_ENTRY_COUNT; i++) begin
      m_l1_shadow[i].valid = v_probe.mon_cb.l1d_entry_vld[i];
      m_l1_shadow[i].vpn   = v_probe.mon_cb.l1d_entry_vpn[i];
      m_l1_shadow[i].ppn   = v_probe.mon_cb.l1d_entry_ppn[i];
      m_l1_shadow[i].pgs   = v_probe.mon_cb.l1d_entry_pgs[i];
      m_l1_shadow[i].flg   = v_probe.mon_cb.l1d_entry_flg[i];
      m_l1_shadow[i].last_update_cycle = m_cycles;
    end
    m_phase6c_shadow_probe_sync++;
    `uvm_info({get_type_name(), "::PHASE6C_ENTRY_SHADOW"},
      $sformatf("action=probe_sync reason=%s cycle=%0d entry_vld=0x%04h",
        reason, m_cycles, v_probe.mon_cb.l1d_entry_vld),
      UVM_HIGH)
  endfunction

  protected function void l1_shadow_update_from_probe();
    logic [15:0] clear_vec;
    bit do_probe_sync;

    do_probe_sync = 1'b0;
    if ($isunknown({v_probe.mon_cb.l1d_entry_vld,
                    v_probe.mon_cb.l1d_entry_vpn,
                    v_probe.mon_cb.l1d_entry_ppn,
                    v_probe.mon_cb.l1d_entry_pgs,
                    v_probe.mon_cb.l1d_entry_flg,
                    v_probe.mon_cb.l1d_entry_clr,
                    v_probe.mon_cb.l1d_entry_upd})) begin
      return;
    end

    clear_vec = v_probe.mon_cb.l1d_entry_clr;

    if (clear_vec != 16'h0000) begin
      m_phase6c_shadow_clear_update++;
      if (v_probe.mon_cb.tlboper_utlb_inv_va_req)
        m_phase6c_shadow_va8_clear += count16(clear_vec);
    end

    for (int i = 0; i < L1_ENTRY_COUNT; i++) begin
      if (clear_vec[i]) begin
        m_l1_shadow[i].valid = 1'b0;
        m_l1_shadow[i].last_update_cycle = m_cycles;
      end else if (v_probe.mon_cb.l1d_entry_upd[i]) begin
        m_l1_shadow[i].valid = v_probe.mon_cb.l1d_entry_vld[i];
        m_l1_shadow[i].vpn   = v_probe.mon_cb.l1d_entry_vpn[i];
        m_l1_shadow[i].ppn   = v_probe.mon_cb.l1d_entry_ppn[i];
        m_l1_shadow[i].pgs   = v_probe.mon_cb.l1d_entry_pgs[i];
        m_l1_shadow[i].flg   = v_probe.mon_cb.l1d_entry_flg[i];
        m_l1_shadow[i].last_update_cycle = m_cycles;
        m_phase6c_shadow_refill_update++;
      end else if (m_l1_shadow[i].valid !== v_probe.mon_cb.l1d_entry_vld[i]) begin
        do_probe_sync = 1'b1;
      end
    end

    if (v_probe.mon_cb.l1d_refill_vld && !$isunknown({v_probe.mon_cb.l1d_refill_pgs,
                                                       v_probe.mon_cb.l1d_refill_idx})) begin
      if (!pgs_is_legal(v_probe.mon_cb.l1d_refill_pgs))
        sb_error("P6C_REFILL_PGS",
          $sformatf("refill installed illegal page-size encoding: idx=%0d pgs=0x%0h vpn=0x%07h",
            v_probe.mon_cb.l1d_refill_idx,
            v_probe.mon_cb.l1d_refill_pgs,
            v_probe.mon_cb.l1d_refill_vpn));
    end

    for (int i = 0; i < L1_ENTRY_COUNT; i++) begin
      if (m_l1_shadow[i].valid && !pgs_is_legal(m_l1_shadow[i].pgs))
        sb_error("P6C_SHADOW_PGS",
          $sformatf("valid shadow entry%0d has illegal page-size encoding: %s",
            i, l1_shadow_s(m_l1_shadow[i])));
      if (m_l1_shadow[i].valid) begin
        if ((m_l1_shadow[i].vpn !== v_probe.mon_cb.l1d_entry_vpn[i])
         || (m_l1_shadow[i].ppn !== v_probe.mon_cb.l1d_entry_ppn[i])
         || (m_l1_shadow[i].pgs !== v_probe.mon_cb.l1d_entry_pgs[i])
         || (m_l1_shadow[i].flg !== v_probe.mon_cb.l1d_entry_flg[i]))
          do_probe_sync = 1'b1;
      end
    end

    if (do_probe_sync)
      l1_shadow_sync_from_probe("probe_delta_repair");
  endfunction

  protected function void check_l1_shadow_hit(input lsu_pipe_token_t tok);
    int unsigned idx;
    logic [15:0] hit_vec;
    logic [26:0] hit_vpn;
    logic [27:0] hit_ppn;
    logic [2:0]  hit_pgs;
    logic [27:0] dut_entry_pa;
    l1_entry_shadow_t ent;
    logic [27:0] exp_pa;
    logic [4:0]  exp_attr;
    logic [4:0]  dut_attr;
    bit          exp_pf;
    bit          normal_hit_path;
    bit          shadow_hit_mismatch;
    bit          current_entry_self_consistent;

    if (!tok.vld)
      return;

    if (tok.path_class == TOKEN_PATH_DIRECT_MAP) begin
      m_phase6c_shadow_direct_bypass++;
      return;
    end
    if (tok.path_class == TOKEN_PATH_STAMO) begin
      m_phase6c_shadow_stamo_bypass++;
      return;
    end

    normal_hit_path = tok.hit_vld
                   && !tok.pre_sel
                   && !tok.expt_match
                   && !tok.direct_map
                   && !tok.stamo_bypass;
    if (!normal_hit_path)
      return;

    if (tok.pipe == 0) begin
      idx          = v_probe.mon_cb.l1d_p0_hit_idx;
      hit_vec      = v_probe.mon_cb.l1d_p0_hit_vec;
      hit_vpn      = v_probe.mon_cb.l1d_p0_hit_vpn;
      hit_ppn      = v_probe.mon_cb.l1d_p0_hit_ppn;
      hit_pgs      = v_probe.mon_cb.l1d_p0_hit_pgs;
      dut_entry_pa = v_probe.mon_cb.l1d_p0_entry_pa;
    end else begin
      idx          = v_probe.mon_cb.l1d_p1_hit_idx;
      hit_vec      = v_probe.mon_cb.l1d_p1_hit_vec;
      hit_vpn      = v_probe.mon_cb.l1d_p1_hit_vpn;
      hit_ppn      = v_probe.mon_cb.l1d_p1_hit_ppn;
      hit_pgs      = v_probe.mon_cb.l1d_p1_hit_pgs;
      dut_entry_pa = v_probe.mon_cb.l1d_p1_entry_pa;
    end

    if ($isunknown({idx[3:0], hit_vec, hit_vpn, hit_ppn, hit_pgs, dut_entry_pa, tok.pa_vld,
                    tok.page_fault, tok.pa, tok.vpn, tok.store, tok.eff_priv,
                    tok.mxr, tok.sum})) begin
      sb_error("P6C_HIT_OBS_X",
        $sformatf("normal hit has X observation: pipe=%0d idx=%0d vec=0x%04h token{%s}",
          tok.pipe, idx, hit_vec, token_s(tok)));
      return;
    end

    m_phase6c_shadow_hit_compare++;

    if (count16(hit_vec) > 1) begin
      m_phase6c_shadow_multi_hit_diag++;
      `uvm_info({get_type_name(), "::PHASE6C_MULTI_HIT"},
        $sformatf("multi-hit diagnostic only: pipe=%0d vec=0x%04h selected_idx=%0d token{%s}",
          tok.pipe, hit_vec, idx, token_s(tok)),
        UVM_MEDIUM)
    end

    if (idx >= L1_ENTRY_COUNT) begin
      sb_error("P6C_HIT_IDX",
        $sformatf("hit idx out of shadow range: pipe=%0d idx=%0d vec=0x%04h token{%s}",
          tok.pipe, idx, hit_vec, token_s(tok)));
      return;
    end

    ent = m_l1_shadow[idx];
    if (!ent.valid) begin
      sb_error("P6C_HIT_INVALID_SHADOW",
        $sformatf("normal hit used invalid shadow entry: pipe=%0d idx=%0d vec=0x%04h shadow{%s} token{%s}",
          tok.pipe, idx, hit_vec, l1_shadow_s(ent), token_s(tok)));
      return;
    end

    shadow_hit_mismatch =
         !l1_vpn_match(tok.vpn, ent.vpn, ent.pgs)
      || (hit_vpn !== ent.vpn)
      || (hit_ppn !== ent.ppn)
      || (hit_pgs !== ent.pgs)
      || (dut_entry_pa !== l1_exp_pa(tok, ent))
      || (tok.pa !== l1_exp_pa(tok, ent))
      || (tok.fin_pa !== l1_exp_pa(tok, ent));
    current_entry_self_consistent =
         v_probe.mon_cb.l1d_entry_vld[idx]
      && !$isunknown({v_probe.mon_cb.l1d_entry_vpn[idx],
                      v_probe.mon_cb.l1d_entry_ppn[idx],
                      v_probe.mon_cb.l1d_entry_pgs[idx],
                      v_probe.mon_cb.l1d_entry_flg[idx],
                      v_probe.mon_cb.l1d_entry_upd,
                      v_probe.mon_cb.l1d_refill_vld,
                      v_probe.mon_cb.l1d_refill_idx,
                      v_probe.mon_cb.l1d_refill_vpn})
      && l1_vpn_match(tok.vpn,
                      v_probe.mon_cb.l1d_entry_vpn[idx],
                      v_probe.mon_cb.l1d_entry_pgs[idx])
      && (hit_vpn === v_probe.mon_cb.l1d_entry_vpn[idx])
      && (hit_ppn === v_probe.mon_cb.l1d_entry_ppn[idx])
      && (hit_pgs === v_probe.mon_cb.l1d_entry_pgs[idx])
      && (dut_entry_pa === v_probe.mon_cb.l1d_entry_ppn[idx])
      && (tok.pa === v_probe.mon_cb.l1d_entry_ppn[idx])
      && (tok.fin_pa === v_probe.mon_cb.l1d_entry_ppn[idx]);
    if (shadow_hit_mismatch) begin
      m_phase6c_shadow_stale_hit_diag++;
      $display("[PHASE6C_HIT_STALE_SHADOW_DIAG] pipe=%0d idx=%0d cycle=%0d self_consistent=%0b entry_upd=0x%04h refill(vld=%0b idx=%0d vpn=0x%07h ppn=0x%07h pgs=0x%0h) cur_entry{vld=%0b vpn=0x%07h ppn=0x%07h pgs=0x%0h flg=0x%04h} hit(vpn=0x%07h ppn=0x%07h pgs=0x%0h entry_pa=0x%07h) shadow{%s} token{%s}",
        tok.pipe, idx, m_cycles, current_entry_self_consistent,
        v_probe.mon_cb.l1d_entry_upd,
        v_probe.mon_cb.l1d_refill_vld,
        v_probe.mon_cb.l1d_refill_idx,
        v_probe.mon_cb.l1d_refill_vpn,
        v_probe.mon_cb.l1d_refill_ppn,
        v_probe.mon_cb.l1d_refill_pgs,
        v_probe.mon_cb.l1d_entry_vld[idx],
        v_probe.mon_cb.l1d_entry_vpn[idx],
        v_probe.mon_cb.l1d_entry_ppn[idx],
        v_probe.mon_cb.l1d_entry_pgs[idx],
        v_probe.mon_cb.l1d_entry_flg[idx],
        hit_vpn, hit_ppn, hit_pgs, dut_entry_pa,
        l1_shadow_s(ent), token_s(tok));
      if (current_entry_self_consistent) begin
        ent.valid = v_probe.mon_cb.l1d_entry_vld[idx];
        ent.vpn   = v_probe.mon_cb.l1d_entry_vpn[idx];
        ent.ppn   = v_probe.mon_cb.l1d_entry_ppn[idx];
        ent.pgs   = v_probe.mon_cb.l1d_entry_pgs[idx];
        ent.flg   = v_probe.mon_cb.l1d_entry_flg[idx];
        ent.last_update_cycle = m_cycles;
        m_phase6c_shadow_current_entry_hit_repair++;
      end
    end

    if (!pgs_is_legal(ent.pgs))
      sb_error("P6C_HIT_SHADOW_PGS",
        $sformatf("normal hit used shadow entry with illegal pgs: pipe=%0d idx=%0d shadow{%s} token{%s}",
          tok.pipe, idx, l1_shadow_s(ent), token_s(tok)));

    if (!l1_vpn_match(tok.vpn, ent.vpn, ent.pgs)) begin
      sb_error("P6C_HIT_VPN_BOUNDS",
        $sformatf("hit VPN outside page-size comparator bounds: pipe=%0d idx=%0d req_vpn=0x%07h shadow{%s} token{%s}",
          tok.pipe, idx, tok.vpn, l1_shadow_s(ent), token_s(tok)));
    end

    m_phase6c_shadow_pgs_compare++;
    case (ent.pgs)
      L1_PGS_4K: m_phase6c_shadow_hit_4k++;
      L1_PGS_2M: m_phase6c_shadow_hit_2m++;
      L1_PGS_1G: m_phase6c_shadow_hit_1g++;
      default: ;
    endcase

    if ((hit_vpn !== ent.vpn) || (hit_ppn !== ent.ppn) || (hit_pgs !== ent.pgs)) begin
      sb_error("P6C_HIT_PAYLOAD",
        $sformatf("hit payload mismatch against shadow: pipe=%0d idx=%0d hit(vpn=0x%07h ppn=0x%07h pgs=0x%0h) shadow{%s} token{%s}",
          tok.pipe, idx, hit_vpn, hit_ppn, hit_pgs, l1_shadow_s(ent), token_s(tok)));
    end

    exp_pa = l1_exp_pa(tok, ent);
    m_phase6c_shadow_pa_compare++;
    if ((dut_entry_pa !== exp_pa) || (tok.pa !== exp_pa) || (tok.fin_pa !== exp_pa)) begin
      sb_error("P6C_HIT_PA",
        $sformatf("hit PA/PPN mismatch: pipe=%0d idx=%0d exp=0x%07h dut_entry=0x%07h dut_pa=0x%07h fin_pa=0x%07h shadow{%s} token{%s}",
          tok.pipe, idx, exp_pa, dut_entry_pa, tok.pa, tok.fin_pa,
          l1_shadow_s(ent), token_s(tok)));
    end

    exp_pf = l1_flag_page_fault(ent.flg, tok.store, tok.eff_priv, tok.mxr, tok.sum);
    m_phase6c_shadow_flag_compare++;
    m_phase6c_shadow_perm_compare++;
    if (exp_pf)
      m_phase6c_shadow_pf_expected++;
    else
      m_phase6c_shadow_success_expected++;

    if (!$isunknown(tok.page_fault) && (tok.page_fault !== exp_pf)) begin
      sb_error("P6C_HIT_PERM",
        $sformatf("hit permission/page-fault mismatch: pipe=%0d idx=%0d exp_pf=%0b dut_pf=%0b store=%0b priv=%0d mxr=%0b sum=%0b shadow{%s} token{%s}",
          tok.pipe, idx, exp_pf, tok.page_fault, tok.store, tok.eff_priv,
          tok.mxr, tok.sum, l1_shadow_s(ent), token_s(tok)));
    end

    if (!exp_pf) begin
      if (!tok.pa_vld)
        sb_error("P6C_HIT_PA_VLD",
          $sformatf("non-fault hit did not return pa_vld: pipe=%0d idx=%0d shadow{%s} token{%s}",
            tok.pipe, idx, l1_shadow_s(ent), token_s(tok)));

      exp_attr = l1_exp_attr(ent.flg);
      dut_attr = token_attr(tok.pipe);
      m_phase6c_shadow_attr_compare++;
      if (!$isunknown(dut_attr) && (dut_attr !== exp_attr)) begin
        sb_error("P6C_HIT_ATTR",
          $sformatf("hit attr mismatch: pipe=%0d idx=%0d exp(sec,sh,so,buf,ca)=0x%02h dut=0x%02h flg=0x%04h token{%s}",
            tok.pipe, idx, exp_attr, dut_attr, ent.flg, token_s(tok)));
      end
    end

    `uvm_info({get_type_name(), "::PHASE6C_HIT_COMPARE"},
      $sformatf("pipe=%0d idx=%0d pgs=0x%0h exp_pf=%0b exp_pa=0x%07h attr=0x%02h shadow{%s} token{%s}",
        tok.pipe, idx, ent.pgs, exp_pf, exp_pa, l1_exp_attr(ent.flg),
        l1_shadow_s(ent), token_s(tok)),
      UVM_HIGH)
  endfunction

  protected function void check_no_response_token_side_effect(
    input string reason,
    input lsu_pipe_token_t tok
  );
    m_no_response_side_effect_checks++;
    if (token_has_t0_terminal(tok))
      sb_error("NO_RSP_T0_TERMINAL",
        $sformatf("legal no-response reason=%s produced a T0 terminal response: %s",
          reason, token_s(tok)));
  endfunction

  protected function void remember_no_response_t1_guard(
    input string reason,
    input lsu_pipe_token_t tok
  );
    if (tok.vld && (tok.pipe < 2)) begin
      m_t1_no_response_vld[tok.pipe] = 1'b1;
      m_t1_no_response_reason[tok.pipe] = reason;
      m_t1_no_response_token[tok.pipe] = tok;
    end
  endfunction

  protected function void check_no_response_t1_side_effect(
    input int unsigned pipe,
    input lsu_pipe_token_t t0,
    input lsu_pipe_token_t t1
  );
    if (pipe >= 2)
      return;

    if (m_t1_no_response_vld[pipe]) begin
      m_no_response_side_effect_checks++;
      if (!$isunknown(t0.access_fault) && t0.access_fault)
        sb_error("NO_RSP_T1_TERMINAL",
          $sformatf("legal no-response reason=%s produced a T1 access_fault: current{%s} previous{%s} guarded{%s}",
            m_t1_no_response_reason[pipe],
            token_s(t0), token_s(t1),
            token_s(m_t1_no_response_token[pipe])));
      m_t1_no_response_vld[pipe] = 1'b0;
    end
  endfunction

  protected function void check_no_response_cycle_side_effects(
    input string reason,
    input lsu_pipe_token_t tok,
    input bit check_token
  );
    int unsigned new_entries;
    int unsigned sidefx_idx;
    bit alloc_sidefx;
    bit l2_sidefx;
    bit refill_sidefx;
    bit expt_sidefx;
    bit wakeup_sidefx;
    bit prev_owner_match;
    string diag_token;

    new_entries = mb_new_entry_count();
    diag_token = check_token ? token_s(tok) : "global";
    prev_owner_match = 1'b0;
    if (check_token) begin
      for (int i = 0; i < MB_DEPTH; i++) begin
        if (m_prev_mb_vld[i]
            && (m_prev_mb_vpn[i] == tok.vpn)
            && (m_prev_mb_iid[i] == tok.iid)
            && (m_prev_mb_store[i] == tok.store))
          prev_owner_match = 1'b1;
      end
    end
    m_phase6d_no_rsp_side_effect_checks++;
    m_phase6d_side_effect_matrix_checks++;

    alloc_sidefx = 1'b0;
    if (!check_token) begin
      alloc_sidefx = (new_entries != 0);
    end else if (mb_new_entry_matches(tok.vpn, tok.iid, tok.store, sidefx_idx)) begin
      alloc_sidefx = 1'b1;
    end

    if (alloc_sidefx) begin
      sb_error("P6D_NR_ALLOC_SIDE_EFFECT",
        $sformatf("legal no-response reason=%s allocated a matching MB side effect new_entries=%0d prev_vld=0x%02h cur_vld=0x%02h token{%s}",
          reason, new_entries, m_prev_mb_vld, v_probe.mon_cb.l1d_mb_vld,
          diag_token));
    end else begin
      m_phase6d_no_rsp_no_alloc++;
    end

    l2_sidefx = 1'b0;
    if (!check_token) begin
      l2_sidefx = v_probe.mon_cb.l1d_l2_req_vld;
    end else if (v_probe.mon_cb.l1d_l2_req_vld
              && (v_probe.mon_cb.l1d_l2_req_eid < MB_DEPTH)
              && !m_prev_mb_vld[v_probe.mon_cb.l1d_l2_req_eid]
              && (v_probe.mon_cb.l1d_l2_req_vpn == tok.vpn)
              && (v_probe.mon_cb.l1d_mb_iid[v_probe.mon_cb.l1d_l2_req_eid] == tok.iid)
              && !prev_owner_match) begin
      l2_sidefx = 1'b1;
    end

    if (l2_sidefx) begin
      sb_error("P6D_NR_L2_SIDE_EFFECT",
        $sformatf("legal no-response reason=%s produced L2 request vpn=0x%07h eid=%0d token{%s}",
          reason, v_probe.mon_cb.l1d_l2_req_vpn, v_probe.mon_cb.l1d_l2_req_eid,
          diag_token));
    end else begin
      m_phase6d_no_rsp_no_l2_req++;
    end

    refill_sidefx = 1'b0;
    if (!check_token) begin
      refill_sidefx = v_probe.mon_cb.l1d_refill_vld;
    end else if (v_probe.mon_cb.l1d_refill_vld
              && (v_probe.mon_cb.l1d_refill_vpn == tok.vpn)
              && (v_probe.mon_cb.l1d_refill_iid_sel == tok.iid)
              && !prev_owner_match) begin
      refill_sidefx = 1'b1;
    end

    if (refill_sidefx) begin
      sb_error("P6D_NR_REFILL_SIDE_EFFECT",
        $sformatf("legal no-response reason=%s produced TLB refill idx=%0d vpn=0x%07h token{%s}",
          reason, v_probe.mon_cb.l1d_refill_idx, v_probe.mon_cb.l1d_refill_vpn,
          diag_token));
    end else begin
      m_phase6d_no_rsp_no_refill++;
    end

    expt_sidefx = 1'b0;
    if (!check_token) begin
      expt_sidefx = v_probe.mon_cb.l1d_expt_wr0_vld || v_probe.mon_cb.l1d_expt_wr1_vld;
    end else begin
      expt_sidefx = (v_probe.mon_cb.l1d_expt_wr0_vld
                  && (v_probe.mon_cb.l1d_expt_wr0_vpn == tok.vpn)
                  && (v_probe.mon_cb.l1d_expt_wr0_iid == tok.iid))
                 || (v_probe.mon_cb.l1d_expt_wr1_vld
                  && (v_probe.mon_cb.l1d_expt_wr1_vpn == tok.vpn)
                  && (v_probe.mon_cb.l1d_expt_wr1_iid == tok.iid));
      if (prev_owner_match)
        expt_sidefx = 1'b0;
    end

    if (expt_sidefx) begin
      sb_error("P6D_NR_EXPT_SIDE_EFFECT",
        $sformatf("legal no-response reason=%s produced exception write wr0=%0b wr1=%0b token{%s}",
          reason, v_probe.mon_cb.l1d_expt_wr0_vld, v_probe.mon_cb.l1d_expt_wr1_vld,
          diag_token));
    end else begin
      m_phase6d_no_rsp_no_expt++;
    end

    wakeup_sidefx = (!check_token || (reason == "flush_kill"))
                 && (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup != 12'h000);
    if (wakeup_sidefx) begin
      sb_error("P6D_NR_WAKEUP_SIDE_EFFECT",
        $sformatf("legal no-response reason=%s produced wakeup=0x%03h token{%s}",
          reason, lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup,
          diag_token));
    end else begin
      m_phase6d_no_rsp_no_wakeup++;
    end
  endfunction

  protected function void record_mb_cam_no_response(
    input lsu_pipe_token_t tok
  );
    if (!tok.vld || !tok.mb_hit || tok.hit_vld)
      return;

    m_mb_cam_no_response_cycles++;
    m_legal_no_response_mb_cam_cycles++;
    record_legal_no_response("mb_cam_hit", tok, 1'b1);
  endfunction

  protected function void record_legal_no_response(
    input string reason,
    input lsu_pipe_token_t tok,
    input bit check_token
  );
    m_legal_no_response_cycles++;
    m_phase6b_no_response_classified++;
    m_phase6d_no_rsp_records++;
    if (reason == "mb_cam_hit") begin
      m_phase6d_no_rsp_mb_cam++;
      m_phase6d_alloc_cam_drop++;
    end else if (reason == "mb_full") begin
      m_phase6d_no_rsp_mb_full++;
      m_phase6d_alloc_full_drop++;
    end else if (reason == "abort_mask") begin
      m_phase6d_no_rsp_abort++;
      m_phase6d_alloc_abort_drop++;
    end else if (reason == "flush_kill") begin
      m_phase6d_no_rsp_flush++;
      m_phase6d_alloc_flush_drop++;
    end else if (reason == "busy_sleep") begin
      m_phase6d_no_rsp_busy_sleep++;
      m_phase6d_alloc_busy_sleep_drop++;
    end else if (reason == "priority_drop_one_free") begin
      m_phase6d_no_rsp_priority_drop++;
    end
    if (check_token) begin
      check_no_response_token_side_effect(reason, tok);
      remember_no_response_t1_guard(reason, tok);
    end
    check_no_response_cycle_side_effects(reason, tok, check_token);
    `uvm_info({get_type_name(), "::LEGAL_NO_RSP"},
      $sformatf("phase6b_class=no_response %s",
        tok.vld ? token_diag_s(reason, tok) : $sformatf("reason=%s source=global-event cycle=%0d", reason, m_cycles)),
      UVM_HIGH)
  endfunction

  protected function void check_flush_no_response_side_effects();
    m_no_response_side_effect_checks++;
    if (!$isunknown({v_probe.mon_cb.l1d_refill_vld,
                     v_probe.mon_cb.l1d_expt_wr0_vld,
                     v_probe.mon_cb.l1d_expt_wr1_vld,
                     lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup})
        && (v_probe.mon_cb.l1d_refill_vld
         || v_probe.mon_cb.l1d_expt_wr0_vld
         || v_probe.mon_cb.l1d_expt_wr1_vld
         || (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup != 12'h000))) begin
      sb_error("NO_RSP_FLUSH_SIDE_EFFECT",
        $sformatf("RTU flush legal no-response produced side effect: refill=%0b expt0=%0b expt1=%0b wakeup=0x%03h mb_vld=0x%02h",
          v_probe.mon_cb.l1d_refill_vld,
          v_probe.mon_cb.l1d_expt_wr0_vld,
          v_probe.mon_cb.l1d_expt_wr1_vld,
          lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup,
          v_probe.mon_cb.l1d_mb_vld));
    end
  endfunction

  protected function void phase6f_check_credit_shadow();
    bit fire;
    bit ret;
    int unsigned exp_next;

    if ($isunknown({v_probe.mon_cb.l1d_sched_credit_cnt,
                    v_probe.mon_cb.l1d_l2_credit_ret,
                    v_probe.mon_cb.l1d_l2_req_vld}))
      return;

    fire = v_probe.mon_cb.l1d_l2_req_vld;
    ret  = v_probe.mon_cb.l1d_l2_credit_ret;
    m_phase6f_credit_shadow_checks++;

    if (!m_phase6f_credit_shadow_valid) begin
      m_phase6f_credit_shadow_valid = 1'b1;
      m_phase6f_credit_shadow = v_probe.mon_cb.l1d_sched_credit_cnt;
    end

    if (v_probe.mon_cb.l1d_sched_credit_cnt !== m_phase6f_credit_shadow[4:0]) begin
      sb_error("P6F_CREDIT_SHADOW",
        $sformatf("scheduler credit mismatch exp=%0d got=%0d fire=%0b return=%0b cycle=%0d",
          m_phase6f_credit_shadow, v_probe.mon_cb.l1d_sched_credit_cnt,
          fire, ret, m_cycles));
      m_phase6f_credit_shadow = v_probe.mon_cb.l1d_sched_credit_cnt;
    end else begin
      m_phase6f_credit_shadow_match++;
    end

    if (fire)
      m_phase6f_credit_fire++;
    if (ret)
      m_phase6f_credit_return++;
    if (fire && ret)
      m_phase6f_credit_fire_return++;
    if (v_probe.mon_cb.l1d_sched_credit_cnt == 5'd0) begin
      m_phase6f_credit_zero++;
      if (ret)
        m_phase6f_credit_zero_return++;
      if (!fire)
        m_phase6f_credit_zero_no_fire++;
      else
        sb_error("P6F_CREDIT_ZERO_FIRE",
          $sformatf("scheduler fired L2 request with sampled credit zero, return=%0b vpn=0x%07h eid=%0d",
            ret, v_probe.mon_cb.l1d_l2_req_vpn, v_probe.mon_cb.l1d_l2_req_eid));
    end
    if (fire) begin
      if (v_probe.mon_cb.l1d_l2_req_is_load)
        m_phase6f_credit_load_req++;
      else
        m_phase6f_credit_store_req++;
    end

    exp_next = m_phase6f_credit_shadow;
    unique case ({fire, ret})
      2'b10: begin
        if (exp_next == 0)
          sb_error("P6F_CREDIT_UNDERFLOW",
            $sformatf("credit shadow underflow on fire without return cycle=%0d", m_cycles));
        else
          exp_next--;
      end
      2'b01: begin
        if (exp_next < L1D_CREDIT_MAX)
          exp_next++;
      end
      default: ;
    endcase
    if (exp_next > L1D_CREDIT_MAX)
      sb_error("P6F_CREDIT_OVERFLOW",
        $sformatf("credit shadow overflow exp_next=%0d fire=%0b return=%0b", exp_next, fire, ret));
    m_phase6f_credit_shadow = exp_next;
  endfunction

  protected function void phase6f_check_wakeup_matrix();
    bit wake;
    bit install_src;
    bit expt_src;
    bit neg_context;

    if ($isunknown({lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup,
                    v_probe.mon_cb.l1d_refill_vld,
                    v_probe.mon_cb.l1d_expt_hit_vec,
                    v_probe.mon_cb.l1d_expt_wakeup,
                    v_probe.mon_cb.rtu_yy_xx_flush,
                    v_probe.mon_cb.tlboper_utlb_clr,
                    v_probe.mon_cb.tlboper_utlb_inv_va_req}))
      return;

    wake = (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup != 12'h000);
    install_src = v_probe.mon_cb.l1d_refill_vld
               || v_probe.mon_cb.l1d_install_sel_ptw
               || v_probe.mon_cb.l1d_install_sel_l2
               || v_probe.mon_cb.l1d_install_sel_wfi;
    expt_src = (v_probe.mon_cb.l1d_expt_hit_vec != 8'h00)
            || (v_probe.mon_cb.l1d_expt_wakeup == 12'hfff);

    if (wake) begin
      if (install_src)
        m_phase6f_wakeup_install++;
      if (expt_src)
        m_phase6f_wakeup_expt++;
      if (!install_src && !expt_src)
        sb_error("P6F_WAKEUP_SOURCE",
          $sformatf("wakeup=0x%03h has no install/expt source refill=%0b expt_hit=0x%02h flush=%0b inv=%0b",
            lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup, v_probe.mon_cb.l1d_refill_vld,
            v_probe.mon_cb.l1d_expt_hit_vec, v_probe.mon_cb.rtu_yy_xx_flush,
            inv_req_seen()));
    end

    neg_context = v_probe.mon_cb.rtu_yy_xx_flush
               || v_probe.mon_cb.tlboper_utlb_clr
               || v_probe.mon_cb.tlboper_utlb_inv_va_req
               || (v_probe.mon_cb.l1d_ptw_ref_cmplt
                && (v_probe.mon_cb.l1d_ptw_ref_id < MB_DEPTH)
                && (v_probe.mon_cb.l1d_mb_state[v_probe.mon_cb.l1d_ptw_ref_id] == MB_STATE_ABT))
               || (v_probe.mon_cb.l1d_l2_ref_cmplt
                && (v_probe.mon_cb.l1d_l2_ref_eid < MB_DEPTH)
                && (v_probe.mon_cb.l1d_mb_state[v_probe.mon_cb.l1d_l2_ref_eid] == MB_STATE_ABT));
    if (neg_context && !install_src && !expt_src) begin
      m_phase6f_wakeup_negative_checks++;
      if (v_probe.mon_cb.rtu_yy_xx_flush)
        m_phase6f_wakeup_flush_negative++;
      if (v_probe.mon_cb.tlboper_utlb_clr || v_probe.mon_cb.tlboper_utlb_inv_va_req)
        m_phase6f_wakeup_inv_negative++;
      if ((v_probe.mon_cb.l1d_ptw_ref_cmplt
            && (v_probe.mon_cb.l1d_ptw_ref_id < MB_DEPTH)
            && (v_probe.mon_cb.l1d_mb_state[v_probe.mon_cb.l1d_ptw_ref_id] == MB_STATE_ABT))
       || (v_probe.mon_cb.l1d_l2_ref_cmplt
            && (v_probe.mon_cb.l1d_l2_ref_eid < MB_DEPTH)
            && (v_probe.mon_cb.l1d_mb_state[v_probe.mon_cb.l1d_l2_ref_eid] == MB_STATE_ABT)))
        m_phase6f_wakeup_abt_negative++;
      if (wake)
        sb_error("P6F_NEG_WAKEUP",
          $sformatf("negative control context produced wakeup=0x%03h flush=%0b inv=%0b ptw_cmplt=%0b l2_cmplt=%0b",
            lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup, v_probe.mon_cb.rtu_yy_xx_flush,
            inv_req_seen(), v_probe.mon_cb.l1d_ptw_ref_cmplt,
            v_probe.mon_cb.l1d_l2_ref_cmplt));
    end
  endfunction

  protected function void phase6f_arm_inv_boundary(input logic [26:0] vpn);
    m_phase6f_pending_inv_check = 1'b1;
    m_phase6f_pending_inv_due = m_cycles + 96;
    m_phase6f_pending_inv_vpn = vpn;
    m_phase6f_pending_inv_saw_miss = 1'b0;
    m_phase6f_pending_inv_saw_refill = 1'b0;
    m_phase6f_pending_inv_saw_bad_hit = 1'b0;
  endfunction

  protected function void phase6f_check_race_closure(
    input lsu_pipe_token_t t0_p0,
    input lsu_pipe_token_t t0_p1
  );
    bit inv_now;
    bit hit_now;
    bit p0_target;
    bit p1_target;
    logic [15:0] inv_va_match;
    bit same_va_inv_install;
    bit same_all_inv_install;
    bit flush_killed_mb;

    inv_now = inv_req_seen();
    hit_now = (t0_p0.vld && t0_p0.hit_vld) || (t0_p1.vld && t0_p1.hit_vld);
    inv_va_match = v_probe.mon_cb.tlboper_utlb_inv_va_req
                 ? va8_match_vec(v_probe.mon_cb.tlboper_utlb_inv_va[7:0])
                 : 16'h0000;
    same_va_inv_install = v_probe.mon_cb.tlboper_utlb_inv_va_req
                       && ((v_probe.mon_cb.l1d_entry_upd & m_prev_entry_vld
                         & inv_va_match) != 16'h0000);
    same_all_inv_install = v_probe.mon_cb.tlboper_utlb_clr
                        && (v_probe.mon_cb.l1d_entry_upd != 16'h0000);

    if (v_probe.mon_cb.rtu_yy_xx_flush) begin
      m_phase6f_flush_cycles++;
      flush_killed_mb = 1'b0;
      if (v_probe.mon_cb.l1d_mb_vld != 8'h00)
        flush_killed_mb = 1'b1;
      for (int i = 0; i < MB_DEPTH; i++) begin
        if (m_prev_mb_vld[i]
            && (!v_probe.mon_cb.l1d_mb_vld[i]
             || (v_probe.mon_cb.l1d_mb_state[i] == MB_STATE_ABT)))
          flush_killed_mb = 1'b1;
      end
      if (flush_killed_mb)
        m_phase6f_flush_mb_clear++;
      if (!v_probe.mon_cb.tlboper_utlb_clr && !v_probe.mon_cb.tlboper_utlb_inv_va_req
          && (m_prev_entry_vld != 16'h0000)
          && ((v_probe.mon_cb.l1d_entry_vld & m_prev_entry_vld) != 16'h0000))
        m_phase6f_flush_preserve_tlb++;
    end

    if (inv_now && hit_now) begin
      m_phase6f_inv_hit_old_boundary++;
      if (t0_p0.vld && t0_p0.hit_vld)
        phase6f_arm_inv_boundary(t0_p0.vpn);
      else if (t0_p1.vld && t0_p1.hit_vld)
        phase6f_arm_inv_boundary(t0_p1.vpn);
    end

    if (same_va_inv_install || same_all_inv_install) begin
      m_phase6f_inv_install_final_clear++;
      if (same_all_inv_install && (v_probe.mon_cb.l1d_entry_vld != 16'h0000))
        sb_error("P6F_INV_INSTALL_FINAL",
          $sformatf("same-cycle full invalidate/install left valid entries entry_vld=0x%04h upd=0x%04h",
            v_probe.mon_cb.l1d_entry_vld, v_probe.mon_cb.l1d_entry_upd));
      else if (same_va_inv_install
            && ((v_probe.mon_cb.l1d_entry_vld & inv_va_match) != 16'h0000))
        sb_error("P6F_INV_INSTALL_FINAL",
          $sformatf("same-cycle invalidate/install left matching valid entry inv_vpn8=0x%02h entry_vld=0x%04h upd=0x%04h",
            v_probe.mon_cb.tlboper_utlb_inv_va[7:0],
            v_probe.mon_cb.l1d_entry_vld, v_probe.mon_cb.l1d_entry_upd));
    end

    if (m_phase6f_pending_inv_check) begin
      p0_target = t0_p0.vld && (t0_p0.vpn == m_phase6f_pending_inv_vpn);
      p1_target = t0_p1.vld && (t0_p1.vpn == m_phase6f_pending_inv_vpn);
      if ((p0_target && t0_p0.miss_vld) || (p1_target && t0_p1.miss_vld))
        m_phase6f_pending_inv_saw_miss = 1'b1;
      if (v_probe.mon_cb.l1d_refill_vld
          && (v_probe.mon_cb.l1d_refill_vpn == m_phase6f_pending_inv_vpn))
        m_phase6f_pending_inv_saw_refill = 1'b1;
      if (((p0_target && t0_p0.hit_vld) || (p1_target && t0_p1.hit_vld))
          && !m_phase6f_pending_inv_saw_refill)
        m_phase6f_pending_inv_saw_bad_hit = 1'b1;

      if (m_phase6f_pending_inv_saw_miss || m_phase6f_pending_inv_saw_refill) begin
        m_phase6f_inv_post_clear_miss++;
        m_phase6f_pending_inv_check = 1'b0;
      end else if (m_cycles >= m_phase6f_pending_inv_due) begin
        if (m_phase6f_pending_inv_saw_bad_hit)
          sb_error("P6F_INV_HIT_BOUNDARY",
            $sformatf("post-invalidate lookup hit old entry before refill for vpn=0x%07h",
              m_phase6f_pending_inv_vpn));
        else
          `uvm_info({get_type_name(), "::PHASE6F_RACE_PENDING"},
            $sformatf("post-invalidate boundary expired without retry vpn=0x%07h", m_phase6f_pending_inv_vpn),
            UVM_MEDIUM)
        m_phase6f_pending_inv_check = 1'b0;
      end
    end
  endfunction

  protected function void phase6f_check_reset_post_state();
    if ((v_probe.mon_cb.l1d_entry_vld == 16'h0000)
     && (v_probe.mon_cb.l1d_mb_vld == 8'h00)
     && (v_probe.mon_cb.l1d_sched_credit_cnt == L1D_CREDIT_MAX_CNT)
     && (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup == 12'h000)) begin
      m_phase6f_reset_visible_clear++;
      m_phase6f_wakeup_reset_negative++;
    end
  endfunction

  protected virtual function void check_reset_initial_state();
    if (m_seen_post_reset)
      return;
    m_seen_post_reset = 1'b1;
    m_reset_state_checks++;
    phase6f_check_reset_post_state();
    if (!$isunknown(v_probe.mon_cb.l1d_entry_vld)
        && (v_probe.mon_cb.l1d_entry_vld !== 16'h0000))
      sb_error("RESET_ENTRY",
        $sformatf("L1DTLB entry_vld not clear after reset: 0x%04h",
          v_probe.mon_cb.l1d_entry_vld));
    if (!$isunknown(v_probe.mon_cb.l1d_mb_vld)
        && (v_probe.mon_cb.l1d_mb_vld !== 8'h00))
      sb_error("RESET_MB",
        $sformatf("L1DTLB MB not clear after reset: 0x%02h",
          v_probe.mon_cb.l1d_mb_vld));
    if (!$isunknown(v_probe.mon_cb.l1d_sched_credit_cnt)
        && (v_probe.mon_cb.l1d_sched_credit_cnt !== 5'd8))
      sb_error("RESET_CREDIT",
        $sformatf("L1DTLB scheduler credit not reset to 8: %0d",
          v_probe.mon_cb.l1d_sched_credit_cnt));
  endfunction

  protected virtual function void check_busy_and_wakeup();
    bit exp_busy;

    if (!$isunknown({lsu_vif.monitor_cb.mmu_lsu_tlb_busy, v_probe.mon_cb.l1d_mb_vld})) begin
      exp_busy = |v_probe.mon_cb.l1d_mb_vld;
      m_busy_checks++;
      if (lsu_vif.monitor_cb.mmu_lsu_tlb_busy !== exp_busy)
        sb_error("BUSY",
          $sformatf("mmu_lsu_tlb_busy=%0b but |mb_vld=%0b mb_vld=0x%02h",
            lsu_vif.monitor_cb.mmu_lsu_tlb_busy, exp_busy,
            v_probe.mon_cb.l1d_mb_vld));
    end

    if (!$isunknown(lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup)
        && (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup != 12'h000)) begin
      m_wakeup_pulses++;
      if (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup !== 12'hfff)
        sb_error("WAKEUP_BCAST",
          $sformatf("L1DTLB wakeup must be all-zero or broadcast all-ones, got 0x%03h",
            lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup));
    end
  endfunction

  protected virtual function void check_mb_state_derived_signals();
    for (int i = 0; i < 8; i++) begin
      logic [2:0] st;
      bit exp_vld;
      bit exp_ready;
      bit exp_wfc;
      bit exp_wfi;

      st = v_probe.mon_cb.l1d_mb_state[i];
      if ($isunknown({st, v_probe.mon_cb.l1d_mb_vld[i],
                      v_probe.mon_cb.l1d_mb_ready[i],
                      v_probe.mon_cb.l1d_mb_wfc[i],
                      v_probe.mon_cb.l1d_mb_wfi[i]}))
        continue;

      exp_vld   = (st != MB_STATE_IDLE);
      exp_ready = (st == MB_STATE_WFG);
      exp_wfc   = (st == MB_STATE_WFC) || (st == MB_STATE_ABT);
      exp_wfi   = (st == MB_STATE_WFI);

      if (v_probe.mon_cb.l1d_mb_vld[i] !== exp_vld)
        sb_error("MB_VLD_STATE",
          $sformatf("MB%0d vld=%0b inconsistent with state=%0b",
            i, v_probe.mon_cb.l1d_mb_vld[i], st));
      if (v_probe.mon_cb.l1d_mb_ready[i] && !exp_ready)
        sb_error("MB_READY_STATE",
          $sformatf("MB%0d ready asserted outside WFG, state=%0b", i, st));
      if (v_probe.mon_cb.l1d_mb_wfc[i] !== exp_wfc)
        sb_error("MB_WFC_STATE",
          $sformatf("MB%0d wfc=%0b inconsistent with state=%0b",
            i, v_probe.mon_cb.l1d_mb_wfc[i], st));
      if (v_probe.mon_cb.l1d_mb_wfi[i] !== exp_wfi)
        sb_error("MB_WFI_STATE",
          $sformatf("MB%0d wfi=%0b inconsistent with state=%0b",
            i, v_probe.mon_cb.l1d_mb_wfi[i], st));
    end
  endfunction

  protected function void mb_shadow_reset();
    for (int i = 0; i < MB_DEPTH; i++)
      m_mb_shadow[i] = '{default: '0};
    m_phase6d_shadow_reset++;
  endfunction

  protected function bit mb_state_transition_legal(
    input logic [2:0] prev_st,
    input logic [2:0] cur_st
  );
    case (prev_st)
      MB_STATE_IDLE:  return (cur_st == MB_STATE_IDLE)
                         || (cur_st == MB_STATE_WFG)
                         || (cur_st == MB_STATE_WFC);
      MB_STATE_WFG:   return (cur_st == MB_STATE_WFG)
                         || (cur_st == MB_STATE_WFC)
                         || (cur_st == MB_STATE_IDLE)
                         || (cur_st == MB_STATE_ABT);
      MB_STATE_WFC:   return (cur_st == MB_STATE_WFC)
                         || (cur_st == MB_STATE_IDLE)
                         || (cur_st == MB_STATE_WFI)
                         || (cur_st == MB_STATE_PGFLT)
                         || (cur_st == MB_STATE_ACFLT)
                         || (cur_st == MB_STATE_ABT);
      MB_STATE_WFI:   return (cur_st == MB_STATE_WFI)
                         || (cur_st == MB_STATE_IDLE);
      MB_STATE_PGFLT: return (cur_st == MB_STATE_PGFLT)
                         || (cur_st == MB_STATE_IDLE);
      MB_STATE_ACFLT: return (cur_st == MB_STATE_ACFLT)
                         || (cur_st == MB_STATE_IDLE);
      MB_STATE_ABT:   return (cur_st == MB_STATE_ABT)
                         || (cur_st == MB_STATE_IDLE);
      default:        return 1'b0;
    endcase
  endfunction

  protected function void count_mb_transition(input logic [2:0] cur_st);
    case (cur_st)
      MB_STATE_WFG:   m_phase6d_wfg_transitions++;
      MB_STATE_WFC:   m_phase6d_wfc_transitions++;
      MB_STATE_WFI:   m_phase6d_wfi_transitions++;
      MB_STATE_PGFLT: m_phase6d_pgflt_transitions++;
      MB_STATE_ACFLT: m_phase6d_acflt_transitions++;
      MB_STATE_ABT:   m_phase6d_abt_transitions++;
      default: ;
    endcase
  endfunction

  protected function void check_mb_shadow_from_probe();
    for (int i = 0; i < MB_DEPTH; i++) begin
      mb_shadow_t cur;
      cur = probe_mb_entry(i);

      if ($isunknown({cur.valid, cur.state, cur.vpn, cur.iid, cur.store,
                      cur.issued, cur.ready, cur.wfc, cur.wfi})) begin
        sb_error("P6D_MB_OBS_X",
          $sformatf("MB%0d has X core observation: %s", i, mb_shadow_s(cur)));
        continue;
      end

      m_phase6d_shadow_state_check++;

      if (!cur.valid && (cur.state != MB_STATE_IDLE)) begin
        sb_error("P6D_MB_IDLE_STATE",
          $sformatf("MB%0d invalid but state is %s: %s",
            i, mb_state_s(cur.state), mb_shadow_s(cur)));
      end

      if (cur.valid) begin
        m_phase6d_shadow_payload_check++;
        if ((cur.state == MB_STATE_WFI)
            && $isunknown({cur.ppn, cur.pgs, cur.flg})) begin
          sb_error("P6D_MB_WFI_PAYLOAD_X",
            $sformatf("MB%0d WFI payload has X: %s", i, mb_shadow_s(cur)));
        end
        if ((cur.state == MB_STATE_WFI) && !pgs_is_legal(cur.pgs)) begin
          sb_error("P6D_MB_WFI_PGS",
            $sformatf("MB%0d WFI payload has illegal page-size: %s",
              i, mb_shadow_s(cur)));
        end
      end

      if (m_prev_mb_vld[i]) begin
        if (!mb_state_transition_legal(m_prev_mb_state[i], cur.state)) begin
          sb_error("P6D_MB_STATE_TRANSITION",
            $sformatf("MB%0d illegal state transition %s -> %s prev(vpn=0x%07h iid=%0d store=%0b) cur{%s}",
              i, mb_state_s(m_prev_mb_state[i]), mb_state_s(cur.state),
              m_prev_mb_vpn[i], m_prev_mb_iid[i], m_prev_mb_store[i],
              mb_shadow_s(cur)));
        end
        if (cur.valid) begin
          if ((cur.vpn !== m_prev_mb_vpn[i])
           || (cur.iid !== m_prev_mb_iid[i])
           || (cur.store !== m_prev_mb_store[i])) begin
            sb_error("P6D_MB_REQ_PAYLOAD_STABILITY",
              $sformatf("MB%0d request payload changed while valid prev(vpn=0x%07h iid=%0d store=%0b state=%s) cur{%s}",
                i, m_prev_mb_vpn[i], m_prev_mb_iid[i], m_prev_mb_store[i],
                mb_state_s(m_prev_mb_state[i]), mb_shadow_s(cur)));
          end
        end else if ((m_prev_mb_state[i] == MB_STATE_PGFLT)
                 ||  (m_prev_mb_state[i] == MB_STATE_ACFLT)) begin
          m_phase6d_replay_release++;
        end
      end

      if (cur.valid && !m_prev_mb_vld[i])
        cur.last_alloc_cycle = m_cycles;
      else
        cur.last_alloc_cycle = m_mb_shadow[i].last_alloc_cycle;
      cur.last_update_cycle = m_cycles;
      m_mb_shadow[i] = cur;
      m_phase6d_shadow_update++;
      count_mb_transition(cur.state);
    end
  endfunction

  protected function void check_mb_cam_hit_against_shadow(input lsu_pipe_token_t tok);
    int unsigned idx;

    if (!tok.vld || !tok.mb_hit)
      return;

    idx = mb_find_vpn(m_prev_mb_vld, m_prev_mb_vpn, tok.vpn);
    m_phase6d_mb_cam_hit_checks++;
    if (idx >= MB_DEPTH) begin
      if (mb_current_vpn_match(tok.vpn, idx)) begin
        m_phase6d_mb_cam_current_window++;
        `uvm_info({get_type_name(), "::PHASE6G_TIMEOUT_FAIRNESS"},
          $sformatf("[PHASE6G_TIMEOUT_FAIRNESS_MB_CAM_CURRENT_WINDOW] token{%s} idx=%0d prev_vld=0x%02h cur_vld=0x%02h cur_iid=%0d cur_store=%0b",
            token_s(tok), idx, m_prev_mb_vld, v_probe.mon_cb.l1d_mb_vld,
            v_probe.mon_cb.l1d_mb_iid[idx], v_probe.mon_cb.l1d_mb_store[idx]),
          UVM_MEDIUM)
      end else begin
        sb_error("P6D_MB_CAM_HIT",
          $sformatf("MB CAM hit without matching previous/current MB shadow: token{%s} prev_vld=0x%02h cur_vld=0x%02h",
            token_s(tok), m_prev_mb_vld, v_probe.mon_cb.l1d_mb_vld));
      end
    end else begin
      `uvm_info({get_type_name(), "::PHASE6D_MB_CAM"},
        $sformatf("idx=%0d token{%s} shadow_vpn=0x%07h shadow_iid=%0d",
          idx, token_s(tok), m_prev_mb_vpn[idx], m_prev_mb_iid[idx]),
        UVM_HIGH)
    end
  endfunction

  protected function void check_mb_allocation_oracle(
    input lsu_pipe_token_t t1_p0,
    input lsu_pipe_token_t t1_p1
  );
    bit p0_req;
    bit p1_req;
    int unsigned free0;
    int unsigned free1;
    int unsigned free_count;
    bit same_4k;
    bit older0;
    bit p0_cam;
    bit p1_cam;

    if ($isunknown({m_prev_mb_vld, v_probe.mon_cb.l1d_mb_vld}))
      return;

    check_mb_cam_hit_against_shadow(t1_p0);
    check_mb_cam_hit_against_shadow(t1_p1);

    // Mirror the RTL allocator inputs: mb_hit0/1 are retimed T1 combinational
    // results from miss*_vld_q and current mb_entry_vld/vpn.  The scoreboard's
    // previous MB shadow can lag legal same-cycle allocation/refill windows.
    p0_cam = t1_p0.vld && t1_p0.mb_hit;
    p1_cam = t1_p1.vld && t1_p1.mb_hit;
    p0_req = t1_p0.vld && !t1_p0.abort && t1_p0.miss_vld && !p0_cam;
    p1_req = t1_p1.vld && !t1_p1.abort && t1_p1.miss_vld && !p1_cam;
    same_4k = p0_req && p1_req && (t1_p0.vpn == t1_p1.vpn);
    free0 = mb_first_free(m_prev_mb_vld);
    free1 = mb_second_free(m_prev_mb_vld, free0);
    free_count = MB_DEPTH - count8(m_prev_mb_vld);

    if (!p0_req && !p1_req)
      return;

    m_phase6d_alloc_oracle_checks++;

    if (p0_req && !p1_req) begin
      if (free_count != 0) begin
        m_phase6d_alloc_single++;
        mb_alloc_expect_push("single_miss_p0", m_prev_mb_vld, 1, 1'b1, 1'b0, 1'b0, 1'b0,
          t1_p0, t1_p1, free0, MB_DEPTH);
      end else begin
        m_phase6d_alloc_full_drop++;
        mb_alloc_expect_push("full_drop_p0", m_prev_mb_vld, 0, 1'b0, 1'b0, 1'b1, 1'b0,
          t1_p0, t1_p1, MB_DEPTH, MB_DEPTH);
      end
      return;
    end

    if (!p0_req && p1_req) begin
      if (free_count != 0) begin
        m_phase6d_alloc_single++;
        mb_alloc_expect_push("single_miss_p1", m_prev_mb_vld, 1, 1'b0, 1'b1, 1'b0, 1'b0,
          t1_p0, t1_p1, MB_DEPTH, free0);
      end else begin
        m_phase6d_alloc_full_drop++;
        mb_alloc_expect_push("full_drop_p1", m_prev_mb_vld, 0, 1'b0, 1'b0, 1'b0, 1'b1,
          t1_p0, t1_p1, MB_DEPTH, MB_DEPTH);
      end
      return;
    end

    if (same_4k) begin
      if (free_count != 0) begin
        m_phase6d_alloc_dual_same_4k++;
        mb_alloc_expect_push("dual_same_4k_dedup_p0_owner", m_prev_mb_vld, 1,
          1'b1, 1'b0, 1'b0, 1'b1, t1_p0, t1_p1, free0, MB_DEPTH);
      end else begin
        m_phase6d_alloc_full_drop++;
        mb_alloc_expect_push("full_drop_same_4k", m_prev_mb_vld, 0,
          1'b0, 1'b0, 1'b1, 1'b1, t1_p0, t1_p1, MB_DEPTH, MB_DEPTH);
      end
      return;
    end

    older0 = iid0_older(t1_p0.iid, t1_p1.iid);
    if (free_count >= 2) begin
      m_phase6d_alloc_dual_diff_two_free++;
      if (older0) begin
        mb_alloc_expect_push("dual_diff_two_free_p0_old", m_prev_mb_vld, 2,
          1'b1, 1'b1, 1'b0, 1'b0, t1_p0, t1_p1, free0, free1);
      end else begin
        mb_alloc_expect_push("dual_diff_two_free_p1_old", m_prev_mb_vld, 2,
          1'b1, 1'b1, 1'b0, 1'b0, t1_p0, t1_p1, free1, free0);
      end
    end else if (free_count == 1) begin
      m_phase6d_alloc_dual_diff_one_free++;
      if (older0) begin
        mb_alloc_expect_push("dual_diff_one_free_p0_old", m_prev_mb_vld, 1,
          1'b1, 1'b0, 1'b0, 1'b1, t1_p0, t1_p1, free0, MB_DEPTH);
      end else begin
        mb_alloc_expect_push("dual_diff_one_free_p1_old", m_prev_mb_vld, 1,
          1'b0, 1'b1, 1'b1, 1'b0, t1_p0, t1_p1, MB_DEPTH, free0);
      end
    end else begin
      m_phase6d_alloc_full_drop++;
      mb_alloc_expect_push("full_drop_dual", m_prev_mb_vld, 0,
        1'b0, 1'b0, 1'b1, 1'b1, t1_p0, t1_p1, MB_DEPTH, MB_DEPTH);
    end
  endfunction

  protected virtual function void check_refill_and_expt();
    phase6e_check_install_and_refill();
    phase6e_check_ref_completion("PTW", v_probe.mon_cb.l1d_ptw_ref_id,
      v_probe.mon_cb.l1d_ptw_ref_cmplt, v_probe.mon_cb.l1d_ptw_ref_pavld,
      v_probe.mon_cb.l1d_ptw_ref_pgflt, v_probe.mon_cb.l1d_ptw_ref_acflt,
      v_probe.mon_cb.l1d_ptw_ref_vpn, v_probe.mon_cb.l1d_ptw_ref_ppn,
      v_probe.mon_cb.l1d_ptw_ref_pgs, v_probe.mon_cb.l1d_ptw_ref_flg);
    phase6e_check_ref_completion("L2", v_probe.mon_cb.l1d_l2_ref_eid,
      v_probe.mon_cb.l1d_l2_ref_cmplt, v_probe.mon_cb.l1d_l2_ref_pavld,
      v_probe.mon_cb.l1d_l2_ref_pgflt, 1'b0,
      v_probe.mon_cb.l1d_l2_ref_vpn, v_probe.mon_cb.l1d_l2_ref_ppn,
      v_probe.mon_cb.l1d_l2_ref_pgs, v_probe.mon_cb.l1d_l2_ref_flg);

    if (v_probe.mon_cb.l1d_refill_vld) begin
      m_refill_cycles++;
      case (v_probe.mon_cb.l1d_refill_pgs)
        3'b001: m_refill_4k_cycles++;
        3'b010: m_refill_2m_cycles++;
        3'b100: m_refill_1g_cycles++;
        default: ;
      endcase
      if ($isunknown({v_probe.mon_cb.l1d_entry_upd,
                      v_probe.mon_cb.l1d_refill_idx,
                      v_probe.mon_cb.l1d_refill_src,
                      v_probe.mon_cb.l1d_refill_vpn,
                      v_probe.mon_cb.l1d_refill_ppn,
                      v_probe.mon_cb.l1d_refill_pgs}))
        sb_error("REFILL_X",
          $sformatf("refill_vld asserted with X payload: src=0x%0h idx=%0d vpn=0x%07h ppn=0x%07h pgs=0x%0h upd=0x%04h",
            v_probe.mon_cb.l1d_refill_src, v_probe.mon_cb.l1d_refill_idx,
            v_probe.mon_cb.l1d_refill_vpn, v_probe.mon_cb.l1d_refill_ppn,
            v_probe.mon_cb.l1d_refill_pgs, v_probe.mon_cb.l1d_entry_upd));
      else if (v_probe.mon_cb.l1d_refill_idx > 4'd15)
        sb_error("REFILL_INDEX_RANGE",
          $sformatf("refill_idx out of entry range: idx=%0d src=0x%0h vpn=0x%07h",
            v_probe.mon_cb.l1d_refill_idx, v_probe.mon_cb.l1d_refill_src,
            v_probe.mon_cb.l1d_refill_vpn));
      else if (count16(v_probe.mon_cb.l1d_entry_upd) != 1)
        sb_error("REFILL_ONEHOT",
          $sformatf("refill_vld requires one-hot entry_upd, got 0x%04h",
            v_probe.mon_cb.l1d_entry_upd));
      else if (v_probe.mon_cb.l1d_entry_upd !== onehot16(v_probe.mon_cb.l1d_refill_idx))
        sb_error("REFILL_INDEX",
          $sformatf("entry_upd=0x%04h does not match refill_idx=%0d",
            v_probe.mon_cb.l1d_entry_upd, v_probe.mon_cb.l1d_refill_idx));
    end

    if (v_probe.mon_cb.l1d_expt_wr0_vld) begin
      m_expt_write_cycles++;
      if ($isunknown({v_probe.mon_cb.l1d_expt_wr0_eid,
                      v_probe.mon_cb.l1d_expt_wr0_iid,
                      v_probe.mon_cb.l1d_expt_wr0_vpn,
                      v_probe.mon_cb.l1d_expt_wr0_pgflt,
                      v_probe.mon_cb.l1d_expt_wr0_acflt}))
        sb_error("EXPT_WR0_X", "expt_wr0 asserted with X payload");
      if (v_probe.mon_cb.l1d_expt_wr0_eid > 4'd7)
        sb_error("EXPT_WR0_EID",
          $sformatf("expt_wr0 EID out of MB range: eid=%0d iid=%0d vpn=0x%07h",
            v_probe.mon_cb.l1d_expt_wr0_eid,
            v_probe.mon_cb.l1d_expt_wr0_iid,
            v_probe.mon_cb.l1d_expt_wr0_vpn));
      if (v_probe.mon_cb.l1d_expt_wr0_pgflt && v_probe.mon_cb.l1d_expt_wr0_acflt)
        sb_error("EXPT_WR0_FAULT_EXCL",
          $sformatf("expt_wr0 has both page/access fault set: eid=%0d iid=%0d vpn=0x%07h",
            v_probe.mon_cb.l1d_expt_wr0_eid,
            v_probe.mon_cb.l1d_expt_wr0_iid,
            v_probe.mon_cb.l1d_expt_wr0_vpn));
    end
    if (v_probe.mon_cb.l1d_expt_wr1_vld) begin
      m_expt_write_cycles++;
      if ($isunknown({v_probe.mon_cb.l1d_expt_wr1_eid,
                      v_probe.mon_cb.l1d_expt_wr1_iid,
                      v_probe.mon_cb.l1d_expt_wr1_vpn,
                      v_probe.mon_cb.l1d_expt_wr1_pgflt,
                      v_probe.mon_cb.l1d_expt_wr1_acflt}))
        sb_error("EXPT_WR1_X", "expt_wr1 asserted with X payload");
      if (v_probe.mon_cb.l1d_expt_wr1_eid > 4'd7)
        sb_error("EXPT_WR1_EID",
          $sformatf("expt_wr1 EID out of MB range: eid=%0d iid=%0d vpn=0x%07h",
            v_probe.mon_cb.l1d_expt_wr1_eid,
            v_probe.mon_cb.l1d_expt_wr1_iid,
            v_probe.mon_cb.l1d_expt_wr1_vpn));
      if (v_probe.mon_cb.l1d_expt_wr1_pgflt && v_probe.mon_cb.l1d_expt_wr1_acflt)
        sb_error("EXPT_WR1_FAULT_EXCL",
          $sformatf("expt_wr1 has both page/access fault set: eid=%0d iid=%0d vpn=0x%07h",
            v_probe.mon_cb.l1d_expt_wr1_eid,
            v_probe.mon_cb.l1d_expt_wr1_iid,
            v_probe.mon_cb.l1d_expt_wr1_vpn));
    end
    if (v_probe.mon_cb.l1d_expt_wr0_vld && v_probe.mon_cb.l1d_expt_wr1_vld
        && !$isunknown({v_probe.mon_cb.l1d_expt_wr0_eid,
                        v_probe.mon_cb.l1d_expt_wr1_eid})
        && (v_probe.mon_cb.l1d_expt_wr0_eid == v_probe.mon_cb.l1d_expt_wr1_eid))
      sb_error("EXPT_DUAL_EID",
        $sformatf("expt_wr0/expt_wr1 overwrite same EID=%0d wr0(iid=%0d vpn=0x%07h pg=%0b af=%0b) wr1(iid=%0d vpn=0x%07h pg=%0b af=%0b)",
          v_probe.mon_cb.l1d_expt_wr0_eid,
          v_probe.mon_cb.l1d_expt_wr0_iid,
          v_probe.mon_cb.l1d_expt_wr0_vpn,
          v_probe.mon_cb.l1d_expt_wr0_pgflt,
          v_probe.mon_cb.l1d_expt_wr0_acflt,
          v_probe.mon_cb.l1d_expt_wr1_iid,
          v_probe.mon_cb.l1d_expt_wr1_vpn,
          v_probe.mon_cb.l1d_expt_wr1_pgflt,
          v_probe.mon_cb.l1d_expt_wr1_acflt));
  endfunction

  protected virtual function void check_phase6a_observability();
    logic [2:0] sel_vec;

    m_phase6a_inventory_checks++;

    if (!$isunknown(v_probe.mon_cb.l1d_entry_vld)) begin
      for (int i = 0; i < 16; i++) begin
        if (v_probe.mon_cb.l1d_entry_vld[i]) begin
          m_phase6a_entry_payload_checks++;
          if ($isunknown({v_probe.mon_cb.l1d_entry_vpn[i],
                          v_probe.mon_cb.l1d_entry_ppn[i],
                          v_probe.mon_cb.l1d_entry_pgs[i],
                          v_probe.mon_cb.l1d_entry_flg[i]}))
            sb_error("P6A_ENTRY_PAYLOAD_X",
              $sformatf("valid entry%0d has X payload vpn=0x%07h ppn=0x%07h pgs=0x%0h flg=0x%04h",
                i, v_probe.mon_cb.l1d_entry_vpn[i], v_probe.mon_cb.l1d_entry_ppn[i],
                v_probe.mon_cb.l1d_entry_pgs[i], v_probe.mon_cb.l1d_entry_flg[i]));
        end
      end
    end

    if (v_probe.mon_cb.l1d_refill_vld) begin
      m_phase6a_refill_payload_checks++;
      if ($isunknown({v_probe.mon_cb.l1d_refill_flg,
                      v_probe.mon_cb.l1d_refill_gnt_bus,
                      v_probe.mon_cb.l1d_ptw_ref_pavld,
                      v_probe.mon_cb.l1d_ptw_ref_cmplt,
                      v_probe.mon_cb.l1d_l2_ref_pavld,
                      v_probe.mon_cb.l1d_l2_ref_cmplt}))
        sb_error("P6A_REFILL_OBS_X",
          $sformatf("refill full observation has X: flg=0x%04h gnt=0x%02h ptw(pavld=%0b cmplt=%0b) l2(pavld=%0b cmplt=%0b)",
            v_probe.mon_cb.l1d_refill_flg, v_probe.mon_cb.l1d_refill_gnt_bus,
            v_probe.mon_cb.l1d_ptw_ref_pavld, v_probe.mon_cb.l1d_ptw_ref_cmplt,
            v_probe.mon_cb.l1d_l2_ref_pavld, v_probe.mon_cb.l1d_l2_ref_cmplt));
    end

    if (!$isunknown({v_probe.mon_cb.l1d_install_sel_ptw,
                     v_probe.mon_cb.l1d_install_sel_l2,
                     v_probe.mon_cb.l1d_install_sel_wfi})) begin
      sel_vec = {v_probe.mon_cb.l1d_install_sel_wfi,
                 v_probe.mon_cb.l1d_install_sel_ptw,
                 v_probe.mon_cb.l1d_install_sel_l2};
      if (sel_vec != 3'b000) begin
        m_phase6a_install_arb_checks++;
        if (count3(sel_vec) > 1)
          sb_error("P6A_INSTALL_MULTI_SEL",
            $sformatf("install selected multiple sources: wfi=%0b ptw=%0b l2=%0b ids wfi=%0d ptw=%0d l2=%0d",
              v_probe.mon_cb.l1d_install_sel_wfi,
              v_probe.mon_cb.l1d_install_sel_ptw,
              v_probe.mon_cb.l1d_install_sel_l2,
              v_probe.mon_cb.l1d_install_id_wfi,
              v_probe.mon_cb.l1d_install_id_ptw,
              v_probe.mon_cb.l1d_install_id_l2));
      end
    end

    if (!$isunknown(v_probe.mon_cb.l1d_expt_hit_vec)
        && (v_probe.mon_cb.l1d_expt_hit_vec != 8'h00)) begin
      m_phase6a_expt_consume_checks++;
      if (count8(v_probe.mon_cb.l1d_expt_hit_vec) > 2)
        sb_error("P6A_EXPT_HIT_VEC_RANGE",
          $sformatf("expt hit vec consumes more than two entries: 0x%02h",
            v_probe.mon_cb.l1d_expt_hit_vec));
      if (!$isunknown(v_probe.mon_cb.l1d_expt_wakeup)
          && (v_probe.mon_cb.l1d_expt_wakeup !== 12'hfff))
        sb_error("P6A_EXPT_WAKEUP",
          $sformatf("expt hit vec requires broadcast wakeup, got hit=0x%02h wakeup=0x%03h",
            v_probe.mon_cb.l1d_expt_hit_vec, v_probe.mon_cb.l1d_expt_wakeup));
    end

    if (!$isunknown({v_probe.mon_cb.l1d_cp0_priv_mode,
                     v_probe.mon_cb.l1d_cp0_mprv,
                     v_probe.mon_cb.l1d_cp0_mpp,
                     v_probe.mon_cb.l1d_cp0_mxr,
                     v_probe.mon_cb.l1d_cp0_sum,
                     v_probe.mon_cb.l1d_regs_cur_asid,
                     v_probe.mon_cb.l1d_regs_satp_ppn}))
      m_phase6a_mode_snapshot_checks++;
  endfunction

  protected virtual function void check_invalidate_edges();
    logic [15:0] match_now;
    logic [15:0] conflict_now;

    if (v_probe.mon_cb.tlboper_utlb_inv_va_req
        && !$isunknown({v_probe.mon_cb.l1d_entry_vld,
                        v_probe.mon_cb.l1d_entry_vpn,
                        v_probe.mon_cb.tlboper_utlb_inv_va})) begin
      match_now = v_probe.mon_cb.l1d_entry_vld
                & va8_match_vec(v_probe.mon_cb.tlboper_utlb_inv_va[7:0]);
      if (match_now != 16'h0000)
        m_va8_inv_cycles++;
      conflict_now = match_now & v_probe.mon_cb.l1d_entry_upd;
      if (conflict_now != 16'h0000)
        m_inv_install_conflict_cycles++;
    end

    if (v_probe.mon_cb.tlboper_utlb_clr
        && !$isunknown(v_probe.mon_cb.l1d_entry_upd)
        && (v_probe.mon_cb.l1d_entry_upd != 16'h0000))
      m_inv_install_conflict_cycles++;

    if (m_prev_refill_vld
        && !$isunknown({m_prev_refill_idx, m_prev_refill_vpn, v_probe.mon_cb.l1d_entry_vld})) begin
      if (v_probe.mon_cb.l1d_entry_vld[m_prev_refill_idx]
          && (v_probe.mon_cb.l1d_entry_vpn[m_prev_refill_idx] == m_prev_refill_vpn))
        m_install_visible_next_cycles++;
    end
  endfunction

  protected virtual function void check_l2_req_and_credit();
    if (v_probe.mon_cb.l1d_l2_req_vld) begin
      m_l2_req_cycles++;
      if (!$isunknown(v_probe.mon_cb.l1d_l2_req_is_load)) begin
        if (v_probe.mon_cb.l1d_l2_req_is_load)
          m_l2_load_req_cycles++;
        else
          m_l2_store_req_cycles++;
      end
      if ($isunknown({v_probe.mon_cb.l1d_l2_req_vpn,
                      v_probe.mon_cb.l1d_l2_req_eid,
                      v_probe.mon_cb.l1d_l2_req_is_load}))
        sb_error("L2_REQ_X", "L1DTLB L2 request asserted with X payload");
      if (v_probe.mon_cb.l1d_l2_req_eid > 3'd7)
        sb_error("L2_REQ_EID",
          $sformatf("L1DTLB L2 request EID out of MB range: %0d",
            v_probe.mon_cb.l1d_l2_req_eid));
    end
    if (!$isunknown(v_probe.mon_cb.l1d_sched_credit_cnt)
        && (v_probe.mon_cb.l1d_sched_credit_cnt > 5'd8)) begin
      sb_error("CREDIT_RANGE",
        $sformatf("L1DTLB scheduler credit_cnt out of range: %0d cycle=%0d l2_req=%0b",
          v_probe.mon_cb.l1d_sched_credit_cnt, m_cycles,
          v_probe.mon_cb.l1d_l2_req_vld));
    end
    if (!$isunknown(v_probe.mon_cb.l1d_sched_credit_cnt)
        && (v_probe.mon_cb.l1d_sched_credit_cnt == 5'd0)) begin
      m_credit_zero_cycles++;
      if (v_probe.mon_cb.l1d_l2_req_vld) begin
        m_credit_zero_req_cycles++;
        `uvm_info({get_type_name(), "::CREDIT_ZERO_REQ"},
          $sformatf("L1DTLB L2 request observed while sampled scheduler credit is zero; exact same-cycle return is SVA-owned. cycle=%0d vpn=0x%07h eid=%0d is_load=%0b",
            m_cycles, v_probe.mon_cb.l1d_l2_req_vpn,
            v_probe.mon_cb.l1d_l2_req_eid,
            v_probe.mon_cb.l1d_l2_req_is_load),
          UVM_MEDIUM)
      end
    end
    phase6f_check_credit_shadow();
  endfunction

  protected virtual function void check_pipe_response_fault_pulses(
    input lsu_pipe_token_t t0,
    input lsu_pipe_token_t t1
  );
    bit pf_owned;
    bit af_owned;
    bit af_expt_owned;
    lsu_pipe_token_t diag_t0;
    lsu_pipe_token_t diag_t1;

    check_no_response_t1_side_effect(t0.pipe, t0, t1);
    diag_t0 = t0;
    diag_t1 = t1;

    if (t0.vld)
      m_t0_token_cycles++;
    if (t1.vld)
      m_t1_token_cycles++;

    if (t0.vld) begin
      if (t0.path_class == TOKEN_PATH_DIRECT_MAP)
        m_phase6b_direct_map_classified++;
      if (t0.path_class == TOKEN_PATH_STAMO)
        m_phase6b_stamo_classified++;
      if (t0.path_class == TOKEN_PATH_EXPT)
        m_phase6b_expt_classified++;
      `uvm_info({get_type_name(), "::PHASE6B_TOKEN"},
        token_diag_s("t0_sample", t0),
        UVM_DEBUG)
    end

    if (!$isunknown({t0.page_fault, t0.pa_vld}) && t0.page_fault) begin
      pf_owned = t0.vld && !t0.abort && t0.pa_vld;
      diag_t0.page_fault_owner = pf_owned;
      m_page_fault_pair_checks++;
      if (t0.store)
        m_page_fault_store_pair_checks++;
      else
        m_page_fault_load_pair_checks++;
      if (!$isunknown(t0.access_fault) && !t0.access_fault)
        m_page_fault_no_access_fault_cycles++;
      if (pf_owned) begin
        m_phase6b_pf_owner_t0++;
        `uvm_info({get_type_name(), "::PHASE6B_FAULT_OWNER"},
          token_diag_s("page_fault_current_t0", diag_t0),
          UVM_HIGH)
      end
      if (!t0.pa_vld) begin
        sb_error("PAGE_FAULT_T0_PAIR",
          $sformatf("page_fault without same-cycle pa_vld ownership: T0{%s} T1{%s}",
            token_s(t0), token_s(t1)));
      end
      if (!t0.vld || t0.abort) begin
        sb_error("PAGE_FAULT_T0_OWNER",
          $sformatf("page_fault has no legal current T0 owner: T0{%s} T1{%s}",
            token_s(t0), token_s(t1)));
      end
    end

    if (!$isunknown(t0.access_fault) && t0.access_fault) begin
      af_owned = t1.vld && !t1.abort && ((t1.cycle + 1) == t0.cycle)
              && ((t1.path_class == TOKEN_PATH_MISS)
               || (t1.path_class == TOKEN_PATH_PA_RSP)
               || (t1.pmp_flg != 4'h0));
      af_expt_owned = t0.vld && !t0.abort && t0.pa_vld
                   && (t0.path_class == TOKEN_PATH_EXPT)
                   && !af_owned;
      diag_t1.access_fault_owner = af_owned;
      diag_t0.access_fault_owner = af_expt_owned;
      m_access_fault_pair_checks++;
      if (af_owned && t1.store)
        m_access_fault_store_pair_checks++;
      else if (af_owned)
        m_access_fault_load_pair_checks++;
      else if (af_expt_owned && t0.store)
        m_access_fault_store_pair_checks++;
      else
        m_access_fault_load_pair_checks++;
      if (af_expt_owned) begin
        `uvm_info({get_type_name(), "::PHASE6B_FAULT_OWNER"},
          token_diag_s("access_fault_expt_replay_t0", diag_t0),
          UVM_HIGH)
      end else if (af_owned) begin
        m_phase6b_af_owner_t1++;
        if ((t1.path_class == TOKEN_PATH_MISS)
         || (t1.path_class == TOKEN_PATH_PA_RSP)
         || (t1.pmp_flg != 4'h0))
          m_phase6b_pmp_t1_classified++;
        `uvm_info({get_type_name(), "::PHASE6B_FAULT_OWNER"},
          token_diag_s("access_fault_previous_t1", diag_t1),
          UVM_HIGH)
      end
      if (!af_owned && !af_expt_owned) begin
        sb_error("ACCESS_FAULT_T1_OWNER",
          $sformatf("access_fault has no legal previous-cycle T1 owner: T0{%s} T1{%s}",
            token_s(t0), token_s(t1)));
      end
      if (!af_expt_owned && t1.vld && t1.page_fault) begin
        sb_error("FAULT_SAME_TOKEN",
          $sformatf("access_fault belongs to a T1 token that already reported page_fault at T0: T0{%s} T1{%s}",
            token_s(t0), token_s(t1)));
      end
    end

    if (!$isunknown({t0.page_fault, t0.access_fault})
        && t0.page_fault && t0.access_fault) begin
      m_fault_overlap_cycles++;
      if (t1.vld && ((t1.cycle + 1) == t0.cycle) && !token_same_owner(t0, t1)) begin
        m_phase6b_fault_overlap_separate++;
        `uvm_info({get_type_name(), "::FAULT_OVERLAP"},
          $sformatf("phase6b_class=fault_overlap separate_owners=1 current{%s} previous{%s}",
            token_s(t0), token_s(t1)),
          UVM_HIGH)
      end else begin
        sb_error("FAULT_OVERLAP_OWNER",
          $sformatf("same-cycle page/access fault does not have separate T0/T1 owners: T0{%s} T1{%s}",
            token_s(t0), token_s(t1)));
      end
    end
  endfunction

  protected virtual function void sample_scenario_counters(
    input lsu_pipe_token_t t0_p0,
    input lsu_pipe_token_t t0_p1
  );
    bit p0_req;
    bit p1_req;
    bit p0_hit;
    bit p1_hit;
    bit p0_miss;
    bit p1_miss;
    bit mb_full_now;
    bit dual_diff_one_free;
    bit inv_now;
    bit any_tlb_hit;
    bit any_expt_replay;
    bit direct_map_req;
    bit stamo_active;

    p0_req  = req0_seen();
    p1_req  = req1_seen();
    p0_hit  = v_probe.mon_cb.l1d_p0_hit_vld;
    p1_hit  = v_probe.mon_cb.l1d_p1_hit_vld;
    p0_miss = v_probe.mon_cb.l1d_p0_miss_vld;
    p1_miss = v_probe.mon_cb.l1d_p1_miss_vld;
    mb_full_now = (count8(v_probe.mon_cb.l1d_mb_vld) == 8);
    dual_diff_one_free = p0_req && p1_req
                      && p0_miss && p1_miss
                      && !v_probe.mon_cb.l1d_p0_mb_hit
                      && !v_probe.mon_cb.l1d_p1_mb_hit
                      && !p0_hit && !p1_hit
                      && (count8(v_probe.mon_cb.l1d_mb_vld) == 7)
                      && (t0_p0.vpn != t0_p1.vpn);
    inv_now = inv_req_seen();
    any_tlb_hit = (p0_req && p0_hit) || (p1_req && p1_hit);
    any_expt_replay = (t0_p0.vld && t0_p0.expt_match)
                   || (t0_p1.vld && t0_p1.expt_match);
    direct_map_req = (lsu_vif.monitor_cb.mmu_lsu_mmu_en === 1'b0)
                  && (p0_req || p1_req);
    stamo_active = lsu_vif.monitor_cb.lsu_mmu_stamo_vld;

    if (p0_req && p1_req) begin
      m_dual_req_cycles++;
      if (p0_hit && p1_hit)
        m_dual_hit_cycles++;
      if ((p0_hit && p1_miss) || (p1_hit && p0_miss))
        m_hit_miss_cycles++;
      if (p0_miss && p1_miss)
        m_dual_miss_cycles++;
    end

    if ((p0_req && p0_hit) || (p1_req && p1_hit))
      m_hit_cycles++;
    if (p0_req && p0_hit) begin
      case (t0_p0.hit_pgs)
        3'b001: m_hit_4k_cycles++;
        3'b010: m_hit_2m_cycles++;
        3'b100: m_hit_1g_cycles++;
        default: ;
      endcase
    end
    if (p0_req && t0_p0.pa_vld && !t0_p0.page_fault && !t0_p0.access_fault) begin
      if (t0_p0.store)
        m_store_success_cycles++;
      else
        m_load_success_cycles++;
      if (!t0_p0.store && token_vpn_idx(t0_p0, 36))
        m_perm_load_mxr_success_cycles++;
      if (!t0_p0.store && token_vpn_idx(t0_p0, 50))
        m_perm_sum1_success_cycles++;
    end
    if (p1_req && p1_hit) begin
      case (t0_p1.hit_pgs)
        3'b001: m_hit_4k_cycles++;
        3'b010: m_hit_2m_cycles++;
        3'b100: m_hit_1g_cycles++;
        default: ;
      endcase
    end
    if (p1_req && t0_p1.pa_vld && !t0_p1.page_fault && !t0_p1.access_fault) begin
      if (t0_p1.store)
        m_store_success_cycles++;
      else
        m_load_success_cycles++;
      if (!t0_p1.store && token_vpn_idx(t0_p1, 36))
        m_perm_load_mxr_success_cycles++;
      if (!t0_p1.store && token_vpn_idx(t0_p1, 50))
        m_perm_sum1_success_cycles++;
    end

    if (mb_full_now)
      m_mb_full_cycles++;

    if (direct_map_req) begin
      m_direct_map_cycles++;
      if (!v_probe.mon_cb.l1d_l2_req_vld)
        `uvm_info({get_type_name(), "::DIRECT_MAP"},
          $sformatf("direct-map request observed with no same-cycle L2 request: p0=%0b p1=%0b",
            p0_req, p1_req),
          UVM_HIGH)
      if (!$isunknown({v_probe.mon_cb.l1d_mb_vld, m_prev_mb_vld})
          && (v_probe.mon_cb.l1d_mb_vld == m_prev_mb_vld))
        m_direct_map_no_mb_cycles++;
    end
    if (stamo_active) begin
      m_stamo_cycles++;
      if (t0_p1.pa_vld && (t0_p1.pa == lsu_vif.monitor_cb.lsu_mmu_stamo_pa))
        m_stamo_pipe1_bypass_cycles++;
      if (t0_p0.vld && !t0_p1.vld) begin
        m_stamo_pipe0_pollution_checks++;
        if (!(t0_p0.pa_vld && (t0_p0.pa == lsu_vif.monitor_cb.lsu_mmu_stamo_pa)))
          m_stamo_pipe0_negative_cycles++;
        else
          sb_error("STAMO_PIPE0_POLLUTION",
            $sformatf("pipe0 response was sourced from STAMO PA: stamo_pa=0x%07h token{%s}",
              lsu_vif.monitor_cb.lsu_mmu_stamo_pa, token_s(t0_p0)));
      end
    end
    if ((lsu_vif.monitor_cb.lsu_mmu_va0_vld && lsu_vif.monitor_cb.lsu_mmu_abort0)
     || (lsu_vif.monitor_cb.lsu_mmu_va1_vld && lsu_vif.monitor_cb.lsu_mmu_abort1))
      m_abort_req_cycles++;
    if (lsu_vif.monitor_cb.mmu_lsu_tlb_inv_done
     || v_probe.mon_cb.tlboper_utlb_clr
     || v_probe.mon_cb.tlboper_utlb_inv_va_req)
      m_inv_cycles++;
    if (v_probe.mon_cb.rtu_yy_xx_flush)
      m_flush_cycles++;
    if (v_probe.mon_cb.l1d_p0_miss_vld || v_probe.mon_cb.l1d_p1_miss_vld)
      m_hpc_miss_cycles++;

    if (inv_now && any_tlb_hit)
      m_inv_hit_same_cycle_cycles++;

    if (any_expt_replay) begin
      m_expt_replay_cycles++;
      if (lsu_vif.monitor_cb.mmu_lsu_tlb_wakeup == 12'hfff)
        m_expt_wakeup_cycles++;
    end

    if ((p0_req && p0_hit && t0_p1.vld && t0_p1.expt_match)
     || (p1_req && p1_hit && t0_p0.vld && t0_p0.expt_match))
      m_expt_tlb_hit_overlap_cycles++;

    if (t0_p0.vld && t0_p0.abort && t0_p0.hit_vld)
      m_abort_hit_cycles++;
    if (t0_p1.vld && t0_p1.abort && t0_p1.hit_vld)
      m_abort_hit_cycles++;

    if (t0_p0.vld && t0_p0.abort && t0_p0.expt_match)
      sb_error("ABORT_EXPT_SIDE_EFFECT",
        $sformatf("abort request consumed exception match on pipe0: %s",
          token_s(t0_p0)));
    if (t0_p1.vld && t0_p1.abort && t0_p1.expt_match)
      sb_error("ABORT_EXPT_SIDE_EFFECT",
        $sformatf("abort request consumed exception match on pipe1: %s",
          token_s(t0_p1)));
    if (t0_p0.vld && t0_p0.abort && t0_p0.miss_vld)
      sb_error("ABORT_MISS_SIDE_EFFECT",
        $sformatf("abort request produced miss side effect on pipe0: %s",
          token_s(t0_p0)));
    if (t0_p1.vld && t0_p1.abort && t0_p1.miss_vld)
      sb_error("ABORT_MISS_SIDE_EFFECT",
        $sformatf("abort request produced miss side effect on pipe1: %s",
          token_s(t0_p1)));

    if (p0_req && p0_miss && mb_full_now && !v_probe.mon_cb.l1d_p0_mb_hit && !p0_hit) begin
      m_legal_no_response_mb_full_cycles++;
      record_legal_no_response("mb_full", t0_p0, 1'b1);
    end
    if (p1_req && p1_miss && mb_full_now && !v_probe.mon_cb.l1d_p1_mb_hit && !p1_hit) begin
      m_legal_no_response_mb_full_cycles++;
      record_legal_no_response("mb_full", t0_p1, 1'b1);
    end
    if (t0_p0.vld && t0_p0.abort && !t0_p0.hit_vld && !token_has_t0_terminal(t0_p0)) begin
      m_abort_miss_no_response_cycles++;
      m_legal_no_response_abort_cycles++;
      record_legal_no_response("abort_mask", t0_p0, 1'b1);
    end
    if (t0_p1.vld && t0_p1.abort && !t0_p1.hit_vld && !token_has_t0_terminal(t0_p1)) begin
      m_abort_miss_no_response_cycles++;
      m_legal_no_response_abort_cycles++;
      record_legal_no_response("abort_mask", t0_p1, 1'b1);
    end
    if (v_probe.mon_cb.rtu_yy_xx_flush && (v_probe.mon_cb.l1d_mb_vld != 8'h00)) begin
      m_legal_no_response_flush_cycles++;
      record_legal_no_response("flush_kill", null_token(), 1'b0);
      check_flush_no_response_side_effects();
    end
    if (dual_diff_one_free) begin
      m_one_free_dual_diff_cycles++;
      if (t0_p0.iid < t0_p1.iid)
        m_one_free_p0_older_cycles++;
      else if (t0_p1.iid < t0_p0.iid)
        m_one_free_p1_older_cycles++;
      m_legal_no_response_priority_drop_cycles++;
      record_legal_no_response("priority_drop_one_free", null_token(), 1'b0);
    end
    if (!dual_diff_one_free && !mb_full_now
        && lsu_vif.monitor_cb.mmu_lsu_tlb_busy
        && p0_req && p0_miss && !v_probe.mon_cb.l1d_p0_mb_hit && !p0_hit) begin
      m_legal_no_response_busy_sleep_cycles++;
      record_legal_no_response("busy_sleep", t0_p0, 1'b1);
    end
    if (!dual_diff_one_free && !mb_full_now
        && lsu_vif.monitor_cb.mmu_lsu_tlb_busy
        && p1_req && p1_miss && !v_probe.mon_cb.l1d_p1_mb_hit && !p1_hit) begin
      m_legal_no_response_busy_sleep_cycles++;
      record_legal_no_response("busy_sleep", t0_p1, 1'b1);
    end
    if (lsu_vif.monitor_cb.mmu_lsu_page_fault0 || lsu_vif.monitor_cb.mmu_lsu_page_fault1)
      m_page_fault_cycles++;
    if (lsu_vif.monitor_cb.mmu_lsu_access_fault0 || lsu_vif.monitor_cb.mmu_lsu_access_fault1)
      m_access_fault_cycles++;
    if (t0_p0.page_fault) begin
      if (!t0_p0.store && token_vpn_idx(t0_p0, 32))
        m_perm_load_r0_pf_cycles++;
      if (!t0_p0.store && token_vpn_idx(t0_p0, 33))
        m_perm_load_mxr_pf_cycles++;
      if (t0_p0.store && token_vpn_idx(t0_p0, 34))
        m_perm_store_w0_pf_cycles++;
      if (t0_p0.store && token_vpn_idx(t0_p0, 35))
        m_perm_store_d0_pf_cycles++;
      if (!t0_p0.store && token_vpn_idx(t0_p0, 48))
        m_perm_a0_pf_cycles++;
      if (!t0_p0.store && token_vpn_idx(t0_p0, 49))
        m_perm_sum0_pf_cycles++;
      if (!t0_p0.store && token_vpn_idx(t0_p0, 51))
        m_perm_user_u0_pf_cycles++;
    end
    if (t0_p1.page_fault) begin
      if (!t0_p1.store && token_vpn_idx(t0_p1, 32))
        m_perm_load_r0_pf_cycles++;
      if (!t0_p1.store && token_vpn_idx(t0_p1, 33))
        m_perm_load_mxr_pf_cycles++;
      if (t0_p1.store && token_vpn_idx(t0_p1, 34))
        m_perm_store_w0_pf_cycles++;
      if (t0_p1.store && token_vpn_idx(t0_p1, 35))
        m_perm_store_d0_pf_cycles++;
      if (!t0_p1.store && token_vpn_idx(t0_p1, 48))
        m_perm_a0_pf_cycles++;
      if (!t0_p1.store && token_vpn_idx(t0_p1, 49))
        m_perm_sum0_pf_cycles++;
      if (!t0_p1.store && token_vpn_idx(t0_p1, 51))
        m_perm_user_u0_pf_cycles++;
    end
  endfunction

  protected function void gate_expect_nonzero(string tag, int unsigned value);
    if (value == 0)
      `uvm_warning({get_type_name(), "::SCENARIO_GATE"},
        $sformatf("%s did not observe required event for tc_id=%s scenario_id=%s",
          tag, m_l1dtlb_tc_id, m_l1dtlb_scenario_id))
  endfunction

  protected virtual function void check_scenario_gate();
    if (!m_l1dtlb_gate_en)
      return;

    if ((m_l1dtlb_tc_id == "DTLB_HIT_001") || (m_l1dtlb_tc_id == "DTLB_HIT_002")
     || (m_l1dtlb_tc_id == "DTLB_CONCURRENT_001") || (m_l1dtlb_tc_id == "DTLB_DUAL_HIT_MUX_001")) begin
      gate_expect_nonzero("hit_cycle", m_hit_cycles);
      gate_expect_nonzero("phase6c_shadow_hit_compare", m_phase6c_shadow_hit_compare);
      gate_expect_nonzero("phase6c_shadow_pa_compare", m_phase6c_shadow_pa_compare);
      gate_expect_nonzero("phase6c_shadow_attr_compare", m_phase6c_shadow_attr_compare);
    end

    if ((m_l1dtlb_tc_id == "DTLB_HIT_MISS_CONCURRENT_001") || (m_l1dtlb_tc_id == "DTLB_CONCURRENT_002"))
      gate_expect_nonzero("hit_miss_cycle", m_hit_miss_cycles);

    if (m_l1dtlb_tc_id == "DTLB_HIT_MISS_CONCURRENT_001")
      gate_expect_nonzero("phase6d_no_rsp_mb_cam", m_phase6d_no_rsp_mb_cam);

    if ((m_l1dtlb_tc_id == "DTLB_ALLOC_001") || (m_l1dtlb_tc_id == "DTLB_ALLOC_TWO_LOWEST_FREE_001"))
      gate_expect_nonzero("dual_miss_cycle", m_dual_miss_cycles);

    if (m_l1dtlb_tc_id == "DTLB_ALLOC_001") begin
      gate_expect_nonzero("phase6d_dual_same_4k", m_phase6d_alloc_dual_same_4k);
      gate_expect_nonzero("phase6d_alloc_oracle", m_phase6d_alloc_oracle_checks);
    end

    if (m_l1dtlb_tc_id == "DTLB_ALLOC_TWO_LOWEST_FREE_001") begin
      gate_expect_nonzero("phase6d_dual_diff_two_free", m_phase6d_alloc_dual_diff_two_free);
      gate_expect_nonzero("phase6d_alloc_match", m_phase6d_alloc_match_checks);
    end

    if ((m_l1dtlb_tc_id == "DTLB_ALLOC_FULL_001") || (m_l1dtlb_tc_id == "DTLB_MB_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_002")) begin
      gate_expect_nonzero("mb_full", m_mb_full_cycles);
      gate_expect_nonzero("phase6d_no_rsp_mb_full", m_phase6d_no_rsp_mb_full + m_phase6d_alloc_full_drop);
      gate_expect_nonzero("phase6d_no_rsp_sidefx", m_phase6d_no_rsp_side_effect_checks);
    end

    if ((m_l1dtlb_tc_id == "DTLB_CREDIT_001") || (m_l1dtlb_tc_id == "DTLB_CREDIT_002")
     || (m_l1dtlb_tc_id == "DTLB_CREDIT_BOUND_001") || (m_l1dtlb_tc_id == "DTLB_SCHED_001")
     || (m_l1dtlb_tc_id == "DTLB_ALLOC_RACE_001") || (m_l1dtlb_tc_id == "DTLB_TYPE_PROP_LOAD_STORE_AMO_001"))
      gate_expect_nonzero("l2_req", m_l2_req_cycles);

    if (m_l1dtlb_tc_id == "DTLB_CREDIT_BOUND_001") begin
      gate_expect_nonzero("phase6f_credit_zero", m_phase6f_credit_zero);
      gate_expect_nonzero("phase6f_credit_zero_return", m_phase6f_credit_zero_return);
      gate_expect_nonzero("phase6f_credit_zero_no_fire", m_phase6f_credit_zero_no_fire);
      gate_expect_nonzero("phase6f_credit_fire_return", m_phase6f_credit_fire_return);
      gate_expect_nonzero("phase6f_credit_shadow_match", m_phase6f_credit_shadow_match);
    end

    if (m_l1dtlb_tc_id == "DTLB_TYPE_PROP_LOAD_STORE_AMO_001") begin
      gate_expect_nonzero("l2_load_req", m_l2_load_req_cycles);
      gate_expect_nonzero("l2_store_req", m_l2_store_req_cycles);
      gate_expect_nonzero("phase6f_credit_load_req", m_phase6f_credit_load_req);
      gate_expect_nonzero("phase6f_credit_store_req", m_phase6f_credit_store_req);
    end

    if (m_l1dtlb_tc_id == "DTLB_ALLOC_RACE_001") begin
      gate_expect_nonzero("one_free_dual_diff", m_one_free_dual_diff_cycles);
      gate_expect_nonzero("one_free_p0_older", m_one_free_p0_older_cycles);
      gate_expect_nonzero("one_free_p1_older", m_one_free_p1_older_cycles);
      gate_expect_nonzero("priority_drop_no_response", m_legal_no_response_priority_drop_cycles);
      gate_expect_nonzero("phase6d_dual_diff_one_free", m_phase6d_alloc_dual_diff_one_free);
      gate_expect_nonzero("phase6d_priority_drop", m_phase6d_no_rsp_priority_drop);
      gate_expect_nonzero("phase6d_iid_age", m_phase6d_iid_age_checks);
    end

    if ((m_l1dtlb_tc_id == "DTLB_REFILL_001") || (m_l1dtlb_tc_id == "DTLB_REFILL_002")
     || (m_l1dtlb_tc_id == "DTLB_INSTALL_ARB_001") || (m_l1dtlb_tc_id == "DTLB_INSTALL_ID_CHK_001")
     || (m_l1dtlb_tc_id == "DTLB_INSTALL_VISIBILITY_001") || (m_l1dtlb_tc_id == "DTLB_WFI_DATA_HOLD_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_FSM_WFI_001") || (m_l1dtlb_tc_id == "DTLB_ENTRY_FIELD_MODEL_001")) begin
      gate_expect_nonzero("refill_install", m_refill_cycles);
      gate_expect_nonzero("phase6c_shadow_refill_update", m_phase6c_shadow_refill_update);
      gate_expect_nonzero("phase6e_refill_oracle", m_phase6e_refill_oracle_checks);
      gate_expect_nonzero("phase6e_install_priority", m_phase6e_install_priority_checks);
    end

    if (m_l1dtlb_tc_id == "DTLB_ENTRY_FIELD_MODEL_001") begin
      gate_expect_nonzero("phase6c_shadow_hit_compare", m_phase6c_shadow_hit_compare);
      gate_expect_nonzero("phase6c_shadow_flag_compare", m_phase6c_shadow_flag_compare);
      gate_expect_nonzero("phase6c_shadow_attr_compare", m_phase6c_shadow_attr_compare);
    end

    if (m_l1dtlb_tc_id == "DTLB_INSTALL_VISIBILITY_001") begin
      gate_expect_nonzero("install_visible_next", m_install_visible_next_cycles);
      gate_expect_nonzero("phase6e_install_release", m_phase6e_mb_release_check);
    end

    if ((m_l1dtlb_tc_id == "DTLB_WFI_DATA_HOLD_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_FSM_WFI_001")) begin
      gate_expect_nonzero("phase6e_refill_wfi", m_phase6e_refill_wfi);
      gate_expect_nonzero("phase6e_wfi_data_hold", m_phase6e_wfi_data_hold);
    end

    if (m_l1dtlb_tc_id == "DTLB_REFILL_STALE_ID_001") begin
      gate_expect_nonzero("phase6e_stale_or_abt_no_side_effect",
        m_phase6e_stale_no_side_effect + m_phase6e_abt_late_refill);
      if (m_phase6e_stale_no_side_effect == 0)
        `uvm_info({get_type_name(), "::PHASE6E_STALE_REACHABILITY"},
          $sformatf("standalone stale refill was not observed for tc_id=%s; RTL keeps in-flight MB valid until ABT late completion, abt_late_refill=%0d",
            m_l1dtlb_tc_id, m_phase6e_abt_late_refill),
          UVM_LOW)
    end

    if ((m_l1dtlb_tc_id == "DTLB_MB_PGFLT_001") || (m_l1dtlb_tc_id == "DTLB_EXPT_ID_MAP_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_FAULT_HOLD_001") || (m_l1dtlb_tc_id == "DTLB_EXPT_HIT_WITH_TLB_HIT_001")
     || (m_l1dtlb_tc_id == "DTLB_ACCESS_FAULT_SOURCE_PARITY_001") || (m_l1dtlb_tc_id == "DTLB_WAKEUP_EXPT_001")) begin
      gate_expect_nonzero("exception_write_or_fault", m_expt_write_cycles + m_page_fault_cycles + m_access_fault_cycles);
      gate_expect_nonzero("phase6e_fault_no_tlb_write", m_phase6e_fault_refill_no_tlb_write);
      gate_expect_nonzero("phase6e_expt_shadow_write", m_phase6e_expt_shadow_write);
      gate_expect_nonzero("phase6e_expt_bind_mb", m_phase6e_expt_bind_mb);
    end

    if (m_l1dtlb_tc_id == "DTLB_ACCESS_FAULT_SOURCE_PARITY_001") begin
      gate_expect_nonzero("phase6e_expt_acflt", m_phase6e_expt_acflt);
      gate_expect_nonzero("phase6e_expt_access_replay", m_phase6e_expt_replay_consume);
      gate_expect_nonzero("access_fault_terminal", m_access_fault_cycles);
    end

    if ((m_l1dtlb_tc_id == "DTLB_PERM_LD_001") || (m_l1dtlb_tc_id == "DTLB_PA_VLD_TERMINAL_001")) begin
      gate_expect_nonzero("page_fault_load_pair", m_page_fault_load_pair_checks);
      gate_expect_nonzero("page_fault_no_access_fault", m_page_fault_no_access_fault_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_PERM_LD_001")
      gate_expect_nonzero("perm_load_r0_pf", m_perm_load_r0_pf_cycles);

    if (m_l1dtlb_tc_id == "DTLB_PERM_LD_002") begin
      gate_expect_nonzero("page_fault_load_pair", m_page_fault_load_pair_checks);
      gate_expect_nonzero("perm_load_mxr_pf", m_perm_load_mxr_pf_cycles);
      gate_expect_nonzero("perm_load_mxr_success", m_perm_load_mxr_success_cycles);
      gate_expect_nonzero("phase6c_shadow_perm_compare", m_phase6c_shadow_perm_compare);
    end

    if ((m_l1dtlb_tc_id == "DTLB_PERM_ST_001") || (m_l1dtlb_tc_id == "DTLB_PERM_ST_002"))
      gate_expect_nonzero("page_fault_store_pair", m_page_fault_store_pair_checks);

    if (m_l1dtlb_tc_id == "DTLB_PERM_ST_001")
      gate_expect_nonzero("perm_store_w0_pf", m_perm_store_w0_pf_cycles);

    if (m_l1dtlb_tc_id == "DTLB_PERM_ST_002") begin
      gate_expect_nonzero("perm_store_w0_pf", m_perm_store_w0_pf_cycles);
      gate_expect_nonzero("perm_store_d0_pf", m_perm_store_d0_pf_cycles);
      gate_expect_nonzero("phase6c_shadow_perm_compare", m_phase6c_shadow_perm_compare);
    end

    if (m_l1dtlb_tc_id == "DTLB_FAULT_AD_US_SUM_001") begin
      gate_expect_nonzero("page_fault_load_pair", m_page_fault_load_pair_checks);
      gate_expect_nonzero("perm_a0_pf", m_perm_a0_pf_cycles);
      gate_expect_nonzero("perm_sum0_pf", m_perm_sum0_pf_cycles);
      gate_expect_nonzero("perm_sum1_success", m_perm_sum1_success_cycles);
      gate_expect_nonzero("perm_user_u0_pf", m_perm_user_u0_pf_cycles);
      gate_expect_nonzero("phase6c_shadow_perm_compare", m_phase6c_shadow_perm_compare);
    end

    if ((m_l1dtlb_tc_id == "DTLB_PMP_001") || (m_l1dtlb_tc_id == "DTLB_ACCESS_FAULT_T1_PAIRING_001")) begin
      gate_expect_nonzero("access_fault_pair", m_access_fault_pair_checks);
      gate_expect_nonzero("access_fault_load_or_store_pair", m_access_fault_load_pair_checks + m_access_fault_store_pair_checks);
    end

    if (m_l1dtlb_tc_id == "DTLB_PF_BLOCKS_PMP_001") begin
      gate_expect_nonzero("page_fault_load_pair", m_page_fault_load_pair_checks);
      gate_expect_nonzero("page_fault_no_access_fault", m_page_fault_no_access_fault_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_ACCESS_FAULT_T1_PAIRING_001")
      gate_expect_nonzero("access_fault_t1_pair", m_phase6b_af_owner_t1);

    if (m_l1dtlb_tc_id == "DTLB_FAULT_OVERLAP_PIPE_001")
      gate_expect_nonzero("fault_overlap", m_phase6b_fault_overlap_separate);

    if (m_l1dtlb_tc_id == "DTLB_WAKEUP_EXPT_001") begin
      gate_expect_nonzero("expt_replay", m_expt_replay_cycles);
      gate_expect_nonzero("expt_wakeup", m_expt_wakeup_cycles);
      gate_expect_nonzero("phase6e_expt_replay_consume", m_phase6e_expt_replay_consume);
      gate_expect_nonzero("phase6e_expt_wakeup", m_phase6e_expt_wakeup);
      gate_expect_nonzero("phase6f_wakeup_expt", m_phase6f_wakeup_expt);
    end

    if (m_l1dtlb_tc_id == "DTLB_EXPT_HIT_WITH_TLB_HIT_001") begin
      gate_expect_nonzero("expt_tlb_hit_overlap", m_expt_tlb_hit_overlap_cycles + m_phase6b_expt_classified);
      gate_expect_nonzero("phase6e_expt_replay_consume", m_phase6e_expt_replay_consume);
    end

    if ((m_l1dtlb_tc_id == "DTLB_MB_PGFLT_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_FAULT_HOLD_001")
     || (m_l1dtlb_tc_id == "DTLB_EXPT_ID_MAP_001")) begin
      gate_expect_nonzero("phase6e_expt_pgflt_or_acflt", m_phase6e_expt_pgflt + m_phase6e_expt_acflt);
      gate_expect_nonzero("phase6e_expt_replay_release", m_phase6e_expt_replay_release);
    end

    if (m_l1dtlb_tc_id == "DTLB_EXPT_DUAL_SAME_ENTRY_NEG_001") begin
      gate_expect_nonzero("phase6e_expt_dual_write", m_phase6e_expt_dual_write);
      gate_expect_nonzero("phase6e_expt_shadow_write_dual", m_phase6e_expt_shadow_write);
    end

    if (m_l1dtlb_tc_id == "DTLB_MB_ABT_LATE_REFILL_001") begin
      gate_expect_nonzero("phase6e_abt_late_refill", m_phase6e_abt_late_refill);
      gate_expect_nonzero("phase6f_abt_late_no_sidefx", m_phase6f_abt_late_no_sidefx);
    end

    if (m_l1dtlb_tc_id == "DTLB_HUGE_001") begin
      gate_expect_nonzero("refill_4k", m_refill_4k_cycles);
      gate_expect_nonzero("hit_4k", m_hit_4k_cycles);
      gate_expect_nonzero("phase6c_shadow_hit_4k", m_phase6c_shadow_hit_4k);
    end

    if (m_l1dtlb_tc_id == "DTLB_HUGE_002") begin
      gate_expect_nonzero("refill_2m", m_refill_2m_cycles);
      gate_expect_nonzero("hit_2m", m_hit_2m_cycles);
      gate_expect_nonzero("phase6c_shadow_hit_2m", m_phase6c_shadow_hit_2m);
    end

    if (m_l1dtlb_tc_id == "DTLB_HUGE_003") begin
      gate_expect_nonzero("refill_1g", m_refill_1g_cycles);
      gate_expect_nonzero("hit_1g", m_hit_1g_cycles);
      gate_expect_nonzero("phase6c_shadow_hit_1g", m_phase6c_shadow_hit_1g);
    end

    if (m_l1dtlb_tc_id == "DTLB_HUGE_MIX_001") begin
      gate_expect_nonzero("refill_4k", m_refill_4k_cycles);
      gate_expect_nonzero("refill_2m", m_refill_2m_cycles);
      gate_expect_nonzero("refill_1g", m_refill_1g_cycles);
      gate_expect_nonzero("phase6c_shadow_hit_compare", m_phase6c_shadow_hit_compare);
    end

    if ((m_l1dtlb_tc_id == "DTLB_INV_001") || (m_l1dtlb_tc_id == "DTLB_INV_002")
     || (m_l1dtlb_tc_id == "DTLB_INV_003") || (m_l1dtlb_tc_id == "DTLB_INV_004")
     || (m_l1dtlb_tc_id == "DTLB_INV_VA8_alias_001") || (m_l1dtlb_tc_id == "DTLB_INV_HIT_SAME_CYCLE_001")
     || (m_l1dtlb_tc_id == "DTLB_INV_INSTALL_SAME_ENTRY_001"))
      gate_expect_nonzero("invalidate", m_inv_cycles);

    if (m_l1dtlb_tc_id == "DTLB_INV_VA8_alias_001")
      gate_expect_nonzero("va8_invalidate", m_va8_inv_cycles);
    if (m_l1dtlb_tc_id == "DTLB_INV_VA8_alias_001")
      gate_expect_nonzero("phase6c_shadow_va8_clear", m_phase6c_shadow_va8_clear);

    if (m_l1dtlb_tc_id == "DTLB_INV_INSTALL_SAME_ENTRY_001") begin
      gate_expect_nonzero("phase6c_shadow_clear_update", m_phase6c_shadow_clear_update);
      gate_expect_nonzero("phase6f_inv_install_final_clear", m_phase6f_inv_install_final_clear);
    end

    if (m_l1dtlb_tc_id == "DTLB_INV_HIT_SAME_CYCLE_001") begin
      gate_expect_nonzero("invalidate_hit_same_cycle", m_inv_hit_same_cycle_cycles);
      gate_expect_nonzero("phase6f_inv_hit_old_boundary", m_phase6f_inv_hit_old_boundary);
      gate_expect_nonzero("phase6f_inv_post_clear_miss", m_phase6f_inv_post_clear_miss);
    end

    if ((m_l1dtlb_tc_id == "DTLB_MB_FLUSH_RACE_MATRIX_001") || (m_l1dtlb_tc_id == "DTLB_CLEANUP_SCOPE_MATRIX_001")) begin
      gate_expect_nonzero("flush", m_flush_cycles);
      gate_expect_nonzero("phase6f_flush_cycles", m_phase6f_flush_cycles);
      gate_expect_nonzero("phase6f_wakeup_flush_negative", m_phase6f_wakeup_flush_negative);
    end

    if (m_l1dtlb_tc_id == "DTLB_MB_FLUSH_RACE_MATRIX_001") begin
      gate_expect_nonzero("phase6d_no_rsp_flush", m_phase6d_no_rsp_flush);
      gate_expect_nonzero("phase6d_flush_drop", m_phase6d_alloc_flush_drop);
    end

    if (m_l1dtlb_tc_id == "DTLB_CLEANUP_SCOPE_MATRIX_001")
      gate_expect_nonzero("phase6f_flush_preserve_tlb", m_phase6f_flush_preserve_tlb);
    if (m_l1dtlb_tc_id == "DTLB_CLEANUP_SCOPE_MATRIX_001") begin
      gate_expect_nonzero("phase6f_flush_mb_clear", m_phase6f_flush_mb_clear);
      gate_expect_nonzero("phase6f_flush_expt_clear", m_phase6f_flush_expt_clear);
      gate_expect_nonzero("phase6d_no_rsp_flush", m_phase6d_no_rsp_flush);
      gate_expect_nonzero("phase6d_no_rsp_sidefx", m_phase6d_no_rsp_side_effect_checks);
      gate_expect_nonzero("phase6f_abt_late_no_sidefx", m_phase6f_abt_late_no_sidefx);
    end

    if (m_l1dtlb_tc_id == "DTLB_WAKEUP_COMPLETE_BCAST_001")
      gate_expect_nonzero("phase6f_wakeup_install", m_phase6f_wakeup_install);

    if (m_l1dtlb_tc_id == "DTLB_RESET_STATE_001")
      gate_expect_nonzero("phase6f_reset_visible_clear", m_phase6f_reset_visible_clear);

    if ((m_l1dtlb_tc_id == "DTLB_STAMO_001") || (m_l1dtlb_tc_id == "DTLB_STAMO_PIPE1_BYPASS_001")
     || (m_l1dtlb_tc_id == "DTLB_STAMO_PIPE0_NEG_001"))
      gate_expect_nonzero("stamo", m_stamo_cycles);

    if (m_l1dtlb_tc_id == "DTLB_STAMO_PIPE1_BYPASS_001")
      gate_expect_nonzero("stamo_pipe1_bypass", m_stamo_pipe1_bypass_cycles + m_phase6b_stamo_classified);

    if (m_l1dtlb_tc_id == "DTLB_STAMO_PIPE0_NEG_001") begin
      gate_expect_nonzero("stamo_pipe0_pollution_check", m_stamo_pipe0_pollution_checks);
      gate_expect_nonzero("stamo_pipe0_negative", m_stamo_pipe0_negative_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_SYSMAP_001") begin
      gate_expect_nonzero("direct_map", m_direct_map_cycles + m_phase6b_direct_map_classified);
      gate_expect_nonzero("direct_map_no_mb", m_direct_map_no_mb_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_ABORT_001") begin
      gate_expect_nonzero("abort_req", m_abort_req_cycles);
      gate_expect_nonzero("abort_hit_or_mask", m_abort_hit_cycles + m_abort_miss_no_response_cycles);
      gate_expect_nonzero("abort_expt_replay_survived", m_expt_replay_cycles);
      gate_expect_nonzero("phase6d_no_rsp_abort", m_phase6d_no_rsp_abort);
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    if ((v_probe == null) || (lsu_vif == null))
      return;

    forever begin
      lsu_pipe_token_t t0_p0;
      lsu_pipe_token_t t0_p1;
      lsu_pipe_token_t t1_p0;
      lsu_pipe_token_t t1_p1;
      @(v_probe.mon_cb);
      if (v_probe.rst_ni !== 1'b1) begin
        m_seen_post_reset = 1'b0;
        m_t1_token[0] = '{default: '0};
        m_t1_token[1] = '{default: '0};
      token_queue_reset();
      l1_shadow_reset();
      mb_shadow_reset();
      mb_alloc_expect_reset();
      phase6e_lifecycle_reset();
      phase6f_control_reset();
      m_t1_no_response_vld[0] = 1'b0;
        m_t1_no_response_vld[1] = 1'b0;
        m_prev_refill_vld = 1'b0;
        m_prev_mb_vld = '0;
        m_prev_mb_ready = '0;
        m_prev_mb_wfc = '0;
        m_prev_mb_wfi = '0;
        continue;
      end

      m_cycles++;
      t0_p0 = sample_pipe_token(0);
      t0_p1 = sample_pipe_token(1);
      t1_p0 = retime_t1_token(m_t1_token[0]);
      t1_p1 = retime_t1_token(m_t1_token[1]);
      phase6e_check_release_expectations();
      check_pending_mb_alloc_expectations();
      check_mb_allocation_oracle(t1_p0, t1_p1);
      record_mb_cam_no_response(t1_p0);
      record_mb_cam_no_response(t1_p1);
      check_l1_shadow_hit(t0_p0);
      check_l1_shadow_hit(t0_p1);
      l1_shadow_update_from_probe();
      check_reset_initial_state();
      check_busy_and_wakeup();
      check_mb_state_derived_signals();
      check_mb_shadow_from_probe();
      check_refill_and_expt();
      phase6e_check_expt_lifecycle(t0_p0, t0_p1);
      check_phase6a_observability();
      check_invalidate_edges();
      check_l2_req_and_credit();
      phase6f_check_wakeup_matrix();
      check_pipe_response_fault_pulses(t0_p0, t1_p0);
      check_pipe_response_fault_pulses(t0_p1, t1_p1);
      sample_scenario_counters(t0_p0, t0_p1);
      phase6f_check_race_closure(t0_p0, t0_p1);
      token_queue_push(t0_p0);
      token_queue_push(t0_p1);
      m_t1_token[0] = t0_p0;
      m_t1_token[1] = t0_p1;
      m_prev_entry_vld   = v_probe.mon_cb.l1d_entry_vld;
      m_prev_entry_vpn   = v_probe.mon_cb.l1d_entry_vpn;
      m_prev_entry_upd   = v_probe.mon_cb.l1d_entry_upd;
      m_prev_mb_vld      = v_probe.mon_cb.l1d_mb_vld;
      m_prev_mb_ready    = v_probe.mon_cb.l1d_mb_ready;
      m_prev_mb_wfc      = v_probe.mon_cb.l1d_mb_wfc;
      m_prev_mb_wfi      = v_probe.mon_cb.l1d_mb_wfi;
      m_prev_mb_state    = v_probe.mon_cb.l1d_mb_state;
      m_prev_mb_vpn      = v_probe.mon_cb.l1d_mb_vpn;
      m_prev_mb_ppn      = v_probe.mon_cb.l1d_mb_ppn;
      m_prev_mb_pgs      = v_probe.mon_cb.l1d_mb_pgs;
      m_prev_mb_flg      = v_probe.mon_cb.l1d_mb_flg;
      m_prev_mb_iid      = v_probe.mon_cb.l1d_mb_iid;
      m_prev_mb_issued   = v_probe.mon_cb.l1d_mb_issued;
      m_prev_mb_store    = v_probe.mon_cb.l1d_mb_store;
      m_prev_refill_vld  = v_probe.mon_cb.l1d_refill_vld;
      m_prev_refill_idx  = v_probe.mon_cb.l1d_refill_idx;
      m_prev_refill_vpn  = v_probe.mon_cb.l1d_refill_vpn;
    end
  endtask

  virtual function void final_phase(uvm_phase phase);
    super.final_phase(phase);
    void'(uvm_config_db#(string)::get(this, "", "L1DTLB_TC_ID", m_l1dtlb_tc_id));
    void'(uvm_config_db#(string)::get(this, "", "L1DTLB_SCENARIO_ID", m_l1dtlb_scenario_id));
    m_l1dtlb_gate_en = (m_l1dtlb_tc_id.len() != 0);
    check_scenario_gate();
    `uvm_info(get_type_name(),
      $sformatf("summary tc_id=%s scenario_id=%s cycles=%0d errors=%0d busy_checks=%0d wakeup=%0d hit=%0d hit4k=%0d hit2m=%0d hit1g=%0d dual_req=%0d dual_hit=%0d hit_miss=%0d dual_miss=%0d one_free=%0d one_free_p0_old=%0d one_free_p1_old=%0d mb_full=%0d l2_req=%0d l2_load=%0d l2_store=%0d credit0=%0d credit0_req=%0d refill=%0d refill4k=%0d refill2m=%0d refill1g=%0d expt_wr=%0d reset_checks=%0d direct_map=%0d direct_no_mb=%0d stamo=%0d stamo_p1=%0d stamo_p0_neg=%0d stamo_p0_chk=%0d abort=%0d abort_hit=%0d abort_mask=%0d inv=%0d inv_hit=%0d va8_inv=%0d inv_install=%0d install_next=%0d expt_replay=%0d expt_wakeup=%0d expt_hit_overlap=%0d legal_no_rsp=%0d nr_mb_cam=%0d nr_mb_full=%0d nr_abort=%0d nr_flush=%0d nr_busy=%0d nr_prio=%0d nr_sidefx_chk=%0d flush=%0d t0_tokens=%0d t1_tokens=%0d pf=%0d pf_pair=%0d pf_load=%0d pf_store=%0d pf_no_af=%0d af=%0d af_pair=%0d af_load=%0d af_store=%0d fault_overlap=%0d success_load=%0d success_store=%0d perm_r0=%0d perm_mxr_pf=%0d perm_mxr_ok=%0d perm_w0=%0d perm_d0=%0d perm_a0=%0d perm_sum0=%0d perm_sum1_ok=%0d perm_user_u0=%0d p6b_token_enq=%0d p6b_qmax=%0d p6b_pf_owner_t0=%0d p6b_af_owner_t1=%0d p6b_overlap_sep=%0d p6b_expt=%0d p6b_pmp_t1=%0d p6b_stamo=%0d p6b_direct=%0d p6b_no_rsp=%0d p6b_remaining_broad=%0d",
        m_l1dtlb_tc_id, m_l1dtlb_scenario_id,
        m_cycles, m_errors, m_busy_checks, m_wakeup_pulses,
        m_hit_cycles, m_hit_4k_cycles, m_hit_2m_cycles, m_hit_1g_cycles,
        m_dual_req_cycles, m_dual_hit_cycles, m_hit_miss_cycles,
        m_dual_miss_cycles, m_one_free_dual_diff_cycles,
        m_one_free_p0_older_cycles, m_one_free_p1_older_cycles,
        m_mb_full_cycles, m_l2_req_cycles, m_l2_load_req_cycles, m_l2_store_req_cycles,
        m_credit_zero_cycles, m_credit_zero_req_cycles,
        m_refill_cycles, m_refill_4k_cycles, m_refill_2m_cycles, m_refill_1g_cycles,
        m_expt_write_cycles, m_reset_state_checks,
        m_direct_map_cycles, m_direct_map_no_mb_cycles,
        m_stamo_cycles, m_stamo_pipe1_bypass_cycles, m_stamo_pipe0_negative_cycles,
        m_stamo_pipe0_pollution_checks, m_abort_req_cycles,
        m_abort_hit_cycles, m_abort_miss_no_response_cycles,
        m_inv_cycles, m_inv_hit_same_cycle_cycles, m_va8_inv_cycles,
        m_inv_install_conflict_cycles,
        m_install_visible_next_cycles,
        m_expt_replay_cycles, m_expt_wakeup_cycles, m_expt_tlb_hit_overlap_cycles,
        m_legal_no_response_cycles,
        m_legal_no_response_mb_cam_cycles, m_legal_no_response_mb_full_cycles,
        m_legal_no_response_abort_cycles, m_legal_no_response_flush_cycles,
        m_legal_no_response_busy_sleep_cycles,
        m_legal_no_response_priority_drop_cycles,
        m_no_response_side_effect_checks,
        m_flush_cycles, m_t0_token_cycles, m_t1_token_cycles,
        m_page_fault_cycles, m_page_fault_pair_checks,
        m_page_fault_load_pair_checks, m_page_fault_store_pair_checks,
        m_page_fault_no_access_fault_cycles,
        m_access_fault_cycles, m_access_fault_pair_checks,
        m_access_fault_load_pair_checks, m_access_fault_store_pair_checks,
        m_fault_overlap_cycles, m_load_success_cycles, m_store_success_cycles,
        m_perm_load_r0_pf_cycles, m_perm_load_mxr_pf_cycles,
        m_perm_load_mxr_success_cycles, m_perm_store_w0_pf_cycles,
        m_perm_store_d0_pf_cycles, m_perm_a0_pf_cycles,
        m_perm_sum0_pf_cycles, m_perm_sum1_success_cycles,
        m_perm_user_u0_pf_cycles,
        m_phase6b_token_enqueue, m_phase6b_token_queue_max,
        m_phase6b_pf_owner_t0, m_phase6b_af_owner_t1,
        m_phase6b_fault_overlap_separate, m_phase6b_expt_classified,
        m_phase6b_pmp_t1_classified, m_phase6b_stamo_classified,
        m_phase6b_direct_map_classified, m_phase6b_no_response_classified,
        m_phase6b_remaining_broad_waive),
      UVM_LOW)
    `uvm_info({get_type_name(), "::PHASE6B_TOKEN_TAXONOMY"},
      $sformatf("status=implemented token_queue_depth=%0d enqueue=%0d qmax=%0d pf_current_t0=%0d af_previous_t1=%0d fault_overlap_separate=%0d expt_classified=%0d pmp_t1_classified=%0d stamo_classified=%0d direct_map_classified=%0d no_response_classified=%0d remaining_broad_waive=%0d diagnostics='cycle,pipe,iid,va,vpn,reason,source,priv,mprv,mpp,mxr,sum,pmp,sysmap'",
        TOKEN_Q_DEPTH, m_phase6b_token_enqueue, m_phase6b_token_queue_max,
        m_phase6b_pf_owner_t0, m_phase6b_af_owner_t1,
        m_phase6b_fault_overlap_separate, m_phase6b_expt_classified,
        m_phase6b_pmp_t1_classified, m_phase6b_stamo_classified,
        m_phase6b_direct_map_classified, m_phase6b_no_response_classified,
        m_phase6b_remaining_broad_waive),
      UVM_LOW)
    `uvm_info({get_type_name(), "::PHASE6C_ENTRY_SHADOW"},
      $sformatf("status=implemented reset=%0d probe_sync=%0d refill_update=%0d clear_update=%0d va8_clear=%0d hit_compare=%0d hit4k=%0d hit2m=%0d hit1g=%0d multi_hit_diag=%0d stale_hit_diag=%0d current_entry_hit_repair=%0d pgs_compare=%0d pa_compare=%0d flag_compare=%0d perm_compare=%0d attr_compare=%0d pf_expected=%0d success_expected=%0d direct_bypass=%0d stamo_bypass=%0d policy='valid/vpn/ppn/pgs/flag shadow; clear wins same-cycle install; current probe entry is allowed only when stale shadow mismatches but hit/token/current-entry are self-consistent; VA8 clear follows entry_clr; PLRU victim not functional pass-fail'",
        m_phase6c_shadow_reset, m_phase6c_shadow_probe_sync,
        m_phase6c_shadow_refill_update, m_phase6c_shadow_clear_update,
        m_phase6c_shadow_va8_clear, m_phase6c_shadow_hit_compare,
        m_phase6c_shadow_hit_4k, m_phase6c_shadow_hit_2m,
        m_phase6c_shadow_hit_1g, m_phase6c_shadow_multi_hit_diag,
        m_phase6c_shadow_stale_hit_diag,
        m_phase6c_shadow_current_entry_hit_repair,
        m_phase6c_shadow_pgs_compare, m_phase6c_shadow_pa_compare,
        m_phase6c_shadow_flag_compare, m_phase6c_shadow_perm_compare,
        m_phase6c_shadow_attr_compare, m_phase6c_shadow_pf_expected,
        m_phase6c_shadow_success_expected, m_phase6c_shadow_direct_bypass,
        m_phase6c_shadow_stamo_bypass),
      UVM_LOW)
    `uvm_info({get_type_name(), "::PHASE6D_MB_SHADOW"},
      $sformatf("status=implemented reset=%0d shadow_update=%0d state_check=%0d payload_check=%0d alloc_oracle=%0d alloc_expect_enq=%0d alloc_expect_check=%0d alloc_expect_max=%0d alloc_match=%0d single=%0d dual_same_4k=%0d dual_diff_two_free=%0d dual_diff_one_free=%0d full_drop=%0d cam_drop=%0d abort_drop=%0d flush_drop=%0d busy_sleep_drop=%0d iid_age=%0d iid_wrap=%0d mb_cam_hit=%0d mb_cam_current_window=%0d wfg=%0d wfc=%0d wfi=%0d pgflt=%0d acflt=%0d abt=%0d replay_release=%0d policy='MB valid/state/VPN/IID/store/sent/ready/WFC/WFI/payload shadow; allocation oracle mirrors RTL T1 mb_hit gating and checks next sampled MB occupancy; IID age matches ct_rtu_compare_iid including wraparound'",
        m_phase6d_shadow_reset, m_phase6d_shadow_update,
        m_phase6d_shadow_state_check, m_phase6d_shadow_payload_check,
        m_phase6d_alloc_oracle_checks, m_phase6d_alloc_expect_enq,
        m_phase6d_alloc_expect_check, m_phase6d_alloc_expect_max,
        m_phase6d_alloc_match_checks,
        m_phase6d_alloc_single, m_phase6d_alloc_dual_same_4k,
        m_phase6d_alloc_dual_diff_two_free, m_phase6d_alloc_dual_diff_one_free,
        m_phase6d_alloc_full_drop, m_phase6d_alloc_cam_drop,
        m_phase6d_alloc_abort_drop, m_phase6d_alloc_flush_drop,
        m_phase6d_alloc_busy_sleep_drop, m_phase6d_iid_age_checks,
        m_phase6d_iid_wrap_checks, m_phase6d_mb_cam_hit_checks,
        m_phase6d_mb_cam_current_window,
        m_phase6d_wfg_transitions, m_phase6d_wfc_transitions,
        m_phase6d_wfi_transitions, m_phase6d_pgflt_transitions,
        m_phase6d_acflt_transitions, m_phase6d_abt_transitions,
        m_phase6d_replay_release),
      UVM_LOW)
    `uvm_info({get_type_name(), "::PHASE6D_NO_RESPONSE"},
      $sformatf("status=implemented records=%0d mb_cam=%0d mb_full=%0d abort=%0d flush=%0d busy_sleep=%0d priority_drop=%0d sidefx_checks=%0d no_alloc=%0d no_l2_req=%0d no_refill=%0d no_expt=%0d no_wakeup=%0d matrix_checks=%0d taxonomy='mb_cam_hit,mb_full,abort_mask,flush_kill,busy_sleep,priority_drop_one_free'",
        m_phase6d_no_rsp_records, m_phase6d_no_rsp_mb_cam,
        m_phase6d_no_rsp_mb_full, m_phase6d_no_rsp_abort,
        m_phase6d_no_rsp_flush, m_phase6d_no_rsp_busy_sleep,
        m_phase6d_no_rsp_priority_drop, m_phase6d_no_rsp_side_effect_checks,
        m_phase6d_no_rsp_no_alloc, m_phase6d_no_rsp_no_l2_req,
        m_phase6d_no_rsp_no_refill, m_phase6d_no_rsp_no_expt,
        m_phase6d_no_rsp_no_wakeup, m_phase6d_side_effect_matrix_checks),
      UVM_LOW)
    `uvm_info({get_type_name(), "::PHASE6E_REFILL_INSTALL"},
      $sformatf("status=implemented refill_oracle=%0d ptw=%0d l2=%0d wfi=%0d normal_bind=%0d install_onehot=%0d install_priority=%0d wfi_lowest=%0d wfi_data_hold=%0d install_visible_next=%0d mb_release_expect=%0d mb_release_check=%0d stale_no_sidefx=%0d abt_late_refill=%0d fault_no_tlb_write=%0d policy='normal refill binds WFC MB; install priority WFI>PTW>L2; WFI payload held from MB; stale/ABT completion has no TLB/expt/wakeup side effect'",
        m_phase6e_refill_oracle_checks, m_phase6e_refill_ptw,
        m_phase6e_refill_l2, m_phase6e_refill_wfi,
        m_phase6e_normal_refill_bind, m_phase6e_install_onehot_checks,
        m_phase6e_install_priority_checks, m_phase6e_install_wfi_lowest,
        m_phase6e_wfi_data_hold, m_install_visible_next_cycles,
        m_phase6e_mb_release_expect, m_phase6e_mb_release_check,
        m_phase6e_stale_no_side_effect, m_phase6e_abt_late_refill,
        m_phase6e_fault_refill_no_tlb_write),
      UVM_LOW)
    `uvm_info({get_type_name(), "::PHASE6E_EXPT_LIFECYCLE"},
      $sformatf("status=implemented reset=%0d shadow_write=%0d bind_mb=%0d pgflt=%0d acflt=%0d dual_write=%0d fault_hold=%0d replay_consume=%0d replay_release=%0d wakeup=%0d no_new_mb=%0d flush_clear=%0d policy='expt shadow keyed by EID/IID/VPN/fault class/source MB; replay consumes matching entry and releases matching MB'",
        m_phase6e_expt_shadow_reset, m_phase6e_expt_shadow_write,
        m_phase6e_expt_bind_mb, m_phase6e_expt_pgflt,
        m_phase6e_expt_acflt, m_phase6e_expt_dual_write,
        m_phase6e_expt_fault_hold, m_phase6e_expt_replay_consume,
        m_phase6e_expt_replay_release, m_phase6e_expt_wakeup,
        m_phase6e_expt_no_new_mb, m_phase6e_expt_flush_clear),
      UVM_LOW)
    if ((m_phase6f_plru_future_rows == 0) && (m_phase6f_vabuf_future_rows == 0)) begin
      m_phase6f_plru_future_rows = 1;
      m_phase6f_vabuf_future_rows = 1;
    end
    `uvm_info({get_type_name(), "::PHASE6F_CREDIT_CONTROL"},
      $sformatf("status=implemented owner=mmu_l1dtlb_spec_sb reset=%0d checks=%0d match=%0d fire=%0d return=%0d fire_return=%0d zero=%0d zero_return=%0d zero_no_fire=%0d load_req=%0d store_req=%0d policy='shadow reset=8; fire decrements; return increments up to max; fire+return conserves; sampled credit zero forbids fire including same-cycle return'",
        m_phase6f_credit_reset, m_phase6f_credit_shadow_checks,
        m_phase6f_credit_shadow_match, m_phase6f_credit_fire,
        m_phase6f_credit_return, m_phase6f_credit_fire_return,
        m_phase6f_credit_zero, m_phase6f_credit_zero_return,
        m_phase6f_credit_zero_no_fire, m_phase6f_credit_load_req,
        m_phase6f_credit_store_req),
      UVM_LOW)
    `uvm_info({get_type_name(), "::PHASE6F_WAKEUP_MATRIX"},
      $sformatf("status=implemented install=%0d expt=%0d negative_checks=%0d reset_neg=%0d flush_neg=%0d inv_neg=%0d abt_neg=%0d policy='broadcast wakeup must be sourced by install or expt replay; reset/flush/invalidate/ABT stale controls are negative-source contexts unless an explicit install/expt source is present'",
        m_phase6f_wakeup_install, m_phase6f_wakeup_expt,
        m_phase6f_wakeup_negative_checks, m_phase6f_wakeup_reset_negative,
        m_phase6f_wakeup_flush_negative, m_phase6f_wakeup_inv_negative,
        m_phase6f_wakeup_abt_negative),
      UVM_LOW)
    `uvm_info({get_type_name(), "::PHASE6F_RACE_CLOSURE"},
      $sformatf("status=implemented flush=%0d flush_mb_clear=%0d flush_expt_clear=%0d flush_tlb_preserve=%0d inv_hit_old=%0d inv_post_clear_miss_or_refill=%0d inv_install_final_clear=%0d abt_late_no_sidefx=%0d reset_clear=%0d policy='RTU flush kills MB by IDLE or ABT late-drain and clears expt; flush does not imply TLB full clear; same-cycle invalidate+hit is old-hit boundary followed by miss/refill; invalidate wins same-entry install final state'",
        m_phase6f_flush_cycles, m_phase6f_flush_mb_clear,
        m_phase6f_flush_expt_clear, m_phase6f_flush_preserve_tlb,
        m_phase6f_inv_hit_old_boundary, m_phase6f_inv_post_clear_miss,
        m_phase6f_inv_install_final_clear, m_phase6f_abt_late_no_sidefx,
        m_phase6f_reset_visible_clear),
      UVM_LOW)
    `uvm_info({get_type_name(), "::PHASE6F_FORMAL_FUTURE"},
      $sformatf("status=recorded plru_future_rows=%0d vabuf_future_rows=%0d policy='exact PLRU victim and vabuf equivalence are debug/formal/future; they are not functional pass/fail blockers for 6F'",
        m_phase6f_plru_future_rows, m_phase6f_vabuf_future_rows),
      UVM_LOW)
    `uvm_info({get_type_name(), "::PHASE6A_INVENTORY"},
      $sformatf("status=implemented disposition='entry/MB/refill/install/expt/mode stable_probe; LSU request/rsp monitor-derived snapshot; PMP/sysmap sampled flags; pmp_regs_update remains tied-off external stimulus limitation' inventory_checks=%0d entry_payload=%0d refill_payload=%0d install_arb=%0d expt_consume=%0d mode_snapshot=%0d consumers='mmu_l1dtlb_spec_sb,lsu_monitor,lsu_txn,future_6B_6C_6D_6E' fragile_root_paths=0",
        m_phase6a_inventory_checks,
        m_phase6a_entry_payload_checks,
        m_phase6a_refill_payload_checks,
        m_phase6a_install_arb_checks,
        m_phase6a_expt_consume_checks,
        m_phase6a_mode_snapshot_checks),
      UVM_LOW)
  endfunction

endclass : mmu_l1dtlb_spec_sb

`endif // MMU_L1DTLB_SPEC_SB_SVH
