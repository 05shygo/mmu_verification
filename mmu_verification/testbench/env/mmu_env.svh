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

  // ── Phase 5 placeholders (declared as comments to avoid forward-ref errors)
  //  ifu_agent        m_ifu;
  //  lsu_agent        m_lsu;
  //  ptw_mem_agent    m_ptw_mem;
  //  misc_agent       m_misc;
  //  mmu_scoreboard   m_sb;
  //  mmu_ref_model    m_ref;
  //  mmu_vseqr        m_vseqr;

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

    // Forward active/passive mode from config
    m_cp0.is_active        = m_cfg.cp0_agent_mode;
    m_pmp.is_active        = m_cfg.pmp_agent_mode;
    m_sysmap_cfg.is_active = m_cfg.sysmap_cfg_agent_mode;
  endfunction

  // ── Connect phase ─────────────────────────────────────────────────────────
  virtual function void connect_phase(uvm_phase phase);
    // TLM connections to scoreboard and ref model to be added in Phase 5.
    // m_cp0.m_monitor.ap    → m_sb.af_cp0_txn
    // m_pmp.m_monitor.ap    → m_sb.af_pmp_txn
    // m_sysmap_cfg.m_monitor.ap → m_sb.af_sysmap_cfg
  endfunction

endclass : mmu_env

`endif // MMU_ENV_SVH
