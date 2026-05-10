// =============================================================================
// L1DTLB directed virtual sequences
//
// These scenarios implement the Chapter-3 L1DTLB audit intent without changing
// the existing thin Phase9 wrappers.  The vseq uses normal LSU sequences for
// fill/retry traffic and raw LSU interface pulses only for same-cycle pipe0/1
// cases that the existing LSU driver serializes with its DTLB mutex.
// =============================================================================
`ifndef MMU_L1DTLB_VSEQ_LIB_SVH
`define MMU_L1DTLB_VSEQ_LIB_SVH

typedef enum int {
  L1DTLB_SCN_SMOKE_P0,
  L1DTLB_SCN_SMOKE_P1,
  L1DTLB_SCN_DUAL_HIT,
  L1DTLB_SCN_HIT_MISS,
  L1DTLB_SCN_DUAL_MISS_SAME,
  L1DTLB_SCN_DUAL_MISS_DIFF,
  L1DTLB_SCN_MB_FULL,
  L1DTLB_SCN_BUSY_WAKEUP,
  L1DTLB_SCN_ABORT,
  L1DTLB_SCN_PERMISSION,
  L1DTLB_SCN_INVALIDATE,
  L1DTLB_SCN_CREDIT,
  L1DTLB_SCN_SCHED,
  L1DTLB_SCN_REFILL,
  L1DTLB_SCN_FAULT_REFILL,
  L1DTLB_SCN_HUGE,
  L1DTLB_SCN_STAMO,
  L1DTLB_SCN_FLUSH_RACE,
  L1DTLB_SCN_RESET_ONLY,
  L1DTLB_SCN_GENERIC_AUDIT
} l1dtlb_scn_e;

