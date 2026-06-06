// =============================================================================
// MMU UVM Verification — testbench/env/mmu_translation_sb.svh
// Phase 5 (Engineer B): Translation Scoreboard
//
// Receives merged req+rsp transactions from IFU/LSU monitors and compares
// DUT MMU translation output against the Sv39 software reference model.
//
// Subscribed analysis ports (connected in mmu_env::connect_phase):
//   af_ifu_rsp    ← m_ifu.m_monitor.ap_rsp      (ifu_txn with VA+PA)
//   af_lsu_p0_rsp ← m_lsu.m_monitor.ap_pipe0_rsp (lsu_txn with VA+PA)
//   af_lsu_p1_rsp ← m_lsu.m_monitor.ap_pipe1_rsp (lsu_txn with VA+PA)
//   af_lsu_p2_rsp ← m_lsu.m_monitor.ap_pipe2_rsp (lsu_txn with correlated VA2+PA)
//
// Comparison logic (per channel):
//   1. If tr.abort==1 (IFU/LSU): skip — aborted transaction has no valid PA.
//   2. Call m_ref.translate(va, acc_type) to get golden result.
//   3. Exception check: ref.exc!=EXC_NONE  vs  DUT fault signals (pgflt/deny).
//   4. PA check (only when no fault on either side): ref.ppn vs tr.pa.
//      Exception (LSU_P1 only): tr.stamo_vld_at_rsp → st_ag can mux dut.pa1 from
//      STAMO (lm), not DTLB; SB checks dut.pa==stamo_pa and skips ref PPN.
//      LSU_P0: lsu_mmu_stamo_vld may be global; pa0 is still the DTLB PPN for
//      this pipe — do not equate mmu_lsu_pa0 to lsu_mmu_stamo_pa.
//   5. Mismatch → uvm_error; match → uvm_info (UVM_HIGH).
//
// LSU: mmu_l1dtlb_hit_rd pre_sel path muxes dutlb_off_pa = VA[38:12] (PPN looks
//   like VPN) for expt CAM consume, VA-illegal, MMU-off, etc. The Sv39 ref has
//   no expt CAM — waive the entire ref-vs-DUT compare when:
//   (a) tr.dtlb_expt_match from u_mmu_l1dtlb.expt_match{0,1}, OR
//   (b) architectural signature: mmu_en && !stall && dut_pa==req_vpn
//       (not STAMO skip path), even if dut fault bits are still 0 on the rsp
//       cycle. This covers replay/pre-select completion windows where pa_vld
//       is observable before page/access-fault indication is aligned.
//   PMP deny on LSU data ports is a T1 access-fault event after the T0 PA
//   response; L1DTLB spec SB owns that T1 token check, so this scoreboard waives
//   only the T0 fault mismatch for modeled PMP-deny LSU responses.
//   SATP root/ASID updates are treated as process switches in PTW stage-7
//   source tests: the directed sequence must issue an LSU INV_ASID_ALL TLBOp
//   and observe tlboper_ptw_abort before an old walk can refill stale state.
//   The old-context acceptance path below is disabled by default and retained
//   only behind +ALLOW_SATP_MIDWALK_OLD_ACCEPT for debug of legacy interleaves.
// IFU: mmu_l1itlb can also complete a response on internal completion sources
//   that the software ref does not observe cycle-accurately:
//   - iutlb_acc_flt   : PTW/TWU access-fault completion. On this pulse
//                       mmu_ifu_pavld can assert one cycle before the
//                       architected deny bit (jtlb_acc_fault_flop) is visible
//                       to the monitor.
//   - iutlb_ref_pgflt : refill-state page-fault completion
//   Only waive IFU compare when monitor observes the exact matching whitebox
//   bit on the response cycle, under a narrow completion signature.
//
// Pipe2 note: monitor merges the single-outstanding PFU VA into rsp txn.
//   If va2_valid is low for an orphan/legacy rsp, count only and skip compare.
// =============================================================================
`ifndef MMU_TRANSLATION_SB_SVH
`define MMU_TRANSLATION_SB_SVH

// ── Analysis import suffix declarations ───────────────────────────────────
// Must be declared outside the class scope (package level when `include'd).
`uvm_analysis_imp_decl(_ifu)
`uvm_analysis_imp_decl(_lsu_p0)
`uvm_analysis_imp_decl(_lsu_p1)
`uvm_analysis_imp_decl(_lsu_p2)

