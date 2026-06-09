// =============================================================================
// MMU UVM Verification — testbench/lsu_agent/lsu_monitor.svh
// Phase 3 (Engineer B): LSU monitor skeleton — 8 analysis ports
//   ap_pipe0_req / ap_pipe0_rsp
//   ap_pipe1_req / ap_pipe1_rsp
//   ap_pipe2_req / ap_pipe2_rsp
//   ap_inv   (TLB invalidation events)
//   ap_stamo (STAMO PA check)
//
// Phase 5 (Engineer B): Added m_pending_p0/p1 queues for req/rsp correlation.
//   pipe0/pipe1 are each 1-outstanding per stall protocol; FIFO order holds.
//   ap_pipe0_rsp / ap_pipe1_rsp txns carry VA+id+st_inst merged from the req
//   so that downstream mmu_translation_sb can call ref_model.translate().
//   Same-cycle hit responses are sampled immediately once the pending queue
//   becomes non-empty, and AP broadcasts use cloned objects so downstream
//   subscribers cannot mutate monitor-owned pending state.
//
// Phase 5 downstream connections:
//   ap_pipe0_rsp → mmu_translation_sb.af_lsu_pipe0_rsp
//   ap_pipe1_rsp → mmu_translation_sb.af_lsu_pipe1_rsp
//   ap_inv       → mmu_invalidate_sb.af_lsu_inv  (Phase 6)
// =============================================================================
`ifndef LSU_MONITOR_SVH
`define LSU_MONITOR_SVH