class l1dtlb_directed_vseq extends mmu_base_vseq;

  `uvm_object_utils(l1dtlb_directed_vseq)

  string        tc_id;
  string        scenario_id;
  string        scenario_intent;
  bit           traceability_shell;
  l1dtlb_scn_e scenario;

  mmu_env        m_env_h;
  virtual lsu_if m_lsu_vif;
  virtual mmu_dut_probes_if m_probe_vif;

  va_t m_va_base;
  ppn_t m_root_ppn;
  asid_t m_asid;
  ppn_t m_leaf_ppn0;
  int unsigned m_nmap;

  function new(string name = "l1dtlb_directed_vseq");
    super.new(name);
    tc_id       = "DTLB_GENERIC";
    scenario_id = "L1DTLB_TS_OBS_REFERENCE_MODEL_BOUNDARY";
    scenario_intent = "generic L1DTLB audit smoke";
    traceability_shell = 1'b0;
    scenario    = L1DTLB_SCN_GENERIC_AUDIT;
    num_txn     = 64;
    m_va_base   = 39'h10_0000;
    m_root_ppn  = 28'h0;
    m_asid      = 16'h0;
    m_leaf_ppn0 = 28'h200;
    m_nmap      = 48;
  endfunction

  static function bit is_l1dtlb_tc(string id);
    l1dtlb_scn_e scn;
    return decode_tc_id(id, scn);
  endfunction

  static function bit decode_tc_id(string id, output l1dtlb_scn_e scn);
    string sid;
    string intent;
    bit shell;
    return decode_tc_info(id, scn, sid, intent, shell);
  endfunction

  static function bit decode_tc_info(
    string id,
    output l1dtlb_scn_e scn,
    output string sid,
    output string intent,
    output bit shell
  );
    scn = L1DTLB_SCN_GENERIC_AUDIT;
    sid = "L1DTLB_TS_OBS_REFERENCE_MODEL_BOUNDARY";
    intent = "generic L1DTLB audit smoke";
    shell = 1'b0;
    case (id)
      "DTLB_HIT_001": begin
        scn = L1DTLB_SCN_SMOKE_P0;
        sid = "L1DTLB_TS_BASIC_HIT_PIPE0";
        intent = "pipe0 single 4K hit";
      end
      "DTLB_HIT_002": begin
        scn = L1DTLB_SCN_SMOKE_P1;
        sid = "L1DTLB_TS_BASIC_HIT_PIPE1";
        intent = "pipe1 single 4K hit/store";
      end
      "DTLB_CONCURRENT_001": begin
        scn = L1DTLB_SCN_DUAL_HIT;
        sid = "L1DTLB_TS_BASIC_DUAL_HIT";
        intent = "same-cycle dual hit";
      end
      "DTLB_CONCURRENT_002",
      "DTLB_HIT_MISS_CONCURRENT_001": begin
        scn = L1DTLB_SCN_HIT_MISS;
        sid = "L1DTLB_TS_BASIC_HIT_MISS";
        intent = "same-cycle hit plus miss";
      end
      "DTLB_ALLOC_001": begin
        scn = L1DTLB_SCN_DUAL_MISS_SAME;
        sid = "L1DTLB_TS_MB_DUAL_SAME_4K_DEDUP";
        intent = "dual miss same 4K VPN dedup";
      end
      "DTLB_ALLOC_TWO_LOWEST_FREE_001": begin
        scn = L1DTLB_SCN_DUAL_MISS_DIFF;
        sid = "L1DTLB_TS_MB_DUAL_DIFF_4K_TWO_FREE";
        intent = "dual miss different 4K VPN allocation";
      end
      "DTLB_ALLOC_FULL_001",
      "DTLB_MB_001",
      "DTLB_MB_002": begin
        scn = L1DTLB_SCN_MB_FULL;
        sid = "L1DTLB_TS_MB_FULL_DROP_RETRY";
        intent = "MB full drop/retry";
      end
      "DTLB_BUSY_ANY_INFLIGHT_001",
      "DTLB_BUSY_RESTART_MODE_001",
      "DTLB_WAKEUP_COMPLETE_BCAST_001",
      "DTLB_WAKEUP_MULTI_RETRY_001": begin
        scn = L1DTLB_SCN_BUSY_WAKEUP;
        sid = "L1DTLB_TS_CTRL_BUSY_ANY_INFLIGHT";
        intent = "busy/wakeup broadcast while in-flight";
      end
      "DTLB_ABORT_001": begin
        scn = L1DTLB_SCN_ABORT;
        sid = "L1DTLB_TS_CTRL_ABORT_MISS";
        intent = "abort hit/miss state side-effect guard";
      end
      "DTLB_PERM_LD_001": begin
        scn = L1DTLB_SCN_PERMISSION;
        sid = "L1DTLB_TS_FAULT_LOAD_R0";
        intent = "R=0 load page fault";
      end
      "DTLB_PERM_LD_002": begin
        scn = L1DTLB_SCN_PERMISSION;
        sid = "L1DTLB_TS_FAULT_LOAD_MXR";
        intent = "X-only load fault/pass under MXR";
      end
      "DTLB_PERM_ST_001",
      "DTLB_PERM_ST_002": begin
        scn = L1DTLB_SCN_PERMISSION;
        sid = "L1DTLB_TS_FAULT_STORE_W_D";
        intent = "store permission W/D directed fault cases";
      end
      "DTLB_FAULT_AD_US_SUM_001": begin
        scn = L1DTLB_SCN_PERMISSION;
        sid = "L1DTLB_TS_FAULT_AD_US_SUM";
        intent = "A-bit, U-bit, and SUM directed permission cases";
      end
      "DTLB_PMP_001",
      "DTLB_ACCESS_FAULT_T1_PAIRING_001": begin
        scn = L1DTLB_SCN_PERMISSION;
        sid = "L1DTLB_TS_FAULT_PMP_ACCESS";
        intent = "PMP access fault and T1 ownership";
      end
      "DTLB_PF_BLOCKS_PMP_001": begin
        scn = L1DTLB_SCN_PERMISSION;
        sid = "L1DTLB_TS_FAULT_PF_BLOCKS_PMP";
        intent = "page fault blocks downstream PMP access fault";
      end
      "DTLB_PA_VLD_TERMINAL_001": begin
        scn = L1DTLB_SCN_PERMISSION;
        sid = "L1DTLB_TS_FAULT_RESPONSE_TIMING";
        intent = "terminal response pa_vld/fault timing";
      end
      "DTLB_FAULT_OVERLAP_PIPE_001": begin
        scn = L1DTLB_SCN_PERMISSION;
        sid = "L1DTLB_TS_FAULT_OVERLAP_PIPE";
        intent = "same-cycle page/access fault overlap observation";
      end
      "DTLB_TYPE_PROP_LOAD_STORE_AMO_001": begin
        scn = L1DTLB_SCN_PERMISSION;
        sid = "L1DTLB_TS_SCHED_STORE_TYPE_PROP";
        intent = "load/store type propagation to L2 request";
      end
      "DTLB_INV_001",
      "DTLB_INV_002",
      "DTLB_INV_003",
      "DTLB_INV_004",
      "DTLB_INV_VA8_alias_001",
      "DTLB_INV_HIT_SAME_CYCLE_001",
      "DTLB_INV_INSTALL_SAME_ENTRY_001",
      "DTLB_CLEANUP_SCOPE_MATRIX_001": begin
        scn = L1DTLB_SCN_INVALIDATE;
        sid = "L1DTLB_TS_INV_TLBOPER_CLR";
        intent = "invalidate/cleanup scope";
      end
      "DTLB_CREDIT_001",
      "DTLB_CREDIT_002",
      "DTLB_CREDIT_BOUND_001": begin
        scn = L1DTLB_SCN_CREDIT;
        sid = "L1DTLB_TS_SCHED_CREDIT_BOUND";
        intent = "scheduler credit bounds and conservation";
      end
      "DTLB_SCHED_001",
      "DTLB_ALLOC_RACE_001": begin
        scn = L1DTLB_SCN_SCHED;
        sid = "L1DTLB_TS_SCHED_BYPASS_ALLOC_ISSUE";
        intent = "scheduler priority and bypass allocate+issue";
      end
      "DTLB_REFILL_001",
      "DTLB_REFILL_002",
      "DTLB_INSTALL_ARB_001",
      "DTLB_INSTALL_ID_CHK_001",
      "DTLB_INSTALL_VISIBILITY_001",
      "DTLB_MB_FSM_WFI_001",
      "DTLB_WFI_DATA_HOLD_001",
      "DTLB_REFILL_STALE_ID_001",
      "DTLB_ENTRY_FIELD_MODEL_001": begin
        scn = L1DTLB_SCN_REFILL;
        sid = "L1DTLB_TS_INSTALL_ARB_WFI_PTW_L2";
        intent = "refill/install/WFI entry field path";
      end
      "DTLB_MB_PGFLT_001",
      "DTLB_EXPT_ID_MAP_001",
      "DTLB_MB_FAULT_HOLD_001",
      "DTLB_MB_ABT_LATE_REFILL_001",
      "DTLB_EXPT_DUAL_SAME_ENTRY_NEG_001",
      "DTLB_ACCESS_FAULT_SOURCE_PARITY_001",
      "DTLB_WAKEUP_EXPT_001",
      "DTLB_EXPT_HIT_WITH_TLB_HIT_001": begin
        scn = L1DTLB_SCN_FAULT_REFILL;
        sid = "L1DTLB_TS_EXPT_FAULT_REFILL_WRITE";
        intent = "fault refill, exception CAM replay, wakeup";
      end
      "DTLB_HUGE_001",
      "DTLB_HUGE_002",
      "DTLB_HUGE_003",
      "DTLB_HUGE_MIX_001",
      "DTLB_DUAL_HIT_MUX_001": begin
        scn = L1DTLB_SCN_HUGE;
        sid = "L1DTLB_TS_BASIC_PAGE_SIZE_4K_2M_1G";
        intent = "4K/2M/1G hit/refill";
      end
      "DTLB_STAMO_001",
      "DTLB_STAMO_PIPE1_BYPASS_001",
      "DTLB_STAMO_PIPE0_NEG_001": begin
        scn = L1DTLB_SCN_STAMO;
        sid = "L1DTLB_TS_MODE_STAMO_PIPE1";
        intent = "STAMO pipe1 bypass and pipe0 negative";
      end
      "DTLB_MB_FLUSH_RACE_MATRIX_001": begin
        scn = L1DTLB_SCN_FLUSH_RACE;
        sid = "L1DTLB_TS_FLUSH_MB_RACE_MATRIX";
        intent = "RTU flush versus MB FSM race";
      end
      "DTLB_RESET_STATE_001": begin
        scn = L1DTLB_SCN_RESET_ONLY;
        sid = "L1DTLB_TS_CTRL_RESET_STATE";
        intent = "post-reset L1DTLB visible state";
      end
      "DTLB_MB_STATE_SIGNAL_001",
      "DTLB_PLRU_001",
      "DTLB_PLRU_WHITEBOX_ONLY_001",
      "DTLB_RESP_NO_IID_T01_001",
      "DTLB_REF_MODEL_OBSERVABILITY_001",
      "DTLB_SYSMAP_001": begin
        scn = L1DTLB_SCN_GENERIC_AUDIT;
        sid = "L1DTLB_TS_OBS_REFERENCE_MODEL_BOUNDARY";
        intent = "traceability shell/generic observability path";
        shell = 1'b1;
      end
      default: return 1'b0;
    endcase
    return 1'b1;
  endfunction

  protected function va_t va_page(int unsigned idx);
    return va_t'(m_va_base) + va_t'(idx << 12);
  endfunction

  protected function bit [63:0] canon_va(va_t va);
    return {25'b0, va};
  endfunction

  protected function bit [27:0] vabuf_for(va_t va);
    bit [63:0] cva;
    cva = canon_va(va);
    return cva[38:11];
  endfunction

  protected task wait_lsu_cycles(int unsigned n);
    repeat (n) @(m_lsu_vif.driver_cb);
  endtask

  protected task wait_l1d_expt_write(
    string ctx,
    int unsigned max_cycles = 524288
  );
    bit seen;
    seen = 1'b0;
    if (m_probe_vif == null) begin
      `uvm_warning(get_type_name(), {ctx, ": MMU_DUT_PROBES_VIF unavailable; using fixed wait for exception write"})
      wait_lsu_cycles(256);
      return;
    end
    fork
      begin
        while (!seen) begin
          @(m_probe_vif.mon_cb);
          if (m_probe_vif.mon_cb.l1d_expt_wr0_vld || m_probe_vif.mon_cb.l1d_expt_wr1_vld)
            seen = 1'b1;
        end
      end
      begin
        repeat (max_cycles) @(m_probe_vif.mon_cb);
        `uvm_warning(get_type_name(), {ctx, ": timed out waiting for L1DTLB exception write"})
        seen = 1'b1;
      end
    join_any
    disable fork;
    wait_lsu_cycles(8);
  endtask

  protected task wait_pipe0_terminal(
    string ctx,
    bit expect_success,
    output bit success,
    int unsigned max_cycles = 524288,
    bit flush_on_timeout = 1'b1
  );
    bit seen;
    bit pa_vld;
    bit page_fault;
    bit access_fault;

    seen = 1'b0;
    success = 1'b0;
    for (int unsigned i = 0; i < max_cycles; i++) begin
      @(m_lsu_vif.monitor_cb);
      pa_vld       = m_lsu_vif.monitor_cb.mmu_lsu_pa0_vld;
      page_fault   = m_lsu_vif.monitor_cb.mmu_lsu_page_fault0;
      access_fault = m_lsu_vif.monitor_cb.mmu_lsu_access_fault0;
      if (pa_vld || page_fault || access_fault) begin
        seen = 1'b1;
        success = pa_vld && !page_fault && !access_fault;
        if (expect_success && !success) begin
          `uvm_error(get_type_name(),
            $sformatf("%s: expected successful pipe0 terminal response, got pa_vld=%0b page_fault=%0b access_fault=%0b",
              ctx, pa_vld, page_fault, access_fault))
        end
        return;
      end
    end

    if (!seen) begin
      `uvm_error(get_type_name(),
        $sformatf("%s: timed out waiting for pipe0 terminal response after %0d cycles",
          ctx, max_cycles))
      if (flush_on_timeout) begin
        send_rtu_flush();
        wait_lsu_cycles(32);
      end
    end
  endtask

  protected task configure_ptw_delay(int unsigned min_delay, int unsigned max_delay, int unsigned err_permille = 0);
    if ((m_env_h != null) && (m_env_h.m_ptw_mem != null) && (m_env_h.m_ptw_mem.m_responder != null)) begin
      m_env_h.m_ptw_mem.m_responder.m_rsp_delay_min = min_delay;
      m_env_h.m_ptw_mem.m_responder.m_rsp_delay_max = max_delay;
      m_env_h.m_ptw_mem.m_responder.m_bus_error_rate_permille = err_permille;
    end
  endtask

  protected task set_mxr_sum(bit mxr, bit sum);
    cp0_mxr_sum_cross_seq seq;
    seq = cp0_mxr_sum_cross_seq::type_id::create("l1dtlb_set_mxr_sum");
    seq.mxr_val = mxr;
    seq.sum_val = sum;
    seq.start(p_sequencer.cp0_sqr);
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(2);
  endtask

  protected task set_pmp_allow_all();
    pmp_flg_normal_seq seq;
    seq = pmp_flg_normal_seq::type_id::create("l1dtlb_pmp_allow_all");
    seq.start(p_sequencer.pmp_sqr);
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(2);
  endtask

  protected task set_pmp_deny_rw();
    pmp_flg_deny_rw_seq seq;
    seq = pmp_flg_deny_rw_seq::type_id::create("l1dtlb_pmp_deny_rw");
    seq.deny_rd = 1'b1;
    seq.deny_wr = 1'b1;
    seq.start(p_sequencer.pmp_sqr);
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(2);
  endtask

  protected task set_priv(bit [1:0] priv);
    cp0_priv_switch_seq seq;
    seq = cp0_priv_switch_seq::type_id::create("l1dtlb_set_priv");
    seq.priv_mode = priv;
    seq.start(p_sequencer.cp0_sqr);
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(2);
  endtask

  protected task set_mprv_mpp(bit mprv, bit [1:0] mpp);
    cp0_mprv_seq seq;
    seq = cp0_mprv_seq::type_id::create("l1dtlb_set_mprv_mpp");
    seq.mprv_val = mprv;
    seq.mpp_val = mpp;
    seq.start(p_sequencer.cp0_sqr);
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(2);
  endtask

  protected task set_satp_mode(bit sv39_en);
    cp0_satp_switch_seq seq;
    seq = cp0_satp_switch_seq::type_id::create("l1dtlb_set_satp_mode");
    seq.satp_sel = 1'b0;
    seq.satp_val = sv39_en ? {4'h8, m_asid, 16'h0, m_root_ppn}
                           : 64'h0;
    seq.start(p_sequencer.cp0_sqr);
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(2);
  endtask

  protected task do_bringup(int unsigned nmap = 48, va_t base = 39'h10_0000);
    m_nmap = nmap;
    m_va_base = base;
    vseq_bringup_sv39_4k(m_env_h, m_root_ppn, m_asid, int'(m_nmap), m_va_base, m_leaf_ppn0);
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
    wait_lsu_cycles(10);
  endtask

  protected task map_special_page(
    int unsigned idx,
    bit r,
    bit w,
    bit x,
    bit a = 1,
    bit d = 1,
    bit u = 0
  );
    m_env_h.m_pt_mem.m_builder.map_4k(
      .va(va_page(idx)),
      .pa(pa_t'({ppn_t'(m_leaf_ppn0 + ppn_t'(idx + 16)), 12'h000})),
      .v(1), .r(r), .w(w), .x(x), .u(u), .g(0), .a(a), .d(d));
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
  endtask

  protected task map_huge_pages();
    m_env_h.m_pt_mem.m_builder.map_2m(
      .va(39'h20_0000),
      .pa(40'h0040_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    m_env_h.m_pt_mem.m_builder.map_1g(
      .va(39'h4000_0000),
      .pa(40'h4000_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
  endtask

  protected task map_2m_page();
    m_env_h.m_pt_mem.m_builder.map_2m(
      .va(39'h20_0000),
      .pa(40'h0040_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
  endtask

  protected task map_1g_page();
    m_env_h.m_pt_mem.m_builder.map_1g(
      .va(39'h4000_0000),
      .pa(40'h4000_0000),
      .v(1), .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1));
    if (m_env_h.m_ref != null)
      m_env_h.m_ref.sync_shadow_state();
  endtask

  protected task send_lsu_item(
    lsu_kind_e kind,
    va_t       va,
    bit [6:0]  iid,
    bit        st_inst = 1'b0,
    bit        abort = 1'b0,
    bit [27:0] stamo_pa = 28'h0,
    lsu_inv_kind_e inv_kind = INV_ALL,
    asid_t inv_asid = 16'h0
  );
    lsu_txn tr;
    tr = lsu_txn::type_id::create("l1dtlb_lsu_item");
    tr.c_kind_default.constraint_mode(0);
    tr.c_no_abort.constraint_mode(0);
    tr.kind = kind;
    tr.va = canon_va(va);
    tr.id = iid;
    tr.st_inst = st_inst;
    tr.abort = abort;
    tr.vabuf = vabuf_for(va);
    begin
      bit [63:0] cva;
      cva = canon_va(va);
      tr.va2 = cva[39:12];
    end
    tr.stamo_pa = stamo_pa;
    tr.inv_kind = inv_kind;
    tr.inv_va = va[38:12];
    tr.inv_asid = inv_asid;
    tr.idle_cycles = 0;
    start_item(tr, -1, p_sequencer.lsu_sqr);
    finish_item(tr);
  endtask

  protected task fill_page(int unsigned idx, bit pipe1 = 1'b0, bit st_inst = 1'b0);
    send_lsu_item(pipe1 ? LSU_PIPE1 : LSU_PIPE0, va_page(idx), pipe1 ? 7'd3 : 7'd2, st_inst);
    m_env_h.wait_for_quiescent_midtest($sformatf("l1dtlb_fill_%0d", idx), 262144, 8);
    wait_lsu_cycles(4);
  endtask

  protected task raw_idle();
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_id0 <= 7'h0;
    m_lsu_vif.driver_cb.lsu_mmu_va0 <= 64'h0;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst0 <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_abort0 <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf0 <= 28'h0;
    m_lsu_vif.driver_cb.lsu_mmu_va1_vld <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_id1 <= 7'h0;
    m_lsu_vif.driver_cb.lsu_mmu_va1 <= 64'h0;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst1 <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_abort1 <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf1 <= 28'h0;
    m_lsu_vif.driver_cb.lsu_mmu_va2_vld <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_va2 <= 28'h0;
    m_lsu_vif.driver_cb.lsu_mmu_stamo_vld <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_stamo_pa <= 28'h0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_va_all_inv <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_all_inv <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_va_asid_inv <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_asid_all_inv <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_va <= 27'h0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_asid <= 16'h0;
  endtask

  protected task raw_pipe0(
    va_t va,
    bit [6:0] iid,
    bit st_inst = 1'b0,
    bit abort = 1'b0
  );
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va0      <= canon_va(va);
    m_lsu_vif.driver_cb.lsu_mmu_id0      <= iid;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst0 <= st_inst;
    m_lsu_vif.driver_cb.lsu_mmu_abort0   <= abort;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf0   <= vabuf_for(va);
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_abort0 <= 1'b0;
  endtask

  protected task raw_pipe0_back_to_back(
    va_t va0,
    bit [6:0] iid0,
    bit st0,
    va_t va1,
    bit [6:0] iid1,
    bit st1
  );
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va0      <= canon_va(va0);
    m_lsu_vif.driver_cb.lsu_mmu_id0      <= iid0;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst0 <= st0;
    m_lsu_vif.driver_cb.lsu_mmu_abort0   <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf0   <= vabuf_for(va0);
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va0      <= canon_va(va1);
    m_lsu_vif.driver_cb.lsu_mmu_id0      <= iid1;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst0 <= st1;
    m_lsu_vif.driver_cb.lsu_mmu_abort0   <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf0   <= vabuf_for(va1);
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld  <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst0 <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_abort0   <= 1'b0;
  endtask

  protected task raw_pipe01(
    va_t va0,
    va_t va1,
    bit [6:0] iid0,
    bit [6:0] iid1,
    bit st0 = 1'b0,
    bit st1 = 1'b0,
    bit abt0 = 1'b0,
    bit abt1 = 1'b0
  );
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va0      <= canon_va(va0);
    m_lsu_vif.driver_cb.lsu_mmu_id0      <= iid0;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst0 <= st0;
    m_lsu_vif.driver_cb.lsu_mmu_abort0   <= abt0;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf0   <= vabuf_for(va0);
    m_lsu_vif.driver_cb.lsu_mmu_va1_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va1      <= canon_va(va1);
    m_lsu_vif.driver_cb.lsu_mmu_id1      <= iid1;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst1 <= st1;
    m_lsu_vif.driver_cb.lsu_mmu_abort1   <= abt1;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf1   <= vabuf_for(va1);
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_va1_vld <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_abort0 <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_abort1 <= 1'b0;
  endtask

  protected task raw_pipe0_with_inv(
    va_t va,
    bit [6:0] iid,
    lsu_inv_kind_e inv_kind,
    va_t inv_va,
    asid_t inv_asid = 16'h0
  );
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va0      <= canon_va(va);
    m_lsu_vif.driver_cb.lsu_mmu_id0      <= iid;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst0 <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_abort0   <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf0   <= vabuf_for(va);
    m_lsu_vif.driver_cb.lsu_mmu_tlb_va   <= inv_va[38:12];
    m_lsu_vif.driver_cb.lsu_mmu_tlb_asid <= inv_asid;
    case (inv_kind)
      INV_ALL:      m_lsu_vif.driver_cb.lsu_mmu_tlb_all_inv <= 1'b1;
      INV_VA_ALL:   m_lsu_vif.driver_cb.lsu_mmu_tlb_va_all_inv <= 1'b1;
      INV_ASID_ALL: m_lsu_vif.driver_cb.lsu_mmu_tlb_asid_all_inv <= 1'b1;
      INV_VA_ASID:  m_lsu_vif.driver_cb.lsu_mmu_tlb_va_asid_inv <= 1'b1;
    endcase
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_all_inv <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_va_all_inv <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_asid_all_inv <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_va_asid_inv <= 1'b0;
    fork
      begin
        @(m_lsu_vif.driver_cb iff m_lsu_vif.driver_cb.mmu_lsu_tlb_inv_done === 1'b1);
      end
      begin
        repeat (1024) @(m_lsu_vif.driver_cb);
        `uvm_warning(get_type_name(), "raw_pipe0_with_inv timed out waiting for mmu_lsu_tlb_inv_done")
      end
    join_any
    disable fork;
    wait_lsu_cycles(2);
  endtask

  protected task raw_inv_pulse(
    lsu_inv_kind_e kind,
    va_t va = 39'h0,
    asid_t asid = 16'h0,
    bit wait_done = 1'b1,
    bit wait_not_busy = 1'b1
  );
    raw_idle();
    if (wait_not_busy && (m_lsu_vif.driver_cb.mmu_lsu_tlb_busy === 1'b1))
      @(m_lsu_vif.driver_cb iff m_lsu_vif.driver_cb.mmu_lsu_tlb_busy === 1'b0);
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_tlb_va <= va[38:12];
    m_lsu_vif.driver_cb.lsu_mmu_tlb_asid <= asid;
    case (kind)
      INV_ALL:      m_lsu_vif.driver_cb.lsu_mmu_tlb_all_inv <= 1'b1;
      INV_VA_ALL:   m_lsu_vif.driver_cb.lsu_mmu_tlb_va_all_inv <= 1'b1;
      INV_ASID_ALL: m_lsu_vif.driver_cb.lsu_mmu_tlb_asid_all_inv <= 1'b1;
      INV_VA_ASID:  m_lsu_vif.driver_cb.lsu_mmu_tlb_va_asid_inv <= 1'b1;
    endcase
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_tlb_all_inv <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_va_all_inv <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_asid_all_inv <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_tlb_va_asid_inv <= 1'b0;
    if (wait_done) begin
      fork
        begin
          @(m_lsu_vif.driver_cb iff m_lsu_vif.driver_cb.mmu_lsu_tlb_inv_done === 1'b1);
        end
        begin
          repeat (1024) @(m_lsu_vif.driver_cb);
          `uvm_warning(get_type_name(), "raw_inv timed out waiting for mmu_lsu_tlb_inv_done")
        end
      join_any
      disable fork;
    end
    wait_lsu_cycles(2);
  endtask

  protected task raw_inv(lsu_inv_kind_e kind, va_t va = 39'h0, asid_t asid = 16'h0);
    raw_inv_pulse(kind, va, asid, 1'b1, 1'b1);
  endtask

  protected task raw_stamo(bit [27:0] pa);
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_stamo_vld <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_stamo_pa <= pa;
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_stamo_vld <= 1'b0;
  endtask

  protected task raw_pipe1_with_stamo(
    va_t va,
    bit [6:0] iid,
    bit [27:0] stamo_pa,
    bit st_inst = 1'b1
  );
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va1_vld    <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va1        <= canon_va(va);
    m_lsu_vif.driver_cb.lsu_mmu_id1        <= iid;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst1   <= st_inst;
    m_lsu_vif.driver_cb.lsu_mmu_abort1     <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf1     <= vabuf_for(va);
    m_lsu_vif.driver_cb.lsu_mmu_stamo_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_stamo_pa   <= stamo_pa;
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va1_vld   <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_stamo_vld <= 1'b0;
  endtask

  protected task raw_pipe0_with_stamo_negative(
    va_t va,
    bit [6:0] iid,
    bit [27:0] stamo_pa,
    bit st_inst = 1'b0
  );
    raw_idle();
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld    <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_va0        <= canon_va(va);
    m_lsu_vif.driver_cb.lsu_mmu_id0        <= iid;
    m_lsu_vif.driver_cb.lsu_mmu_st_inst0   <= st_inst;
    m_lsu_vif.driver_cb.lsu_mmu_abort0     <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_vabuf0     <= vabuf_for(va);
    m_lsu_vif.driver_cb.lsu_mmu_stamo_vld  <= 1'b1;
    m_lsu_vif.driver_cb.lsu_mmu_stamo_pa   <= stamo_pa;
    @(m_lsu_vif.driver_cb);
    m_lsu_vif.driver_cb.lsu_mmu_va0_vld   <= 1'b0;
    m_lsu_vif.driver_cb.lsu_mmu_stamo_vld <= 1'b0;
  endtask

  protected task send_rtu_flush();
    misc_rtu_flush_seq seq;
    seq = misc_rtu_flush_seq::type_id::create("l1dtlb_rtu_flush");
    seq.start(p_sequencer.misc_sqr);
    wait_lsu_cycles(4);
  endtask

  protected task scenario_smoke_p0();
    do_bringup(32, 39'h10_0000);
    fill_page(0, 1'b0, 1'b0);
    fill_page(1, 1'b0, 1'b0);
  endtask

  protected task scenario_smoke_p1();
    do_bringup(32, 39'h10_0000);
    fill_page(0, 1'b1, 1'b0);
    fill_page(1, 1'b1, 1'b1);
  endtask

  protected task scenario_dual_hit();
    do_bringup(32, 39'h10_0000);
    fill_page(0);
    fill_page(1);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_dual_hit_prefill", 262144, 8);
    raw_pipe01(va_page(0), va_page(1), 7'd4, 7'd5, 1'b0, 1'b1);
    wait_lsu_cycles(12);
    raw_pipe01(va_page(0), va_page(0), 7'd6, 7'd7, 1'b0, 1'b0);
    wait_lsu_cycles(12);
  endtask

  protected task scenario_hit_miss();
    do_bringup(48, 39'h10_0000);
    fill_page(0);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_hit_miss_prefill", 262144, 8);
    raw_pipe01(va_page(0), va_page(16), 7'd8, 7'd9, 1'b0, 1'b0);
    wait_lsu_cycles(40);
  endtask

  protected task scenario_dual_miss_same();
    do_bringup(48, 39'h10_0000);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_dual_miss_same_start", 262144, 8);
    raw_pipe01(va_page(20), va_page(20), 7'd10, 7'd11, 1'b0, 1'b1);
    wait_lsu_cycles(80);
  endtask

  protected task scenario_dual_miss_diff();
    do_bringup(48, 39'h10_0000);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_dual_miss_diff_start", 262144, 8);
    raw_pipe01(va_page(21), va_page(22), 7'd1, 7'd2, 1'b0, 1'b1);
    wait_lsu_cycles(80);
  endtask

  protected task scenario_mb_full();
    do_bringup(96, 39'h10_0000);
    configure_ptw_delay(96, 160);
    for (int unsigned i = 0; i < 10; i++) begin
      bit [6:0] iid;
      iid = i + 1;
      raw_pipe0(va_page(i + 32), iid, 1'b0, 1'b0);
      wait_lsu_cycles(1);
    end
    wait_lsu_cycles(220);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_mb_full_drain", 524288, 16);
  endtask

  protected task scenario_busy_wakeup();
    do_bringup(48, 39'h10_0000);
    configure_ptw_delay(24, 48);
    raw_pipe0(va_page(24), 7'd3, 1'b0, 1'b0);
    wait_lsu_cycles(80);
    configure_ptw_delay(1, 4);
    fill_page(24);
  endtask

  protected task scenario_abort();
    do_bringup(48, 39'h10_0000);
    fill_page(0);
    raw_pipe0(va_page(0), 7'd4, 1'b0, 1'b1);
    wait_lsu_cycles(8);
    raw_pipe0(va_page(30), 7'd5, 1'b0, 1'b1);
    wait_lsu_cycles(24);
    configure_ptw_delay(24, 48);
    raw_pipe0(va_page(31), 7'd6, 1'b0, 1'b0);
    wait_lsu_cycles(3);
    raw_pipe0(va_page(31), 7'd6, 1'b0, 1'b1);
    wait_lsu_cycles(80);
    map_special_page(46, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0);
    configure_ptw_delay(8, 24);
    raw_pipe0(va_page(46), 7'd7, 1'b0, 1'b0);
    wait_l1d_expt_write("l1dtlb_abort_expt_entry");
    raw_pipe0(va_page(46), 7'd7, 1'b0, 1'b1);
    wait_lsu_cycles(8);
    raw_pipe0(va_page(46), 7'd7, 1'b0, 1'b0);
    wait_lsu_cycles(96);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_abort", 524288, 16);
  endtask

  protected task scenario_permission();
    do_bringup(64, 39'h10_0000);

    if (tc_id == "DTLB_PERM_LD_001") begin
      map_special_page(32, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
      set_mxr_sum(1'b0, 1'b0);
      send_lsu_item(LSU_PIPE0, va_page(32), 7'd1, 1'b0);
    end else if (tc_id == "DTLB_PERM_LD_002") begin
      map_special_page(33, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0);
      map_special_page(36, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0);
      set_mxr_sum(1'b0, 1'b0);
      send_lsu_item(LSU_PIPE0, va_page(33), 7'd2, 1'b0);
      m_env_h.wait_for_quiescent_midtest("l1dtlb_perm_mxr_fault", 524288, 8);
      set_mxr_sum(1'b1, 1'b0);
      send_lsu_item(LSU_PIPE0, va_page(36), 7'd3, 1'b0);
      m_env_h.wait_for_quiescent_midtest("l1dtlb_perm_mxr_pass_fill", 524288, 8);
      raw_pipe0(va_page(36), 7'd3);
    end else if (tc_id == "DTLB_PERM_ST_001") begin
      map_special_page(34, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
      send_lsu_item(LSU_PIPE1, va_page(34), 7'd4, 1'b1);
    end else if (tc_id == "DTLB_PERM_ST_002") begin
      map_special_page(34, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
      map_special_page(35, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0);
      send_lsu_item(LSU_PIPE1, va_page(34), 7'd5, 1'b1);
      send_lsu_item(LSU_PIPE1, va_page(35), 7'd6, 1'b1);
    end else if (tc_id == "DTLB_FAULT_AD_US_SUM_001") begin
      bit sum1_pass_ok;
      bit sum1_hit_ok;
      map_special_page(48, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
      map_special_page(49, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1);
      map_special_page(50, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b1);
      map_special_page(51, 1'b1, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0);
      set_priv(2'b01);
      set_mxr_sum(1'b0, 1'b0);
      send_lsu_item(LSU_PIPE0, va_page(48), 7'd19, 1'b0);
      m_env_h.wait_for_quiescent_midtest("l1dtlb_perm_a0_fault", 524288, 8);
      send_lsu_item(LSU_PIPE0, va_page(49), 7'd20, 1'b0);
      m_env_h.wait_for_quiescent_midtest("l1dtlb_perm_sum0_fault", 524288, 8);
      set_mxr_sum(1'b0, 1'b1);
      send_lsu_item(LSU_PIPE0, va_page(50), 7'd21, 1'b0);
      wait_pipe0_terminal("l1dtlb_perm_sum1_pass", 1'b1, sum1_pass_ok);
      if (sum1_pass_ok) begin
        m_env_h.wait_for_quiescent_midtest("l1dtlb_perm_sum1_pass_fill", 524288, 8);
        raw_pipe0(va_page(50), 7'd21, 1'b0);
        wait_pipe0_terminal("l1dtlb_perm_sum1_hit", 1'b1, sum1_hit_ok, 4096, 1'b0);
        wait_lsu_cycles(12);
      end
      set_priv(2'b00);
      set_mxr_sum(1'b0, 1'b0);
      send_lsu_item(LSU_PIPE0, va_page(51), 7'd22, 1'b0);
      m_env_h.wait_for_quiescent_midtest("l1dtlb_perm_user_u0_fault", 524288, 8);
      set_priv(2'b01);
    end else if (tc_id == "DTLB_TYPE_PROP_LOAD_STORE_AMO_001") begin
      send_lsu_item(LSU_PIPE0, va_page(36), 7'd8, 1'b0);
      send_lsu_item(LSU_PIPE1, va_page(37), 7'd9, 1'b1);
    end else if (tc_id == "DTLB_PMP_001") begin
      fill_page(38);
      fill_page(39, 1'b1, 1'b1);
      set_pmp_deny_rw();
      raw_pipe01(va_page(38), va_page(39), 7'd10, 7'd11, 1'b0, 1'b1);
      wait_lsu_cycles(24);
      set_pmp_allow_all();
    end else if (tc_id == "DTLB_PF_BLOCKS_PMP_001") begin
      map_special_page(40, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
      set_pmp_deny_rw();
      send_lsu_item(LSU_PIPE0, va_page(40), 7'd12, 1'b0);
      m_env_h.wait_for_quiescent_midtest("l1dtlb_perm_pf_blocks_pmp", 524288, 8);
      set_pmp_allow_all();
    end else if (tc_id == "DTLB_PA_VLD_TERMINAL_001") begin
      map_special_page(41, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
      send_lsu_item(LSU_PIPE0, va_page(41), 7'd13, 1'b0);
      send_lsu_item(LSU_PIPE0, va_page(0), 7'd14, 1'b0);
    end else if (tc_id == "DTLB_ACCESS_FAULT_T1_PAIRING_001") begin
      fill_page(42);
      fill_page(43, 1'b1, 1'b1);
      set_pmp_deny_rw();
      raw_pipe01(va_page(42), va_page(43), 7'd15, 7'd16, 1'b0, 1'b1);
      wait_lsu_cycles(24);
      set_pmp_allow_all();
    end else if (tc_id == "DTLB_FAULT_OVERLAP_PIPE_001") begin
      map_special_page(45, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
      raw_pipe0(va_page(45), 7'd18);
      wait_l1d_expt_write("l1dtlb_fault_overlap_pf_entry");
      fill_page(44);
      set_pmp_deny_rw();
      raw_pipe0_back_to_back(va_page(44), 7'd17, 1'b0, va_page(45), 7'd18, 1'b0);
      wait_lsu_cycles(48);
      set_pmp_allow_all();
    end else begin
      map_special_page(32, 1'b0, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
      map_special_page(33, 1'b0, 1'b0, 1'b1, 1'b1, 1'b1, 1'b0);
      map_special_page(34, 1'b1, 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
      map_special_page(35, 1'b1, 1'b1, 1'b0, 1'b1, 1'b0, 1'b0);
      set_mxr_sum(1'b0, 1'b0);
      send_lsu_item(LSU_PIPE0, va_page(32), 7'd1, 1'b0);
      send_lsu_item(LSU_PIPE0, va_page(33), 7'd2, 1'b0);
      set_mxr_sum(1'b1, 1'b0);
      send_lsu_item(LSU_PIPE0, va_page(33), 7'd3, 1'b0);
      send_lsu_item(LSU_PIPE1, va_page(34), 7'd4, 1'b1);
      send_lsu_item(LSU_PIPE1, va_page(35), 7'd5, 1'b1);
    end

    m_env_h.wait_for_quiescent_midtest("l1dtlb_perm", 524288, 16);
  endtask

  protected task scenario_direct_map();
    do_bringup(16, 39'h10_0000);
    fill_page(0);
    set_satp_mode(1'b0);
    send_lsu_item(LSU_PIPE0, va_page(4), 7'd8, 1'b0);
    wait_lsu_cycles(12);
    set_satp_mode(1'b1);
    set_priv(2'b11);
    send_lsu_item(LSU_PIPE0, va_page(5), 7'd9, 1'b0);
    wait_lsu_cycles(12);
    set_mprv_mpp(1'b1, 2'b01);
    send_lsu_item(LSU_PIPE0, va_page(6), 7'd10, 1'b0);
    wait_lsu_cycles(12);
    set_mprv_mpp(1'b0, 2'b11);
    set_priv(2'b01);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_direct_map", 262144, 8);
  endtask

  protected task scenario_invalidate();
    do_bringup(64, 39'h10_0000);
    fill_page(0);
    fill_page(1);
    raw_inv(INV_ALL);
    fill_page(0);
    raw_inv(INV_VA_ALL, va_page(0), m_asid);
    fill_page(0);
    raw_inv(INV_ASID_ALL, va_page(0), m_asid);
    fill_page(1);
    raw_inv(INV_VA_ASID, va_page(1), m_asid);
    fill_page(1);
  endtask

  protected task scenario_inv_va8_alias();
    do_bringup(320, 39'h10_0000);
    fill_page(0);
    fill_page(256);
    fill_page(1);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_inv_va8_alias_prefill", 524288, 8);
    raw_inv(INV_VA_ALL, va_page(0), m_asid);
    raw_pipe0(va_page(0), 7'd12);
    wait_lsu_cycles(24);
    raw_pipe0(va_page(256), 7'd13);
    wait_lsu_cycles(24);
    raw_pipe0(va_page(1), 7'd14);
    wait_lsu_cycles(40);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_inv_va8_alias_done", 524288, 8);
  endtask

  protected task scenario_inv_install_same_entry();
    do_bringup(96, 39'h10_0000);
    configure_ptw_delay(24, 48);
    fill_page(2);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_inv_install_seed", 524288, 8);
    raw_pipe0(va_page(44), 7'd15);
    wait_lsu_cycles(3);
    raw_inv_pulse(INV_ALL, 39'h0, m_asid, 1'b0, 1'b0);
    wait_lsu_cycles(260);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_inv_install_done", 524288, 16);
  endtask

  protected task scenario_inv_hit_same_cycle();
    do_bringup(64, 39'h10_0000);
    fill_page(0);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_inv_hit_prefill", 262144, 8);
    raw_pipe0_with_inv(va_page(0), 7'd16, INV_VA_ALL, va_page(0), m_asid);
    raw_pipe0(va_page(0), 7'd17);
    wait_lsu_cycles(48);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_inv_hit_done", 524288, 8);
  endtask

  protected task scenario_credit();
    do_bringup(96, 39'h10_0000);
    configure_ptw_delay(32, 96);
    for (int unsigned i = 0; i < 16; i++) begin
      bit [6:0] iid;
      iid = i % 12;
      raw_pipe0(va_page(i + 36), iid, (i[0] == 1'b1), 1'b0);
      wait_lsu_cycles(1);
    end
    wait_lsu_cycles(260);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_credit", 524288, 16);
  endtask

  protected task scenario_sched();
    do_bringup(96, 39'h10_0000);
    configure_ptw_delay(48, 96);
    raw_pipe0(va_page(40), 7'd1, 1'b0, 1'b0);
    wait_lsu_cycles(3);
    raw_pipe01(va_page(41), va_page(42), 7'd2, 7'd3, 1'b0, 1'b1);
    wait_lsu_cycles(180);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_sched", 524288, 16);
  endtask

  protected task scenario_alloc_race();
    do_bringup(128, 39'h10_0000);
    configure_ptw_delay(56, 96);
    for (int unsigned i = 0; i < 7; i++) begin
      bit [6:0] iid;
      iid = i + 1;
      raw_pipe0(va_page(i + 60), iid);
      wait_lsu_cycles(1);
    end
    wait_lsu_cycles(8);
    raw_pipe01(va_page(80), va_page(81), 7'd2, 7'd9, 1'b0, 1'b1);
    wait_lsu_cycles(96);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_alloc_race_p0_older_drain", 524288, 16);
    configure_ptw_delay(56, 96);
    for (int unsigned i = 0; i < 7; i++) begin
      bit [6:0] iid;
      iid = i + 16;
      raw_pipe0(va_page(i + 88), iid);
      wait_lsu_cycles(1);
    end
    wait_lsu_cycles(8);
    raw_pipe01(va_page(108), va_page(109), 7'd12, 7'd3, 1'b0, 1'b1);
    wait_lsu_cycles(220);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_alloc_race", 524288, 16);
  endtask

  protected task scenario_refill();
    do_bringup(96, 39'h10_0000);
    configure_ptw_delay(6, 16);
    raw_pipe0(va_page(44), 7'd4);
    wait_lsu_cycles(5);
    raw_pipe0(va_page(45), 7'd5);
    wait_lsu_cycles(120);
    fill_page(44);
    fill_page(45);
    configure_ptw_delay(1, 4);
  endtask

  protected task scenario_install_visibility();
    do_bringup(96, 39'h10_0000);
    configure_ptw_delay(8, 18);
    raw_pipe0(va_page(44), 7'd4);
    wait_lsu_cycles(140);
    raw_pipe0(va_page(44), 7'd4);
    wait_lsu_cycles(40);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_install_visibility", 524288, 16);
  endtask

  protected task scenario_fault_refill();
    do_bringup(96, 39'h10_0000);
    map_special_page(46, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0);
    map_special_page(47, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
    configure_ptw_delay(8, 24);
    send_lsu_item(LSU_PIPE0, va_page(46), 7'd6, 1'b0);
    send_lsu_item(LSU_PIPE1, va_page(47), 7'd7, 1'b1);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_fault_refill_before_replay", 524288, 16);
    raw_pipe01(va_page(46), va_page(47), 7'd6, 7'd7, 1'b0, 1'b1);
    wait_lsu_cycles(80);
    send_rtu_flush();
    configure_ptw_delay(1, 4);
  endtask

  protected task scenario_wakeup_expt();
    do_bringup(96, 39'h10_0000);
    map_special_page(46, 1'b0, 1'b1, 1'b0, 1'b1, 1'b1, 1'b0);
    configure_ptw_delay(8, 24);
    raw_pipe0(va_page(46), 7'd6, 1'b0, 1'b0);
    wait_l1d_expt_write("l1dtlb_wakeup_expt_entry");
    raw_pipe0(va_page(46), 7'd6);
    wait_lsu_cycles(96);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_wakeup_expt_done", 524288, 16);
  endtask

  protected task scenario_expt_hit_with_tlb_hit();
    do_bringup(96, 39'h10_0000);
    fill_page(0);
    map_special_page(47, 1'b1, 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
    configure_ptw_delay(8, 24);
    raw_pipe0(va_page(47), 7'd7, 1'b0, 1'b0);
    wait_l1d_expt_write("l1dtlb_expt_tlb_overlap_entry");
    raw_pipe01(va_page(47), va_page(0), 7'd7, 7'd1, 1'b0, 1'b1);
    wait_lsu_cycles(96);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_expt_tlb_overlap_done", 524288, 16);
  endtask

  protected task scenario_huge();
    do_bringup(32, 39'h10_0000);
    if (tc_id == "DTLB_HUGE_001") begin
      send_lsu_item(LSU_PIPE0, va_page(0), 7'd1, 1'b0);
      m_env_h.wait_for_quiescent_midtest("l1dtlb_huge_4k_fill", 524288, 8);
      raw_pipe0(va_page(0), 7'd1);
    end else if (tc_id == "DTLB_HUGE_002") begin
      map_2m_page();
      send_lsu_item(LSU_PIPE0, 39'h20_0000, 7'd2, 1'b0);
      m_env_h.wait_for_quiescent_midtest("l1dtlb_huge_2m_fill", 524288, 8);
      raw_pipe01(39'h20_0000, 39'h20_1000, 7'd2, 7'd3, 1'b0, 1'b1);
      wait_lsu_cycles(12);
      raw_inv(INV_VA_ALL, 39'h20_0000, m_asid);
      send_lsu_item(LSU_PIPE0, 39'h20_2000, 7'd4, 1'b0);
    end else if (tc_id == "DTLB_HUGE_003") begin
      map_1g_page();
      send_lsu_item(LSU_PIPE0, 39'h4000_0000, 7'd5, 1'b0);
      m_env_h.wait_for_quiescent_midtest("l1dtlb_huge_1g_fill", 524288, 8);
      raw_pipe01(39'h4000_0000, 39'h4000_1000, 7'd5, 7'd6, 1'b0, 1'b1);
      wait_lsu_cycles(12);
      raw_inv(INV_VA_ALL, 39'h4000_0000, m_asid);
      send_lsu_item(LSU_PIPE1, 39'h4000_2000, 7'd7, 1'b1);
    end else begin
      map_huge_pages();
      send_lsu_item(LSU_PIPE0, va_page(0), 7'd8, 1'b0);
      send_lsu_item(LSU_PIPE0, 39'h20_0000, 7'd9, 1'b0);
      send_lsu_item(LSU_PIPE1, 39'h20_1000, 7'd10, 1'b1);
      send_lsu_item(LSU_PIPE0, 39'h4000_0000, 7'd11, 1'b0);
      send_lsu_item(LSU_PIPE1, 39'h4000_1000, 7'd12, 1'b1);
    end
    m_env_h.wait_for_quiescent_midtest("l1dtlb_huge", 524288, 16);
  endtask

  protected task scenario_stamo();
    do_bringup(32, 39'h10_0000);
    fill_page(0);
    fill_page(1, 1'b1, 1'b1);
    if (tc_id == "DTLB_STAMO_PIPE1_BYPASS_001") begin
      raw_pipe1_with_stamo(va_page(1), 7'd2, 28'h12345);
      wait_lsu_cycles(24);
      fill_page(2, 1'b1, 1'b1);
      raw_pipe1_with_stamo(va_page(2), 7'd3, 28'h23456);
    end else if (tc_id == "DTLB_STAMO_PIPE0_NEG_001") begin
      raw_pipe0_with_stamo_negative(va_page(0), 7'd4, 28'h34567);
      wait_lsu_cycles(24);
      raw_pipe01(va_page(0), va_page(1), 7'd5, 7'd6, 1'b0, 1'b1);
    end else begin
      raw_stamo(28'h12345);
      raw_pipe01(va_page(0), va_page(1), 7'd1, 7'd2, 1'b0, 1'b1);
      wait_lsu_cycles(30);
      raw_pipe1_with_stamo(va_page(2), 7'd3, 28'h23456);
    end
    m_env_h.wait_for_quiescent_midtest("l1dtlb_stamo", 262144, 8);
  endtask

  protected task scenario_flush_race();
    do_bringup(96, 39'h10_0000);
    configure_ptw_delay(48, 96);
    raw_pipe0(va_page(50), 7'd4);
    wait_lsu_cycles(2);
    send_rtu_flush();
    wait_lsu_cycles(120);
    raw_pipe01(va_page(51), va_page(52), 7'd5, 7'd6);
    wait_lsu_cycles(2);
    send_rtu_flush();
    wait_lsu_cycles(160);
    configure_ptw_delay(1, 4);
  endtask

  protected task scenario_reset_only();
    do_bringup(8, 39'h10_0000);
    raw_inv(INV_ALL);
    wait_lsu_cycles(20);
  endtask

  protected task scenario_mb_state_signal();
    do_bringup(96, 39'h10_0000);
    configure_ptw_delay(24, 72);
    raw_pipe0(va_page(53), 7'd1);
    wait_lsu_cycles(3);
    raw_pipe0(va_page(54), 7'd2);
    wait_lsu_cycles(40);
    send_rtu_flush();
    wait_lsu_cycles(80);
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest("l1dtlb_mb_state_signal", 524288, 16);
  endtask

  protected task scenario_plru_pressure();
    do_bringup(96, 39'h10_0000);
    for (int unsigned i = 0; i < 24; i++) begin
      fill_page(i % 48, i[0], i[1]);
    end
    raw_pipe01(va_page(0), va_page(1), 7'd11, 7'd12);
    wait_lsu_cycles(20);
    raw_inv(INV_ALL);
    for (int unsigned i = 24; i < 40; i++) begin
      fill_page(i, i[0], i[1]);
    end
  endtask

  protected task scenario_observability();
    do_bringup(96, 39'h10_0000);
    configure_ptw_delay(12, 32);
    fill_page(0);
    raw_pipe01(va_page(0), va_page(60), 7'd1, 7'd2);
    wait_lsu_cycles(32);
    raw_pipe0(va_page(60), 7'd2);
    wait_lsu_cycles(64);
    raw_inv(INV_ALL);
    scenario_direct_map();
    raw_stamo(28'h34567);
    wait_lsu_cycles(20);
    configure_ptw_delay(1, 4);
  endtask

  protected task scenario_generic_audit();
    do_bringup(64, 39'h10_0000);
    fill_page(0);
    fill_page(1, 1'b1, 1'b1);
    raw_pipe01(va_page(0), va_page(16), 7'd1, 7'd2);
    wait_lsu_cycles(60);
    raw_inv(INV_ALL);
    wait_lsu_cycles(20);
  endtask

  virtual task body();
    l1dtlb_scn_e decoded;
    string decoded_sid;
    string decoded_intent;
    bit decoded_shell;
    m_env_h = get_env();
    m_lsu_vif = m_env_h.m_lsu.vif;
    if (m_lsu_vif == null)
      `uvm_fatal(get_type_name(), "LSU VIF is null")
    if (!uvm_config_db#(virtual mmu_dut_probes_if)::get(null, "*", "MMU_DUT_PROBES_VIF", m_probe_vif))
      `uvm_info(get_type_name(), "MMU_DUT_PROBES_VIF not found - probe-assisted L1DTLB waits use fallback", UVM_LOW)
    if (decode_tc_info(tc_id, decoded, decoded_sid, decoded_intent, decoded_shell)) begin
      scenario = decoded;
      scenario_id = decoded_sid;
      scenario_intent = decoded_intent;
      traceability_shell = decoded_shell;
    end

    `uvm_info(get_type_name(),
      $sformatf("L1DTLB directed scenario start: tc_id=%s scenario=%0d scenario_id=%s shell=%0b intent=%s num_txn=%0d",
        tc_id, scenario, scenario_id, traceability_shell, scenario_intent, num_txn),
      UVM_LOW)

    uvm_config_db#(string)::set(null, "*", "L1DTLB_TC_ID", tc_id);
    uvm_config_db#(string)::set(null, "*", "L1DTLB_SCENARIO_ID", scenario_id);

    configure_ptw_delay(1, 4);
    raw_idle();

    case (scenario)
      L1DTLB_SCN_SMOKE_P0:         scenario_smoke_p0();
      L1DTLB_SCN_SMOKE_P1:         scenario_smoke_p1();
      L1DTLB_SCN_DUAL_HIT:         scenario_dual_hit();
      L1DTLB_SCN_HIT_MISS:         scenario_hit_miss();
      L1DTLB_SCN_DUAL_MISS_SAME:   scenario_dual_miss_same();
      L1DTLB_SCN_DUAL_MISS_DIFF:   scenario_dual_miss_diff();
      L1DTLB_SCN_MB_FULL:          scenario_mb_full();
      L1DTLB_SCN_BUSY_WAKEUP:      scenario_busy_wakeup();
      L1DTLB_SCN_ABORT:            scenario_abort();
      L1DTLB_SCN_PERMISSION:       scenario_permission();
      L1DTLB_SCN_INVALIDATE: begin
        if (tc_id == "DTLB_INV_VA8_alias_001")
          scenario_inv_va8_alias();
        else if (tc_id == "DTLB_INV_INSTALL_SAME_ENTRY_001")
          scenario_inv_install_same_entry();
        else if (tc_id == "DTLB_INV_HIT_SAME_CYCLE_001")
          scenario_inv_hit_same_cycle();
        else
          scenario_invalidate();
      end
      L1DTLB_SCN_CREDIT:           scenario_credit();
      L1DTLB_SCN_SCHED: begin
        if (tc_id == "DTLB_ALLOC_RACE_001")
          scenario_alloc_race();
        else
          scenario_sched();
      end
      L1DTLB_SCN_REFILL: begin
        if (tc_id == "DTLB_INSTALL_VISIBILITY_001")
          scenario_install_visibility();
        else
          scenario_refill();
      end
      L1DTLB_SCN_FAULT_REFILL: begin
        if (tc_id == "DTLB_WAKEUP_EXPT_001")
          scenario_wakeup_expt();
        else if (tc_id == "DTLB_EXPT_HIT_WITH_TLB_HIT_001")
          scenario_expt_hit_with_tlb_hit();
        else
          scenario_fault_refill();
      end
      L1DTLB_SCN_HUGE:             scenario_huge();
      L1DTLB_SCN_STAMO:            scenario_stamo();
      L1DTLB_SCN_FLUSH_RACE:       scenario_flush_race();
      L1DTLB_SCN_RESET_ONLY:       scenario_reset_only();
      default: begin
        if (tc_id == "DTLB_SYSMAP_001")
          scenario_direct_map();
        else if ((tc_id == "DTLB_PLRU_001") || (tc_id == "DTLB_PLRU_WHITEBOX_ONLY_001"))
          scenario_plru_pressure();
        else if (tc_id == "DTLB_MB_STATE_SIGNAL_001")
          scenario_mb_state_signal();
        else if ((tc_id == "DTLB_REF_MODEL_OBSERVABILITY_001") || (tc_id == "DTLB_RESP_NO_IID_T01_001"))
          scenario_observability();
        else
          scenario_generic_audit();
      end
    endcase

    raw_idle();
    configure_ptw_delay(1, 4);
    m_env_h.wait_for_quiescent_midtest({tc_id, "_l1dtlb_final"}, 524288, 16);
    wait_lsu_cycles(40);
  endtask

endclass : l1dtlb_directed_vseq

`endif // MMU_L1DTLB_VSEQ_LIB_SVH
