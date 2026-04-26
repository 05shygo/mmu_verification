// =============================================================================
// MMU UVM Verification — testbench/env/mmu_env.svh
// Phase 3 (Batch 1): Environment — integrates cp0/pmp/sysmap_cfg agents only.
// ifu_agent, lsu_agent, ptw_mem_agent, misc_agent are added in Phase 5.
// Scoreboard, ref model, and virtual sequencer are added in Phase 5.
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

  // ── Phase 5: Translation scoreboard ─────────────────────────────────────
  mmu_translation_sb m_translation_sb;
  mmu_invalidate_sb  m_invalidate_sb;

  // ── Phase 5 (Engineer A): misc agent + credit SB + perf monitor ─────────
  misc_agent         m_misc;
  mmu_credit_sb      m_credit_sb;
  mmu_perf_mon         m_perf;
  mmu_env_cg_whitebox  m_cg_whitebox;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  // ── Build phase ───────────────────────────────────────────────────────────
  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    // Get top-level configuration object
    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg)) begin
      `uvm_info(get_type_name(),
                "mmu_top_cfg not in config_db — creating default instance",
                UVM_MEDIUM)
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");
    end

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

    if (m_cfg.en_whitebox_cg) begin
      m_cg_whitebox = mmu_env_cg_whitebox::type_id::create("m_cg_whitebox", this);
    end

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
    // Phase 4: inject shared page table builder into PTW responder
    m_ptw_mem.m_responder.set_page_table(m_pt_mem.m_builder);

    // Phase 5: Connect monitor APs → ref model TLM FIFOs
    // (Converts CSR/PMP/SysMap write events into ref model mirror updates)
    m_cp0.m_monitor.ap.connect(m_ref.af_csr_write.analysis_export);
    m_lsu.m_monitor.ap_inv.connect(m_ref.af_tlb_inv.analysis_export);
    m_pmp.m_monitor.ap.connect(m_ref.af_pmp_cfg.analysis_export);
    m_sysmap_cfg.m_monitor.ap.connect(m_ref.af_sysmap_cfg.analysis_export);

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

    // Phase 5 (Engineer A): IFU/LSU/PTW req+rsp → credit scoreboard
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

    // Phase 5 (Engineer A): IFU/LSU rsp + misc HPCP → performance monitor
    m_ifu.m_monitor.ap_rsp.connect(m_perf.af_ifu_rsp.analysis_export);
    m_lsu.m_monitor.ap_pipe0_rsp.connect(m_perf.af_lsu_p0_rsp.analysis_export);
    m_lsu.m_monitor.ap_pipe1_rsp.connect(m_perf.af_lsu_p1_rsp.analysis_export);
    m_lsu.m_monitor.ap_pipe2_rsp.connect(m_perf.af_lsu_p2_rsp.analysis_export);
    m_misc.m_monitor.ap_hpcp.connect(m_perf.af_hpcp.analysis_export);
  endfunction

endclass : mmu_env

`endif // MMU_ENV_SVH
