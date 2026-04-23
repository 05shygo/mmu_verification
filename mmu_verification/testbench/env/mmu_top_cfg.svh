// =============================================================================
// MMU UVM Verification — testbench/env/mmu_top_cfg.svh
// Phase 2: Top-level environment configuration object
// Used by: mmu_env.sv (Phase 3)
// =============================================================================
`ifndef MMU_TOP_CFG_SVH
`define MMU_TOP_CFG_SVH

class mmu_top_cfg extends uvm_object;

  `uvm_object_utils_begin(mmu_top_cfg)
    // Agent Active/Passive switches
    `uvm_field_enum(uvm_active_passive_enum, ifu_agent_mode,        UVM_ALL_ON)
    `uvm_field_enum(uvm_active_passive_enum, lsu_agent_mode,        UVM_ALL_ON)
    `uvm_field_enum(uvm_active_passive_enum, cp0_agent_mode,        UVM_ALL_ON)
    `uvm_field_enum(uvm_active_passive_enum, ptw_mem_agent_mode,    UVM_ALL_ON)
    `uvm_field_enum(uvm_active_passive_enum, pmp_agent_mode,        UVM_ALL_ON)
    `uvm_field_enum(uvm_active_passive_enum, sysmap_cfg_agent_mode, UVM_ALL_ON)
    `uvm_field_enum(uvm_active_passive_enum, misc_agent_mode,       UVM_ALL_ON)
    // Scoreboard enables
    `uvm_field_int(en_translation_sb,  UVM_ALL_ON)
    `uvm_field_int(en_invalidate_sb,   UVM_ALL_ON)
    `uvm_field_int(en_credit_sb,       UVM_ALL_ON)
    `uvm_field_int(en_perf_mon,        UVM_ALL_ON)
    // Reference model mode
    `uvm_field_int(ref_model_strict,   UVM_ALL_ON)
    // SVA enable knobs
    `uvm_field_int(en_sva_arb,         UVM_ALL_ON)
    `uvm_field_int(en_sva_rrpv,        UVM_ALL_ON)
    `uvm_field_int(en_sva_plru,        UVM_ALL_ON)
    `uvm_field_int(en_sva_credit,      UVM_ALL_ON)
  `uvm_object_utils_end

  // =========================================================================
  // Agent Active / Passive Mode
  //   UVM_ACTIVE  (default) = driver + sequencer + monitor
  //   UVM_PASSIVE           = monitor-only (no driver/sequencer instantiated)
  // =========================================================================
  uvm_active_passive_enum ifu_agent_mode        = UVM_ACTIVE;
  uvm_active_passive_enum lsu_agent_mode        = UVM_ACTIVE;
  uvm_active_passive_enum cp0_agent_mode        = UVM_ACTIVE;
  uvm_active_passive_enum ptw_mem_agent_mode    = UVM_ACTIVE;
  uvm_active_passive_enum pmp_agent_mode        = UVM_ACTIVE;
  uvm_active_passive_enum sysmap_cfg_agent_mode = UVM_ACTIVE;
  uvm_active_passive_enum misc_agent_mode       = UVM_ACTIVE;

  // =========================================================================
  // Scoreboard / Checker Enables
  // =========================================================================
  bit en_translation_sb = 1;  // Translation result checker (IFU + LSU)
  bit en_invalidate_sb  = 1;  // TLB invalidation coverage checker
  bit en_credit_sb      = 1;  // L2 TLB request-queue credit protocol checker
  bit en_perf_mon       = 1;  // HPCP performance event monitor

  // =========================================================================
  // Reference Model Strictness
  //   1 = strict bit-exact comparison (default)
  //   0 = relaxed (attribute mis-match is warning, not error)
  // =========================================================================
  bit ref_model_strict = 1;

  // =========================================================================
  // SVA Enable Knobs (Phase 5 assertions)
  //   Allows individual assertion groups to be disabled for debug
  // =========================================================================
  bit en_sva_arb    = 1;   // L2TLB arbitration fairness assertions
  bit en_sva_rrpv   = 1;   // RRPV QLRU replacement policy assertions
  bit en_sva_plru   = 1;   // L1 PLRU assertions
  bit en_sva_credit = 1;   // L2 request-queue credit assertions

  // =========================================================================
  // Constructor
  // =========================================================================
  function new(string name = "mmu_top_cfg");
    super.new(name);
  endfunction

endclass : mmu_top_cfg

`endif // MMU_TOP_CFG_SVH