class lsu_monitor extends uvm_monitor;

  `uvm_component_utils(lsu_monitor)

  virtual lsu_if vif;
  virtual mmu_dut_probes_if v_probe;

  // Pipe 0
  uvm_analysis_port #(lsu_txn) ap_pipe0_req;
  uvm_analysis_port #(lsu_txn) ap_pipe0_rsp;
  uvm_analysis_port #(lsu_txn) ap_pipe0_drop;
  // Pipe 1
  uvm_analysis_port #(lsu_txn) ap_pipe1_req;
  uvm_analysis_port #(lsu_txn) ap_pipe1_rsp;
  uvm_analysis_port #(lsu_txn) ap_pipe1_drop;
  // Pipe 2 (prefetch)
  uvm_analysis_port #(lsu_txn) ap_pipe2_req;
  uvm_analysis_port #(lsu_txn) ap_pipe2_rsp;
  // TLB Invalidation
  uvm_analysis_port #(lsu_txn) ap_inv;
  // STAMO PA check
  uvm_analysis_port #(lsu_txn) ap_stamo;

  // Outstanding request queues for req/rsp correlation.
  // Pipe0/1 stall until pa_vld; pipe2 follows PFU single-outstanding protocol.
  protected lsu_txn m_pending_p0[$];
  protected lsu_txn m_pending_p1[$];
  protected lsu_txn m_pending_p2[$];
  protected bit     m_p2_rsp_seen;

  // Timeout-resilience flags: set by _collect_pipeN_rsp when pa_vld arrives,
  // checked by _collect_pipeN_req when va_vld deasserts.  If the flag is still
  // 0 when va_vld falls, the driver timed out → discard the pending entry.
  protected bit m_p0_rsp_seen;
  protected bit m_p1_rsp_seen;
  protected int unsigned m_inv_done_watchdog_cycles;

  protected function lsu_txn _clone_txn(lsu_txn src, string name);
    lsu_txn dst;
    dst = lsu_txn::type_id::create(name);
    dst.copy(src);
    return dst;
  endfunction

  protected function bit [1:0] _effective_priv();
    if (v_probe == null)
      return 2'b00;
    // Match RTL: cp0_priv_mode = cp0_mmu_mprv ? cp0_mmu_mpp : cp0_yy_priv_mode
    if (v_probe.mon_cb.l1d_cp0_mprv === 1'b1)
      return v_probe.mon_cb.l1d_cp0_mpp;
    return v_probe.mon_cb.l1d_cp0_priv_mode;
  endfunction

  protected function void _sample_obs_common(ref lsu_txn tr);
    tr.obs_valid = (v_probe != null);
    if (v_probe == null)
      return;

    tr.eff_priv   = _effective_priv();
    tr.mprv       = v_probe.mon_cb.l1d_cp0_mprv;
    tr.mpp        = v_probe.mon_cb.l1d_cp0_mpp;
    tr.mxr        = v_probe.mon_cb.l1d_cp0_mxr;
    tr.sum        = v_probe.mon_cb.l1d_cp0_sum;
    tr.maee       = v_probe.mon_cb.l1d_cp0_maee;
    tr.asid       = v_probe.mon_cb.l1d_regs_cur_asid;
    tr.satp_ppn   = v_probe.mon_cb.l1d_regs_satp_ppn;
    tr.direct_map = (vif.monitor_cb.mmu_lsu_mmu_en === 1'b0);
  endfunction

  protected function void _sample_pipe0_obs(ref lsu_txn tr);
    _sample_obs_common(tr);
    tr.req_type = tr.st_inst ? 3'd1 : 3'd0;
    if (v_probe == null)
      return;
    tr.l1d_hit_vld    = v_probe.mon_cb.l1d_p0_hit_vld;
    tr.l1d_miss_vld   = v_probe.mon_cb.l1d_p0_miss_vld;
    tr.l1d_mb_hit     = v_probe.mon_cb.l1d_p0_mb_hit;
    tr.l1d_pre_sel    = v_probe.mon_cb.l1d_p0_pre_sel;
    tr.l1d_hit_idx    = v_probe.mon_cb.l1d_p0_hit_idx;
    tr.l1d_hit_pgs    = v_probe.mon_cb.l1d_p0_hit_pgs;
    tr.l1d_hit_ppn    = v_probe.mon_cb.l1d_p0_hit_ppn;
    tr.l1d_fin_pa     = v_probe.mon_cb.l1d_p0_fin_pa;
    tr.l1d_pmp_flg    = v_probe.mon_cb.l1d_pmp_flg0;
    tr.l1d_sysmap_flg = v_probe.mon_cb.l1d_sysmap_flg0;
    tr.l1d_sysmap_hit = v_probe.mon_cb.l1d_sysmap_hit0;
    tr.l1d_sysmap_pa  = v_probe.mon_cb.l1d_sysmap_pa0;
  endfunction

  protected function void _sample_pipe1_obs(ref lsu_txn tr);
    _sample_obs_common(tr);
    tr.req_type = tr.st_inst ? 3'd1 : 3'd0;
    if (v_probe == null)
      return;
    tr.l1d_hit_vld    = v_probe.mon_cb.l1d_p1_hit_vld;
    tr.l1d_miss_vld   = v_probe.mon_cb.l1d_p1_miss_vld;
    tr.l1d_mb_hit     = v_probe.mon_cb.l1d_p1_mb_hit;
    tr.l1d_pre_sel    = v_probe.mon_cb.l1d_p1_pre_sel;
    tr.l1d_hit_idx    = v_probe.mon_cb.l1d_p1_hit_idx;
    tr.l1d_hit_pgs    = v_probe.mon_cb.l1d_p1_hit_pgs;
    tr.l1d_hit_ppn    = v_probe.mon_cb.l1d_p1_hit_ppn;
    tr.l1d_fin_pa     = v_probe.mon_cb.l1d_p1_fin_pa;
    tr.l1d_pmp_flg    = v_probe.mon_cb.l1d_pmp_flg1;
    tr.l1d_sysmap_flg = v_probe.mon_cb.l1d_sysmap_flg1;
    tr.l1d_sysmap_hit = v_probe.mon_cb.l1d_sysmap_hit1;
    tr.l1d_sysmap_pa  = v_probe.mon_cb.l1d_sysmap_pa1;
  endfunction

  protected function void _sample_pipe0_rsp_fields(ref lsu_txn tr);
    tr.kind             = LSU_PIPE0;
    tr.pa               = vif.monitor_cb.mmu_lsu_pa0;
    tr.pgflt            = vif.monitor_cb.mmu_lsu_page_fault0;
    tr.access_fault     = vif.monitor_cb.mmu_lsu_access_fault0;
    tr.stall            = vif.monitor_cb.mmu_lsu_stall0;
    tr.sec              = vif.monitor_cb.mmu_lsu_sec0;
    tr.mmu_en           = vif.monitor_cb.mmu_lsu_mmu_en;
    tr.tlb_busy         = vif.monitor_cb.mmu_lsu_tlb_busy;
    tr.tlb_wakeup       = vif.monitor_cb.mmu_lsu_tlb_wakeup;
    tr.stamo_vld_at_rsp = vif.monitor_cb.lsu_mmu_stamo_vld;
    tr.stamo_pa_at_rsp  = vif.monitor_cb.lsu_mmu_stamo_pa;
    tr.dtlb_expt_match  = vif.monitor_cb.mmu_lsu_dtlb_expt_match0;
    _sample_pipe0_obs(tr);
  endfunction

  protected function void _sample_pipe1_rsp_fields(ref lsu_txn tr);
    tr.kind             = LSU_PIPE1;
    tr.pa               = vif.monitor_cb.mmu_lsu_pa1;
    tr.pgflt            = vif.monitor_cb.mmu_lsu_page_fault1;
    tr.access_fault     = vif.monitor_cb.mmu_lsu_access_fault1;
    tr.stall            = vif.monitor_cb.mmu_lsu_stall1;
    tr.sec              = vif.monitor_cb.mmu_lsu_sec1;
    tr.mmu_en           = vif.monitor_cb.mmu_lsu_mmu_en;
    tr.tlb_busy         = vif.monitor_cb.mmu_lsu_tlb_busy;
    tr.tlb_wakeup       = vif.monitor_cb.mmu_lsu_tlb_wakeup;
    tr.stamo_vld_at_rsp = vif.monitor_cb.lsu_mmu_stamo_vld;
    tr.stamo_pa_at_rsp  = vif.monitor_cb.lsu_mmu_stamo_pa;
    tr.dtlb_expt_match  = vif.monitor_cb.mmu_lsu_dtlb_expt_match1;
    _sample_pipe1_obs(tr);
  endfunction

  protected function bit _pipe0_t0_terminal();
    return (vif.monitor_cb.mmu_lsu_pa0_vld === 1'b1)
        || (vif.monitor_cb.mmu_lsu_page_fault0 === 1'b1)
        || (vif.monitor_cb.mmu_lsu_access_fault0 === 1'b1);
  endfunction

  protected function bit _pipe1_t0_terminal();
    return (vif.monitor_cb.mmu_lsu_pa1_vld === 1'b1)
        || (vif.monitor_cb.mmu_lsu_page_fault1 === 1'b1)
        || (vif.monitor_cb.mmu_lsu_access_fault1 === 1'b1);
  endfunction

  function new(string name, uvm_component parent);
    super.new(name, parent);
    m_inv_done_watchdog_cycles = 8192;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(virtual lsu_if)::get(this, "", "LSU_VIF", vif))
      `uvm_fatal(get_type_name(), "Cannot get LSU_VIF from config_db")
    if (!uvm_config_db #(virtual mmu_dut_probes_if)::get(this, "", "MMU_DUT_PROBES_VIF", v_probe))
      `uvm_info(get_type_name(),
        "MMU_DUT_PROBES_VIF not in config_db - pipe2 monitor will fall back to va2_vld edge correlation",
        UVM_LOW)
    ap_pipe0_req = new("ap_pipe0_req", this);
    ap_pipe0_rsp = new("ap_pipe0_rsp", this);
    ap_pipe0_drop = new("ap_pipe0_drop", this);
    ap_pipe1_req = new("ap_pipe1_req", this);
    ap_pipe1_rsp = new("ap_pipe1_rsp", this);
    ap_pipe1_drop = new("ap_pipe1_drop", this);
    ap_pipe2_req = new("ap_pipe2_req", this);
    ap_pipe2_rsp = new("ap_pipe2_rsp", this);
    ap_inv       = new("ap_inv",       this);
    ap_stamo     = new("ap_stamo",     this);
    void'($value$plusargs("LSU_INV_DONE_WATCHDOG_CYCLES=%0d", m_inv_done_watchdog_cycles));
    void'($value$plusargs("LSU_INV_RSP_WATCHDOG_CYCLES=%0d", m_inv_done_watchdog_cycles));
    if (m_inv_done_watchdog_cycles == 0)
      m_inv_done_watchdog_cycles = 1;
  endfunction

  virtual task run_phase(uvm_phase phase);
    fork
      _collect_pipe0_sm();
      _collect_pipe1_sm();
      _collect_pipe2_sm();
      _collect_inv();
      _collect_stamo();
    join_none
  endtask

  // ── Pipe 0 single-state monitor ──────────────────────────────────────────
  // Use a single per-pipe state machine so request open / response bind /
  // drop cleanup all observe one coherent sampled timeline. This avoids
  // binding a residual pa0_vld tail from the previous request to a new req.
  protected task _collect_pipe0_sm();
    lsu_txn pending_req;
    bit     has_pending;
    bit     prev_rsp_seen;
    bit     rsp_tail_hold;
    bit [63:0] rsp_tail_va;
    bit [6:0]  rsp_tail_id;
    bit        rsp_tail_st_inst;
    bit        rsp_tail_abort;
    int unsigned drop_reopen_block;
    bit [63:0] drop_reopen_va;
    bit        drop_reopen_abort;

    has_pending       = 1'b0;
    prev_rsp_seen     = 1'b0;
    rsp_tail_hold     = 1'b0;
    rsp_tail_va       = '0;
    rsp_tail_id       = '0;
    rsp_tail_st_inst  = 1'b0;
    rsp_tail_abort    = 1'b0;
    drop_reopen_block = 0;
    drop_reopen_va    = '0;
    drop_reopen_abort = 1'b0;

    forever begin
      lsu_txn req_tr, rsp_tr, drop_tr;
      bit     req_seen;
      bit     rsp_seen;
      bit     fresh_rsp;
      bit     hold_blocks_reopen;
      bit [63:0] cur_va;
      bit [6:0]  cur_id;
      bit        cur_st_inst;
      bit        cur_abort;
      bit [27:0] cur_vabuf;

      @(vif.monitor_cb);

      if (vif.rst_ni !== 1'b1) begin
        has_pending       = 1'b0;
        prev_rsp_seen     = 1'b0;
        rsp_tail_hold     = 1'b0;
        rsp_tail_va       = '0;
        rsp_tail_id       = '0;
        rsp_tail_st_inst  = 1'b0;
        rsp_tail_abort    = 1'b0;
        drop_reopen_block = 0;
        drop_reopen_va    = '0;
        drop_reopen_abort = 1'b0;
        continue;
      end

      req_seen    = vif.monitor_cb.lsu_mmu_va0_vld;
      rsp_seen    = _pipe0_t0_terminal();
      fresh_rsp   = rsp_seen && !prev_rsp_seen;
      cur_va      = vif.monitor_cb.lsu_mmu_va0;
      cur_id      = vif.monitor_cb.lsu_mmu_id0;
      cur_st_inst = vif.monitor_cb.lsu_mmu_st_inst0;
      cur_abort   = vif.monitor_cb.lsu_mmu_abort0;
      cur_vabuf   = vif.monitor_cb.lsu_mmu_vabuf0;

      if (rsp_tail_hold &&
          (!req_seen
           || (cur_va      !== rsp_tail_va)
           || (cur_id      !== rsp_tail_id)
           || (cur_st_inst !== rsp_tail_st_inst)
           || (cur_abort   !== rsp_tail_abort))) begin
        rsp_tail_hold = 1'b0;
      end

      hold_blocks_reopen = rsp_tail_hold
                        && req_seen
                        && (cur_va      === rsp_tail_va)
                        && (cur_id      === rsp_tail_id)
                        && (cur_st_inst === rsp_tail_st_inst)
                        && (cur_abort   === rsp_tail_abort);
      hold_blocks_reopen = hold_blocks_reopen || (drop_reopen_block != 0);

      if (req_seen && !has_pending && !hold_blocks_reopen) begin
        req_tr           = lsu_txn::type_id::create("lsu_p0_req_sm");
        req_tr.kind      = LSU_PIPE0;
        req_tr.va        = cur_va;
        req_tr.id        = cur_id;
        req_tr.st_inst   = cur_st_inst;
        req_tr.abort     = cur_abort;
        req_tr.vabuf     = cur_vabuf;
        req_tr.tlb_busy  = vif.monitor_cb.mmu_lsu_tlb_busy;
        req_tr.tlb_wakeup= vif.monitor_cb.mmu_lsu_tlb_wakeup;
        _sample_pipe0_obs(req_tr);
        pending_req      = _clone_txn(req_tr, "lsu_p0_req_pending_sm");
        has_pending      = 1'b1;
        `uvm_info(get_type_name(),
          $sformatf("[LSU_P0_REQ_DBG] open pending: va=0x%010h id=%0d st=%0b abort=%0b pavld=%0b pa=0x%07h mmu_en=%0b tlb_busy=%0b wakeup=0x%03h",
            {1'b0, req_tr.va[38:0]}, req_tr.id, req_tr.st_inst, req_tr.abort,
            vif.monitor_cb.mmu_lsu_pa0_vld, vif.monitor_cb.mmu_lsu_pa0,
            vif.monitor_cb.mmu_lsu_mmu_en, vif.monitor_cb.mmu_lsu_tlb_busy,
            vif.monitor_cb.mmu_lsu_tlb_wakeup),
          UVM_DEBUG)
        `uvm_info(get_type_name(), {"P0 REQ: ", req_tr.convert2string()}, UVM_HIGH)
        ap_pipe0_req.write(_clone_txn(req_tr, "lsu_p0_req_ap_sm"));
      end

      if (fresh_rsp) begin
        if (!has_pending) begin
          if (drop_reopen_block != 0) begin
            `uvm_warning(get_type_name(),
              $sformatf("[LSU_P0_LATE_RSP_AFTER_DROP] ignore rsp during drop barrier: dropped_va=0x%010h dropped_abort=%0b cur_va=0x%010h pa=0x%07h pgflt=%0b acflt=%0b",
                {1'b0, drop_reopen_va[38:0]}, drop_reopen_abort,
                {1'b0, cur_va[38:0]}, vif.monitor_cb.mmu_lsu_pa0,
                vif.monitor_cb.mmu_lsu_page_fault0, vif.monitor_cb.mmu_lsu_access_fault0))
          end else begin
            `uvm_warning(get_type_name(),
              $sformatf("[LSU_P0_ORPHAN_RSP] rsp observed without pending req: cur_va=0x%010h pa=0x%07h pgflt=%0b acflt=%0b",
                {1'b0, cur_va[38:0]}, vif.monitor_cb.mmu_lsu_pa0,
                vif.monitor_cb.mmu_lsu_page_fault0, vif.monitor_cb.mmu_lsu_access_fault0))
          end
        end else begin
          rsp_tr = lsu_txn::type_id::create("lsu_p0_rsp_sm");
          _sample_pipe0_rsp_fields(rsp_tr);
          rsp_tr.va      = pending_req.va;
          rsp_tr.id      = pending_req.id;
          rsp_tr.st_inst = pending_req.st_inst;
          rsp_tr.abort   = pending_req.abort;
          rsp_tr.vabuf   = pending_req.vabuf;
          _sample_pipe0_obs(rsp_tr);
          if (!rsp_tr.obs_valid && pending_req.obs_valid) begin
            rsp_tr.obs_valid = pending_req.obs_valid;
            rsp_tr.eff_priv  = pending_req.eff_priv;
            rsp_tr.mprv      = pending_req.mprv;
            rsp_tr.mpp       = pending_req.mpp;
            rsp_tr.mxr       = pending_req.mxr;
            rsp_tr.sum       = pending_req.sum;
            rsp_tr.maee      = pending_req.maee;
            rsp_tr.asid      = pending_req.asid;
            rsp_tr.satp_ppn  = pending_req.satp_ppn;
            rsp_tr.req_type  = pending_req.req_type;
          end
          `uvm_info(get_type_name(),
            $sformatf("[LSU_P0_RSP_DBG] bind rsp: pending_va=0x%010h cur_va=0x%010h id=%0d pa=0x%07h pgflt=%0b acflt=%0b stall=%0b mmu_en=%0b dtlb_expt_match=%0b busy=%0b wakeup=0x%03h",
              {1'b0, pending_req.va[38:0]}, {1'b0, cur_va[38:0]}, rsp_tr.id,
              rsp_tr.pa, rsp_tr.pgflt, rsp_tr.access_fault, rsp_tr.stall,
              rsp_tr.mmu_en, rsp_tr.dtlb_expt_match,
              vif.monitor_cb.mmu_lsu_tlb_busy, vif.monitor_cb.mmu_lsu_tlb_wakeup),
            UVM_DEBUG)
          rsp_tail_hold    = req_seen;
          rsp_tail_va      = pending_req.va;
          rsp_tail_id      = pending_req.id;
          rsp_tail_st_inst = pending_req.st_inst;
          rsp_tail_abort   = pending_req.abort;
          has_pending      = 1'b0;
          `uvm_info(get_type_name(), {"P0 RSP: ", rsp_tr.convert2string()}, UVM_HIGH)
          ap_pipe0_rsp.write(_clone_txn(rsp_tr, "lsu_p0_rsp_ap_sm"));
        end
      end

      if (!fresh_rsp && has_pending && !req_seen) begin
        drop_tr       = _clone_txn(pending_req, "lsu_p0_drop_sm");
        has_pending   = 1'b0;
        drop_reopen_block = 2;
        drop_reopen_va    = drop_tr.va;
        drop_reopen_abort = drop_tr.abort;
        `uvm_info(get_type_name(),
          $sformatf("P0 REQ dropped before rsp: VA=0x%016h id=%0d",
            drop_tr.va, drop_tr.id), UVM_DEBUG)
        ap_pipe0_drop.write(_clone_txn(drop_tr, "lsu_p0_drop_ap_sm"));
      end

      if (drop_reopen_block != 0) begin
        drop_reopen_block--;
        if (drop_reopen_block == 0) begin
          drop_reopen_va    = '0;
          drop_reopen_abort = 1'b0;
        end
      end

      prev_rsp_seen = rsp_seen;
    end
  endtask

  // ── Pipe 1 single-state monitor ──────────────────────────────────────────
  protected task _collect_pipe1_sm();
    lsu_txn pending_req;
    bit     has_pending;
    bit     prev_rsp_seen;
    bit     rsp_tail_hold;
    bit [63:0] rsp_tail_va;
    bit [6:0]  rsp_tail_id;
    bit        rsp_tail_st_inst;
    bit        rsp_tail_abort;
    int unsigned drop_reopen_block;
    bit [63:0] drop_reopen_va;
    bit        drop_reopen_abort;

    has_pending       = 1'b0;
    prev_rsp_seen     = 1'b0;
    rsp_tail_hold     = 1'b0;
    rsp_tail_va       = '0;
    rsp_tail_id       = '0;
    rsp_tail_st_inst  = 1'b0;
    rsp_tail_abort    = 1'b0;
    drop_reopen_block = 0;
    drop_reopen_va    = '0;
    drop_reopen_abort = 1'b0;

    forever begin
      lsu_txn req_tr, rsp_tr, drop_tr;
      bit     req_seen;
      bit     rsp_seen;
      bit     fresh_rsp;
      bit     hold_blocks_reopen;
      bit [63:0] cur_va;
      bit [6:0]  cur_id;
      bit        cur_st_inst;
      bit        cur_abort;
      bit [27:0] cur_vabuf;

      @(vif.monitor_cb);

      if (vif.rst_ni !== 1'b1) begin
        has_pending       = 1'b0;
        prev_rsp_seen     = 1'b0;
        rsp_tail_hold     = 1'b0;
        rsp_tail_va       = '0;
        rsp_tail_id       = '0;
        rsp_tail_st_inst  = 1'b0;
        rsp_tail_abort    = 1'b0;
        drop_reopen_block = 0;
        drop_reopen_va    = '0;
        drop_reopen_abort = 1'b0;
        continue;
      end

      req_seen    = vif.monitor_cb.lsu_mmu_va1_vld;
      rsp_seen    = _pipe1_t0_terminal();
      fresh_rsp   = rsp_seen && !prev_rsp_seen;
      cur_va      = vif.monitor_cb.lsu_mmu_va1;
      cur_id      = vif.monitor_cb.lsu_mmu_id1;
      cur_st_inst = vif.monitor_cb.lsu_mmu_st_inst1;
      cur_abort   = vif.monitor_cb.lsu_mmu_abort1;
      cur_vabuf   = vif.monitor_cb.lsu_mmu_vabuf1;

      if (rsp_tail_hold &&
          (!req_seen
           || (cur_va      !== rsp_tail_va)
           || (cur_id      !== rsp_tail_id)
           || (cur_st_inst !== rsp_tail_st_inst)
           || (cur_abort   !== rsp_tail_abort))) begin
        rsp_tail_hold = 1'b0;
      end

      hold_blocks_reopen = rsp_tail_hold
                        && req_seen
                        && (cur_va      === rsp_tail_va)
                        && (cur_id      === rsp_tail_id)
                        && (cur_st_inst === rsp_tail_st_inst)
                        && (cur_abort   === rsp_tail_abort);
      hold_blocks_reopen = hold_blocks_reopen || (drop_reopen_block != 0);

      if (req_seen && !has_pending && !hold_blocks_reopen) begin
        req_tr            = lsu_txn::type_id::create("lsu_p1_req_sm");
        req_tr.kind       = LSU_PIPE1;
        req_tr.va         = cur_va;
        req_tr.id         = cur_id;
        req_tr.st_inst    = cur_st_inst;
        req_tr.abort      = cur_abort;
        req_tr.vabuf      = cur_vabuf;
        req_tr.tlb_busy   = vif.monitor_cb.mmu_lsu_tlb_busy;
        req_tr.tlb_wakeup = vif.monitor_cb.mmu_lsu_tlb_wakeup;
        _sample_pipe1_obs(req_tr);
        pending_req       = _clone_txn(req_tr, "lsu_p1_req_pending_sm");
        has_pending       = 1'b1;
        `uvm_info(get_type_name(),
          $sformatf("[LSU_P1_REQ_DBG] open pending: va=0x%010h id=%0d st=%0b abort=%0b pavld=%0b pa=0x%07h mmu_en=%0b tlb_busy=%0b wakeup=0x%03h",
            {1'b0, req_tr.va[38:0]}, req_tr.id, req_tr.st_inst, req_tr.abort,
            vif.monitor_cb.mmu_lsu_pa1_vld, vif.monitor_cb.mmu_lsu_pa1,
            vif.monitor_cb.mmu_lsu_mmu_en, vif.monitor_cb.mmu_lsu_tlb_busy,
            vif.monitor_cb.mmu_lsu_tlb_wakeup),
          UVM_DEBUG)
        `uvm_info(get_type_name(), {"P1 REQ: ", req_tr.convert2string()}, UVM_HIGH)
        ap_pipe1_req.write(_clone_txn(req_tr, "lsu_p1_req_ap_sm"));
      end

      if (fresh_rsp) begin
        if (!has_pending) begin
          if (drop_reopen_block != 0) begin
            `uvm_warning(get_type_name(),
              $sformatf("[LSU_P1_LATE_RSP_AFTER_DROP] ignore rsp during drop barrier: dropped_va=0x%010h dropped_abort=%0b cur_va=0x%010h pa=0x%07h pgflt=%0b acflt=%0b",
                {1'b0, drop_reopen_va[38:0]}, drop_reopen_abort,
                {1'b0, cur_va[38:0]}, vif.monitor_cb.mmu_lsu_pa1,
                vif.monitor_cb.mmu_lsu_page_fault1, vif.monitor_cb.mmu_lsu_access_fault1))
          end else begin
            `uvm_warning(get_type_name(),
              $sformatf("[LSU_P1_ORPHAN_RSP] rsp observed without pending req: cur_va=0x%010h pa=0x%07h pgflt=%0b acflt=%0b",
                {1'b0, cur_va[38:0]}, vif.monitor_cb.mmu_lsu_pa1,
                vif.monitor_cb.mmu_lsu_page_fault1, vif.monitor_cb.mmu_lsu_access_fault1))
          end
        end else begin
          rsp_tr = lsu_txn::type_id::create("lsu_p1_rsp_sm");
          _sample_pipe1_rsp_fields(rsp_tr);
          rsp_tr.va      = pending_req.va;
          rsp_tr.id      = pending_req.id;
          rsp_tr.st_inst = pending_req.st_inst;
          rsp_tr.abort   = pending_req.abort;
          rsp_tr.vabuf   = pending_req.vabuf;
          _sample_pipe1_obs(rsp_tr);
          if (!rsp_tr.obs_valid && pending_req.obs_valid) begin
            rsp_tr.obs_valid = pending_req.obs_valid;
            rsp_tr.eff_priv  = pending_req.eff_priv;
            rsp_tr.mprv      = pending_req.mprv;
            rsp_tr.mpp       = pending_req.mpp;
            rsp_tr.mxr       = pending_req.mxr;
            rsp_tr.sum       = pending_req.sum;
            rsp_tr.maee      = pending_req.maee;
            rsp_tr.asid      = pending_req.asid;
            rsp_tr.satp_ppn  = pending_req.satp_ppn;
            rsp_tr.req_type  = pending_req.req_type;
          end
          `uvm_info(get_type_name(),
            $sformatf("[LSU_P1_RSP_DBG] bind rsp: pending_va=0x%010h cur_va=0x%010h id=%0d pa=0x%07h pgflt=%0b acflt=%0b stall=%0b mmu_en=%0b dtlb_expt_match=%0b busy=%0b wakeup=0x%03h",
              {1'b0, pending_req.va[38:0]}, {1'b0, cur_va[38:0]}, rsp_tr.id,
              rsp_tr.pa, rsp_tr.pgflt, rsp_tr.access_fault, rsp_tr.stall,
              rsp_tr.mmu_en, rsp_tr.dtlb_expt_match,
              vif.monitor_cb.mmu_lsu_tlb_busy, vif.monitor_cb.mmu_lsu_tlb_wakeup),
            UVM_DEBUG)
          rsp_tail_hold    = req_seen;
          rsp_tail_va      = pending_req.va;
          rsp_tail_id      = pending_req.id;
          rsp_tail_st_inst = pending_req.st_inst;
          rsp_tail_abort   = pending_req.abort;
          has_pending      = 1'b0;
          `uvm_info(get_type_name(), {"P1 RSP: ", rsp_tr.convert2string()}, UVM_HIGH)
          ap_pipe1_rsp.write(_clone_txn(rsp_tr, "lsu_p1_rsp_ap_sm"));
        end
      end

      if (!fresh_rsp && has_pending && !req_seen) begin
        drop_tr       = _clone_txn(pending_req, "lsu_p1_drop_sm");
        has_pending   = 1'b0;
        drop_reopen_block = 2;
        drop_reopen_va    = drop_tr.va;
        drop_reopen_abort = drop_tr.abort;
        `uvm_info(get_type_name(),
          $sformatf("P1 REQ dropped before rsp: VA=0x%016h id=%0d",
            drop_tr.va, drop_tr.id), UVM_DEBUG)
        ap_pipe1_drop.write(_clone_txn(drop_tr, "lsu_p1_drop_ap_sm"));
      end

      if (drop_reopen_block != 0) begin
        drop_reopen_block--;
        if (drop_reopen_block == 0) begin
          drop_reopen_va    = '0;
          drop_reopen_abort = 1'b0;
        end
      end

      prev_rsp_seen = rsp_seen;
    end
  endtask

  // ── Pipe 0 request ────────────────────────────────────────────────────────
  // Edge detection: wait for va0_vld HIGH, sample once, then wait for LOW
  // before looping.  When va0_vld falls, check if a matching T0 terminal was
  // received.  If not (driver timeout), pop the stale entry to keep the
  // m_pending_p0 FIFO in sync and prevent downstream PA mismatch cascades.
  protected task _collect_pipe0_req();
    lsu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.lsu_mmu_va0_vld);
      tr          = lsu_txn::type_id::create("lsu_p0_req");
      tr.kind     = LSU_PIPE0;
      tr.va       = vif.monitor_cb.lsu_mmu_va0;
      tr.id       = vif.monitor_cb.lsu_mmu_id0;
      tr.st_inst  = vif.monitor_cb.lsu_mmu_st_inst0;
      tr.abort    = vif.monitor_cb.lsu_mmu_abort0;
      tr.vabuf    = vif.monitor_cb.lsu_mmu_vabuf0;
      tr.tlb_busy = vif.monitor_cb.mmu_lsu_tlb_busy;
      tr.tlb_wakeup = vif.monitor_cb.mmu_lsu_tlb_wakeup;
      _sample_pipe0_obs(tr);
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P0_REQ_DBG] va=0x%010h id=%0d st=%0b abort=%0b mmu_en=%0b tlb_busy=%0b tlb_wakeup=0x%03h",
          {1'b0, tr.va[38:0]}, tr.id, tr.st_inst, tr.abort,
          vif.monitor_cb.mmu_lsu_mmu_en, vif.monitor_cb.mmu_lsu_tlb_busy, vif.monitor_cb.mmu_lsu_tlb_wakeup),
        UVM_DEBUG)
      `uvm_info(get_type_name(), {"P0 REQ: ", tr.convert2string()}, UVM_HIGH)
      m_p0_rsp_seen = 0;
      m_pending_p0.push_back(_clone_txn(tr, "lsu_p0_req_pending"));
      ap_pipe0_req.write(_clone_txn(tr, "lsu_p0_req_ap"));
      // Wait for va0_vld to deassert (rising-edge semantics)
      @(vif.monitor_cb iff !vif.monitor_cb.lsu_mmu_va0_vld);
      // If va0_vld fell without a matching T0 terminal (driver timeout),
      // discard the pending entry to prevent FIFO desync.
      if (!m_p0_rsp_seen && m_pending_p0.size() > 0) begin
        lsu_txn drop_tr;
        drop_tr = m_pending_p0.pop_back();
        `uvm_info(get_type_name(),
          $sformatf("P0 REQ dropped (no pipe0 terminal before va0_vld deassert): VA=0x%016h id=%0d",
            tr.va, tr.id), UVM_DEBUG)
        ap_pipe0_drop.write(_clone_txn(drop_tr, "lsu_p0_drop_ap"));
      end
    end
  endtask

  // ── Pipe 0 response ───────────────────────────────────────────────────────
  // Wait for a matching req in the queue before latching T0 terminal. If it is
  // already high on the same sampled cycle as the req, capture it immediately
  // instead of waiting for a later edge and risking req/rsp skew.
  protected task _collect_pipe0_rsp();
    lsu_txn tr, req_tr;
    forever begin
      wait(m_pending_p0.size() > 0);
      if (!_pipe0_t0_terminal())
        @(vif.monitor_cb iff ((vif.monitor_cb.mmu_lsu_pa0_vld === 1'b1)
                           || (vif.monitor_cb.mmu_lsu_page_fault0 === 1'b1)
                           || (vif.monitor_cb.mmu_lsu_access_fault0 === 1'b1)));
      tr              = lsu_txn::type_id::create("lsu_p0_rsp");
      _sample_pipe0_rsp_fields(tr);
      // --- Req/rsp correlation (FIFO, 1-outstanding per pipe) ---
      req_tr      = m_pending_p0.pop_front();
      m_p0_rsp_seen = 1;
      tr.va       = req_tr.va;
      tr.id       = req_tr.id;
      tr.st_inst  = req_tr.st_inst;
      tr.abort    = req_tr.abort;
      tr.vabuf    = req_tr.vabuf;
      _sample_pipe0_obs(tr);
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P0_RSP_DBG] va=0x%010h id=%0d pa=0x%07h pgflt=%0b acflt=%0b stall=%0b mmu_en=%0b dtlb_expt_match=%0b busy=%0b wakeup=0x%03h pend_depth=%0d",
          {1'b0, tr.va[38:0]}, tr.id, tr.pa, tr.pgflt, tr.access_fault, tr.stall,
          tr.mmu_en, tr.dtlb_expt_match,
          vif.monitor_cb.mmu_lsu_tlb_busy, vif.monitor_cb.mmu_lsu_tlb_wakeup, m_pending_p0.size()),
        UVM_DEBUG)
      `uvm_info(get_type_name(), {"P0 RSP: ", tr.convert2string()}, UVM_HIGH)
      ap_pipe0_rsp.write(_clone_txn(tr, "lsu_p0_rsp_ap"));
      @(vif.monitor_cb iff !((vif.monitor_cb.mmu_lsu_pa0_vld === 1'b1)
                          || (vif.monitor_cb.mmu_lsu_page_fault0 === 1'b1)
                          || (vif.monitor_cb.mmu_lsu_access_fault0 === 1'b1)));
    end
  endtask

  // ── Pipe 1 request ────────────────────────────────────────────────────────
  // Same timeout-resilient approach as pipe0: track va1_vld deassert without
  // pipe1 terminal and discard the stale pending entry if so.
  protected task _collect_pipe1_req();
    lsu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.lsu_mmu_va1_vld);
      tr         = lsu_txn::type_id::create("lsu_p1_req");
      tr.kind    = LSU_PIPE1;
      tr.va      = vif.monitor_cb.lsu_mmu_va1;
      tr.id      = vif.monitor_cb.lsu_mmu_id1;
      tr.st_inst = vif.monitor_cb.lsu_mmu_st_inst1;
      tr.abort   = vif.monitor_cb.lsu_mmu_abort1;
      tr.vabuf   = vif.monitor_cb.lsu_mmu_vabuf1;
      tr.tlb_busy = vif.monitor_cb.mmu_lsu_tlb_busy;
      tr.tlb_wakeup = vif.monitor_cb.mmu_lsu_tlb_wakeup;
      _sample_pipe1_obs(tr);
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P1_REQ_DBG] va=0x%010h id=%0d st=%0b abort=%0b mmu_en=%0b tlb_busy=%0b tlb_wakeup=0x%03h",
          {1'b0, tr.va[38:0]}, tr.id, tr.st_inst, tr.abort,
          vif.monitor_cb.mmu_lsu_mmu_en, vif.monitor_cb.mmu_lsu_tlb_busy, vif.monitor_cb.mmu_lsu_tlb_wakeup),
        UVM_DEBUG)
      m_p1_rsp_seen = 0;
      m_pending_p1.push_back(_clone_txn(tr, "lsu_p1_req_pending"));
      ap_pipe1_req.write(_clone_txn(tr, "lsu_p1_req_ap"));
      @(vif.monitor_cb iff !vif.monitor_cb.lsu_mmu_va1_vld);
      if (!m_p1_rsp_seen && m_pending_p1.size() > 0) begin
        lsu_txn drop_tr;
        drop_tr = m_pending_p1.pop_back();
        `uvm_info(get_type_name(),
          $sformatf("P1 REQ dropped (no pipe1 terminal before va1_vld deassert): VA=0x%016h id=%0d",
            tr.va, tr.id), UVM_DEBUG)
        ap_pipe1_drop.write(_clone_txn(drop_tr, "lsu_p1_drop_ap"));
      end
    end
  endtask

  // ── Pipe 1 response (same req-before-pa ordering as pipe0) ────────────────
  protected task _collect_pipe1_rsp();
    lsu_txn tr, req_tr;
    forever begin
      wait(m_pending_p1.size() > 0);
      if (!_pipe1_t0_terminal())
        @(vif.monitor_cb iff ((vif.monitor_cb.mmu_lsu_pa1_vld === 1'b1)
                           || (vif.monitor_cb.mmu_lsu_page_fault1 === 1'b1)
                           || (vif.monitor_cb.mmu_lsu_access_fault1 === 1'b1)));
      tr              = lsu_txn::type_id::create("lsu_p1_rsp");
      _sample_pipe1_rsp_fields(tr);
      req_tr      = m_pending_p1.pop_front();
      m_p1_rsp_seen = 1;
      tr.va       = req_tr.va;
      tr.id       = req_tr.id;
      tr.st_inst  = req_tr.st_inst;
      tr.abort    = req_tr.abort;
      tr.vabuf    = req_tr.vabuf;
      _sample_pipe1_obs(tr);
      `uvm_info(get_type_name(),
        $sformatf("[LSU_P1_RSP_DBG] va=0x%010h id=%0d pa=0x%07h pgflt=%0b acflt=%0b stall=%0b mmu_en=%0b dtlb_expt_match=%0b busy=%0b wakeup=0x%03h pend_depth=%0d",
          {1'b0, tr.va[38:0]}, tr.id, tr.pa, tr.pgflt, tr.access_fault, tr.stall,
          tr.mmu_en, tr.dtlb_expt_match,
          vif.monitor_cb.mmu_lsu_tlb_busy, vif.monitor_cb.mmu_lsu_tlb_wakeup, m_pending_p1.size()),
        UVM_DEBUG)
      // Same-cycle bus snapshot (enable with +MMU_LSU_MON_DBG) to correlate P1 PA
      // with P0 / STAMO and spot mux or STAMO overlay issues vs translation_sb.
      if ($test$plusargs("MMU_LSU_MON_DBG")) begin
        `uvm_info("LSU_MON_DBG",
          $sformatf(
            "[P1] t=%0t VA=%010h VPN=%07h id=%0d st=%0b | P1: pa=%07h pav=%0b pg=%0b af=%0b st=%0b va1v=%0b vabuf=%07h | P0: pa=%07h pav=%0b va0v=%0b | stamo: v=%0b pa=%07h | mmu_en=%0b tlb_b=%0b tlb_wk=0x%03h",
            $time, {1'b0, tr.va[38:0]}, tr.va[38:12], tr.id, tr.st_inst,
            vif.monitor_cb.mmu_lsu_pa1, vif.monitor_cb.mmu_lsu_pa1_vld,
            vif.monitor_cb.mmu_lsu_page_fault1, vif.monitor_cb.mmu_lsu_access_fault1,
            vif.monitor_cb.mmu_lsu_stall1, vif.monitor_cb.lsu_mmu_va1_vld, vif.monitor_cb.lsu_mmu_vabuf1,
            vif.monitor_cb.mmu_lsu_pa0, vif.monitor_cb.mmu_lsu_pa0_vld, vif.monitor_cb.lsu_mmu_va0_vld,
            vif.monitor_cb.lsu_mmu_stamo_vld, vif.monitor_cb.lsu_mmu_stamo_pa,
            vif.monitor_cb.mmu_lsu_mmu_en, vif.monitor_cb.mmu_lsu_tlb_busy, vif.monitor_cb.mmu_lsu_tlb_wakeup),
          UVM_NONE)
      end
      ap_pipe1_rsp.write(_clone_txn(tr, "lsu_p1_rsp_ap"));
      @(vif.monitor_cb iff !((vif.monitor_cb.mmu_lsu_pa1_vld === 1'b1)
                          || (vif.monitor_cb.mmu_lsu_page_fault1 === 1'b1)
                          || (vif.monitor_cb.mmu_lsu_access_fault1 === 1'b1)));
    end
  endtask

  // ── Pipe 2 (prefetch) single-state monitor ───────────────────────────────
  protected task _collect_pipe2_sm();
    lsu_txn tr, req_tr;
    bit     prev_rsp_seen;
    bit     has_visible_req;
    bit     prev_va2_vld;
    bit     publish_rsp;

    prev_rsp_seen = 1'b0;
    has_visible_req = 1'b0;
    forever begin
      @(vif.monitor_cb);
      if (vif.rst_ni !== 1'b1) begin
        prev_rsp_seen = 1'b0;
        prev_va2_vld  = 1'b0;
        has_visible_req = 1'b0;
        m_p2_rsp_seen = 1'b0;
        m_pending_p2.delete();
        continue;
      end

      // Capture PFU VA on rising edge of va2_vld.  Previous code gated
      // on arb_pfu_grant (probe signal from a different path) which can
      // arrive in a different cycle under heavy load, causing VA to be
      // missed.  Edge detection prevents re-capture of the same VA.
      if (vif.monitor_cb.lsu_mmu_va2_vld && !prev_va2_vld && !has_visible_req) begin
        tr      = lsu_txn::type_id::create("lsu_p2_req");
        tr.kind = LSU_PIPE2;
        tr.va2  = vif.monitor_cb.lsu_mmu_va2;
        tr.va2_valid = 1'b1;
        _sample_obs_common(tr);
        tr.req_type = 3'd2;
        has_visible_req = 1'b1;
        m_p2_rsp_seen = 1'b0;
        m_pending_p2.push_back(_clone_txn(tr, "lsu_p2_req_pending"));
        ap_pipe2_req.write(_clone_txn(tr, "lsu_p2_req_ap"));
      end

      if (vif.monitor_cb.mmu_lsu_pa2_vld && !prev_rsp_seen) begin
        publish_rsp     = 1'b1;
        tr              = lsu_txn::type_id::create("lsu_p2_rsp");
        tr.kind         = LSU_PIPE2;
        tr.pa           = vif.monitor_cb.mmu_lsu_pa2;
        tr.sec          = vif.monitor_cb.mmu_lsu_sec2;
        tr.access_fault = vif.monitor_cb.mmu_lsu_pa2_err;
        tr.mmu_en       = vif.monitor_cb.mmu_lsu_mmu_en;
        _sample_obs_common(tr);
        tr.req_type     = 3'd2;
        if (m_pending_p2.size() > 0) begin
          req_tr = m_pending_p2.pop_front();
          tr.va2 = req_tr.va2;
          tr.va2_valid = 1'b1;
          if (!tr.obs_valid && req_tr.obs_valid) begin
            tr.obs_valid = req_tr.obs_valid;
            tr.eff_priv  = req_tr.eff_priv;
            tr.mprv      = req_tr.mprv;
            tr.mpp       = req_tr.mpp;
            tr.mxr       = req_tr.mxr;
            tr.sum       = req_tr.sum;
            tr.maee      = req_tr.maee;
            tr.asid      = req_tr.asid;
            tr.satp_ppn  = req_tr.satp_ppn;
            tr.req_type  = req_tr.req_type;
            tr.direct_map = req_tr.direct_map;
          end
          m_p2_rsp_seen = 1'b1;
        end else begin
          if (has_visible_req && m_p2_rsp_seen) begin
            publish_rsp = 1'b0;
            `uvm_info(get_type_name(),
              $sformatf("[LSU_P2_DUP_RSP] extra rsp while PFU req is closing: pa=0x%07h err=%0b",
                tr.pa, tr.access_fault),
              UVM_DEBUG)
          end else if (!has_visible_req) begin
            // No pending VA — this PA belongs to a previously-completed
            // request.  PFU pipeline may hold pa2_vld across VA boundaries.
            `uvm_info(get_type_name(),
              $sformatf("[LSU_P2_STALE_RSP] rsp without pending req (prior request already drained): pa=0x%07h err=%0b",
                tr.pa, tr.access_fault),
              UVM_HIGH)
            publish_rsp = 1'b0;
          end else begin
            `uvm_warning(get_type_name(),
              $sformatf("[LSU_P2_ORPHAN_RSP] rsp observed without pending req: pa=0x%07h err=%0b",
                tr.pa, tr.access_fault))
          end
        end
        if (publish_rsp)
          ap_pipe2_rsp.write(_clone_txn(tr, "lsu_p2_rsp_ap"));
      end

      if (m_p2_rsp_seen && has_visible_req) begin
        // Only allow a new request after the current response is fully
        // processed (not when va2_vld merely deasserts).  This prevents
        // a new VA from being enqueued while the previous PA response
        // is still in flight, which would cause VA/PA mis-pairing.
        if (m_pending_p2.size() > 0) begin
          tr = m_pending_p2.pop_front();
        end
        has_visible_req = 1'b0;
        m_p2_rsp_seen = 1'b0;
      end else if (!vif.monitor_cb.lsu_mmu_va2_vld && has_visible_req && !m_p2_rsp_seen) begin
        // VA deasserted but no response arrived — keep the request pending.
        `uvm_info(get_type_name(),
          $sformatf("[LSU_P2_WAIT] va2 deasserted before rsp, holding request"),
          UVM_DEBUG)
      end

      prev_rsp_seen = vif.monitor_cb.mmu_lsu_pa2_vld;
      prev_va2_vld  = vif.monitor_cb.lsu_mmu_va2_vld;
    end
  endtask

  // ── TLB Invalidation event ────────────────────────────────────────────────
  // Publish the invalidate event after the DUT completion pulse is observed or
  // the bounded watchdog expires.  inv_done is the sampled DUT response.
  protected task _collect_inv();
    lsu_txn tr;
    forever begin
      bit inv_done_seen;
      int unsigned wait_cycles;

      @(vif.monitor_cb iff (vif.monitor_cb.lsu_mmu_tlb_va_all_inv   |
                             vif.monitor_cb.lsu_mmu_tlb_all_inv      |
                             vif.monitor_cb.lsu_mmu_tlb_va_asid_inv  |
                             vif.monitor_cb.lsu_mmu_tlb_asid_all_inv));
      tr          = lsu_txn::type_id::create("lsu_inv");
      tr.kind     = LSU_INV;
      tr.inv_va   = vif.monitor_cb.lsu_mmu_tlb_va;
      tr.inv_asid = vif.monitor_cb.lsu_mmu_tlb_asid;
      tr.inv_done = 1'b0;
      // Decode inv_kind from which strobe is high
      if      (vif.monitor_cb.lsu_mmu_tlb_all_inv)      tr.inv_kind = INV_ALL;
      else if (vif.monitor_cb.lsu_mmu_tlb_va_all_inv)   tr.inv_kind = INV_VA_ALL;
      else if (vif.monitor_cb.lsu_mmu_tlb_asid_all_inv) tr.inv_kind = INV_ASID_ALL;
      else                                               tr.inv_kind = INV_VA_ASID;
      `uvm_info(get_type_name(), {"INV: ", tr.convert2string()}, UVM_HIGH)

      inv_done_seen = (vif.monitor_cb.mmu_lsu_tlb_inv_done === 1'b1);
      wait_cycles = 0;
      while (!inv_done_seen && (wait_cycles < m_inv_done_watchdog_cycles)) begin
        @(vif.monitor_cb);
        wait_cycles++;
        if (vif.monitor_cb.mmu_lsu_tlb_inv_done === 1'b1)
          inv_done_seen = 1'b1;
      end
      tr.inv_done = inv_done_seen;
      if (!tr.inv_done) begin
        `uvm_error(get_type_name(),
          $sformatf({"LSU INV monitor did not observe mmu_lsu_tlb_inv_done ",
                     "within %0d cycles: kind=%s va=0x%07h asid=0x%04h tlb_busy=%0b wakeup=0x%03h"},
            m_inv_done_watchdog_cycles, tr.inv_kind.name(), tr.inv_va, tr.inv_asid,
            vif.monitor_cb.mmu_lsu_tlb_busy, vif.monitor_cb.mmu_lsu_tlb_wakeup))
      end

      ap_inv.write(tr);
      // Wait until ALL invalidation strobes return to zero before re-arming.
      if ((vif.monitor_cb.lsu_mmu_tlb_va_all_inv   !== 1'b0) ||
          (vif.monitor_cb.lsu_mmu_tlb_all_inv      !== 1'b0) ||
          (vif.monitor_cb.lsu_mmu_tlb_va_asid_inv  !== 1'b0) ||
          (vif.monitor_cb.lsu_mmu_tlb_asid_all_inv !== 1'b0)) begin
        @(vif.monitor_cb iff (vif.monitor_cb.lsu_mmu_tlb_va_all_inv   === 1'b0 &&
                               vif.monitor_cb.lsu_mmu_tlb_all_inv      === 1'b0 &&
                               vif.monitor_cb.lsu_mmu_tlb_va_asid_inv  === 1'b0 &&
                               vif.monitor_cb.lsu_mmu_tlb_asid_all_inv === 1'b0));
      end
    end
  endtask

  // ── STAMO physical address check ─────────────────────────────────────────
  protected task _collect_stamo();
    lsu_txn tr;
    forever begin
      @(vif.monitor_cb iff vif.monitor_cb.lsu_mmu_stamo_vld);
      tr          = lsu_txn::type_id::create("lsu_stamo");
      tr.kind     = LSU_STAMO;
      tr.stamo_pa = vif.monitor_cb.lsu_mmu_stamo_pa;
      ap_stamo.write(tr);
    end
  endtask

endclass : lsu_monitor

`endif // LSU_MONITOR_SVH
