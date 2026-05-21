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
  } lsu_pipe_token_t;

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

  logic [15:0] m_prev_entry_vld;
  logic [15:0][26:0] m_prev_entry_vpn;
  logic [15:0] m_prev_entry_upd;
  logic [7:0] m_prev_mb_vld;
  bit m_prev_refill_vld;
  logic [3:0] m_prev_refill_idx;
  logic [26:0] m_prev_refill_vpn;
  lsu_pipe_token_t m_t1_token[2];
  bit m_t1_no_response_vld[2];
  string m_t1_no_response_reason[2];
  lsu_pipe_token_t m_t1_no_response_token[2];

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

  protected function int unsigned count3(input logic [2:0] v);
    return int'($countones(v));
  endfunction

  protected function logic [15:0] onehot16(input logic [3:0] idx);
    logic [15:0] v;
    v = '0;
    v[idx] = 1'b1;
    return v;
  endfunction

  protected function bit token_vpn_idx(input lsu_pipe_token_t tok, input int unsigned idx);
    logic [26:0] idx_vpn;
    idx_vpn = idx[26:0];
    return !$isunknown(tok.vpn) && (tok.vpn == (L1DTLB_DIR_VPN_BASE + idx_vpn));
  endfunction

  protected function lsu_pipe_token_t sample_pipe_token(input int unsigned pipe);
    lsu_pipe_token_t tok;
    tok = '{default: '0};
    tok.pipe  = pipe;
    tok.cycle = m_cycles;
    if (pipe == 0) begin
      tok.vld          = lsu_vif.monitor_cb.lsu_mmu_va0_vld;
      tok.va           = lsu_vif.monitor_cb.lsu_mmu_va0;
      tok.vpn          = lsu_vif.monitor_cb.lsu_mmu_va0[38:12];
      tok.iid          = lsu_vif.monitor_cb.lsu_mmu_id0;
      tok.abort        = lsu_vif.monitor_cb.lsu_mmu_abort0;
      tok.store        = lsu_vif.monitor_cb.lsu_mmu_st_inst0;
      tok.pa_vld       = lsu_vif.monitor_cb.mmu_lsu_pa0_vld;
      tok.page_fault   = lsu_vif.monitor_cb.mmu_lsu_page_fault0;
      tok.access_fault = lsu_vif.monitor_cb.mmu_lsu_access_fault0;
      tok.hit_vld      = v_probe.mon_cb.l1d_p0_hit_vld;
      tok.miss_vld     = v_probe.mon_cb.l1d_p0_miss_vld;
      tok.mb_hit       = v_probe.mon_cb.l1d_p0_mb_hit;
      tok.expt_match   = v_probe.mon_cb.l1d_p0_expt_match
                       || lsu_vif.monitor_cb.mmu_lsu_dtlb_expt_match0;
      tok.pa           = lsu_vif.monitor_cb.mmu_lsu_pa0;
      tok.hit_pgs      = v_probe.mon_cb.l1d_p0_hit_pgs;
      tok.fin_pa       = v_probe.mon_cb.l1d_p0_fin_pa;
    end else begin
      tok.vld          = lsu_vif.monitor_cb.lsu_mmu_va1_vld;
      tok.va           = lsu_vif.monitor_cb.lsu_mmu_va1;
      tok.vpn          = lsu_vif.monitor_cb.lsu_mmu_va1[38:12];
      tok.iid          = lsu_vif.monitor_cb.lsu_mmu_id1;
      tok.abort        = lsu_vif.monitor_cb.lsu_mmu_abort1;
      tok.store        = lsu_vif.monitor_cb.lsu_mmu_st_inst1;
      tok.pa_vld       = lsu_vif.monitor_cb.mmu_lsu_pa1_vld;
      tok.page_fault   = lsu_vif.monitor_cb.mmu_lsu_page_fault1;
      tok.access_fault = lsu_vif.monitor_cb.mmu_lsu_access_fault1;
      tok.hit_vld      = v_probe.mon_cb.l1d_p1_hit_vld;
      tok.miss_vld     = v_probe.mon_cb.l1d_p1_miss_vld;
      tok.mb_hit       = v_probe.mon_cb.l1d_p1_mb_hit;
      tok.expt_match   = v_probe.mon_cb.l1d_p1_expt_match
                       || lsu_vif.monitor_cb.mmu_lsu_dtlb_expt_match1;
      tok.pa           = lsu_vif.monitor_cb.mmu_lsu_pa1;
      tok.hit_pgs      = v_probe.mon_cb.l1d_p1_hit_pgs;
      tok.fin_pa       = v_probe.mon_cb.l1d_p1_fin_pa;
    end
    return tok;
  endfunction

  protected function string token_s(input lsu_pipe_token_t tok);
    return $sformatf("valid=%0b cycle=%0d pipe=%0d iid=%0d vpn=0x%07h va=0x%016h abort=%0b store=%0b pa_vld=%0b pa=0x%07h pf=%0b af=%0b hit=%0b hit_pgs=0x%0h miss=%0b mb_hit=%0b expt=%0b",
      tok.vld, tok.cycle, tok.pipe, tok.iid, tok.vpn, tok.va, tok.abort,
      tok.store, tok.pa_vld, tok.pa, tok.page_fault, tok.access_fault, tok.hit_vld, tok.hit_pgs,
      tok.miss_vld, tok.mb_hit, tok.expt_match);
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

  protected function void record_legal_no_response(
    input string reason,
    input lsu_pipe_token_t tok,
    input bit check_token
  );
    m_legal_no_response_cycles++;
    if (check_token) begin
      check_no_response_token_side_effect(reason, tok);
      remember_no_response_t1_guard(reason, tok);
    end
    `uvm_info({get_type_name(), "::LEGAL_NO_RSP"},
      $sformatf("reason=%s %s", reason, tok.vld ? token_s(tok) : "global-event"),
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

  protected virtual function void check_reset_initial_state();
    if (m_seen_post_reset)
      return;
    m_seen_post_reset = 1'b1;
    m_reset_state_checks++;
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

  protected virtual function void check_refill_and_expt();
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
  endfunction

  protected virtual function void check_pipe_response_fault_pulses(
    input lsu_pipe_token_t t0,
    input lsu_pipe_token_t t1
  );
    check_no_response_t1_side_effect(t0.pipe, t0, t1);

    if (t0.vld)
      m_t0_token_cycles++;
    if (t1.vld)
      m_t1_token_cycles++;

    if (!$isunknown({t0.page_fault, t0.pa_vld}) && t0.page_fault) begin
      m_page_fault_pair_checks++;
      if (t0.store)
        m_page_fault_store_pair_checks++;
      else
        m_page_fault_load_pair_checks++;
      if (!$isunknown(t0.access_fault) && !t0.access_fault)
        m_page_fault_no_access_fault_cycles++;
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
      m_access_fault_pair_checks++;
      if (t1.vld && t1.store)
        m_access_fault_store_pair_checks++;
      else
        m_access_fault_load_pair_checks++;
      if (!t1.vld || t1.abort) begin
        sb_error("ACCESS_FAULT_T1_OWNER",
          $sformatf("access_fault has no legal previous-cycle T1 owner: T0{%s} T1{%s}",
            token_s(t0), token_s(t1)));
      end
      if (t1.vld && t1.page_fault) begin
        sb_error("FAULT_SAME_TOKEN",
          $sformatf("access_fault belongs to a T1 token that already reported page_fault at T0: T0{%s} T1{%s}",
            token_s(t0), token_s(t1)));
      end
    end

    if (!$isunknown({t0.page_fault, t0.access_fault})
        && t0.page_fault && t0.access_fault) begin
      m_fault_overlap_cycles++;
      if (!(t1.vld && t1.page_fault)) begin
        `uvm_info({get_type_name(), "::FAULT_OVERLAP"},
          $sformatf("legal same-cycle fault overlap with separate T0/T1 owners: T0{%s} T1{%s}",
            token_s(t0), token_s(t1)),
          UVM_HIGH)
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

    if ((p0_req && v_probe.mon_cb.l1d_p0_mb_hit && !v_probe.mon_cb.l1d_p0_hit_vld)
     || (p1_req && v_probe.mon_cb.l1d_p1_mb_hit && !v_probe.mon_cb.l1d_p1_hit_vld)) begin
      m_mb_cam_no_response_cycles++;
    end
    if (p0_req && v_probe.mon_cb.l1d_p0_mb_hit && !v_probe.mon_cb.l1d_p0_hit_vld) begin
      m_legal_no_response_mb_cam_cycles++;
      record_legal_no_response("mb_cam_hit", t0_p0, 1'b1);
    end
    if (p1_req && v_probe.mon_cb.l1d_p1_mb_hit && !v_probe.mon_cb.l1d_p1_hit_vld) begin
      m_legal_no_response_mb_cam_cycles++;
      record_legal_no_response("mb_cam_hit", t0_p1, 1'b1);
    end
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
     || (m_l1dtlb_tc_id == "DTLB_CONCURRENT_001") || (m_l1dtlb_tc_id == "DTLB_DUAL_HIT_MUX_001"))
      gate_expect_nonzero("hit_cycle", m_hit_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_HIT_MISS_CONCURRENT_001") || (m_l1dtlb_tc_id == "DTLB_CONCURRENT_002"))
      gate_expect_nonzero("hit_miss_cycle", m_hit_miss_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_ALLOC_001") || (m_l1dtlb_tc_id == "DTLB_ALLOC_TWO_LOWEST_FREE_001"))
      gate_expect_nonzero("dual_miss_cycle", m_dual_miss_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_ALLOC_FULL_001") || (m_l1dtlb_tc_id == "DTLB_MB_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_002"))
      gate_expect_nonzero("mb_full", m_mb_full_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_CREDIT_001") || (m_l1dtlb_tc_id == "DTLB_CREDIT_002")
     || (m_l1dtlb_tc_id == "DTLB_CREDIT_BOUND_001") || (m_l1dtlb_tc_id == "DTLB_SCHED_001")
     || (m_l1dtlb_tc_id == "DTLB_ALLOC_RACE_001") || (m_l1dtlb_tc_id == "DTLB_TYPE_PROP_LOAD_STORE_AMO_001"))
      gate_expect_nonzero("l2_req", m_l2_req_cycles);

    if (m_l1dtlb_tc_id == "DTLB_TYPE_PROP_LOAD_STORE_AMO_001") begin
      gate_expect_nonzero("l2_load_req", m_l2_load_req_cycles);
      gate_expect_nonzero("l2_store_req", m_l2_store_req_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_ALLOC_RACE_001") begin
      gate_expect_nonzero("one_free_dual_diff", m_one_free_dual_diff_cycles);
      gate_expect_nonzero("one_free_p0_older", m_one_free_p0_older_cycles);
      gate_expect_nonzero("one_free_p1_older", m_one_free_p1_older_cycles);
      gate_expect_nonzero("priority_drop_no_response", m_legal_no_response_priority_drop_cycles);
    end

    if ((m_l1dtlb_tc_id == "DTLB_REFILL_001") || (m_l1dtlb_tc_id == "DTLB_REFILL_002")
     || (m_l1dtlb_tc_id == "DTLB_INSTALL_ARB_001") || (m_l1dtlb_tc_id == "DTLB_INSTALL_ID_CHK_001")
     || (m_l1dtlb_tc_id == "DTLB_INSTALL_VISIBILITY_001") || (m_l1dtlb_tc_id == "DTLB_WFI_DATA_HOLD_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_FSM_WFI_001") || (m_l1dtlb_tc_id == "DTLB_ENTRY_FIELD_MODEL_001"))
      gate_expect_nonzero("refill_install", m_refill_cycles);

    if (m_l1dtlb_tc_id == "DTLB_INSTALL_VISIBILITY_001")
      gate_expect_nonzero("install_visible_next", m_install_visible_next_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_MB_PGFLT_001") || (m_l1dtlb_tc_id == "DTLB_EXPT_ID_MAP_001")
     || (m_l1dtlb_tc_id == "DTLB_MB_FAULT_HOLD_001") || (m_l1dtlb_tc_id == "DTLB_EXPT_HIT_WITH_TLB_HIT_001")
     || (m_l1dtlb_tc_id == "DTLB_ACCESS_FAULT_SOURCE_PARITY_001") || (m_l1dtlb_tc_id == "DTLB_WAKEUP_EXPT_001"))
      gate_expect_nonzero("exception_write_or_fault", m_expt_write_cycles + m_page_fault_cycles + m_access_fault_cycles);

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
    end

    if ((m_l1dtlb_tc_id == "DTLB_PERM_ST_001") || (m_l1dtlb_tc_id == "DTLB_PERM_ST_002"))
      gate_expect_nonzero("page_fault_store_pair", m_page_fault_store_pair_checks);

    if (m_l1dtlb_tc_id == "DTLB_PERM_ST_001")
      gate_expect_nonzero("perm_store_w0_pf", m_perm_store_w0_pf_cycles);

    if (m_l1dtlb_tc_id == "DTLB_PERM_ST_002") begin
      gate_expect_nonzero("perm_store_w0_pf", m_perm_store_w0_pf_cycles);
      gate_expect_nonzero("perm_store_d0_pf", m_perm_store_d0_pf_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_FAULT_AD_US_SUM_001") begin
      gate_expect_nonzero("page_fault_load_pair", m_page_fault_load_pair_checks);
      gate_expect_nonzero("perm_a0_pf", m_perm_a0_pf_cycles);
      gate_expect_nonzero("perm_sum0_pf", m_perm_sum0_pf_cycles);
      gate_expect_nonzero("perm_sum1_success", m_perm_sum1_success_cycles);
      gate_expect_nonzero("perm_user_u0_pf", m_perm_user_u0_pf_cycles);
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
      gate_expect_nonzero("access_fault_t1_pair", m_access_fault_pair_checks);

    if (m_l1dtlb_tc_id == "DTLB_FAULT_OVERLAP_PIPE_001")
      gate_expect_nonzero("fault_overlap", m_fault_overlap_cycles);

    if (m_l1dtlb_tc_id == "DTLB_WAKEUP_EXPT_001") begin
      gate_expect_nonzero("expt_replay", m_expt_replay_cycles);
      gate_expect_nonzero("expt_wakeup", m_expt_wakeup_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_EXPT_HIT_WITH_TLB_HIT_001")
      gate_expect_nonzero("expt_tlb_hit_overlap", m_expt_tlb_hit_overlap_cycles);

    if (m_l1dtlb_tc_id == "DTLB_HUGE_001") begin
      gate_expect_nonzero("refill_4k", m_refill_4k_cycles);
      gate_expect_nonzero("hit_4k", m_hit_4k_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_HUGE_002") begin
      gate_expect_nonzero("refill_2m", m_refill_2m_cycles);
      gate_expect_nonzero("hit_2m", m_hit_2m_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_HUGE_003") begin
      gate_expect_nonzero("refill_1g", m_refill_1g_cycles);
      gate_expect_nonzero("hit_1g", m_hit_1g_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_HUGE_MIX_001") begin
      gate_expect_nonzero("refill_4k", m_refill_4k_cycles);
      gate_expect_nonzero("refill_2m", m_refill_2m_cycles);
      gate_expect_nonzero("refill_1g", m_refill_1g_cycles);
    end

    if ((m_l1dtlb_tc_id == "DTLB_INV_001") || (m_l1dtlb_tc_id == "DTLB_INV_002")
     || (m_l1dtlb_tc_id == "DTLB_INV_003") || (m_l1dtlb_tc_id == "DTLB_INV_004")
     || (m_l1dtlb_tc_id == "DTLB_INV_VA8_alias_001") || (m_l1dtlb_tc_id == "DTLB_INV_HIT_SAME_CYCLE_001")
     || (m_l1dtlb_tc_id == "DTLB_INV_INSTALL_SAME_ENTRY_001"))
      gate_expect_nonzero("invalidate", m_inv_cycles);

    if (m_l1dtlb_tc_id == "DTLB_INV_VA8_alias_001")
      gate_expect_nonzero("va8_invalidate", m_va8_inv_cycles);

    if (m_l1dtlb_tc_id == "DTLB_INV_INSTALL_SAME_ENTRY_001")
      gate_expect_nonzero("invalidate_install_conflict", m_inv_install_conflict_cycles);

    if (m_l1dtlb_tc_id == "DTLB_INV_HIT_SAME_CYCLE_001")
      gate_expect_nonzero("invalidate_hit_same_cycle", m_inv_hit_same_cycle_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_MB_FLUSH_RACE_MATRIX_001") || (m_l1dtlb_tc_id == "DTLB_CLEANUP_SCOPE_MATRIX_001"))
      gate_expect_nonzero("flush", m_flush_cycles);

    if ((m_l1dtlb_tc_id == "DTLB_STAMO_001") || (m_l1dtlb_tc_id == "DTLB_STAMO_PIPE1_BYPASS_001")
     || (m_l1dtlb_tc_id == "DTLB_STAMO_PIPE0_NEG_001"))
      gate_expect_nonzero("stamo", m_stamo_cycles);

    if (m_l1dtlb_tc_id == "DTLB_STAMO_PIPE1_BYPASS_001")
      gate_expect_nonzero("stamo_pipe1_bypass", m_stamo_pipe1_bypass_cycles);

    if (m_l1dtlb_tc_id == "DTLB_STAMO_PIPE0_NEG_001") begin
      gate_expect_nonzero("stamo_pipe0_pollution_check", m_stamo_pipe0_pollution_checks);
      gate_expect_nonzero("stamo_pipe0_negative", m_stamo_pipe0_negative_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_SYSMAP_001") begin
      gate_expect_nonzero("direct_map", m_direct_map_cycles);
      gate_expect_nonzero("direct_map_no_mb", m_direct_map_no_mb_cycles);
    end

    if (m_l1dtlb_tc_id == "DTLB_ABORT_001") begin
      gate_expect_nonzero("abort_req", m_abort_req_cycles);
      gate_expect_nonzero("abort_hit_or_mask", m_abort_hit_cycles + m_abort_miss_no_response_cycles);
      gate_expect_nonzero("abort_expt_replay_survived", m_expt_replay_cycles);
    end
  endfunction

  virtual task run_phase(uvm_phase phase);
    if ((v_probe == null) || (lsu_vif == null))
      return;

    forever begin
      lsu_pipe_token_t t0_p0;
      lsu_pipe_token_t t0_p1;
      @(v_probe.mon_cb);
      if (v_probe.rst_ni !== 1'b1) begin
        m_seen_post_reset = 1'b0;
        m_t1_token[0] = '{default: '0};
        m_t1_token[1] = '{default: '0};
        m_t1_no_response_vld[0] = 1'b0;
        m_t1_no_response_vld[1] = 1'b0;
        m_prev_refill_vld = 1'b0;
        continue;
      end

      m_cycles++;
      t0_p0 = sample_pipe_token(0);
      t0_p1 = sample_pipe_token(1);
      check_reset_initial_state();
      check_busy_and_wakeup();
      check_mb_state_derived_signals();
      check_refill_and_expt();
      check_phase6a_observability();
      check_invalidate_edges();
      check_l2_req_and_credit();
      check_pipe_response_fault_pulses(t0_p0, m_t1_token[0]);
      check_pipe_response_fault_pulses(t0_p1, m_t1_token[1]);
      sample_scenario_counters(t0_p0, t0_p1);
      m_t1_token[0] = t0_p0;
      m_t1_token[1] = t0_p1;
      m_prev_entry_vld   = v_probe.mon_cb.l1d_entry_vld;
      m_prev_entry_vpn   = v_probe.mon_cb.l1d_entry_vpn;
      m_prev_entry_upd   = v_probe.mon_cb.l1d_entry_upd;
      m_prev_mb_vld      = v_probe.mon_cb.l1d_mb_vld;
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
      $sformatf("summary tc_id=%s scenario_id=%s cycles=%0d errors=%0d busy_checks=%0d wakeup=%0d hit=%0d hit4k=%0d hit2m=%0d hit1g=%0d dual_req=%0d dual_hit=%0d hit_miss=%0d dual_miss=%0d one_free=%0d one_free_p0_old=%0d one_free_p1_old=%0d mb_full=%0d l2_req=%0d l2_load=%0d l2_store=%0d credit0=%0d credit0_req=%0d refill=%0d refill4k=%0d refill2m=%0d refill1g=%0d expt_wr=%0d reset_checks=%0d direct_map=%0d direct_no_mb=%0d stamo=%0d stamo_p1=%0d stamo_p0_neg=%0d stamo_p0_chk=%0d abort=%0d abort_hit=%0d abort_mask=%0d inv=%0d inv_hit=%0d va8_inv=%0d inv_install=%0d install_next=%0d expt_replay=%0d expt_wakeup=%0d expt_hit_overlap=%0d legal_no_rsp=%0d nr_mb_cam=%0d nr_mb_full=%0d nr_abort=%0d nr_flush=%0d nr_busy=%0d nr_prio=%0d nr_sidefx_chk=%0d flush=%0d t0_tokens=%0d t1_tokens=%0d pf=%0d pf_pair=%0d pf_load=%0d pf_store=%0d pf_no_af=%0d af=%0d af_pair=%0d af_load=%0d af_store=%0d fault_overlap=%0d success_load=%0d success_store=%0d perm_r0=%0d perm_mxr_pf=%0d perm_mxr_ok=%0d perm_w0=%0d perm_d0=%0d perm_a0=%0d perm_sum0=%0d perm_sum1_ok=%0d perm_user_u0=%0d",
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
        m_perm_user_u0_pf_cycles),
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
