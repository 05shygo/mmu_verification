// =============================================================================
// L2TLB Phase 6E directed/negative wrapper set.
// =============================================================================
`ifndef L2TLB_PHASE6E_TESTS_SVH
`define L2TLB_PHASE6E_TESTS_SVH

class test_l2tlb_p6e_reset_active_lookup_ptw_tlbop_pfu extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_l2tlb_p6e_reset_active_lookup_ptw_tlbop_pfu)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                   = "L2TLB-P6E-RESET-ACTIVE";
    p9_seq_desc                = "mmu_reset_midtransaction_vseq + tlb_inv_all_seq + lsu_prefetch_pipe2_seq";
    p9_checker                 = "phase6c_epoch,phase6d_reset_sva,credit_sb";
    phase6e_scenario_id        = "L2TLB_SCN_RESET_WARM_ACTIVE_002";
    phase6e_audit_ids          = "L2TLB_TP_001,L2TLB_TP_002,L2TLB_TP_043,L2TLB_SVA_001,L2TLB_SVA_002";
    phase6e_trigger_gate       = "active lookup/PTW/TLBOP/PFU traffic with reset epoch";
    phase6e_checker_gate       = "PHASE6C_L2_EPOCH/SHADOW_RESET plus reset SVA health";
    phase6e_expected_log_token = "PHASE6C_L2_EPOCH";
    phase6e_run_tier           = "l2tlb_smoke";
    num_txn                    = 32;
    timeout_ns                 = 8_000_000;
    m_post_drain               = 800ns;
    m_vseq_names.push_back("mmu_reset_midtransaction_vseq");
    m_lsu_seq_names.push_back("tlb_inv_all_seq");
    m_lsu_seq_names.push_back("lsu_prefetch_pipe2_seq");
  endfunction
endclass : test_l2tlb_p6e_reset_active_lookup_ptw_tlbop_pfu

class test_l2tlb_p6e_reqq_arb_payload_owner extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_l2tlb_p6e_reqq_arb_payload_owner)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                   = "L2TLB-P6E-REQQ-ARB";
    p9_seq_desc                = "mmu_l2tlb_bank_conflict_vseq";
    p9_checker                 = "credit_sb,mmu_arb_sva,credit_sva,phase6c_l2_shadow";
    phase6e_scenario_id        = "L2TLB_SCN_ARB_PAYLOAD_NO_CROSS_011";
    phase6e_audit_ids          = "L2TLB_TP_004,L2TLB_TP_005,L2TLB_TP_006,L2TLB_TP_007,L2TLB_TP_008,L2TLB_TP_009,L2TLB_TP_010,L2TLB_TP_011,L2TLB_TP_051,L2TLB_TP_052,L2TLB_SVA_003,L2TLB_SVA_004,L2TLB_SVA_005,L2TLB_SVA_006,L2TLB_SVA_019,L2TLB_SVA_020";
    phase6e_trigger_gate       = "ReqQ allocation/issue plus multi-source bank conflict";
    phase6e_checker_gate       = "credit/SVA payload no-cross and Phase6C owner tokens";
    phase6e_expected_log_token = "PHASE6C_L2_PTW_REQ";
    phase6e_run_tier           = "l2tlb_directed_p0";
    num_txn                    = 96;
    timeout_ns                 = 8_000_000;
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
  endfunction
endclass : test_l2tlb_p6e_reqq_arb_payload_owner

class test_l2tlb_p6e_ptw_disabled_fault_accerr extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_l2tlb_p6e_ptw_disabled_fault_accerr)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                   = "L2TLB-P6E-PTW-DIS-FAULT";
    p9_seq_desc                = "scoped waiver classification for PTW disabled/fault/access-error mixed stimulus";
    p9_checker                 = "phase6e_waiver_gate,phase6c_payload_ignore_followup";
    phase6e_scenario_id        = "L2TLB_SCN_PTW_PAGE_FAULT_OWNER_025";
    phase6e_audit_ids          = "L2TLB_TP_018,L2TLB_TP_025,L2TLB_TP_026,L2TLB_TP_033,L2TLB_SVA_012,L2TLB_SVA_014";
    phase6e_kind               = "waiver";
    phase6e_trigger_gate       = "PTW disabled/fault/access-error terminal paths";
    phase6e_checker_gate       = "scoped waiver emitted; no normal directed closure";
    phase6e_expected_log_token = "L2TLB_PHASE6E_WAIVER";
    phase6e_waiver_policy      = "combined cp0_ptw_disable_seq + illegal/bus-error PTW memory + ptw_thrash produces existing translation scoreboard mismatches; keep out of normal directed closure until a source-specific L2TLB harness is added";
    phase6e_run_tier           = "l2tlb_negative";
    phase6e_require_trigger_gate = 1'b0;
    phase6e_is_future_or_waiver = 1'b1;
    num_txn                    = 1;
    timeout_ns                 = 2_000_000;
    m_enable_sv39_4k_bringup   = 1'b0;
    m_run_misc_init            = 1'b1;
  endfunction

  protected virtual task phase6e_post_stimulus();
    phase6e_note_waiver("PTW disabled/fault/access-error source-specific positive closure remains follow-up; PFU payload-ignore is covered by test_l2tlb_p6e_pfu_direct_hit_miss_fault_mask.");
    phase6e_note_checker("scoped waiver classification emitted; normal directed list excludes this wrapper");
  endtask
