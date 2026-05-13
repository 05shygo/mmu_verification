// =============================================================================
// MMU UVM Verification — testbench/env/mmu_env.svh
// Phase 3+ : Environment — cp0/pmp/sysmap_cfg + IFU/LSU/PTW/misc + ref/SB/perf; Phase 8: m_vseqr.
// =============================================================================
`ifndef MMU_ENV_SVH
`define MMU_ENV_SVH

class mmu_env extends uvm_env;

  `uvm_component_utils(mmu_env)

  // ── Configuration ─────────────────────────────────────────────────────────
  mmu_top_cfg m_cfg;

  // ── Phase 3 agents ────────────────────────────────────────────────────────
  cp0_agent         m_cp0;
  pmp_agent         m_pmp;
  sysmap_cfg_agent  m_sysmap_cfg;
  ifu_agent         m_ifu;
  lsu_agent         m_lsu;

  // ── Phase 4: PTW memory agent + shadow PT + reference model ─────────────
  ptw_mem_agent    m_ptw_mem;
  mmu_page_table_mem m_pt_mem;
  mmu_ref_model    m_ref;

  // PTW source-side checker skeletons (created only when enabled)
  ptw_source_monitor   m_ptw_source_mon;
  ptw_scenario_db      m_ptw_scenario_db;
  ptw_source_ref_model m_ptw_source_ref;
  ptw_source_sb        m_ptw_source_sb;

  // ── Phase 5: Translation scoreboard ─────────────────────────────────────
  mmu_translation_sb m_translation_sb;
  mmu_invalidate_sb  m_invalidate_sb;

  // ── Phase 5 (Engineer A): misc agent + credit SB + perf monitor ─────────
  misc_agent         m_misc;
  mmu_credit_sb      m_credit_sb;
  mmu_perf_mon         m_perf;
  mmu_env_cg_whitebox  m_cg_whitebox;
  mmu_l1dtlb_spec_sb   m_l1dtlb_spec_sb;

  // Phase 8: virtual sequencer (6 sub-sequencer handles, no ptw_mem)
  mmu_virtual_sequencer m_vseqr;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task quiesce_request_stimulus_before_end(
    int unsigned max_cycles = 262144,
    int unsigned stable_cycles = 32
  );
    if ((m_ifu != null) && (m_ifu.m_driver != null))
      m_ifu.m_driver.set_end_quiesce(1'b1);
    if ((m_lsu != null) && (m_lsu.m_driver != null))
      m_lsu.m_driver.set_end_quiesce(1'b1);

    fork
      begin
        if ((m_ifu != null) && (m_ifu.m_driver != null))
          m_ifu.m_driver.wait_for_idle("test_end_quiesce", max_cycles, stable_cycles);
      end
      begin
        if ((m_lsu != null) && (m_lsu.m_driver != null))
          m_lsu.m_driver.wait_for_idle("test_end_quiesce", max_cycles, stable_cycles);
      end
    join

    `uvm_info(get_type_name(),
      "IFU/LSU stimulus quiesced and locked before final PTW/L2 drain",
      UVM_MEDIUM)
  endtask

  virtual task wait_for_quiescent_midtest(
    string       ctx = "mid-test",
    int unsigned max_cycles = 262144,
    int unsigned stable_cycles = 16
  );
    fork
      begin
        if ((m_ifu != null) && (m_ifu.m_driver != null))
          m_ifu.m_driver.wait_for_idle({ctx, "_ifu"}, max_cycles, stable_cycles);
      end
      begin
        if ((m_lsu != null) && (m_lsu.m_driver != null))
          m_lsu.m_driver.wait_for_idle({ctx, "_lsu"}, max_cycles, stable_cycles);
      end
    join

    // Wait for DUT tlb_busy to clear (all MB entries IDLE).
    // The LSU driver may complete its transaction when a fault refill returns
    // pa_vld=1 with page_fault/access_fault, but the DUT's MB entry remains
    // in PGFLT/ACFLT until the exception CAM is consumed by LSU replay.
    // Without this check, subsequent requests see a non-empty exception array.
    if ((m_lsu != null) && (m_lsu.m_driver != null)) begin
      int unsigned busy_wait_cycles;
      string credit_snapshot;
      busy_wait_cycles = 0;
      while (m_lsu.m_driver.vif.driver_cb.mmu_lsu_tlb_busy === 1'b1) begin
        @(m_lsu.m_driver.vif.driver_cb);
        busy_wait_cycles++;
        if (busy_wait_cycles >= max_cycles) begin
          credit_snapshot = (m_credit_sb != null)
                            ? m_credit_sb.pending_snapshot()
                            : "credit_sb=null";
          `uvm_error(get_type_name(),
            $sformatf("TLB busy did not clear before %s after %0d cycles: %s",
              ctx,
              busy_wait_cycles,
              credit_snapshot))
          if (m_credit_sb != null)
            m_credit_sb.print_timeout_debug(ctx);
          if ((m_ptw_mem != null) && (m_ptw_mem.m_responder != null))
            m_ptw_mem.m_responder.print_timeout_debug(ctx);
          break;
        end
      end
      if (busy_wait_cycles > 0) begin
        `uvm_info(get_type_name(),
          $sformatf("TLB busy cleared before %s after %0d cycles", ctx, busy_wait_cycles),
          UVM_MEDIUM)
      end
    end

    if (m_credit_sb != null)
      m_credit_sb.wait_for_internal_idle(ctx);
  endtask

  // ── Build phase ───────────────────────────────────────────────────────────
  virtual task print_timeout_debug(
    string owner = "unknown",
    int unsigned timeout_ns = 0,
    int unsigned num_txn = 0
  );
    $display("[MMU_TIMEOUT_DBG] owner=%s timeout_ns=%0d num_txn=%0d time=%0t",
      owner, timeout_ns, num_txn, $time);

    if ((m_ifu != null) && (m_ifu.m_driver != null))
      m_ifu.m_driver.print_timeout_debug("global_timeout");
    else
      $display("[MMU_TIMEOUT_DBG] IFU driver unavailable");

    if ((m_lsu != null) && (m_lsu.m_driver != null))
      m_lsu.m_driver.print_timeout_debug("global_timeout");
    else
      $display("[MMU_TIMEOUT_DBG] LSU driver unavailable");

    if (m_credit_sb != null)
      m_credit_sb.print_timeout_debug("global_timeout");
    else
      $display("[MMU_TIMEOUT_DBG] CreditSB unavailable");

    if ((m_ptw_mem != null) && (m_ptw_mem.m_responder != null))
      m_ptw_mem.m_responder.print_timeout_debug("global_timeout");
    else
      $display("[MMU_TIMEOUT_DBG] PTW responder unavailable");
  endtask

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get top-level configuration object
    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg)) begin
      `uvm_info(get_type_name(),
                "mmu_top_cfg not in config_db — creating default instance",
                UVM_MEDIUM)
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");
    end

    if ($test$plusargs("EN_PTW_SOURCE_MONITOR"))
      m_cfg.en_ptw_source_monitor = 1'b1;
    if ($test$plusargs("EN_PTW_SOURCE_REF_MODEL"))
      m_cfg.en_ptw_source_ref_model = 1'b1;
    if ($test$plusargs("EN_PTW_SOURCE_SB"))
      m_cfg.en_ptw_source_sb = 1'b1;
    if ($test$plusargs("EN_PTW_SOURCE_COV"))
      m_cfg.en_ptw_source_cov = 1'b1;

    // Create agents
    m_cp0        = cp0_agent::type_id::create("m_cp0",        this);
    m_pmp        = pmp_agent::type_id::create("m_pmp",        this);
    m_sysmap_cfg = sysmap_cfg_agent::type_id::create("m_sysmap_cfg", this);
    m_ifu        = ifu_agent::type_id::create("m_ifu",        this);
    m_lsu        = lsu_agent::type_id::create("m_lsu",        this);

    // Phase 4: PTW memory agent (always ACTIVE — drives lsu_mmu responses)
    m_ptw_mem           = ptw_mem_agent::type_id::create("m_ptw_mem", this);
    m_ptw_mem.is_active = UVM_ACTIVE;

    // Phase 4: Shadow page table memory (shared by responder + ref model)
    m_pt_mem = mmu_page_table_mem::type_id::create("m_pt_mem");
    m_pt_mem.init();

    // Phase 4: Reference model
    m_ref = mmu_ref_model::type_id::create("m_ref", this);
    // Inject shared page table reference BEFORE run_phase
    m_ref.m_pt = m_pt_mem;

    if (m_cfg.en_ptw_source_monitor
        || m_cfg.en_ptw_source_ref_model
        || m_cfg.en_ptw_source_sb) begin
      m_ptw_source_mon = ptw_source_monitor::type_id::create("m_ptw_source_mon", this);
      m_ptw_scenario_db = ptw_scenario_db::type_id::create("m_ptw_scenario_db", this);
    end
    if (m_cfg.en_ptw_source_ref_model)
      m_ptw_source_ref = ptw_source_ref_model::type_id::create("m_ptw_source_ref", this);
    if (m_cfg.en_ptw_source_sb)
      m_ptw_source_sb = ptw_source_sb::type_id::create("m_ptw_source_sb", this);

    // Phase 5: Translation scoreboard (optional: RTU/PTW stress may disable)
    if (m_cfg.en_translation_sb) begin
      m_translation_sb        = mmu_translation_sb::type_id::create("m_translation_sb", this);
      m_translation_sb.m_ref  = m_ref;
    end
    if (m_cfg.en_invalidate_sb)
      m_invalidate_sb = mmu_invalidate_sb::type_id::create("m_invalidate_sb", this);

    // Phase 5 (Engineer A): misc agent (ACTIVE by default)
    m_misc    = misc_agent::type_id::create("m_misc",    this);
    // Phase 5 (Engineer A): credit scoreboard + performance monitor
    m_credit_sb = mmu_credit_sb::type_id::create("m_credit_sb", this);
    m_perf      = mmu_perf_mon::type_id::create("m_perf",      this);
    if (m_cfg.en_l1dtlb_spec_sb)
      m_l1dtlb_spec_sb = mmu_l1dtlb_spec_sb::type_id::create("m_l1dtlb_spec_sb", this);

    if (m_cfg.en_whitebox_cg) begin
      m_cg_whitebox = mmu_env_cg_whitebox::type_id::create("m_cg_whitebox", this);
    end

    m_vseqr = mmu_virtual_sequencer::type_id::create("m_vseqr", this);

    // Forward active/passive mode from config
    m_cp0.is_active        = m_cfg.cp0_agent_mode;
    m_pmp.is_active        = m_cfg.pmp_agent_mode;
    m_sysmap_cfg.is_active = m_cfg.sysmap_cfg_agent_mode;
    m_ifu.is_active        = m_cfg.ifu_agent_mode;
    m_lsu.is_active        = m_cfg.lsu_agent_mode;
    m_misc.is_active       = m_cfg.misc_agent_mode;
  endfunction

  // ── Connect phase ─────────────────────────────────────────────────────────
  virtual function void connect_phase(uvm_phase phase);
    // Phase 8: sub-sequencer handles for virtual sequences
    m_vseqr.ifu_sqr    = m_ifu.m_sequencer;
    m_vseqr.lsu_sqr    = m_lsu.m_sequencer;
    m_vseqr.cp0_sqr    = m_cp0.m_sequencer;
    m_vseqr.pmp_sqr    = m_pmp.m_sequencer;
    m_vseqr.sysmap_sqr = m_sysmap_cfg.m_sequencer;
    m_vseqr.misc_sqr   = m_misc.m_sequencer;

    // Phase 4: inject shared page table builder into PTW responder
    m_ptw_mem.m_responder.set_page_table(m_pt_mem.m_builder);

    // Phase 5: Connect monitor APs → ref model TLM FIFOs
    // (Converts CSR/PMP/SysMap write events into ref model mirror updates)
    m_cp0.m_monitor.ap.connect(m_ref.af_csr_write.analysis_export);
    m_lsu.m_monitor.ap_inv.connect(m_ref.af_tlb_inv.analysis_export);
    m_pmp.m_monitor.ap.connect(m_ref.af_pmp_cfg.analysis_export);
    m_sysmap_cfg.m_monitor.ap.connect(m_ref.af_sysmap_cfg.analysis_export);

    // PTW source-side fanout. Stage 3 monitor/scenario-db emit actual/probe
    // transactions only; source ref-model/SB matching remains later-stage work.
    if (m_ptw_source_ref != null) begin
      m_cp0.m_monitor.ap.connect(m_ptw_source_ref.af_csr_write.analysis_export);
      m_pmp.m_monitor.ap.connect(m_ptw_source_ref.af_pmp_cfg.analysis_export);
      m_sysmap_cfg.m_monitor.ap.connect(m_ptw_source_ref.af_sysmap_cfg.analysis_export);
      m_ptw_mem.m_monitor.ap_req.connect(m_ptw_source_ref.af_ptw_mem_req.analysis_export);
      m_ptw_mem.m_monitor.ap_rsp.connect(m_ptw_source_ref.af_ptw_mem_rsp.analysis_export);
      m_ptw_mem.m_monitor.ap_drop.connect(m_ptw_source_ref.af_ptw_mem_drop.analysis_export);
    end

    if ((m_ptw_source_mon != null) && (m_ptw_source_ref != null)) begin
      m_ptw_source_mon.ap_req_accept.connect(m_ptw_source_ref.af_req_accept.analysis_export);
      m_ptw_source_mon.ap_abort.connect(m_ptw_source_ref.af_abort.analysis_export);
    end

    if ((m_ptw_source_ref != null) && (m_ptw_source_sb != null))
      m_ptw_source_ref.ap_expected.connect(m_ptw_source_sb.af_expected.analysis_export);

    if ((m_ptw_source_mon != null) && (m_ptw_source_sb != null)) begin
      m_ptw_source_mon.ap_req_accept.connect(m_ptw_source_sb.af_req.analysis_export);
      m_ptw_source_mon.ap_actual_rsp.connect(m_ptw_source_sb.af_actual.analysis_export);
    end

    if ((m_ptw_source_mon != null) && (m_ptw_scenario_db != null)) begin
      m_ptw_source_mon.ap_req_accept.connect(m_ptw_scenario_db.af_req_accept.analysis_export);
      m_ptw_source_mon.ap_actual_rsp.connect(m_ptw_scenario_db.af_actual_rsp.analysis_export);
      m_ptw_source_mon.ap_abort.connect(m_ptw_scenario_db.af_abort.analysis_export);
      m_ptw_source_mon.ap_ctx.connect(m_ptw_scenario_db.af_ctx.analysis_export);
      m_ptw_source_mon.ap_level.connect(m_ptw_scenario_db.af_level.analysis_export);
      m_ptw_source_mon.ap_pde.connect(m_ptw_scenario_db.af_pde.analysis_export);
      m_ptw_source_mon.ap_drop.connect(m_ptw_scenario_db.af_drop.analysis_export);
      m_ptw_mem.m_monitor.ap_req.connect(m_ptw_scenario_db.af_ptw_mem_req.analysis_export);
      m_ptw_mem.m_monitor.ap_rsp.connect(m_ptw_scenario_db.af_ptw_mem_rsp.analysis_export);
      m_ptw_mem.m_monitor.ap_drop.connect(m_ptw_scenario_db.af_ptw_mem_drop.analysis_export);
    end

    if (m_ptw_source_sb != null) begin
      m_ptw_mem.m_monitor.ap_req.connect(m_ptw_source_sb.af_mem_req.analysis_export);
      m_ptw_mem.m_monitor.ap_rsp.connect(m_ptw_source_sb.af_mem_rsp.analysis_export);
      m_ptw_mem.m_monitor.ap_drop.connect(m_ptw_source_sb.af_mem_drop.analysis_export);
    end

    // Phase 5: Connect monitor rsp APs → translation scoreboard
    if (m_translation_sb != null) begin
      m_ifu.m_monitor.ap_rsp.connect(m_translation_sb.af_ifu_rsp);
      m_lsu.m_monitor.ap_pipe0_rsp.connect(m_translation_sb.af_lsu_p0_rsp);
      m_lsu.m_monitor.ap_pipe1_rsp.connect(m_translation_sb.af_lsu_p1_rsp);
      m_lsu.m_monitor.ap_pipe2_rsp.connect(m_translation_sb.af_lsu_p2_rsp);
    end

    // Phase 6: Connect invalidate paths into invalidate scoreboard.
    if (m_invalidate_sb != null) begin
      m_lsu.m_monitor.ap_inv.connect(m_invalidate_sb.af_inv.analysis_export);
      m_cp0.m_monitor.ap.connect(m_invalidate_sb.af_cp0.analysis_export);
    end

    // Phase 5 (Engineer A): IFU/LSU/PTW req+rsp+drop → credit scoreboard
    // IFU: ap_req (request) + ap_rsp (merged response)
    m_ifu.m_monitor.ap_req.connect(m_credit_sb.af_ifu_req.analysis_export);
    m_ifu.m_monitor.ap_rsp.connect(m_credit_sb.af_ifu_rsp.analysis_export);
    m_ifu.m_monitor.ap_drop.connect(m_credit_sb.af_ifu_drop.analysis_export);
    // LSU pipe0
    m_lsu.m_monitor.ap_pipe0_req.connect(m_credit_sb.af_lsu_p0_req.analysis_export);
    m_lsu.m_monitor.ap_pipe0_rsp.connect(m_credit_sb.af_lsu_p0_rsp.analysis_export);
    m_lsu.m_monitor.ap_pipe0_drop.connect(m_credit_sb.af_lsu_p0_drop.analysis_export);
    // LSU pipe1
    m_lsu.m_monitor.ap_pipe1_req.connect(m_credit_sb.af_lsu_p1_req.analysis_export);
    m_lsu.m_monitor.ap_pipe1_rsp.connect(m_credit_sb.af_lsu_p1_rsp.analysis_export);
    m_lsu.m_monitor.ap_pipe1_drop.connect(m_credit_sb.af_lsu_p1_drop.analysis_export);
    // PTW memory channel
    m_ptw_mem.m_monitor.ap_req.connect(m_credit_sb.af_ptw_req.analysis_export);
    m_ptw_mem.m_monitor.ap_rsp.connect(m_credit_sb.af_ptw_rsp.analysis_export);
    m_ptw_mem.m_monitor.ap_drop.connect(m_credit_sb.af_ptw_drop.analysis_export);

    // Phase 5 (Engineer A): IFU/LSU rsp + misc HPCP → performance monitor
    m_ifu.m_monitor.ap_rsp.connect(m_perf.af_ifu_rsp.analysis_export);
    m_lsu.m_monitor.ap_pipe0_rsp.connect(m_perf.af_lsu_p0_rsp.analysis_export);
    m_lsu.m_monitor.ap_pipe1_rsp.connect(m_perf.af_lsu_p1_rsp.analysis_export);
    m_lsu.m_monitor.ap_pipe2_rsp.connect(m_perf.af_lsu_p2_rsp.analysis_export);
    m_misc.m_monitor.ap_hpcp.connect(m_perf.af_hpcp.analysis_export);
    // Phase 8: PTW mem channel → perf (PTW walk proxy / TaskDivision #3)
    m_ptw_mem.m_monitor.ap_req.connect(m_perf.af_ptw_req.analysis_export);
    m_ptw_mem.m_monitor.ap_rsp.connect(m_perf.af_ptw_rsp.analysis_export);
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    if ((m_cfg != null) && m_cfg.en_ptw_source_cov) begin
      `uvm_info(get_type_name(),
        "PTW_SVA_COVER module=mmu_env name=ptw_source_stage1_placeholder hits=0 provisional=1",
        UVM_NONE)
    end
  endfunction

endclass : mmu_env

`endif // MMU_ENV_SVH