class mmu_translation_sb extends uvm_scoreboard;

  `uvm_component_utils(mmu_translation_sb)

  virtual mmu_dut_probes_if v_probe;

  // ── Analysis import ports ─────────────────────────────────────────────────
  uvm_analysis_imp_ifu    #(ifu_txn, mmu_translation_sb) af_ifu_rsp;
  uvm_analysis_imp_lsu_p0 #(lsu_txn, mmu_translation_sb) af_lsu_p0_rsp;
  uvm_analysis_imp_lsu_p1 #(lsu_txn, mmu_translation_sb) af_lsu_p1_rsp;
  uvm_analysis_imp_lsu_p2 #(lsu_txn, mmu_translation_sb) af_lsu_p2_rsp;

  // ── Reference model (injected from mmu_env.build_phase) ──────────────────
  mmu_ref_model m_ref;
  mmu_l2tlb_txn_shadow m_l2_shadow;

  // ── Statistics ────────────────────────────────────────────────────────────
  int unsigned m_total_checked;
  int unsigned m_mismatch;
  int unsigned m_lsu_fault_replay_rsp;
  int unsigned m_lsu_replay_mismatch;
  int unsigned m_lsu_replay_waive_rsp;
  int unsigned m_lsu_expt_replay_rsp;
  int unsigned m_lsu_expt_replay_timing_waive_rsp;
  int unsigned m_lsu_expt_replay_orphan_rsp;
  int unsigned m_lsu_pmp_t1_waive_rsp;
  int unsigned m_lsu_satp_midwalk_waive_rsp;
  int unsigned m_ifu_accerr_waive_rsp;
  int unsigned m_ifu_refpgflt_waive_rsp;
  int unsigned m_lsu_phase6b_expt_classified_rsp;
  int unsigned m_lsu_phase6b_expt_timing_classified_rsp;
  int unsigned m_lsu_phase6b_expt_orphan_rsp;
  int unsigned m_lsu_phase6b_pmp_t1_classified_rsp;
  int unsigned m_lsu_phase6b_satp_midwalk_classified_rsp;
  int unsigned m_lsu_phase6b_stamo_classified_rsp;
  int unsigned m_lsu_phase6b_direct_map_classified_rsp;
  int unsigned m_lsu_phase6b_remaining_broad_waive_rsp;
  int unsigned m_pfu_error_payload_ignore_rsp;
  int unsigned m_pfu_flag_only_diag_rsp;
  bit          m_allow_satp_midwalk_old_accept;

  localparam int DTLB_EXPT_CAM_DEPTH = 8;
  localparam int PTW_REQ_SHADOW_DEPTH = 8;
  localparam int PTW_ID_WIDTH = 7;
  localparam int unsigned LSU_SATP_MIDWALK_REFILL_CYCLE_WINDOW = 32;
  localparam int unsigned LSU_SATP_MIDWALK_SATP_CYCLE_WINDOW   = 128;
  localparam int unsigned LSU_SATP_MIDWALK_REQ_CYCLE_WINDOW    = 128;

  typedef struct packed {
    bit        vld;
    bit [6:0]  iid;
    bit [26:0] vpn;
    bit        pgflt;
    bit        acflt;
    bit [3:0]  eid;
  } dtlb_expt_cam_entry_t;

  dtlb_expt_cam_entry_t m_dtlb_expt_cam[DTLB_EXPT_CAM_DEPTH];

  typedef struct {
    bit              vld;
    bit [PTW_ID_WIDTH-1:0] id;
    bit [26:0]       vpn;
    bit [27:0]       satp_ppn;
    bit [15:0]       asid;
    bit [1:0]        priv_mode;
    bit              mxr;
    bit              sum;
    bit              mprv;
    bit [1:0]        mpp;
    time             req_time;
    longint unsigned req_cycle;
  } ptw_req_shadow_entry_t;

  ptw_req_shadow_entry_t m_ptw_req_shadow[PTW_REQ_SHADOW_DEPTH];

  // ── Recent whitebox snapshots for LSU_P1 root-cause diagnostics ──────────
  bit          m_last_l2_ref_valid;
  bit          m_last_l2_ref_pavld;
  bit          m_last_l2_ref_cmplt;
  bit [26:0]   m_last_l2_ref_vpn;
  bit [27:0]   m_last_l2_ref_ppn;
  time         m_last_l2_ref_time;
  bit          m_last_ptw_ref_valid;
  bit [2:0]    m_last_ptw_ref_id;
  bit [27:0]   m_last_ptw_ref_ppn;
  bit [26:0]   m_last_ptw_arb_vpn;
  bit          m_last_ptw_ref_mb_vld;
  bit [6:0]    m_last_ptw_ref_mb_iid;
  bit [26:0]   m_last_ptw_ref_mb_vpn;
  time         m_last_ptw_ref_time;
  longint unsigned m_probe_cycle;
  bit          m_last_l2tlb_ptw_req_valid;
  bit [PTW_ID_WIDTH-1:0] m_last_l2tlb_ptw_req_id;
  bit [26:0]   m_last_l2tlb_ptw_req_vpn;
  bit [27:0]   m_last_l2tlb_ptw_req_satp_ppn;
  bit [15:0]   m_last_l2tlb_ptw_req_asid;
  bit [1:0]    m_last_l2tlb_ptw_req_priv_mode;
  bit          m_last_l2tlb_ptw_req_mxr;
  bit          m_last_l2tlb_ptw_req_sum;
  bit          m_last_l2tlb_ptw_req_mprv;
  bit [1:0]    m_last_l2tlb_ptw_req_mpp;
  time         m_last_l2tlb_ptw_req_time;
  longint unsigned m_last_l2tlb_ptw_req_cycle;
  longint unsigned m_last_ptw_ref_cycle;
  bit          m_satp_snapshot_valid;
  bit          m_satp_change_valid;
  bit          m_last_satp_root_changed;
  bit [27:0]   m_prev_satp_ppn;
  bit [27:0]   m_cur_satp_ppn;
  bit [15:0]   m_prev_satp_asid;
  bit [15:0]   m_cur_satp_asid;
  time         m_last_satp_change_time;
  longint unsigned m_last_satp_change_cycle;
  longint unsigned m_last_tlboper_ptw_abort_cycle;
  bit          m_last_l1_refill_valid;
  bit [1:0]    m_last_l1_refill_src;
  bit [3:0]    m_last_l1_refill_idx;
  bit [26:0]   m_last_l1_refill_vpn;
  bit [27:0]   m_last_l1_refill_ppn;
  bit [2:0]    m_last_l1_refill_pgs;
  bit [15:0]   m_last_l1_entry_upd;
  time         m_last_l1_refill_time;
  bit          m_last_ptw_l2_ref_valid;
  bit          m_last_ptw_l2_ref_pgflt;
  bit          m_last_ptw_l2_ref_acc_err;
  time         m_last_ptw_l2_ref_time;
  bit          m_l2_prev_reset_asserted;
  bit          m_l2_prev_tlboper_ptw_abort;
  bit          m_l2_prev_rtu_flush;
  bit          m_l2_prev_utlb_clr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_total_checked = 0;
    m_mismatch      = 0;
    m_lsu_fault_replay_rsp = 0;
    m_lsu_replay_mismatch = 0;
    m_lsu_replay_waive_rsp = 0;
    m_lsu_expt_replay_rsp = 0;
    m_lsu_expt_replay_timing_waive_rsp = 0;
    m_lsu_expt_replay_orphan_rsp = 0;
    m_lsu_pmp_t1_waive_rsp = 0;
    m_lsu_satp_midwalk_waive_rsp = 0;
    m_ifu_accerr_waive_rsp = 0;
    m_ifu_refpgflt_waive_rsp = 0;
    m_lsu_phase6b_expt_classified_rsp = 0;
    m_lsu_phase6b_expt_timing_classified_rsp = 0;
    m_lsu_phase6b_expt_orphan_rsp = 0;
    m_lsu_phase6b_pmp_t1_classified_rsp = 0;
    m_lsu_phase6b_satp_midwalk_classified_rsp = 0;
    m_lsu_phase6b_stamo_classified_rsp = 0;
    m_lsu_phase6b_direct_map_classified_rsp = 0;
    m_lsu_phase6b_remaining_broad_waive_rsp = 0;
    m_pfu_error_payload_ignore_rsp = 0;
    m_pfu_flag_only_diag_rsp = 0;
    m_allow_satp_midwalk_old_accept = 1'b0;
    m_last_l2_ref_valid = 1'b0;
    m_last_l2_ref_pavld = 1'b0;
    m_last_l2_ref_cmplt = 1'b0;
    m_last_l2_ref_vpn = '0;
    m_last_l2_ref_ppn = '0;
    m_last_l2_ref_time = 0;
    m_last_ptw_ref_valid = 1'b0;
    m_last_ptw_ref_id = '0;
    m_last_ptw_ref_ppn = '0;
    m_last_ptw_arb_vpn = '0;
    m_last_ptw_ref_mb_vld = 1'b0;
    m_last_ptw_ref_mb_iid = '0;
    m_last_ptw_ref_mb_vpn = '0;
    m_last_ptw_ref_time = 0;
    m_probe_cycle = 0;
    m_last_l2tlb_ptw_req_valid = 1'b0;
    m_last_l2tlb_ptw_req_id = '0;
    m_last_l2tlb_ptw_req_vpn = '0;
    m_last_l2tlb_ptw_req_satp_ppn = '0;
    m_last_l2tlb_ptw_req_asid = '0;
    m_last_l2tlb_ptw_req_priv_mode = '0;
    m_last_l2tlb_ptw_req_mxr = 1'b0;
    m_last_l2tlb_ptw_req_sum = 1'b0;
    m_last_l2tlb_ptw_req_mprv = 1'b0;
    m_last_l2tlb_ptw_req_mpp = PRIV_M;
    m_last_l2tlb_ptw_req_time = 0;
    m_last_l2tlb_ptw_req_cycle = 0;
    m_last_ptw_ref_cycle = 0;
    m_satp_snapshot_valid = 1'b0;
    m_satp_change_valid = 1'b0;
    m_last_satp_root_changed = 1'b0;
    m_prev_satp_ppn = '0;
    m_cur_satp_ppn = '0;
    m_prev_satp_asid = '0;
    m_cur_satp_asid = '0;
    m_last_satp_change_time = 0;
    m_last_satp_change_cycle = 0;
    m_last_tlboper_ptw_abort_cycle = 0;
    m_last_l1_refill_valid = 1'b0;
    m_last_l1_refill_src = '0;
    m_last_l1_refill_idx = '0;
    m_last_l1_refill_vpn = '0;
    m_last_l1_refill_ppn = '0;
    m_last_l1_refill_pgs = '0;
    m_last_l1_entry_upd = '0;
    m_last_l1_refill_time = 0;
    m_last_ptw_l2_ref_valid = 1'b0;
    m_last_ptw_l2_ref_pgflt = 1'b0;
    m_last_ptw_l2_ref_acc_err = 1'b0;
    m_last_ptw_l2_ref_time = 0;
    m_l2_prev_reset_asserted = 1'b0;
    m_l2_prev_tlboper_ptw_abort = 1'b0;
    m_l2_prev_rtu_flush = 1'b0;
    m_l2_prev_utlb_clr = 1'b0;
    m_l2_shadow = null;
    _ptw_req_shadow_clear_all();
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    af_ifu_rsp    = new("af_ifu_rsp",    this);
    af_lsu_p0_rsp = new("af_lsu_p0_rsp", this);
    af_lsu_p1_rsp = new("af_lsu_p1_rsp", this);
    af_lsu_p2_rsp = new("af_lsu_p2_rsp", this);
    if (!uvm_config_db #(virtual mmu_dut_probes_if)::get(this, "", "MMU_DUT_PROBES_VIF", v_probe))
      `uvm_info(get_type_name(),
        "MMU_DUT_PROBES_VIF not in config_db — LSU_P1 whitebox root-cause dump will be unavailable",
        UVM_LOW)
    if (m_l2_shadow == null) begin
      if (!uvm_config_db #(mmu_l2tlb_txn_shadow)::get(this, "", "L2TLB_TXN_SHADOW", m_l2_shadow))
        m_l2_shadow = mmu_l2tlb_txn_shadow::type_id::create("m_l2_shadow");
    end
    m_allow_satp_midwalk_old_accept = $test$plusargs("ALLOW_SATP_MIDWALK_OLD_ACCEPT");
  endfunction

  virtual task run_phase(uvm_phase phase);
    if (v_probe == null)
      return;

    forever begin
      bit cur_reset_asserted;
      bit cur_tlboper_ptw_abort;
      bit cur_rtu_flush;
      bit cur_utlb_clr;

      @(v_probe.mon_cb);
      cur_reset_asserted = (v_probe.rst_ni !== 1'b1);
      cur_tlboper_ptw_abort = v_probe.mon_cb.tlboper_ptw_abort;
      cur_rtu_flush = v_probe.mon_cb.rtu_yy_xx_flush;
      cur_utlb_clr = v_probe.mon_cb.tlboper_utlb_clr;
      m_probe_cycle++;
      if (m_l2_shadow != null)
        m_l2_shadow.m_cycle = m_probe_cycle;
      if (m_l2_shadow != null) begin
        if (cur_reset_asserted && !m_l2_prev_reset_asserted)
          m_l2_shadow.on_reset();
        if (!cur_reset_asserted && cur_tlboper_ptw_abort && !m_l2_prev_tlboper_ptw_abort)
          m_l2_shadow.on_abort("tlboper_ptw_abort");
        if (!cur_reset_asserted && cur_rtu_flush && !m_l2_prev_rtu_flush)
          m_l2_shadow.bump_epoch("rtu_yy_xx_flush", .clear_ptw(1'b0));
        if (!cur_reset_asserted && cur_utlb_clr && !m_l2_prev_utlb_clr)
          m_l2_shadow.on_control_epoch("tlboper_utlb_clr");
      end
      if (cur_reset_asserted
          || cur_rtu_flush
          || cur_utlb_clr
          || v_probe.mon_cb.tlboper_utlb_inv_va_req) begin
        _dtlb_expt_cam_clear_all();
      end else begin
        if (v_probe.mon_cb.l1d_expt_wr0_vld)
          _dtlb_expt_cam_write(v_probe.mon_cb.l1d_expt_wr0_iid,
                               v_probe.mon_cb.l1d_expt_wr0_vpn,
                               v_probe.mon_cb.l1d_expt_wr0_pgflt,
                               v_probe.mon_cb.l1d_expt_wr0_acflt,
                               v_probe.mon_cb.l1d_expt_wr0_eid);
        if (v_probe.mon_cb.l1d_expt_wr1_vld)
          _dtlb_expt_cam_write(v_probe.mon_cb.l1d_expt_wr1_iid,
                               v_probe.mon_cb.l1d_expt_wr1_vpn,
                               v_probe.mon_cb.l1d_expt_wr1_pgflt,
                               v_probe.mon_cb.l1d_expt_wr1_acflt,
                               v_probe.mon_cb.l1d_expt_wr1_eid);
      end
      if (cur_reset_asserted
          || cur_rtu_flush
          || cur_tlboper_ptw_abort) begin
        _ptw_req_shadow_clear_all();
      end
      if (cur_reset_asserted) begin
        m_last_l2tlb_ptw_req_valid = 1'b0;
        m_satp_snapshot_valid = 1'b0;
        m_satp_change_valid = 1'b0;
        m_last_satp_root_changed = 1'b0;
        m_last_tlboper_ptw_abort_cycle = 0;
      end else if (!m_satp_snapshot_valid) begin
        m_satp_snapshot_valid = 1'b1;
        m_cur_satp_ppn = v_probe.mon_cb.regs_ptw_satp_ppn;
        m_cur_satp_asid = v_probe.mon_cb.regs_ptw_cur_asid;
        m_prev_satp_ppn = v_probe.mon_cb.regs_ptw_satp_ppn;
        m_prev_satp_asid = v_probe.mon_cb.regs_ptw_cur_asid;
      end else if ((v_probe.mon_cb.regs_ptw_satp_ppn !== m_cur_satp_ppn)
                   || (v_probe.mon_cb.regs_ptw_cur_asid !== m_cur_satp_asid)) begin
        m_last_satp_root_changed = (v_probe.mon_cb.regs_ptw_satp_ppn !== m_cur_satp_ppn);
        m_prev_satp_ppn = m_cur_satp_ppn;
        m_prev_satp_asid = m_cur_satp_asid;
        m_cur_satp_ppn = v_probe.mon_cb.regs_ptw_satp_ppn;
        m_cur_satp_asid = v_probe.mon_cb.regs_ptw_cur_asid;
        m_last_satp_change_time = $time;
        m_last_satp_change_cycle = m_probe_cycle;
        m_satp_change_valid = 1'b1;
      end
      if (cur_tlboper_ptw_abort) begin
        m_last_tlboper_ptw_abort_cycle = m_probe_cycle;
        m_last_l2tlb_ptw_req_valid = 1'b0;
        m_last_satp_root_changed = 1'b0;
        m_prev_satp_ppn = m_cur_satp_ppn;
        m_prev_satp_asid = m_cur_satp_asid;
      end
      if (v_probe.mon_cb.l2tlb_ptw_req
          && !v_probe.mon_cb.tlboper_ptw_abort) begin
        // Track every PTW request by (id, type) — the shadow model has
        // 16 independent slots.  Using a single m_last_* flag would drop
        // concurrent ITLB + DTLB requests, causing orphan completions.
        if (!m_last_l2tlb_ptw_req_valid) begin
          m_last_l2tlb_ptw_req_valid = 1'b1;
          m_last_l2tlb_ptw_req_id    = v_probe.mon_cb.l2tlb_ptw_id;
          m_last_l2tlb_ptw_req_vpn   = v_probe.mon_cb.l2tlb_ptw_vpn;
          m_last_l2tlb_ptw_req_satp_ppn = v_probe.mon_cb.regs_ptw_satp_ppn;
          m_last_l2tlb_ptw_req_asid = v_probe.mon_cb.regs_ptw_cur_asid;
          m_last_l2tlb_ptw_req_priv_mode = v_probe.mon_cb.ptw_cp0_priv_mode;
          m_last_l2tlb_ptw_req_mxr = v_probe.mon_cb.ptw_cp0_mxr;
          m_last_l2tlb_ptw_req_sum = v_probe.mon_cb.ptw_cp0_sum;
          m_last_l2tlb_ptw_req_mprv = v_probe.mon_cb.ptw_cp0_mprv;
          m_last_l2tlb_ptw_req_mpp = v_probe.mon_cb.ptw_cp0_mpp;
          m_last_l2tlb_ptw_req_time  = $time;
          m_last_l2tlb_ptw_req_cycle = m_probe_cycle;
          _ptw_req_shadow_write(v_probe.mon_cb.l2tlb_ptw_id,
                                v_probe.mon_cb.l2tlb_ptw_vpn,
                                v_probe.mon_cb.regs_ptw_satp_ppn,
                                v_probe.mon_cb.regs_ptw_cur_asid,
                                v_probe.mon_cb.ptw_cp0_priv_mode,
                                v_probe.mon_cb.ptw_cp0_mxr,
                                v_probe.mon_cb.ptw_cp0_sum,
                                v_probe.mon_cb.ptw_cp0_mprv,
                                v_probe.mon_cb.ptw_cp0_mpp);
        end
        if (m_l2_shadow != null) begin
          m_l2_shadow.on_ptw_request(v_probe.mon_cb.l2tlb_ptw_id,
            v_probe.mon_cb.l2tlb_ptw_type,
            v_probe.mon_cb.l2tlb_ptw_vpn,
            v_probe.mon_cb.regs_ptw_cur_asid,
            v_probe.mon_cb.regs_ptw_satp_ppn,
            v_probe.mon_cb.ptw_cp0_priv_mode,
            v_probe.mon_cb.ptw_cp0_mxr,
            v_probe.mon_cb.ptw_cp0_sum,
            v_probe.mon_cb.ptw_cp0_mprv,
            v_probe.mon_cb.ptw_cp0_mpp);
        end
      end
      if (v_probe.mon_cb.l2_dtlb_ref_pavld || v_probe.mon_cb.l2_dtlb_ref_cmplt) begin
        m_last_l2_ref_valid = 1'b1;
        m_last_l2_ref_pavld = v_probe.mon_cb.l2_dtlb_ref_pavld;
        m_last_l2_ref_cmplt = v_probe.mon_cb.l2_dtlb_ref_cmplt;
        m_last_l2_ref_vpn   = v_probe.mon_cb.l2_dtlb_ref_vpn;
        m_last_l2_ref_ppn   = v_probe.mon_cb.l2_dtlb_ref_ppn;
        m_last_l2_ref_time  = $time;
      end
      if (m_l2_shadow != null) begin
        m_l2_shadow.on_l2_final(v_probe.mon_cb.l2_final_vld,
          v_probe.mon_cb.l2_final_tlb_hit,
          v_probe.mon_cb.l2_miss,
          v_probe.mon_cb.l2_final_is_dtlb,
          v_probe.mon_cb.l2_final_vpn,
          v_probe.mon_cb.l2_final_hit_ppn,
          v_probe.mon_cb.regs_ptw_cur_asid);
      end
      if (v_probe.mon_cb.ptw_l1d_ref_cmplt) begin
        m_last_ptw_ref_valid = 1'b1;
        m_last_ptw_ref_id    = v_probe.mon_cb.ptw_l1d_ref_id;
        m_last_ptw_ref_ppn   = v_probe.mon_cb.ptw_l1d_ref_ppn;
        m_last_ptw_arb_vpn   = v_probe.mon_cb.ptw_arb_vpn;
        m_last_ptw_ref_mb_vld = v_probe.mon_cb.l1d_ptw_ref_mb_vld;
        m_last_ptw_ref_mb_iid = v_probe.mon_cb.l1d_ptw_ref_mb_iid;
        m_last_ptw_ref_mb_vpn = v_probe.mon_cb.l1d_ptw_ref_mb_vpn;
        m_last_ptw_ref_time  = $time;
        m_last_ptw_ref_cycle = m_probe_cycle;
      end
      if (v_probe.mon_cb.l1d_refill_vld) begin
        m_last_l1_refill_valid = 1'b1;
        m_last_l1_refill_src   = v_probe.mon_cb.l1d_refill_src;
        m_last_l1_refill_idx   = v_probe.mon_cb.l1d_refill_idx;
        m_last_l1_refill_vpn   = v_probe.mon_cb.l1d_refill_vpn;
        m_last_l1_refill_ppn   = v_probe.mon_cb.l1d_refill_ppn;
        m_last_l1_refill_pgs   = v_probe.mon_cb.l1d_refill_pgs;
        m_last_l1_entry_upd    = v_probe.mon_cb.l1d_entry_upd;
        m_last_l1_refill_time  = $time;
      end
      if (v_probe.mon_cb.ptw_l2tlb_ref_pgflt || v_probe.mon_cb.ptw_l2tlb_ref_acc_err) begin
        m_last_ptw_l2_ref_valid   = 1'b1;
        m_last_ptw_l2_ref_pgflt   = v_probe.mon_cb.ptw_l2tlb_ref_pgflt;
        m_last_ptw_l2_ref_acc_err = v_probe.mon_cb.ptw_l2tlb_ref_acc_err;
        m_last_ptw_l2_ref_time    = $time;
      end
      if (m_l2_shadow != null) begin
        m_l2_shadow.on_ptw_completion(v_probe.mon_cb.ptw_l2tlb_cmplt,
          v_probe.mon_cb.ptw_l2tlb_ref_data_vld,
          v_probe.mon_cb.ptw_l2tlb_ref_pgflt,
          v_probe.mon_cb.ptw_l2tlb_ref_acc_err,
          v_probe.mon_cb.ptw_l2tlb_id,
          v_probe.mon_cb.ptw_l2tlb_type,
          v_probe.mon_cb.ptw_arb_ref_tag_din,
          v_probe.mon_cb.ptw_arb_ref_data_din,
          v_probe.mon_cb.ptw_l2tlb_flg);
      end
      // PTW completion consumed — allow next request to be tracked
      if (v_probe.mon_cb.ptw_l2tlb_cmplt)
        m_last_l2tlb_ptw_req_valid = 1'b0;
      m_l2_prev_reset_asserted = cur_reset_asserted;
      m_l2_prev_tlboper_ptw_abort = cur_tlboper_ptw_abort;
      m_l2_prev_rtu_flush = cur_rtu_flush;
      m_l2_prev_utlb_clr = cur_utlb_clr;
    end
  endtask

  protected function int _dtlb_expt_cam_find(bit [6:0] iid, bit [26:0] vpn);
    for (int i = 0; i < DTLB_EXPT_CAM_DEPTH; i++) begin
      if (m_dtlb_expt_cam[i].vld
          && (m_dtlb_expt_cam[i].iid == iid)
          && (m_dtlb_expt_cam[i].vpn == vpn))
        return i;
    end
    return -1;
  endfunction

  protected function int _dtlb_expt_cam_first_free();
    for (int i = 0; i < DTLB_EXPT_CAM_DEPTH; i++) begin
      if (!m_dtlb_expt_cam[i].vld)
        return i;
    end
    return -1;
  endfunction

  protected function void _dtlb_expt_cam_clear_all();
    for (int i = 0; i < DTLB_EXPT_CAM_DEPTH; i++)
      m_dtlb_expt_cam[i].vld = 1'b0;
  endfunction

  protected function void _dtlb_expt_cam_clear_match(bit [6:0] iid, bit [26:0] vpn);
    int idx;
    idx = _dtlb_expt_cam_find(iid, vpn);
    if (idx >= 0)
      m_dtlb_expt_cam[idx].vld = 1'b0;
  endfunction

  protected function void _dtlb_expt_cam_write(
    bit [6:0]  iid,
    bit [26:0] vpn,
    bit        pgflt,
    bit        acflt,
    bit [3:0]  eid
  );
    int idx;
    idx = _dtlb_expt_cam_find(iid, vpn);
    if (idx < 0)
      idx = _dtlb_expt_cam_first_free();

    if (idx < 0) begin
      `uvm_warning(get_type_name(),
        $sformatf("[LSU_EXPT_CAM_SHADOW_FULL] drop write iid=%0d vpn=0x%07h pgflt=%0b acflt=%0b eid=%0d",
          iid, vpn, pgflt, acflt, eid))
      return;
    end

    m_dtlb_expt_cam[idx].vld   = 1'b1;
    m_dtlb_expt_cam[idx].iid   = iid;
    m_dtlb_expt_cam[idx].vpn   = vpn;
    m_dtlb_expt_cam[idx].pgflt = pgflt;
    m_dtlb_expt_cam[idx].acflt = acflt;
    m_dtlb_expt_cam[idx].eid   = eid;
  endfunction

  protected function int _ptw_req_shadow_find(bit [PTW_ID_WIDTH-1:0] id, bit [26:0] vpn);
    for (int i = 0; i < PTW_REQ_SHADOW_DEPTH; i++) begin
      if (m_ptw_req_shadow[i].vld
          && (m_ptw_req_shadow[i].id == id)
          && (m_ptw_req_shadow[i].vpn == vpn))
        return i;
    end
    return -1;
  endfunction

  protected function int _ptw_req_shadow_find_l1eid(bit [2:0] l1eid, bit [26:0] vpn);
    for (int i = 0; i < PTW_REQ_SHADOW_DEPTH; i++) begin
      if (m_ptw_req_shadow[i].vld
          && (m_ptw_req_shadow[i].id[2:0] == l1eid)
          && (m_ptw_req_shadow[i].vpn == vpn))
        return i;
    end
    return -1;
  endfunction

  protected function int _ptw_req_shadow_first_free();
    for (int i = 0; i < PTW_REQ_SHADOW_DEPTH; i++) begin
      if (!m_ptw_req_shadow[i].vld)
        return i;
    end
    return -1;
  endfunction

  protected function void _ptw_req_shadow_entry_clear(output ptw_req_shadow_entry_t ent);
    ent.vld = 1'b0;
    ent.id = '0;
    ent.vpn = '0;
    ent.satp_ppn = '0;
    ent.asid = '0;
    ent.priv_mode = '0;
    ent.mxr = 1'b0;
    ent.sum = 1'b0;
    ent.mprv = 1'b0;
    ent.mpp = PRIV_M;
    ent.req_time = 0;
    ent.req_cycle = 0;
  endfunction

  protected function void _ptw_req_shadow_clear_all();
    for (int i = 0; i < PTW_REQ_SHADOW_DEPTH; i++)
      m_ptw_req_shadow[i].vld = 1'b0;
  endfunction

  protected function void _ptw_req_shadow_write(
    bit [PTW_ID_WIDTH-1:0] id,
    bit [26:0] vpn,
    bit [27:0] satp_ppn,
    bit [15:0] asid,
    bit [1:0]  priv_mode,
    bit        mxr,
    bit        sum,
    bit        mprv,
    bit [1:0]  mpp
  );
    int idx;
    idx = _ptw_req_shadow_find(id, vpn);
    if (idx < 0)
      idx = _ptw_req_shadow_first_free();
    if (idx < 0)
      idx = 0;

    m_ptw_req_shadow[idx].vld = 1'b1;
    m_ptw_req_shadow[idx].id = id;
    m_ptw_req_shadow[idx].vpn = vpn;
    m_ptw_req_shadow[idx].satp_ppn = satp_ppn;
    m_ptw_req_shadow[idx].asid = asid;
    m_ptw_req_shadow[idx].priv_mode = priv_mode;
    m_ptw_req_shadow[idx].mxr = mxr;
    m_ptw_req_shadow[idx].sum = sum;
    m_ptw_req_shadow[idx].mprv = mprv;
    m_ptw_req_shadow[idx].mpp = mpp;
    m_ptw_req_shadow[idx].req_time = $time;
    m_ptw_req_shadow[idx].req_cycle = m_probe_cycle;
  endfunction

  protected function bit _recent_satp_root_change_seen(
    output longint unsigned satp_age_cycles
  );
    satp_age_cycles = 0;
    if (!m_allow_satp_midwalk_old_accept)
      return 1'b0;
    if (!m_satp_change_valid || !m_last_satp_root_changed)
      return 1'b0;
    if ((m_last_tlboper_ptw_abort_cycle >= m_last_satp_change_cycle)
        && (m_last_tlboper_ptw_abort_cycle <= m_probe_cycle))
      return 1'b0;
    if (m_probe_cycle < m_last_satp_change_cycle)
      return 1'b0;

    satp_age_cycles = m_probe_cycle - m_last_satp_change_cycle;
    if (satp_age_cycles > LSU_SATP_MIDWALK_SATP_CYCLE_WINDOW)
      return 1'b0;

    return 1'b1;
  endfunction

  protected function bit _ptw_req_is_old_satp_context(
    input longint unsigned req_cycle,
    input bit [27:0]       req_satp_ppn
  );
    if (!m_allow_satp_midwalk_old_accept)
      return 1'b0;
    if (!m_satp_change_valid || !m_last_satp_root_changed)
      return 1'b0;
    if ((m_last_tlboper_ptw_abort_cycle >= m_last_satp_change_cycle)
        && (m_last_tlboper_ptw_abort_cycle >= req_cycle))
      return 1'b0;
    if (req_cycle < m_last_satp_change_cycle)
      return ((m_last_satp_change_cycle - req_cycle)
              <= LSU_SATP_MIDWALK_REQ_CYCLE_WINDOW)
          && (req_satp_ppn == m_prev_satp_ppn)
          && (req_satp_ppn != m_cur_satp_ppn);
    if (req_cycle == m_last_satp_change_cycle)
      return (req_satp_ppn == m_prev_satp_ppn) && (req_satp_ppn != m_cur_satp_ppn);
    return 1'b0;
  endfunction

  protected function bit _recent_ptw_l1d_refill_matches(
    input  bit [26:0] req_vpn,
    input  bit [6:0]  lsu_iid,
    input  bit [27:0] dut_pa,
    output longint unsigned refill_age_cycles
  );
    refill_age_cycles = 0;

    if ((v_probe != null)
        && v_probe.ptw_l1d_ref_cmplt
        && (m_probe_cycle > m_last_satp_change_cycle)
        && (v_probe.ptw_arb_vpn == req_vpn)
        && (v_probe.ptw_l1d_ref_id == lsu_iid[2:0])
        && (v_probe.ptw_l1d_ref_ppn == dut_pa)
        && (!v_probe.l1d_ptw_ref_mb_vld
            || ((v_probe.l1d_ptw_ref_mb_iid == lsu_iid)
                && (v_probe.l1d_ptw_ref_mb_vpn == req_vpn))))
      return 1'b1;

    if (!m_last_ptw_ref_valid)
      return 1'b0;
    if (m_last_ptw_ref_cycle <= m_last_satp_change_cycle)
      return 1'b0;
    if (m_probe_cycle < m_last_ptw_ref_cycle)
      return 1'b0;

    refill_age_cycles = m_probe_cycle - m_last_ptw_ref_cycle;
    if (refill_age_cycles > LSU_SATP_MIDWALK_REFILL_CYCLE_WINDOW)
      return 1'b0;

    return (m_last_ptw_arb_vpn == req_vpn)
        && (m_last_ptw_ref_id == lsu_iid[2:0])
        && (m_last_ptw_ref_ppn == dut_pa)
        && (!m_last_ptw_ref_mb_vld
            || ((m_last_ptw_ref_mb_iid == lsu_iid)
                && (m_last_ptw_ref_mb_vpn == req_vpn)));
  endfunction

  protected function bit _ptw_request_started_before_satp_change(
    input  bit [26:0] req_vpn,
    input  bit [6:0]  lsu_iid,
    output ptw_req_shadow_entry_t req_ent
  );
    int idx;
    _ptw_req_shadow_entry_clear(req_ent);

    if ((v_probe != null)
        && v_probe.l2tlb_ptw_req
        && v_probe.ptw_jtlb_ready
        && (v_probe.l2tlb_ptw_id[2:0] == lsu_iid[2:0])
        && (v_probe.l2tlb_ptw_vpn == req_vpn)
        && _ptw_req_is_old_satp_context(m_probe_cycle,
                                        v_probe.regs_ptw_satp_ppn)) begin
      req_ent.vld = 1'b1;
      req_ent.id = v_probe.l2tlb_ptw_id;
      req_ent.vpn = v_probe.l2tlb_ptw_vpn;
      req_ent.satp_ppn = v_probe.regs_ptw_satp_ppn;
      req_ent.asid = v_probe.regs_ptw_cur_asid;
      req_ent.priv_mode = v_probe.ptw_cp0_priv_mode;
      req_ent.mxr = v_probe.ptw_cp0_mxr;
      req_ent.sum = v_probe.ptw_cp0_sum;
      req_ent.mprv = v_probe.ptw_cp0_mprv;
      req_ent.mpp = v_probe.ptw_cp0_mpp;
      req_ent.req_time = $time;
      req_ent.req_cycle = m_probe_cycle;
      return 1'b1;
    end

    idx = _ptw_req_shadow_find_l1eid(lsu_iid[2:0], req_vpn);
    if (idx >= 0) begin
      if (_ptw_req_is_old_satp_context(m_ptw_req_shadow[idx].req_cycle,
                                       m_ptw_req_shadow[idx].satp_ppn)) begin
        req_ent = m_ptw_req_shadow[idx];
        return 1'b1;
      end
      return 1'b0;
    end

    if (m_last_l2tlb_ptw_req_valid
        && (m_last_l2tlb_ptw_req_id[2:0] == lsu_iid[2:0])
        && (m_last_l2tlb_ptw_req_vpn == req_vpn)
        && _ptw_req_is_old_satp_context(m_last_l2tlb_ptw_req_cycle,
                                        m_last_l2tlb_ptw_req_satp_ppn)) begin
      req_ent.vld = 1'b1;
      req_ent.id = m_last_l2tlb_ptw_req_id;
      req_ent.vpn = m_last_l2tlb_ptw_req_vpn;
      req_ent.satp_ppn = m_last_l2tlb_ptw_req_satp_ppn;
      req_ent.asid = m_last_l2tlb_ptw_req_asid;
      req_ent.priv_mode = m_last_l2tlb_ptw_req_priv_mode;
      req_ent.mxr = m_last_l2tlb_ptw_req_mxr;
      req_ent.sum = m_last_l2tlb_ptw_req_sum;
      req_ent.mprv = m_last_l2tlb_ptw_req_mprv;
      req_ent.mpp = m_last_l2tlb_ptw_req_mpp;
      req_ent.req_time = m_last_l2tlb_ptw_req_time;
      req_ent.req_cycle = m_last_l2tlb_ptw_req_cycle;
      return 1'b1;
    end

    return 1'b0;
  endfunction

  protected function bit _lsu_satp_midwalk_old_refill_waive(
    input  string       channel,
    input  xlation_rsp_t ref_rsp,
    input  bit          exp_fault,
    input  bit          dut_fault,
    input  bit [26:0]   req_vpn,
    input  bit [6:0]    lsu_iid,
    input  bit [27:0]   dut_pa,
    input  bit          tr_mmu_en,
    input  bit          skip_ref_ppn_check,
    input  bit          skip_lsu_dtlb_ref_compare,
    output ptw_req_shadow_entry_t req_ent,
    output longint unsigned refill_age_cycles,
    output longint unsigned satp_age_cycles
  );
    _ptw_req_shadow_entry_clear(req_ent);
    refill_age_cycles = 0;
    satp_age_cycles = 0;

    if (!((channel == "LSU_P0") || (channel == "LSU_P1")))
      return 1'b0;
    if (!tr_mmu_en || !exp_fault || dut_fault || skip_ref_ppn_check || skip_lsu_dtlb_ref_compare)
      return 1'b0;
    if ((ref_rsp.exc != EXC_PAGE_FAULT) || ref_rsp.deny)
      return 1'b0;
    if (!_recent_satp_root_change_seen(satp_age_cycles))
      return 1'b0;
    if (!_ptw_request_started_before_satp_change(req_vpn, lsu_iid, req_ent))
      return 1'b0;
    if (!_recent_ptw_l1d_refill_matches(req_vpn, lsu_iid, dut_pa, refill_age_cycles))
      return 1'b0;

    return 1'b1;
  endfunction

  protected function bit _lsu_satp_midwalk_ref_context(
    input  string       channel,
    input  bit [26:0]   req_vpn,
    input  bit [6:0]    lsu_iid,
    input  bit [27:0]   dut_pa,
    input  bit          tr_mmu_en,
    input  bit          skip_ref_ppn_check,
    input  bit          skip_lsu_dtlb_ref_compare,
    output ptw_req_shadow_entry_t req_ent,
    output bit          refill_match,
    output longint unsigned refill_age_cycles,
    output longint unsigned satp_age_cycles
  );
    _ptw_req_shadow_entry_clear(req_ent);
    refill_match = 1'b0;
    refill_age_cycles = 0;
    satp_age_cycles = 0;

    if (!((channel == "LSU_P0") || (channel == "LSU_P1")))
      return 1'b0;
    if (!tr_mmu_en || skip_ref_ppn_check || skip_lsu_dtlb_ref_compare)
      return 1'b0;
    if (!_recent_satp_root_change_seen(satp_age_cycles))
      return 1'b0;
    if (!_ptw_request_started_before_satp_change(req_vpn, lsu_iid, req_ent))
      return 1'b0;

    // The reference context is defined by the accepted PTW request.  A matching
    // PTW->L1D refill is useful evidence, but it can be sampled in a different
    // delta from the LSU response.  Do not fall back to the current SATP root
    // solely because that refill record is not visible to this scoreboard call.
    refill_match = _recent_ptw_l1d_refill_matches(req_vpn, lsu_iid, dut_pa,
                                                  refill_age_cycles);

    return 1'b1;
  endfunction

  protected function xlation_rsp_t _translate_lsu_with_midwalk_context(
    input string     channel,
    input va_t       va,
    input acc_type_e acc,
    input bit [27:0] dut_pa,
    input bit [6:0]  lsu_iid,
    input bit        tr_mmu_en,
    input bit        skip_ref_ppn_check,
    output bit       used_midwalk_ctx
  );
    xlation_rsp_t ref_rsp;
    ptw_req_shadow_entry_t req_ent;
    bit refill_match;
    longint unsigned refill_age_cycles;
    longint unsigned satp_age_cycles;
    int pmp_port_idx;

    pmp_port_idx = (channel == "LSU_P1") ? 1 : 0;
    used_midwalk_ctx = 1'b0;

    // Drain CSR/PMP/SysMap FIFOs before either current-context or old-context
    // translation so non-SATP attributes remain coherent with the monitor.
    m_ref.sync_shadow_state();

    if (_lsu_satp_midwalk_ref_context(channel, va[38:12], lsu_iid, dut_pa,
                                      tr_mmu_en, skip_ref_ppn_check, 1'b0,
                                      req_ent, refill_match,
                                      refill_age_cycles, satp_age_cycles)) begin
      ref_rsp = m_ref.translate_with_twu_context(
        va, acc, req_ent.satp_ppn, 4'h8, req_ent.priv_mode,
        req_ent.mxr, req_ent.sum, req_ent.mprv, req_ent.mpp, pmp_port_idx,
        "satp_midwalk_old_accept");
      used_midwalk_ctx = 1'b1;
      `uvm_info(get_type_name(),
        $sformatf("[%s] PTW_TRANSLATION_SB_REF_CONTEXT class=satp_midwalk_old_accept VA=0x%010h iid=%0d req_vpn=0x%07h satp_ppn=0x%07h asid=0x%04h refill_match=%0b refill_age_cycles=%0d satp_age_cycles=%0d ref.exc=%s ref.ppn=0x%07h dut.pa=0x%07h",
          channel, {1'b0, va}, lsu_iid, va[38:12], req_ent.satp_ppn,
          req_ent.asid, refill_match, refill_age_cycles, satp_age_cycles,
          ref_rsp.exc.name(), ref_rsp.ppn, dut_pa),
        UVM_MEDIUM)
      return ref_rsp;
    end

    ref_rsp = m_ref.translate(va, acc, pmp_port_idx, 1'b1);
    return ref_rsp;
  endfunction

  protected function string _lsu_pipe_label(input string channel);
    if (channel == "LSU_P1")
      return "pipe=1";
    if (channel == "LSU_P0")
      return "pipe=0";
    return "pipe=-1";
  endfunction

  protected function void _phase6b_log_classification(
    input string        channel,
    input string        cls,
    input va_t          va,
    input bit [27:0]    req_vpn,
    input bit [6:0]     iid,
    input xlation_rsp_t ref_rsp,
    input bit [27:0]    dut_pa,
    input bit           dut_fault,
    input bit           tr_pgflt,
    input bit           tr_access_fault,
    input string        extra = ""
  );
    `uvm_info(get_type_name(),
      $sformatf("[%s] PHASE6B_TRANSLATION_CLASS class=%s cycle=%0d %s iid=%0d VA=0x%010h vpn=0x%07h ref.exc=%s ref.deny=%0b ref.ppn=0x%07h dut.pa=0x%07h dut_fault=%0b dut.pgflt=%0b dut.acflt=%0b %s",
        channel, cls, m_probe_cycle, _lsu_pipe_label(channel), iid, {1'b0, va},
        req_vpn[26:0], ref_rsp.exc.name(), ref_rsp.deny, ref_rsp.ppn,
        dut_pa, dut_fault, tr_pgflt, tr_access_fault, extra),
      UVM_MEDIUM)
  endfunction

  // =========================================================================
  // write_ifu — IFU fetch translation check
  //   Access type: ACC_FETCH
  //   Fault signals: tr.pgflt (page fault) | tr.deny (PMP/sysmap deny)
  //   Skip when tr.abort==1 (pipeline abort, no valid translation)
  // =========================================================================
  virtual function void write_ifu(ifu_txn tr);
    xlation_rsp_t ref_rsp;
    va_t          va;
    bit           dut_fault;

    if (tr.abort) begin
      `uvm_info(get_type_name(),
        $sformatf("write_ifu: abort=1, VA=0x%010h — skipping check", {1'b0, tr.va}),
        UVM_HIGH)
      return;
    end

    m_total_checked++;
    va        = va_t'(tr.va[38:0]);
    ref_rsp   = m_ref.translate(va, ACC_FETCH, 2);
    dut_fault = tr.pgflt | tr.deny;

    _compare(.channel("IFU"), .va(va), .ref_rsp(ref_rsp),
             .dut_pa(tr.pa),  .dut_fault(dut_fault),
             .tr_pgflt(tr.pgflt), .tr_deny(tr.deny),
             .ifu_dbg_iutlb_acc_flt(tr.dbg_iutlb_acc_flt),
             .ifu_dbg_iutlb_pmp_deny(tr.dbg_iutlb_pmp_deny),
             .ifu_dbg_iutlb_ref_pgflt(tr.dbg_iutlb_ref_pgflt),
             .ifu_dbg_jtlb_acc_fault_flop(tr.dbg_jtlb_acc_fault_flop));
  endfunction

  // =========================================================================
  // write_lsu_p0 — LSU Pipe 0 load/store translation check
  //   Access type: ACC_STORE if tr.st_inst==1, else ACC_LOAD
  //   Fault signals: tr.pgflt | tr.access_fault
  //   Skip when tr.abort==1
  // =========================================================================
  virtual function void write_lsu_p0(lsu_txn tr);
    xlation_rsp_t ref_rsp;
    va_t          va;
    acc_type_e    acc;
    bit           dut_fault;
    bit           used_midwalk_ctx;

    if (tr.abort) begin
      `uvm_info(get_type_name(),
        $sformatf("write_lsu_p0: abort=1, VA=0x%016h — skipping check", tr.va),
        UVM_HIGH)
      return;
    end

    m_total_checked++;
    va        = va_t'(tr.va[38:0]);
    acc       = tr.st_inst ? ACC_STORE : ACC_LOAD;
    ref_rsp   = _translate_lsu_with_midwalk_context("LSU_P0", va, acc, tr.pa,
                                                    tr.id, tr.mmu_en, 1'b0,
                                                    used_midwalk_ctx);
    dut_fault = tr.pgflt | tr.access_fault;

    _compare(.channel("LSU_P0"), .va(va), .ref_rsp(ref_rsp),
             .dut_pa(tr.pa),     .dut_fault(dut_fault),
             .req_vpn(va[38:12]), .dbg_valid(1'b1),
             .lsu_iid(tr.id),
             .tr_stall(tr.stall), .tr_pgflt(tr.pgflt),
             .tr_access_fault(tr.access_fault), .tr_mmu_en(tr.mmu_en),
             .dtlb_expt_match(tr.dtlb_expt_match));
  endfunction

  // =========================================================================
  // write_lsu_p1 — LSU Pipe 1 load/store translation check (same as pipe0)
  //   Access type: ACC_STORE if tr.st_inst==1, else ACC_LOAD
  // =========================================================================
  virtual function void write_lsu_p1(lsu_txn tr);
    xlation_rsp_t ref_rsp;
    va_t          va;
    acc_type_e    acc;
    bit           dut_fault;
    bit           used_midwalk_ctx;

    if (tr.abort) begin
      `uvm_info(get_type_name(),
        $sformatf("write_lsu_p1: abort=1, VA=0x%016h — skipping check", tr.va),
        UVM_HIGH)
      return;
    end

    m_total_checked++;
    va        = va_t'(tr.va[38:0]);
    acc       = tr.st_inst ? ACC_STORE : ACC_LOAD;
    ref_rsp   = _translate_lsu_with_midwalk_context("LSU_P1", va, acc, tr.pa,
                                                    tr.id, tr.mmu_en,
                                                    tr.stamo_vld_at_rsp,
                                                    used_midwalk_ctx);
    dut_fault = tr.pgflt | tr.access_fault;

    if (tr.stamo_vld_at_rsp && (tr.pa !== tr.stamo_pa_at_rsp)) begin
      `uvm_error(get_type_name(),
        $sformatf("[LSU_P1] STAMO vld: expected dut.pa=lsu_mmu_stamo_pa, got pa=0x%07h stamo=0x%07h (VA=0x%010h)",
          tr.pa, tr.stamo_pa_at_rsp, {1'b0, va}))
    end else if (tr.stamo_vld_at_rsp) begin
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P1] PHASE6B_TRANSLATION_CLASS class=stamo_pipe1_bypass trigger=monitor_rsp iid=%0d VA=0x%010h dut.pa=0x%07h stamo_pa=0x%07h",
          tr.id, {1'b0, va}, tr.pa, tr.stamo_pa_at_rsp),
        UVM_MEDIUM)
    end

    _compare(.channel("LSU_P1"), .va(va), .ref_rsp(ref_rsp),
             .dut_pa(tr.pa),     .dut_fault(dut_fault),
             .req_vpn(va[38:12]), .dbg_valid(1'b1),
             .lsu_iid(tr.id),
             .tr_stall(tr.stall), .tr_pgflt(tr.pgflt),
             .tr_access_fault(tr.access_fault), .tr_mmu_en(tr.mmu_en),
             .skip_ref_ppn_check(tr.stamo_vld_at_rsp),
             .dtlb_expt_match(tr.dtlb_expt_match));
  endfunction

  // =========================================================================
  // write_lsu_p2 — LSU Pipe 2 prefetch translation check
  //   Access type: ACC_PFU (always prefetch)
  //   VA source: tr.va2[26:0] reconstructed as VA[38:12] (27-bit VPN << 12).
  //
  //   Pipe2 monitor correlates the single-outstanding PFU req VA into rsp txn.
  //   If va2_valid is low due to an orphan/legacy rsp, count only and skip compare.
  // =========================================================================
  virtual function void write_lsu_p2(lsu_txn tr);
    xlation_rsp_t ref_rsp;
    va_t          va;
    bit           exp_fault;
    bit           dut_fault;
    bit           pfu_deny;
    bit           pfu_acc_fault;
    bit           pfu_flag_fault;
    bit           pfu_error;
    bit           pfu_payload_ignore;
    bit [3:0]     pfu_pmp_flg4;
    bit [4:0]     pfu_sysmap_flg4;

    m_total_checked++;

    if (!tr.va2_valid) begin
      `uvm_info(get_type_name(),
        "write_lsu_p2: va2 invalid (orphan/legacy pipe2 rsp) — count only",
        UVM_DEBUG)
      return;
    end

    // Reconstruct 39-bit VA: take lower 27 bits of va2 as VPN (VA[38:12]),
    // append 12-bit zero page offset.
    va      = va_t'({tr.va2[26:0], 12'b0});
    ref_rsp = m_ref.translate(va, ACC_PFU, 4);
    exp_fault = (ref_rsp.exc != EXC_NONE) || ref_rsp.deny;
    dut_fault = tr.access_fault;
    pfu_deny = (v_probe != null) ? v_probe.mon_cb.pfu_l2tlb_deny : 1'b0;
    pfu_acc_fault = (v_probe != null) ? v_probe.mon_cb.pfu_l2tlb_acc_fault : tr.access_fault;
    pfu_flag_fault = (v_probe != null) ? v_probe.mon_cb.pfu_l2tlb_flag_fault : 1'b0;
    pfu_pmp_flg4 = (v_probe != null) ? v_probe.mon_cb.pfu_pmp_flg4 : '0;
    pfu_sysmap_flg4 = (v_probe != null) ? v_probe.mon_cb.pfu_sysmap_flg4 : '0;
    // mmu_lsu_pa2_err is driven from the PFU_DENY response state.  The raw
    // l2tlb_pfu_flag_fault probe is combinational diagnostic context: it does
    // not by itself require pa2_err, but it does make the PFU PA payload
    // architecturally non-comparable for this response.
    pfu_error = dut_fault || pfu_deny || pfu_acc_fault;
    pfu_payload_ignore = pfu_error || pfu_flag_fault;
    if (m_l2_shadow != null) begin
      m_l2_shadow.on_pfu_response(1'b1,
        pfu_deny,
        pfu_acc_fault,
        pfu_flag_fault,
        tr.va2[26:0],
        tr.pa,
        (tr.mmu_en === 1'b0),
        tr.asid);
    end

    if (pfu_payload_ignore) begin
      if (!dut_fault && (pfu_deny || pfu_acc_fault)) begin
        `uvm_error(get_type_name(),
          $sformatf("[LSU_P2][PFU_ERROR_CLASS] VA=0x%010h: PFU deny/acc_fault classified but DUT access_fault=0 deny=%0b acc_fault=%0b flag_fault=%0b pa=0x%07h",
            {1'b0, va}, pfu_deny, pfu_acc_fault, pfu_flag_fault, tr.pa))
        m_mismatch++;
        return;
      end
      m_pfu_error_payload_ignore_rsp++;
      if (pfu_flag_fault && !pfu_error)
        m_pfu_flag_only_diag_rsp++;
      `uvm_info({get_type_name(), "::PHASE6G_TIMEOUT_FAIRNESS"},
        $sformatf("[PHASE6G_TIMEOUT_FAIRNESS_PFU_PAYLOAD_IGNORE] issue=L2TLB-P6-ISSUE-013 va=0x%010h vpn=0x%07h pa=0x%07h deny=%0b acc_fault=%0b flag_fault=%0b pmp_flg4=0x%0h ref_pmp_flg4=0x%0h sysmap_flg4=0x%02h ref.exc=%s ref.deny=%0b action=skip_pa_payload_compare",
          {1'b0, va}, tr.va2[26:0], tr.pa, pfu_deny, pfu_acc_fault,
          pfu_flag_fault, pfu_pmp_flg4, m_ref.m_pmp_flg[4], pfu_sysmap_flg4,
          ref_rsp.exc.name(), ref_rsp.deny),
        UVM_MEDIUM)
      return;
    end

    // Pipe2 top-level reports a combined translation/PMP error bit.  Check the
    // fault bit first so an unexpected PMP deny is not misdiagnosed as PA=0.
    if (exp_fault !== dut_fault) begin
      `uvm_error(get_type_name(),
        $sformatf("[LSU_P2] VA=0x%010h: fault mismatch - ref.exc=%s ref.deny=%0b exp_fault=%0b dut.access_fault=%0b dut.pa=0x%07h",
          {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, exp_fault, dut_fault, tr.pa))
      if (v_probe != null) begin
        `uvm_error(get_type_name(),
          $sformatf("[LSU_P2][WB] pmp_flg4=0x%0h ref_pmp_flg4=0x%0h sysmap_flg4=0x%02h pfu_deny=%0b pfu_acc_fault=%0b pfu_flag_fault=%0b last_ptw_l2_ref={valid:%0b pgflt:%0b acc_err:%0b age:%0t}",
            v_probe.mon_cb.pfu_pmp_flg4, m_ref.m_pmp_flg[4],
            v_probe.mon_cb.pfu_sysmap_flg4,
            v_probe.mon_cb.pfu_l2tlb_deny,
            v_probe.mon_cb.pfu_l2tlb_acc_fault,
            v_probe.mon_cb.pfu_l2tlb_flag_fault,
            m_last_ptw_l2_ref_valid, m_last_ptw_l2_ref_pgflt,
            m_last_ptw_l2_ref_acc_err, $time - m_last_ptw_l2_ref_time))
      end
      m_mismatch++;
      return;
    end

    // Restrict PA comparison to no-fault cases on both reference and DUT.
    if (exp_fault) begin
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P2] VA=0x%010h ref.exc=%s ref.deny=%0b dut.access_fault=%0b - skip PA compare on fault case",
          {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, dut_fault),
        UVM_MEDIUM)
      return;
    end

    if (ref_rsp.ppn !== tr.pa) begin
      // If DUT PA is all zeros the translation result is not yet valid.
      // Skip PA comparison rather than reporting a spurious mismatch.
      if (tr.pa === '0) begin
        `uvm_info(get_type_name(),
          $sformatf("[LSU_P2] VA=0x%010h: skip PA compare — dut.pa is zero (translation not complete)",
            {1'b0, va}),
          UVM_HIGH)
        return;
      end
      `uvm_error(get_type_name(),
        $sformatf("[LSU_P2] VA=0x%010h: PA mismatch — ref.ppn=0x%07h  dut.pa=0x%07h",
          {1'b0, va}, ref_rsp.ppn, tr.pa))
      m_mismatch++;
    end else begin
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P2] VA=0x%010h  ref.ppn=0x%07h  dut.pa=0x%07h  PASS",
          {1'b0, va}, ref_rsp.ppn, tr.pa),
        UVM_HIGH)
    end
  endfunction

  // =========================================================================
  // report_phase — print summary and trigger final error if mismatches found
  // =========================================================================
  virtual function void report_phase(uvm_phase phase);
    `uvm_info(get_type_name(),
      $sformatf("Translation SB summary: total_checked=%0d mismatch=%0d lsu_fault_replay_rsp=%0d lsu_replay_mismatch=%0d lsu_replay_waive_rsp=%0d lsu_expt_replay_rsp=%0d lsu_expt_replay_timing_waive_rsp=%0d lsu_expt_replay_orphan_rsp=%0d lsu_pmp_t1_waive_rsp=%0d lsu_satp_midwalk_waive_rsp=%0d ifu_accerr_waive_rsp=%0d ifu_refpgflt_waive_rsp=%0d p6b_expt=%0d p6b_expt_timing=%0d p6b_expt_orphan=%0d p6b_pmp_t1=%0d p6b_satp_midwalk=%0d p6b_stamo=%0d p6b_direct=%0d p6b_remaining_broad=%0d p6g_pfu_error_payload_ignore=%0d p6g_pfu_flag_only_diag=%0d",
        m_total_checked, m_mismatch, m_lsu_fault_replay_rsp, m_lsu_replay_mismatch,
        m_lsu_replay_waive_rsp, m_lsu_expt_replay_rsp,
        m_lsu_expt_replay_timing_waive_rsp, m_lsu_expt_replay_orphan_rsp,
        m_lsu_pmp_t1_waive_rsp, m_lsu_satp_midwalk_waive_rsp,
        m_ifu_accerr_waive_rsp, m_ifu_refpgflt_waive_rsp,
        m_lsu_phase6b_expt_classified_rsp,
        m_lsu_phase6b_expt_timing_classified_rsp,
        m_lsu_phase6b_expt_orphan_rsp,
        m_lsu_phase6b_pmp_t1_classified_rsp,
        m_lsu_phase6b_satp_midwalk_classified_rsp,
        m_lsu_phase6b_stamo_classified_rsp,
        m_lsu_phase6b_direct_map_classified_rsp,
        m_lsu_phase6b_remaining_broad_waive_rsp,
        m_pfu_error_payload_ignore_rsp,
        m_pfu_flag_only_diag_rsp),
      UVM_NONE)
    `uvm_info({get_type_name(), "::PHASE6G_TIMEOUT_FAIRNESS"},
      $sformatf("status=implemented issue=L2TLB-P6-ISSUE-013 pfu_error_payload_ignore=%0d pfu_flag_only_diag=%0d diagnostics='va,vpn,pa,pfu_error_bits,pmp,sysmap,ref'",
        m_pfu_error_payload_ignore_rsp, m_pfu_flag_only_diag_rsp),
      UVM_NONE)
    `uvm_info({get_type_name(), "::PHASE6B_TRANSLATION_TAXONOMY"},
      $sformatf("status=implemented lsu_expt=%0d lsu_expt_timing=%0d lsu_expt_orphan=%0d lsu_pmp_t1=%0d lsu_satp_midwalk=%0d lsu_stamo=%0d lsu_direct=%0d remaining_broad_waive=%0d diagnostics='cycle,pipe,iid,va,vpn,reason,source,ref,dut'",
        m_lsu_phase6b_expt_classified_rsp,
        m_lsu_phase6b_expt_timing_classified_rsp,
        m_lsu_phase6b_expt_orphan_rsp,
        m_lsu_phase6b_pmp_t1_classified_rsp,
        m_lsu_phase6b_satp_midwalk_classified_rsp,
        m_lsu_phase6b_stamo_classified_rsp,
        m_lsu_phase6b_direct_map_classified_rsp,
        m_lsu_phase6b_remaining_broad_waive_rsp),
      UVM_NONE)
    if (m_l2_shadow != null)
      $display("[PHASE6C_L2_SHADOW] component=%s %s",
        get_full_name(), m_l2_shadow.summary());
    if (m_mismatch > 0)
      `uvm_error(get_type_name(),
        $sformatf("Translation SB FAILED: %0d mismatch(es) detected!", m_mismatch))
  endfunction

  // =========================================================================
  // _compare — internal comparison helper (channels IFU / LSU_P0 / LSU_P1)
  //
  //   ref_rsp.exc != EXC_NONE → expect dut_fault == 1
  //   ref_rsp.exc == EXC_NONE → expect dut_fault == 0 AND ref.ppn == dut_pa
  //   skip_ref_ppn_check: DUT muxes PPN from STAMO (lsu_mmu_stamo_*) at rsp —
  //   not comparable to mmu_ref_model.translate() (see mmu_l1dtlb dutlb_pre_pa).
  // =========================================================================
  protected function void _compare(
    string        channel,
    va_t          va,
    xlation_rsp_t ref_rsp,
    bit [27:0]    dut_pa,
    bit           dut_fault,
    bit [27:0]    req_vpn = '0,
    bit           dbg_valid = 1'b0,
    bit [6:0]     lsu_iid = '0,
    bit           tr_stall = 1'b0,
    bit           tr_pgflt = 1'b0,
    bit           tr_access_fault = 1'b0,
    bit           tr_deny = 1'b0,
    bit           tr_mmu_en = 1'b0,
    bit           skip_ref_ppn_check = 1'b0,
    bit           dtlb_expt_match = 1'b0,
    bit           ifu_dbg_iutlb_acc_flt = 1'b0,
    bit           ifu_dbg_iutlb_pmp_deny = 1'b0,
    bit           ifu_dbg_iutlb_ref_pgflt = 1'b0,
    bit           ifu_dbg_jtlb_acc_fault_flop = 1'b0
  );
    // Treat deny as a fault-class outcome as well (for PMP/SysMap modeled paths).
    bit exp_fault = (ref_rsp.exc != EXC_NONE) || ref_rsp.deny;
    bit local_mismatch = 0;
    bit fault_replay_rsp = 0;
    // Ref does not model DTLB pre_sel/expt CAM; see file header.
    bit skip_lsu_dtlb_ref_compare;
    bit lsu_req_vpn_bypass_sig;
    bit lsu_pre_sel_probe_sig;
    int lsu_expt_cam_idx;
    bit lsu_expt_cam_hit;
    bit lsu_expt_cur_wr_hit;
    dtlb_expt_cam_entry_t lsu_expt_cam_ent;
    bit lsu_expt_replay_sig;
    bit lsu_expt_replay_rsp;
    bit lsu_expt_expected_fault;
    bit lsu_expt_fault_class_ok;
    bit lsu_expt_timing_waive;
    bit lsu_expt_orphan;
    bit lsu_pmp_t1_waive;
    bit lsu_satp_midwalk_waive;
    bit lsu_direct_map_class;
    bit lsu_stamo_class;
    ptw_req_shadow_entry_t lsu_satp_midwalk_req_ent;
    longint unsigned lsu_satp_midwalk_refill_age;
    longint unsigned lsu_satp_midwalk_satp_age;
    bit skip_ifu_accerr_fault_compare;
    bit skip_ifu_accerr_completion_compare;
    bit skip_ifu_refpgflt_fault_compare;

    // LSU: stats for fault responses under MMU (legacy visibility)
    fault_replay_rsp = dbg_valid
                    && tr_mmu_en
                    && dut_fault;
    if (fault_replay_rsp)
      m_lsu_fault_replay_rsp++;

    lsu_expt_cam_ent = '0;
    lsu_expt_cam_idx = dbg_valid ? _dtlb_expt_cam_find(lsu_iid, req_vpn[26:0]) : -1;
    lsu_expt_cam_hit = (lsu_expt_cam_idx >= 0);
    if (lsu_expt_cam_hit)
      lsu_expt_cam_ent = m_dtlb_expt_cam[lsu_expt_cam_idx];

    lsu_expt_cur_wr_hit = 1'b0;
    if (dbg_valid && !lsu_expt_cam_hit && (v_probe != null)) begin
      if (v_probe.l1d_expt_wr0_vld
          && (v_probe.l1d_expt_wr0_iid == lsu_iid)
          && (v_probe.l1d_expt_wr0_vpn == req_vpn[26:0])) begin
        lsu_expt_cur_wr_hit = 1'b1;
        lsu_expt_cam_ent.vld   = 1'b1;
        lsu_expt_cam_ent.iid   = v_probe.l1d_expt_wr0_iid;
        lsu_expt_cam_ent.vpn   = v_probe.l1d_expt_wr0_vpn;
        lsu_expt_cam_ent.pgflt = v_probe.l1d_expt_wr0_pgflt;
        lsu_expt_cam_ent.acflt = v_probe.l1d_expt_wr0_acflt;
        lsu_expt_cam_ent.eid   = v_probe.l1d_expt_wr0_eid;
      end else if (v_probe.l1d_expt_wr1_vld
          && (v_probe.l1d_expt_wr1_iid == lsu_iid)
          && (v_probe.l1d_expt_wr1_vpn == req_vpn[26:0])) begin
        lsu_expt_cur_wr_hit = 1'b1;
        lsu_expt_cam_ent.vld   = 1'b1;
        lsu_expt_cam_ent.iid   = v_probe.l1d_expt_wr1_iid;
        lsu_expt_cam_ent.vpn   = v_probe.l1d_expt_wr1_vpn;
        lsu_expt_cam_ent.pgflt = v_probe.l1d_expt_wr1_pgflt;
        lsu_expt_cam_ent.acflt = v_probe.l1d_expt_wr1_acflt;
        lsu_expt_cam_ent.eid   = v_probe.l1d_expt_wr1_eid;
      end
      lsu_expt_cam_hit = lsu_expt_cur_wr_hit;
    end

    lsu_pre_sel_probe_sig = 1'b0;
    if (dbg_valid && (v_probe != null)) begin
      if (channel == "LSU_P0")
        lsu_pre_sel_probe_sig = v_probe.l1d_p0_pre_sel;
      else if (channel == "LSU_P1")
        lsu_pre_sel_probe_sig = v_probe.l1d_p1_pre_sel;
    end

    lsu_req_vpn_bypass_sig = dbg_valid
      && tr_mmu_en
      && !tr_stall
      && (dut_pa == req_vpn)
      && !skip_ref_ppn_check
      && (dtlb_expt_match || lsu_expt_cam_hit || lsu_expt_cur_wr_hit || (v_probe == null));

    lsu_expt_replay_sig = dbg_valid
      && !skip_ref_ppn_check
      && (dtlb_expt_match || lsu_req_vpn_bypass_sig);

    lsu_expt_replay_rsp = lsu_expt_replay_sig
      || (dbg_valid && !skip_ref_ppn_check && lsu_expt_cam_hit && dut_fault);

    lsu_pmp_t1_waive = (channel == "LSU_P0" || channel == "LSU_P1")
                    && dbg_valid
                    && tr_mmu_en
                    && ref_rsp.deny
                    && (ref_rsp.exc == EXC_ACCESS_FAULT)
                    && !tr_pgflt
                    && !tr_access_fault
                    && !skip_ref_ppn_check
                    && !lsu_expt_replay_rsp;
    if (lsu_pmp_t1_waive)
      m_lsu_pmp_t1_waive_rsp++;

    lsu_expt_expected_fault = lsu_expt_cam_hit
      && (lsu_expt_cam_ent.pgflt || lsu_expt_cam_ent.acflt);

    lsu_expt_fault_class_ok = lsu_expt_cam_hit
      && (
           (lsu_expt_cam_ent.pgflt && tr_pgflt)
        || (lsu_expt_cam_ent.acflt && tr_access_fault)
      );

    lsu_expt_timing_waive = lsu_expt_expected_fault
      && !lsu_expt_fault_class_ok
      && dtlb_expt_match
      && lsu_req_vpn_bypass_sig;

    lsu_expt_orphan = lsu_expt_replay_sig && !lsu_expt_cam_hit;

    skip_lsu_dtlb_ref_compare = lsu_expt_replay_rsp;

    lsu_direct_map_class = dbg_valid
      && !tr_mmu_en
      && !skip_ref_ppn_check;

    lsu_stamo_class = dbg_valid
      && skip_ref_ppn_check
      && (channel == "LSU_P1");

    lsu_satp_midwalk_waive = _lsu_satp_midwalk_old_refill_waive(
      channel, ref_rsp, exp_fault, dut_fault, req_vpn[26:0], lsu_iid, dut_pa,
      tr_mmu_en, skip_ref_ppn_check, skip_lsu_dtlb_ref_compare,
      lsu_satp_midwalk_req_ent,
      lsu_satp_midwalk_refill_age, lsu_satp_midwalk_satp_age);

    if (lsu_expt_replay_rsp) begin
      m_lsu_expt_replay_rsp++;
      m_lsu_phase6b_expt_classified_rsp++;
      _phase6b_log_classification(channel, "expt_replay", va, req_vpn,
        lsu_iid, ref_rsp, dut_pa, dut_fault, tr_pgflt, tr_access_fault,
        $sformatf("shadow_hit=%0b cur_wr_hit=%0b shadow_pgflt=%0b shadow_acflt=%0b eid=%0d expt_match=%0b vpn_bypass=%0b",
          lsu_expt_cam_hit, lsu_expt_cur_wr_hit, lsu_expt_cam_ent.pgflt,
          lsu_expt_cam_ent.acflt, lsu_expt_cam_ent.eid, dtlb_expt_match,
          lsu_req_vpn_bypass_sig));
    end

    if (skip_lsu_dtlb_ref_compare)
      m_lsu_replay_waive_rsp++;

    if (lsu_expt_timing_waive) begin
      m_lsu_expt_replay_timing_waive_rsp++;
      m_lsu_phase6b_expt_timing_classified_rsp++;
      _phase6b_log_classification(channel, "expt_timing_boundary", va, req_vpn,
        lsu_iid, ref_rsp, dut_pa, dut_fault, tr_pgflt, tr_access_fault,
        "pre_sel/vpn-bypass response precedes aligned fault class");
    end

    if (lsu_satp_midwalk_waive) begin
      m_lsu_satp_midwalk_waive_rsp++;
      m_lsu_phase6b_satp_midwalk_classified_rsp++;
      _phase6b_log_classification(channel, "satp_midwalk_old_refill", va, req_vpn,
        lsu_iid, ref_rsp, dut_pa, dut_fault, tr_pgflt, tr_access_fault,
        $sformatf("refill_age_cycles=%0d satp_age_cycles=%0d old_satp_ppn=0x%07h new_satp_ppn=0x%07h old_asid=0x%04h new_asid=0x%04h",
          lsu_satp_midwalk_refill_age, lsu_satp_midwalk_satp_age,
          m_prev_satp_ppn, m_cur_satp_ppn, m_prev_satp_asid, m_cur_satp_asid));
    end

    if (lsu_pmp_t1_waive) begin
      m_lsu_phase6b_pmp_t1_classified_rsp++;
      _phase6b_log_classification(channel, "pmp_t1_access_fault_owned_by_l1dtlb_sb",
        va, req_vpn, lsu_iid, ref_rsp, dut_pa, dut_fault,
        tr_pgflt, tr_access_fault,
        "translation SB skips only T0 fault mismatch; Phase6B token queue owns previous-T1 access_fault");
    end

    if (lsu_direct_map_class) begin
      m_lsu_phase6b_direct_map_classified_rsp++;
      _phase6b_log_classification(channel, "direct_map", va, req_vpn,
        lsu_iid, ref_rsp, dut_pa, dut_fault, tr_pgflt, tr_access_fault,
        "mmu_lsu_mmu_en=0");
    end

    if (lsu_stamo_class) begin
      m_lsu_phase6b_stamo_classified_rsp++;
      _phase6b_log_classification(channel, "stamo_pipe1_bypass", va, req_vpn,
        lsu_iid, ref_rsp, dut_pa, dut_fault, tr_pgflt, tr_access_fault,
        "pipe1 PA sourced from LSU STAMO path");
    end

    if (skip_lsu_dtlb_ref_compare && lsu_expt_orphan)
      m_lsu_phase6b_remaining_broad_waive_rsp++;

    if (lsu_expt_replay_rsp && lsu_expt_cam_hit && !lsu_expt_cur_wr_hit && dtlb_expt_match)
      _dtlb_expt_cam_clear_match(lsu_iid, req_vpn[26:0]);

    if (lsu_expt_orphan) begin
      m_lsu_expt_replay_orphan_rsp++;
      m_lsu_phase6b_expt_orphan_rsp++;
      `uvm_warning(get_type_name(),
        $sformatf("[%s][PHASE6B_EXPT_REPLAY_ORPHAN] class=expt_orphan cycle=%0d %s iid=%0d vpn=0x%07h VA=0x%010h expt_match=%0b req_vpn_pa=%0b pre_sel_probe=%0b dut_fault=%0b dut.pa=0x%07h ref.exc=%s ref.deny=%0b remaining_broad_waive=%0d",
          channel, m_probe_cycle, _lsu_pipe_label(channel), lsu_iid,
          req_vpn[26:0], {1'b0, va}, dtlb_expt_match,
          lsu_req_vpn_bypass_sig, lsu_pre_sel_probe_sig, dut_fault, dut_pa,
          ref_rsp.exc.name(), ref_rsp.deny,
          m_lsu_phase6b_remaining_broad_waive_rsp))
    end

    // IFU access-fault can surface in two observable forms:
    //   1) completion-only pulse: pavld is visible while deny/pgflt are still 0
    //   2) faulted response: deny is already visible on the sampled rsp cycle
    // In both cases the software ref is not comparable because the rsp came
    // from the internal PTW/TWU acc_err completion path rather than a normal
    // translated fetch result.
    skip_ifu_accerr_completion_compare = ifu_dbg_iutlb_acc_flt
      && !tr_pgflt
      && !tr_deny
      && !ifu_dbg_iutlb_pmp_deny
      && !ifu_dbg_iutlb_ref_pgflt
      && !ifu_dbg_jtlb_acc_fault_flop;

    skip_ifu_accerr_fault_compare = ifu_dbg_iutlb_acc_flt
      && dut_fault
      && !tr_pgflt
      && !ifu_dbg_iutlb_pmp_deny
      && !ifu_dbg_iutlb_ref_pgflt;

    skip_ifu_refpgflt_fault_compare = ifu_dbg_iutlb_ref_pgflt
      && (ref_rsp.exc == EXC_NONE)
      && !ref_rsp.deny
      && dut_fault
      && tr_pgflt
      && !tr_deny
      && !ifu_dbg_iutlb_acc_flt
      && !ifu_dbg_jtlb_acc_fault_flop;

    if (skip_ifu_accerr_fault_compare || skip_ifu_accerr_completion_compare)
      m_ifu_accerr_waive_rsp++;
    if (skip_ifu_refpgflt_fault_compare)
      m_ifu_refpgflt_waive_rsp++;

    if (lsu_expt_replay_rsp && lsu_expt_cam_hit) begin
      if (lsu_expt_expected_fault
          && !lsu_expt_fault_class_ok
          && !lsu_expt_timing_waive) begin
        `uvm_error(get_type_name(),
          $sformatf("[%s][EXPT_REPLAY] iid=%0d vpn=0x%07h VA=0x%010h: fault class mismatch on DTLB exception replay - shadow(pgflt=%0b acflt=%0b eid=%0d cur_wr_hit=%0b) dut.pgflt=%0b dut.acflt=%0b expt_match=%0b req_vpn_pa=%0b dut.pa=0x%07h",
            channel, lsu_iid, req_vpn[26:0], {1'b0, va},
            lsu_expt_cam_ent.pgflt, lsu_expt_cam_ent.acflt, lsu_expt_cam_ent.eid,
            lsu_expt_cur_wr_hit, tr_pgflt, tr_access_fault, dtlb_expt_match,
            lsu_req_vpn_bypass_sig, dut_pa))
        m_lsu_replay_mismatch++;
        local_mismatch = 1;
      end
    end

    // ── Exception / fault check ───────────────────────────────────────────
    if (exp_fault !== dut_fault) begin
      if (!skip_lsu_dtlb_ref_compare
          && !lsu_pmp_t1_waive
          && !lsu_satp_midwalk_waive
          && !skip_ifu_accerr_completion_compare
          && !skip_ifu_accerr_fault_compare
          && !skip_ifu_refpgflt_fault_compare) begin
        if (fault_replay_rsp) begin
          `uvm_error(get_type_name(),
            $sformatf("[%s][EXPT_REPLAY] VA=0x%010h: fault mismatch on replay response — ref.exc=%s ref.deny=%0b (exp_fault=%0b) dut_fault=%0b dut.pa=0x%07h req_vpn=0x%07h",
              channel, {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, exp_fault, dut_fault, dut_pa, req_vpn))
          m_lsu_replay_mismatch++;
        end else begin
          if (dbg_valid) begin
            `uvm_error(get_type_name(),
              $sformatf("[%s] VA=0x%010h: fault mismatch — ref.exc=%s ref.deny=%0b (exp_fault=%0b) dut_fault=%0b",
                channel, {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, exp_fault, dut_fault))
          end else begin
            `uvm_error(get_type_name(),
              $sformatf("[%s] VA=0x%010h: fault mismatch — ref.exc=%s ref.deny=%0b (exp_fault=%0b) dut_fault=%0b dut.pgflt=%0b dut.deny=%0b dbg_ifu_pmp_deny=%0b dbg_iutlb_acc_flt=%0b dbg_iutlb_ref_pgflt=%0b dbg_jtlb_acc_fault_flop=%0b",
                channel, {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, exp_fault, dut_fault,
                tr_pgflt, tr_deny, ifu_dbg_iutlb_pmp_deny, ifu_dbg_iutlb_acc_flt,
                ifu_dbg_iutlb_ref_pgflt,
                ifu_dbg_jtlb_acc_fault_flop))
          end
        end
        local_mismatch = 1;
      end
    end

    // ── PA check — only when both ref and DUT predict no fault ────────────
    if (!exp_fault
        && !dut_fault
        && !skip_lsu_dtlb_ref_compare
        && !skip_ifu_accerr_completion_compare) begin
      if (!skip_ref_ppn_check && (ref_rsp.ppn !== dut_pa)) begin
        `uvm_error(get_type_name(),
          $sformatf("[%s] VA=0x%010h: PA mismatch — ref.ppn=0x%07h  dut.pa=0x%07h",
            channel, {1'b0, va}, ref_rsp.ppn, dut_pa))
        local_mismatch = 1;
      end
    end

    if (local_mismatch) begin
      if (dbg_valid) begin
        `uvm_error(get_type_name(),
          $sformatf("[%s][DBG] VA=0x%010h iid=%0d dut.pa=0x%07h req_vpn(va[38:12])=0x%07h | stall=%0b pgflt=%0b access_fault=%0b mmu_lsu_mmu_en=%0b dtlb_expt_match=%0b shadow_hit=%0b cur_wr_hit=%0b shadow_pgflt=%0b shadow_acflt=%0b shadow_eid=%0d req_vpn_pa=%0b skip_ref_ppn_check=%0b",
            channel, {1'b0, va}, lsu_iid, dut_pa, req_vpn,
            tr_stall, tr_pgflt, tr_access_fault, tr_mmu_en,
            dtlb_expt_match, lsu_expt_cam_hit, lsu_expt_cur_wr_hit, lsu_expt_cam_ent.pgflt,
            lsu_expt_cam_ent.acflt, lsu_expt_cam_ent.eid,
            lsu_req_vpn_bypass_sig, skip_ref_ppn_check))
        if (channel == "LSU_P0")
          _dump_lsu_p0_whitebox(va, ref_rsp, dut_pa, req_vpn);
        else if (channel == "LSU_P1")
          _dump_lsu_p1_whitebox(va, ref_rsp, dut_pa, req_vpn);
      end else begin
        `uvm_info(get_type_name(),
          $sformatf("[%s][DBG] VA=0x%010h dut.pa=0x%07h | pgflt=%0b deny=%0b dbg_ifu_pmp_deny=%0b dbg_iutlb_acc_flt=%0b dbg_iutlb_ref_pgflt=%0b dbg_jtlb_acc_fault_flop=%0b",
            channel, {1'b0, va}, dut_pa, tr_pgflt, tr_deny,
            ifu_dbg_iutlb_pmp_deny, ifu_dbg_iutlb_acc_flt,
            ifu_dbg_iutlb_ref_pgflt,
            ifu_dbg_jtlb_acc_fault_flop),
          UVM_NONE)
      end
      m_mismatch++;
    end else begin
      if (skip_lsu_dtlb_ref_compare) begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] PHASE6B_TRANSLATION_CLASS class=expt_replay compare=classified_skip VA=0x%010h iid=%0d ref.exc=%s shadow_hit=%0b cur_wr_hit=%0b pgflt=%0b acflt=%0b eid=%0d timing_boundary=%0b orphan=%0b expt_match=%0b vpn_bypass=%0b dut.pgflt=%0b dut.acflt=%0b dut.pa=0x%07h req_vpn=0x%07h",
            channel, {1'b0, va}, lsu_iid, ref_rsp.exc.name(),
            lsu_expt_cam_hit, lsu_expt_cur_wr_hit, lsu_expt_cam_ent.pgflt, lsu_expt_cam_ent.acflt,
            lsu_expt_cam_ent.eid, lsu_expt_timing_waive, lsu_expt_orphan,
            dtlb_expt_match, lsu_req_vpn_bypass_sig, tr_pgflt,
            tr_access_fault, dut_pa, req_vpn),
          UVM_HIGH)
      end else if (lsu_pmp_t1_waive) begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] PHASE6B_TRANSLATION_CLASS class=pmp_t1_access_fault_owned_by_l1dtlb_sb compare=classified_skip VA=0x%010h ref.exc=%s ref.deny=%0b dut.pgflt=%0b dut.acflt=%0b",
            channel, {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, tr_pgflt, tr_access_fault),
          UVM_HIGH)
      end else if (lsu_satp_midwalk_waive) begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] PHASE6B_TRANSLATION_CLASS class=satp_midwalk_old_refill compare=classified_skip VA=0x%010h iid=%0d req_vpn=0x%07h ref.exc=%s ref.deny=%0b dut.pa=0x%07h ptw_ref_ppn=0x%07h refill_age_cycles=%0d satp_age_cycles=%0d old_satp_ppn=0x%07h new_satp_ppn=0x%07h old_asid=0x%04h new_asid=0x%04h",
            channel, {1'b0, va}, lsu_iid, req_vpn[26:0], ref_rsp.exc.name(),
            ref_rsp.deny, dut_pa, m_last_ptw_ref_ppn, lsu_satp_midwalk_refill_age,
            lsu_satp_midwalk_satp_age, m_prev_satp_ppn, m_cur_satp_ppn,
            m_prev_satp_asid, m_cur_satp_asid),
          UVM_MEDIUM)
      end else if (skip_ifu_accerr_completion_compare) begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] VA=0x%010h  PTW acc_err completion-only IFU rsp observed (dbg_iutlb_acc_flt=1, pavld before deny flop): compare waived  ref.exc=%s ref.deny=%0b dut.pgflt=%0b dut.deny=%0b",
            channel, {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, tr_pgflt, tr_deny),
          UVM_HIGH)
      end else if (skip_ifu_accerr_fault_compare) begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] VA=0x%010h  PTW acc_err IFU rsp observed (dbg_iutlb_acc_flt=1): fault mismatch waived  ref.exc=%s ref.deny=%0b dut_fault=%0b",
            channel, {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, dut_fault),
          UVM_HIGH)
      end else if (skip_ifu_refpgflt_fault_compare) begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] VA=0x%010h  refill-state pgflt completion observed (dbg_iutlb_ref_pgflt=1): fault mismatch waived  ref.exc=%s ref.deny=%0b dut.pgflt=%0b dut.deny=%0b",
            channel, {1'b0, va}, ref_rsp.exc.name(), ref_rsp.deny, tr_pgflt, tr_deny),
          UVM_HIGH)
      end else if (skip_ref_ppn_check) begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] PHASE6B_TRANSLATION_CLASS class=stamo_pipe1_bypass compare=classified_skip VA=0x%010h dut.pa=0x%07h ref.exc=%s",
            channel, {1'b0, va}, dut_pa, ref_rsp.exc.name()),
          UVM_MEDIUM)
      end else begin
        `uvm_info(get_type_name(),
          $sformatf("[%s] VA=0x%010h  ref.ppn=0x%07h  dut.pa=0x%07h  exc=%s  PASS",
            channel, {1'b0, va}, ref_rsp.ppn, dut_pa, ref_rsp.exc.name()),
          UVM_HIGH)
      end
    end
  endfunction

  protected function void _dump_lsu_p0_whitebox(
    va_t          va,
    xlation_rsp_t ref_rsp,
    bit [27:0]    dut_pa,
    bit [27:0]    req_vpn
  );
    string src_hint;
    string rc_hint;
    string cur_refill_src;
    string last_refill_src;

    if (v_probe == null) begin
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P0][WB] VA=0x%010h ref.ppn=0x%07h dut.pa=0x%07h req_vpn=0x%07h | MMU_DUT_PROBES_VIF unavailable",
          {1'b0, va}, ref_rsp.ppn, dut_pa, req_vpn),
        UVM_NONE)
      return;
    end

    src_hint = "UNKNOWN";
    if (v_probe.l1d_p0_hit_vld && v_probe.l1d_p0_addr_hit && !v_probe.l1d_p0_pre_sel)
      src_hint = "L1DTLB_HIT";
    else if (v_probe.l1d_p0_expt_match || (dut_pa == req_vpn))
      src_hint = "L1DTLB_PRESEL_OR_REPLAY";
    else if (v_probe.l2_final_vld && v_probe.l2_final_tlb_hit && v_probe.l2_final_is_dtlb)
      src_hint = "L2TLB_HIT";
    else if (v_probe.ptw_l1d_ref_cmplt)
      src_hint = "PTW_REFILL";
    else if (v_probe.l2_dtlb_ref_cmplt || v_probe.l2_dtlb_ref_pavld)
      src_hint = "L2_TO_L1_REFILL";

    case (v_probe.l1d_refill_src)
      2'b01: cur_refill_src = "PTW";
      2'b10: cur_refill_src = "JTLB";
      2'b11: cur_refill_src = "WFI";
      default: cur_refill_src = "NONE";
    endcase

    case (m_last_l1_refill_src)
      2'b01: last_refill_src = "PTW";
      2'b10: last_refill_src = "JTLB";
      2'b11: last_refill_src = "WFI";
      default: last_refill_src = "NONE";
    endcase

    rc_hint = "NEED_WAVE_CHECK";
    if (v_probe.ptw_l1d_ref_cmplt
        && (v_probe.ptw_arb_vpn == req_vpn)
        && (v_probe.ptw_l1d_ref_ppn == ref_rsp.ppn)) begin
      if (v_probe.l1d_refill_vld
          && (v_probe.l1d_refill_vpn == req_vpn)
          && (v_probe.l1d_refill_ppn == ref_rsp.ppn)) begin
        if (v_probe.l1d_p0_hit_vld && (v_probe.l1d_p0_hit_ppn != ref_rsp.ppn))
          rc_hint = "PTW_OK_REFILL_OK_BUT_P0_HIT_ENTRY_WRONG";
        else if (v_probe.l1d_p0_pre_sel)
          rc_hint = "PTW_OK_REFILL_OK_BUT_PRESEL_OVERRIDES_P0_HIT";
        else
          rc_hint = "PTW_OK_REFILL_OK_CHECK_PA0_OUTPUT_CHAIN";
      end else begin
        rc_hint = "PTW_OK_BUT_NO_MATCHING_L1_REFILL_OBSERVED";
      end
    end else if (m_last_l1_refill_valid
                 && (m_last_l1_refill_vpn == req_vpn)
                 && (m_last_l1_refill_ppn == ref_rsp.ppn)) begin
      if (v_probe.l1d_p0_hit_vld && (v_probe.l1d_p0_hit_ppn != ref_rsp.ppn))
        rc_hint = "LAST_REFILL_MATCHED_BUT_CURRENT_P0_HIT_ENTRY_WRONG";
      else if (v_probe.l1d_p0_pre_sel)
        rc_hint = "LAST_REFILL_MATCHED_BUT_PRESEL_ACTIVE";
      else if (!v_probe.l1d_p0_hit_vld)
        rc_hint = "LAST_REFILL_MATCHED_BUT_NO_P0_HIT_VISIBLE";
      else
        rc_hint = "LAST_REFILL_MATCHED_CHECK_PA0_OUTPUT_CHAIN";
    end else if (v_probe.l1d_p0_hit_vld && (v_probe.l1d_p0_hit_ppn == dut_pa) && (dut_pa != ref_rsp.ppn)) begin
      rc_hint = "CURRENT_P0_HIT_SELECTED_MISMATCHED_ENTRY";
    end

    `uvm_info(get_type_name(),
      $sformatf(
        "[LSU_P0][WB] VA=0x%010h ref.ppn=0x%07h dut.pa=0x%07h req_vpn=0x%07h src_hint=%s rc_hint=%s | L1: req_vpn=0x%07h addr_hit=%0b hit_vld=%0b miss_vld=%0b pre_sel=%0b expt_match=%0b entry_pa=0x%07h off_pa=0x%07h fin_pa=0x%07h | L1_REFILL: vld=%0b src=%s idx=%0d vpn=0x%07h ppn=0x%07h pgs=0x%0h entry_upd=0x%04h refill_iid0=%0d refill_iid1=%0d refill_iid_sel=%0d | P0_HIT: vec=0x%04h idx=%0d vpn=0x%07h ppn=0x%07h pgs=0x%0h | L2: final_vld=%0b final_hit=%0b miss=%0b is_dtlb=%0b final_vpn=0x%07h final_hit_ppn=0x%07h ref_pavld=%0b ref_cmplt=%0b ref_vpn=0x%07h ref_ppn=0x%07h | PTW: ref_cmplt=%0b ref_id=%0d mb_vld=%0b mb_iid=%0d mb_vpn=0x%07h arb_vpn=0x%07h ref_ppn=0x%07h | LAST_L2: valid=%0b t=%0t pavld=%0b cmplt=%0b vpn=0x%07h ppn=0x%07h | LAST_L1_REFILL: valid=%0b t=%0t src=%s idx=%0d vpn=0x%07h ppn=0x%07h pgs=0x%0h upd=0x%04h | LAST_PTW: valid=%0b t=%0t id=%0d mb_vld=%0b mb_iid=%0d mb_vpn=0x%07h arb_vpn=0x%07h ppn=0x%07h",
        {1'b0, va}, ref_rsp.ppn, dut_pa, req_vpn, src_hint, rc_hint,
        v_probe.l1d_p0_req_vpn, v_probe.l1d_p0_addr_hit, v_probe.l1d_p0_hit_vld,
        v_probe.l1d_p0_miss_vld, v_probe.l1d_p0_pre_sel, v_probe.l1d_p0_expt_match,
        v_probe.l1d_p0_entry_pa, v_probe.l1d_p0_off_pa, v_probe.l1d_p0_fin_pa,
        v_probe.l1d_refill_vld, cur_refill_src, v_probe.l1d_refill_idx,
        v_probe.l1d_refill_vpn, v_probe.l1d_refill_ppn, v_probe.l1d_refill_pgs,
        v_probe.l1d_entry_upd, v_probe.l1d_refill_iid0, v_probe.l1d_refill_iid1,
        v_probe.l1d_refill_iid_sel, v_probe.l1d_p0_hit_vec, v_probe.l1d_p0_hit_idx,
        v_probe.l1d_p0_hit_vpn, v_probe.l1d_p0_hit_ppn, v_probe.l1d_p0_hit_pgs,
        v_probe.l2_final_vld, v_probe.l2_final_tlb_hit, v_probe.l2_miss,
        v_probe.l2_final_is_dtlb, v_probe.l2_final_vpn, v_probe.l2_final_hit_ppn,
        v_probe.l2_dtlb_ref_pavld, v_probe.l2_dtlb_ref_cmplt,
        v_probe.l2_dtlb_ref_vpn, v_probe.l2_dtlb_ref_ppn,
        v_probe.ptw_l1d_ref_cmplt, v_probe.ptw_l1d_ref_id,
        v_probe.l1d_ptw_ref_mb_vld, v_probe.l1d_ptw_ref_mb_iid, v_probe.l1d_ptw_ref_mb_vpn,
        v_probe.ptw_arb_vpn, v_probe.ptw_l1d_ref_ppn,
        m_last_l2_ref_valid, m_last_l2_ref_time, m_last_l2_ref_pavld,
        m_last_l2_ref_cmplt, m_last_l2_ref_vpn, m_last_l2_ref_ppn,
        m_last_l1_refill_valid, m_last_l1_refill_time, last_refill_src,
        m_last_l1_refill_idx, m_last_l1_refill_vpn, m_last_l1_refill_ppn,
        m_last_l1_refill_pgs, m_last_l1_entry_upd, m_last_ptw_ref_valid,
        m_last_ptw_ref_time, m_last_ptw_ref_id, m_last_ptw_ref_mb_vld,
        m_last_ptw_ref_mb_iid, m_last_ptw_ref_mb_vpn, m_last_ptw_arb_vpn,
        m_last_ptw_ref_ppn),
      UVM_NONE)
  endfunction

  protected function void _dump_lsu_p1_whitebox(
    va_t          va,
    xlation_rsp_t ref_rsp,
    bit [27:0]    dut_pa,
    bit [27:0]    req_vpn
  );
    string src_hint;
    string rc_hint;
    string cur_refill_src;
    string last_refill_src;

    if (v_probe == null) begin
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P1][WB] VA=0x%010h ref.ppn=0x%07h dut.pa=0x%07h req_vpn=0x%07h | MMU_DUT_PROBES_VIF unavailable",
          {1'b0, va}, ref_rsp.ppn, dut_pa, req_vpn),
        UVM_NONE)
      return;
    end

    src_hint = "UNKNOWN";
    if (v_probe.l1d_p1_hit_vld && v_probe.l1d_p1_addr_hit && !v_probe.l1d_p1_pre_sel)
      src_hint = "L1DTLB_HIT";
    else if (v_probe.l1d_p1_expt_match || (dut_pa == req_vpn))
      src_hint = "L1DTLB_PRESEL_OR_REPLAY";
    else if (v_probe.l2_final_vld && v_probe.l2_final_tlb_hit && v_probe.l2_final_is_dtlb)
      src_hint = "L2TLB_HIT";
    else if (v_probe.ptw_l1d_ref_cmplt)
      src_hint = "PTW_REFILL";
    else if (v_probe.l2_dtlb_ref_cmplt || v_probe.l2_dtlb_ref_pavld)
      src_hint = "L2_TO_L1_REFILL";

    case (v_probe.l1d_refill_src)
      2'b01: cur_refill_src = "PTW";
      2'b10: cur_refill_src = "JTLB";
      2'b11: cur_refill_src = "WFI";
      default: cur_refill_src = "NONE";
    endcase

    case (m_last_l1_refill_src)
      2'b01: last_refill_src = "PTW";
      2'b10: last_refill_src = "JTLB";
      2'b11: last_refill_src = "WFI";
      default: last_refill_src = "NONE";
    endcase

    rc_hint = "NEED_WAVE_CHECK";
    if (v_probe.ptw_l1d_ref_cmplt
        && (v_probe.ptw_arb_vpn == req_vpn)
        && (v_probe.ptw_l1d_ref_ppn == ref_rsp.ppn)) begin
      if (v_probe.l1d_refill_vld
          && (v_probe.l1d_refill_vpn == req_vpn)
          && (v_probe.l1d_refill_ppn == ref_rsp.ppn)) begin
        if (v_probe.l1d_p1_hit_vld && (v_probe.l1d_p1_hit_ppn != ref_rsp.ppn))
          rc_hint = "PTW_OK_REFILL_OK_BUT_P1_HIT_ENTRY_WRONG";
        else if (v_probe.l1d_p1_pre_sel)
          rc_hint = "PTW_OK_REFILL_OK_BUT_PRESEL_OVERRIDES_P1_HIT";
        else
          rc_hint = "PTW_OK_REFILL_OK_CHECK_PA1_OUTPUT_CHAIN";
      end else begin
        rc_hint = "PTW_OK_BUT_NO_MATCHING_L1_REFILL_OBSERVED";
      end
    end else if (m_last_l1_refill_valid
                 && (m_last_l1_refill_vpn == req_vpn)
                 && (m_last_l1_refill_ppn == ref_rsp.ppn)) begin
      if (v_probe.l1d_p1_hit_vld && (v_probe.l1d_p1_hit_ppn != ref_rsp.ppn))
        rc_hint = "LAST_REFILL_MATCHED_BUT_CURRENT_P1_HIT_ENTRY_WRONG";
      else if (v_probe.l1d_p1_pre_sel)
        rc_hint = "LAST_REFILL_MATCHED_BUT_PRESEL_ACTIVE";
      else if (!v_probe.l1d_p1_hit_vld)
        rc_hint = "LAST_REFILL_MATCHED_BUT_NO_P1_HIT_VISIBLE";
      else
        rc_hint = "LAST_REFILL_MATCHED_CHECK_PA1_OUTPUT_CHAIN";
    end else if (v_probe.l1d_p1_hit_vld && (v_probe.l1d_p1_hit_ppn == dut_pa) && (dut_pa != ref_rsp.ppn)) begin
      rc_hint = "CURRENT_P1_HIT_SELECTED_MISMATCHED_ENTRY";
    end

    `uvm_info(get_type_name(),
      $sformatf(
        "[LSU_P1][WB] VA=0x%010h ref.ppn=0x%07h dut.pa=0x%07h req_vpn=0x%07h src_hint=%s rc_hint=%s | L1: req_vpn=0x%07h addr_hit=%0b hit_vld=%0b miss_vld=%0b pre_sel=%0b expt_match=%0b entry_pa=0x%07h off_pa=0x%07h fin_pa=0x%07h | L1_REFILL: vld=%0b src=%s idx=%0d vpn=0x%07h ppn=0x%07h pgs=0x%0h entry_upd=0x%04h refill_iid0=%0d refill_iid1=%0d refill_iid_sel=%0d | P1_HIT: vec=0x%04h idx=%0d vpn=0x%07h ppn=0x%07h pgs=0x%0h | L2: final_vld=%0b final_hit=%0b miss=%0b is_dtlb=%0b final_vpn=0x%07h final_hit_ppn=0x%07h ref_pavld=%0b ref_cmplt=%0b ref_vpn=0x%07h ref_ppn=0x%07h | PTW: ref_cmplt=%0b ref_id=%0d mb_vld=%0b mb_iid=%0d mb_vpn=0x%07h arb_vpn=0x%07h ref_ppn=0x%07h | LAST_L2: valid=%0b t=%0t pavld=%0b cmplt=%0b vpn=0x%07h ppn=0x%07h | LAST_L1_REFILL: valid=%0b t=%0t src=%s idx=%0d vpn=0x%07h ppn=0x%07h pgs=0x%0h upd=0x%04h | LAST_PTW: valid=%0b t=%0t id=%0d mb_vld=%0b mb_iid=%0d mb_vpn=0x%07h arb_vpn=0x%07h ppn=0x%07h",
        {1'b0, va}, ref_rsp.ppn, dut_pa, req_vpn, src_hint, rc_hint,
        v_probe.l1d_p1_req_vpn, v_probe.l1d_p1_addr_hit, v_probe.l1d_p1_hit_vld,
        v_probe.l1d_p1_miss_vld, v_probe.l1d_p1_pre_sel, v_probe.l1d_p1_expt_match,
        v_probe.l1d_p1_entry_pa, v_probe.l1d_p1_off_pa, v_probe.l1d_p1_fin_pa,
        v_probe.l1d_refill_vld, cur_refill_src, v_probe.l1d_refill_idx,
        v_probe.l1d_refill_vpn, v_probe.l1d_refill_ppn, v_probe.l1d_refill_pgs,
        v_probe.l1d_entry_upd, v_probe.l1d_refill_iid0, v_probe.l1d_refill_iid1,
        v_probe.l1d_refill_iid_sel, v_probe.l1d_p1_hit_vec, v_probe.l1d_p1_hit_idx,
        v_probe.l1d_p1_hit_vpn, v_probe.l1d_p1_hit_ppn, v_probe.l1d_p1_hit_pgs,
        v_probe.l2_final_vld, v_probe.l2_final_tlb_hit, v_probe.l2_miss,
        v_probe.l2_final_is_dtlb, v_probe.l2_final_vpn, v_probe.l2_final_hit_ppn,
        v_probe.l2_dtlb_ref_pavld, v_probe.l2_dtlb_ref_cmplt,
        v_probe.l2_dtlb_ref_vpn, v_probe.l2_dtlb_ref_ppn,
        v_probe.ptw_l1d_ref_cmplt, v_probe.ptw_l1d_ref_id,
        v_probe.l1d_ptw_ref_mb_vld, v_probe.l1d_ptw_ref_mb_iid, v_probe.l1d_ptw_ref_mb_vpn,
        v_probe.ptw_arb_vpn, v_probe.ptw_l1d_ref_ppn,
        m_last_l2_ref_valid, m_last_l2_ref_time, m_last_l2_ref_pavld,
        m_last_l2_ref_cmplt, m_last_l2_ref_vpn, m_last_l2_ref_ppn,
        m_last_l1_refill_valid, m_last_l1_refill_time, last_refill_src,
        m_last_l1_refill_idx, m_last_l1_refill_vpn, m_last_l1_refill_ppn,
        m_last_l1_refill_pgs, m_last_l1_entry_upd, m_last_ptw_ref_valid,
        m_last_ptw_ref_time, m_last_ptw_ref_id, m_last_ptw_ref_mb_vld,
        m_last_ptw_ref_mb_iid, m_last_ptw_ref_mb_vpn, m_last_ptw_arb_vpn,
        m_last_ptw_ref_ppn),
      UVM_NONE)
  endfunction

endclass : mmu_translation_sb

`endif // MMU_TRANSLATION_SB_SVH