endclass : test_l2tlb_p6e_ptw_disabled_fault_accerr

class test_l2tlb_p6e_pfu_direct_hit_miss_fault_mask extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_l2tlb_p6e_pfu_direct_hit_miss_fault_mask)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                   = "L2TLB-P6E-PFU";
    p9_seq_desc                = "lsu_prefetch_pipe2_seq with PMP/sysmap/PTW support";
    p9_checker                 = "phase6c_pfu_classifier,mmu_arb_sva_prefetch_mask";
    phase6e_scenario_id        = "L2TLB_SCN_PFU_MISS_PTW_030";
    phase6e_audit_ids          = "L2TLB_TP_028,L2TLB_TP_029,L2TLB_TP_030,L2TLB_TP_031,L2TLB_TP_032,L2TLB_TP_033,L2TLB_TP_053,L2TLB_TP_057,L2TLB_SVA_021";
    phase6e_trigger_gate       = "PFU direct/hit/miss/fault/mask traffic";
    phase6e_checker_gate       = "PFU classifier and payload-ignore/mask SVA evidence";
    phase6e_expected_log_token = "PHASE6C_PFU_DIRECT,PHASE6C_PAYLOAD_IGNORE";
    phase6e_run_tier           = "l2tlb_directed_p0";
    num_txn                    = 48;
    timeout_ns                 = 8_000_000;
    m_pmp_seq_names.push_back("pmp_flg_deny_pfu_seq");
    m_sysmap_seq_names.push_back("sysmap_perm_flag_seq");
    m_lsu_seq_names.push_back("lsu_prefetch_pipe2_seq");
  endfunction
endclass : test_l2tlb_p6e_pfu_direct_hit_miss_fault_mask

class test_l2tlb_p6e_tlbop_inv_abort_lifecycle extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_l2tlb_p6e_tlbop_inv_abort_lifecycle)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                   = "L2TLB-P6E-TLBOP-INV";
    p9_seq_desc                = "TLBP/TLBR/TLBWI/TLBWR/INV/SFENCE candidate lifecycle";
    p9_checker                 = "phase6c_l2_shadow,mmu_invalidate_sb,tlbop_sva";
    phase6e_scenario_id        = "L2TLB_SCN_TLBOP_LIFECYCLE_042";
    phase6e_audit_ids          = "L2TLB_TP_034,L2TLB_TP_035,L2TLB_TP_036,L2TLB_TP_037,L2TLB_TP_038,L2TLB_TP_039,L2TLB_TP_040,L2TLB_TP_041,L2TLB_TP_042,L2TLB_TP_043,L2TLB_TP_044,L2TLB_SVA_015,L2TLB_SVA_016";
    phase6e_trigger_gate       = "TLBOP query/read/write/replace/invalidate/abort lifecycle";
    phase6e_checker_gate       = "invalidate shadow, epoch stale completion, lifecycle SVA health";
    phase6e_expected_log_token = "PHASE6C_L2_INV";
    phase6e_run_tier           = "l2tlb_directed_p0";
    num_txn                    = 24;
    timeout_ns                 = 8_000_000;
    m_cp0_seq_names.push_back("cp0_tlbp_seq");
    m_cp0_seq_names.push_back("cp0_tlbr_seq");
    m_cp0_seq_names.push_back("cp0_tlbwi_seq");
    m_cp0_seq_names.push_back("cp0_tlbwr_seq");
    m_lsu_seq_names.push_back("tlb_inv_all_seq");
    m_lsu_seq_names.push_back("tlb_inv_va_seq");
    m_lsu_seq_names.push_back("tlb_inv_asid_seq");
    m_vseq_names.push_back("mmu_sfence_during_walk_vseq");
  endfunction
endclass : test_l2tlb_p6e_tlbop_inv_abort_lifecycle

class test_l2tlb_p6e_negative_ptw_completion_control extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_l2tlb_p6e_negative_ptw_completion_control)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                    = "L2TLB-P6E-NEG-PTW-CTRL";
    p9_seq_desc                 = "negative classification for obsolete OOO/bad completion/control hazard";
    p9_checker                  = "negative_metadata_gate,phase6d_followup";
    phase6e_scenario_id         = "L2TLB_SCN_PTW_NEG_PROTOCOL_027";
    phase6e_audit_ids           = "L2TLB_TP_027,L2TLB_TP_048,L2TLB_TP_056,L2TLB_TP_058,L2TLB_SVA_012,L2TLB_SVA_013,L2TLB_SVA_017,L2TLB_SVA_018";
    phase6e_kind                = "negative";
    phase6e_trigger_gate        = "isolated negative protocol/control hazard gate";
    phase6e_checker_gate        = "expected assertion/error/waiver classification";
    phase6e_expected_log_token  = "L2TLB_PHASE6E_WAIVER";
    phase6e_waiver_policy       = "bad PTW completion/control hazard injection requires a legal negative harness; OOO legacy wrapper is obsolete";
    phase6e_run_tier            = "l2tlb_negative";
    phase6e_is_negative         = 1'b1;
    phase6e_require_trigger_gate = 1'b0;
    phase6e_require_checker_gate = 1'b1;
    phase6e_is_future_or_waiver  = 1'b1;
    num_txn                     = 16;
    timeout_ns                  = 4_000_000;
    m_enable_sv39_4k_bringup    = 1'b0;
    m_run_misc_init             = 1'b1;
    m_cp0_seq_names.push_back("cp0_satp_switch_seq");
    m_vseq_names.push_back("mmu_satp_hotswap_vseq");
  endfunction

  protected virtual task phase6e_post_stimulus();
    phase6e_note_waiver("No approved L2TLB bad-completion/control-hazard injector is present in Phase6E; negative case remains isolated from normal directed closure.");
    phase6e_note_checker("negative classification emitted; no normal functional TP closed by this wrapper");
  endtask
endclass : test_l2tlb_p6e_negative_ptw_completion_control

class test_l2tlb_p6e_timeout_fairness_release extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_l2tlb_p6e_timeout_fairness_release)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                   = "L2TLB-P6E-TIMEOUT-FAIR";
    p9_seq_desc                = "bounded PTW/MB/TLBOP pressure with release";
    p9_checker                 = "credit_sb,timeout_classifier,phase6g_manifest_seed";
    phase6e_scenario_id        = "L2TLB_SCN_TIMEOUT_FAIRNESS_049";
    phase6e_audit_ids          = "L2TLB_TP_049,L2TLB_TP_050";
    phase6e_trigger_gate       = "bounded backpressure/retry/release traffic";
    phase6e_checker_gate       = "test completes without timeout after release; credit drain and translation scoreboards clean";
    phase6e_expected_log_token = "MMU_CREDIT_SB";
    phase6e_run_tier           = "l2tlb_timeout_fairness";
    num_txn                    = 96;
    timeout_ns                 = 10_000_000;
    m_post_drain               = 1000ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
    m_vseq_names.push_back("mmu_stress_all_ports_vseq");
  endfunction
endclass : test_l2tlb_p6e_timeout_fairness_release

class test_l2tlb_p6e_rrpv_debug_pressure extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_l2tlb_p6e_rrpv_debug_pressure)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                   = "L2TLB-P6E-RRPV-DEBUG";
    p9_seq_desc                = "mmu_rrpv_aging_vseq debug-only pressure";
    p9_checker                 = "rrpv_debug_sva,visible_result_only";
    phase6e_scenario_id        = "L2TLB_SCN_RRPV_WBUF_DEBUG_046";
    phase6e_audit_ids          = "L2TLB_TP_045,L2TLB_TP_046,L2TLB_TP_047,L2TLB_SVA_022,L2TLB_SVA_023,L2TLB_SVA_024";
    phase6e_kind               = "debug";
    phase6e_trigger_gate       = "RRPV aging/wbuf/replacement pressure";
    phase6e_checker_gate       = "debug cover/no-overflow if implemented; exact victim/RRPV future";
    phase6e_expected_log_token = "L2TLB_PHASE6E_WAIVER";
    phase6e_waiver_policy      = "exact victim, exact RRPV value, wbuf latest-wins remain Phase6F/future exact-model items";
    phase6e_run_tier           = "l2tlb_debug_rrpv";
    phase6e_is_debug           = 1'b1;
    num_txn                    = 96;
    timeout_ns                 = 8_000_000;
    m_vseq_names.push_back("mmu_rrpv_aging_vseq");
  endfunction

  protected virtual task phase6e_post_stimulus();
    phase6e_note_observed_shadow_trigger();
    phase6e_note_waiver("RRPV exact victim/value/latest-wins are debug/future only; this run supplies pressure evidence, not v1 exact closure.");
    phase6e_note_checker("RRPV debug pressure completed; visible functional result remains owned by Phase6C/6F");
  endtask
endclass : test_l2tlb_p6e_rrpv_debug_pressure

`endif // L2TLB_PHASE6E_TESTS_SVH
