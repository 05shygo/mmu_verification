// =============================================================================
// L2TLB Phase 6E directed/negative wrapper set.
// =============================================================================
`ifndef L2TLB_PHASE6E_TESTS_SVH
`define L2TLB_PHASE6E_TESTS_SVH

class l2tlb_p6e_directed_lsu_one_seq extends lsu_base_seq;
  `uvm_object_utils(l2tlb_p6e_directed_lsu_one_seq)

  lsu_kind_e   req_kind;
  va_t         req_va;
  bit [6:0]    req_id;
  bit          req_store;
  int unsigned req_idle;

  function new(string name = "l2tlb_p6e_directed_lsu_one_seq");
    super.new(name);
    num_txn = 1;
    req_kind = LSU_PIPE0;
    req_va = '0;
    req_id = '0;
    req_store = 1'b0;
    req_idle = 0;
  endfunction

  virtual task body();
    lsu_txn tr;

    `uvm_create(tr)
    tr.c_kind_default.constraint_mode(0);
    tr.c_no_abort.constraint_mode(0);
    if (!tr.randomize() with {
          kind        == req_kind;
          va          == {25'b0, req_va};
          va2         == 28'(({25'b0, req_va}) >> PAGE_OFFSET);
          id          == req_id;
          st_inst     == req_store;
          abort       == 1'b0;
          idle_cycles == int'(req_idle);
          vabuf       == 28'(({25'b0, req_va}) >> 11);
        })
      `uvm_fatal(get_type_name(), "l2tlb_p6e_directed_lsu_one_seq randomize failed")
    `uvm_send(tr)
  endtask
endclass : l2tlb_p6e_directed_lsu_one_seq

class l2tlb_p6e_directed_ifu_one_seq extends ifu_base_seq;
  `uvm_object_utils(l2tlb_p6e_directed_ifu_one_seq)

  va_t         req_va;
  int unsigned req_idle;

  function new(string name = "l2tlb_p6e_directed_ifu_one_seq");
    super.new(name);
    num_txn = 1;
    req_va = '0;
    req_idle = 0;
  endfunction

  virtual task body();
    ifu_txn tr;

    `uvm_create(tr)
    if (!tr.randomize() with {
          va[38:0]    == req_va;
          abort       == 1'b0;
          idle_cycles == int'(req_idle);
        })
      `uvm_fatal(get_type_name(), "l2tlb_p6e_directed_ifu_one_seq randomize failed")
    `uvm_send(tr)
  endtask
endclass : l2tlb_p6e_directed_ifu_one_seq

class l2tlb_p6e_set_ptw_en_seq extends cp0_base_seq;
  `uvm_object_utils(l2tlb_p6e_set_ptw_en_seq)

  bit enable;

  function new(string name = "l2tlb_p6e_set_ptw_en_seq");
    super.new(name);
    enable = 1'b1;
  endfunction

  virtual task body();
    cp0_txn tr;

    `uvm_create(tr)
    tr.op = CP0_SET_PTW_EN;
    tr.ptw_en = enable;
    `uvm_send(tr)
  endtask
endclass : l2tlb_p6e_set_ptw_en_seq

class l2tlb_p6e_ptw_source_harness_base extends l2tlb_phase6e_test_base;

  localparam ppn_t  L2TLB_P6E_ROOT_PPN  = 28'h260;
  localparam asid_t L2TLB_P6E_ROOT_ASID = 16'h0618;

  virtual mmu_dut_probes_if m_probe_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(virtual mmu_dut_probes_if)::get(
      this, "", "MMU_DUT_PROBES_VIF", m_probe_vif));
  endfunction

  protected function bit [2:0] l2tlb_p6e_type_for_owner(l2tlb_owner_e owner);
    case (owner)
      L2TLB_OWNER_ITLB:       return 3'b011;
      L2TLB_OWNER_DTLB_LOAD:  return 3'b010;
      L2TLB_OWNER_DTLB_STORE: return 3'b110;
      L2TLB_OWNER_PFU:        return 3'b100;
      default:                return 3'b000;
    endcase
  endfunction

  protected function string l2tlb_p6e_owner_short(l2tlb_owner_e owner);
    case (owner)
      L2TLB_OWNER_ITLB:       return "itlb";
      L2TLB_OWNER_DTLB_LOAD:  return "dtlb_load";
      L2TLB_OWNER_DTLB_STORE: return "dtlb_store";
      L2TLB_OWNER_PFU:        return "pfu";
      default:                return "unknown";
    endcase
  endfunction

  protected function va_t l2tlb_p6e_va_for(
    input int unsigned group_id,
    input int unsigned owner_id
  );
    return va_t'(39'h0_2600_0000
      + va_t'(group_id << 20)
      + va_t'(owner_id << 12));
  endfunction

  protected task l2tlb_p6e_setup_sv39(bit ptw_enable = 1'b1);
    cp0_tlb_allinv_seq      cp0_inv;
    pmp_flg_normal_seq      pmp_seq;
    sysmap_region_setup_seq sysmap_seq;
    cp0_reg_rw_seq          cp0_init;

    cp0_inv = cp0_tlb_allinv_seq::type_id::create("l2tlb_p6e_cp0_inv");
    cp0_inv.start(m_env.m_cp0.m_sequencer);

    pmp_seq = pmp_flg_normal_seq::type_id::create("l2tlb_p6e_pmp_allow");
    pmp_seq.start(m_env.m_pmp.m_sequencer);

    sysmap_seq = sysmap_region_setup_seq::type_id::create("l2tlb_p6e_sysmap_disable");
    sysmap_seq.enable_r0 = 1'b0;
    sysmap_seq.start(m_env.m_sysmap_cfg.m_sequencer);

    cp0_init = cp0_reg_rw_seq::type_id::create("l2tlb_p6e_cp0_init");
    if (!cp0_init.randomize() with {
          satp_val  == {4'h8, 16'(L2TLB_P6E_ROOT_ASID), 44'(L2TLB_P6E_ROOT_PPN)};
          priv_mode == PRIV_S;
          ptw_en    == ptw_enable;
          icg_en    == 1'b1;
        })
      `uvm_fatal(get_type_name(), "l2tlb_p6e_setup_sv39 cp0_init randomize failed")
    cp0_init.start(m_env.m_cp0.m_sequencer);

    m_env.m_pt_mem.m_builder.set_root(L2TLB_P6E_ROOT_PPN, L2TLB_P6E_ROOT_ASID);
    if (m_env.m_ref != null)
      m_env.m_ref.sync_shadow_state();
    #100ns;
  endtask

  protected function bit l2tlb_p6e_map_leaf(
    input va_t va,
    input pa_t pa,
    input bit v = 1'b1,
    input bit r = 1'b1,
    input bit w = 1'b1,
    input bit x = 1'b1,
    input bit a = 1'b1,
    input bit d = 1'b1
  );
    pte_t raw_pte;
    pa_t  pte_pa;

    return m_env.m_pt_mem.m_builder.map_raw_leaf_pa(
      .va(va), .level(0), .pa(pa),
      .raw_pte(raw_pte), .pte_addr(pte_pa),
      .v(v), .r(r), .w(w), .x(x), .u(1'b0), .g(1'b0), .a(a), .d(d));
  endfunction

  protected task l2tlb_p6e_set_ptw_enable(bit enable);
    l2tlb_p6e_set_ptw_en_seq seq;

    seq = l2tlb_p6e_set_ptw_en_seq::type_id::create("l2tlb_p6e_set_ptw_enable");
    seq.enable = enable;
    seq.start(m_env.m_cp0.m_sequencer);
    if (m_env.m_ref != null)
      m_env.m_ref.sync_shadow_state();
  endtask

  protected task l2tlb_p6e_drive_owner(
    input l2tlb_owner_e owner,
    input va_t va,
    input int unsigned id
  );
    case (owner)
      L2TLB_OWNER_ITLB: begin
        l2tlb_p6e_directed_ifu_one_seq seq;
        seq = l2tlb_p6e_directed_ifu_one_seq::type_id::create("l2tlb_p6e_ifu_one");
        seq.req_va = va;
        seq.req_idle = 0;
        seq.start(m_env.m_ifu.m_sequencer);
      end
      L2TLB_OWNER_DTLB_LOAD,
      L2TLB_OWNER_DTLB_STORE,
      L2TLB_OWNER_PFU: begin
        l2tlb_p6e_directed_lsu_one_seq seq;
        seq = l2tlb_p6e_directed_lsu_one_seq::type_id::create("l2tlb_p6e_lsu_one");
        seq.req_kind = (owner == L2TLB_OWNER_PFU) ? LSU_PIPE2 : LSU_PIPE0;
        seq.req_va = va;
        seq.req_id = id[6:0];
        seq.req_store = (owner == L2TLB_OWNER_DTLB_STORE);
        seq.req_idle = 0;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      default:
        `uvm_fatal(get_type_name(), "Unsupported L2TLB Phase6E PTW harness owner")
    endcase
  endtask

  protected task l2tlb_p6e_wait_shadow_delta(
    input string ctx,
    input int unsigned max_cycles = 262144
  );
    m_env.wait_for_quiescent_midtest(ctx, max_cycles, 16);
    if (m_env.m_ref != null)
      m_env.m_ref.sync_shadow_state();
  endtask

  protected task l2tlb_p6e_run_ptw_disabled_owner(
    input l2tlb_owner_e owner,
    input int unsigned owner_id
  );
    va_t va;
    bit [2:0] typ;
    int unsigned base_ptw_req;

    va = l2tlb_p6e_va_for(0, owner_id);
    typ = l2tlb_p6e_type_for_owner(owner);
    if (!l2tlb_p6e_map_leaf(va, pa_t'({ppn_t'(28'h36000 + owner_id), 12'h000})))
      `uvm_fatal(get_type_name(), "PTW disabled harness failed to map legal leaf")

    l2tlb_p6e_set_ptw_enable(1'b0);
    base_ptw_req = (m_env.m_l2tlb_shadow != null) ? m_env.m_l2tlb_shadow.m_ptw_req_seen : 0;
    l2tlb_p6e_drive_owner(owner, va, 7'd16 + owner_id);
    l2tlb_p6e_wait_shadow_delta({"ptw_disabled_", l2tlb_p6e_owner_short(owner)});
    if ((m_env.m_l2tlb_shadow != null)
        && (m_env.m_l2tlb_shadow.m_ptw_req_seen != base_ptw_req)) begin
      `uvm_error(get_type_name(),
        $sformatf("PTW disabled source %s issued PTW request: before=%0d after=%0d",
          l2tlb_p6e_owner_short(owner), base_ptw_req,
          m_env.m_l2tlb_shadow.m_ptw_req_seen))
    end
    if (m_env.m_l2tlb_shadow != null)
      m_env.m_l2tlb_shadow.note_ptw_disabled_terminal(
        typ, va[38:12], L2TLB_P6E_ROOT_ASID, 7'd16 + owner_id,
        "directed PTW disabled miss terminal source bin");
    l2tlb_p6e_set_ptw_enable(1'b1);
  endtask

  protected task l2tlb_p6e_run_page_fault_owner(
    input l2tlb_owner_e owner,
    input int unsigned owner_id
  );
    va_t va;

    va = l2tlb_p6e_va_for(1, owner_id);
    if (!l2tlb_p6e_map_leaf(va, pa_t'({ppn_t'(28'h37000 + owner_id), 12'h000}),
          .v(1'b0), .r(1'b1), .w(1'b1), .x(1'b1)))
      `uvm_fatal(get_type_name(), "PTW page-fault harness failed to map V=0 leaf")
    l2tlb_p6e_drive_owner(owner, va, 7'd32 + owner_id);
    l2tlb_p6e_wait_shadow_delta({"ptw_pgflt_", l2tlb_p6e_owner_short(owner)});
  endtask

  protected task l2tlb_p6e_run_access_error_owner(
    input l2tlb_owner_e owner,
    input int unsigned owner_id
  );
    va_t va;

    va = l2tlb_p6e_va_for(2, owner_id);
    if (!l2tlb_p6e_map_leaf(va, pa_t'({ppn_t'(28'h38000 + owner_id), 12'h000})))
      `uvm_fatal(get_type_name(), "PTW access-error harness failed to map legal leaf")
    if ((m_env == null) || (m_env.m_ptw_mem == null) || (m_env.m_ptw_mem.m_responder == null))
      `uvm_fatal(get_type_name(), "PTW responder unavailable for access-error harness")
    m_env.m_ptw_mem.m_responder.clear_directed_controls();
    m_env.m_ptw_mem.m_responder.set_delay_range(1, 1);
    m_env.m_ptw_mem.m_responder.m_bus_error_rate_permille = 1000;
    l2tlb_p6e_drive_owner(owner, va, 7'd48 + owner_id);
    l2tlb_p6e_wait_shadow_delta({"ptw_accerr_", l2tlb_p6e_owner_short(owner)});
    m_env.m_ptw_mem.m_responder.clear_directed_controls();
    m_env.m_ptw_mem.m_responder.set_delay_range(1, 4);
  endtask

  protected function void l2tlb_p6e_check_source_bins();
    if (m_env.m_l2tlb_shadow == null) begin
      `uvm_error(get_type_name(), "L2TLB shadow unavailable for source-specific PTW harness")
      return;
    end

    if ((m_env.m_l2tlb_shadow.m_ptw_disabled_itlb_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_disabled_dtlb_load_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_disabled_dtlb_store_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_disabled_pfu_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_pgflt_itlb_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_pgflt_dtlb_load_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_pgflt_dtlb_store_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_pgflt_pfu_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_accerr_itlb_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_accerr_dtlb_load_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_accerr_dtlb_store_seen == 0)
        || (m_env.m_l2tlb_shadow.m_ptw_accerr_pfu_seen == 0)) begin
      `uvm_error(get_type_name(),
        $sformatf("PTW source/result bin gate failed: %s",
          m_env.m_l2tlb_shadow.summary()))
      return;
    end

    phase6e_note_trigger($sformatf("source_specific_ptw_bins %s",
      m_env.m_l2tlb_shadow.summary()));
    phase6e_note_checker("source-specific PTW disabled/page-fault/access-error bins all nonzero; payload-ignore counters checked by Phase6C shadow");
  endfunction

  virtual task run_test_body();
    setup_plan();
    phase6e_emit_meta();
    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");

    l2tlb_p6e_setup_sv39(1'b1);
    phase6e_pre_stimulus();

    l2tlb_p6e_run_ptw_disabled_owner(L2TLB_OWNER_ITLB,       0);
    l2tlb_p6e_run_ptw_disabled_owner(L2TLB_OWNER_DTLB_LOAD,  1);
    l2tlb_p6e_run_ptw_disabled_owner(L2TLB_OWNER_DTLB_STORE, 2);
    l2tlb_p6e_run_ptw_disabled_owner(L2TLB_OWNER_PFU,        3);

    l2tlb_p6e_run_page_fault_owner(L2TLB_OWNER_ITLB,       0);
    l2tlb_p6e_run_page_fault_owner(L2TLB_OWNER_DTLB_LOAD,  1);
    l2tlb_p6e_run_page_fault_owner(L2TLB_OWNER_DTLB_STORE, 2);
    l2tlb_p6e_run_page_fault_owner(L2TLB_OWNER_PFU,        3);

    l2tlb_p6e_run_access_error_owner(L2TLB_OWNER_ITLB,       0);
    l2tlb_p6e_run_access_error_owner(L2TLB_OWNER_DTLB_LOAD,  1);
    l2tlb_p6e_run_access_error_owner(L2TLB_OWNER_DTLB_STORE, 2);
    l2tlb_p6e_run_access_error_owner(L2TLB_OWNER_PFU,        3);

    #(m_post_drain);
    phase6e_note_observed_shadow_trigger();
    l2tlb_p6e_check_source_bins();
    phase6e_check_gates();
  endtask

endclass : l2tlb_p6e_ptw_source_harness_base

class test_l2tlb_p6e_reset_active_lookup_ptw_tlbop_pfu extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_l2tlb_p6e_reset_active_lookup_ptw_tlbop_pfu)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                   = "L2TLB-P6E-RESET-ACTIVE";
    p9_seq_desc                = "tlb_inv_all + pipe2 + RTU-flush interleaved with loads";
    p9_checker                 = "phase6c_epoch,phase6d_reset_sva,credit_sb";
    phase6e_scenario_id        = "L2TLB_SCN_RESET_WARM_ACTIVE_002";
    phase6e_audit_ids          = "L2TLB_TP_001,L2TLB_TP_002,L2TLB_TP_043,L2TLB_SVA_001,L2TLB_SVA_002";
    phase6e_trigger_gate       = "active lookup/PTW/TLBOP/PFU traffic with reset epoch";
    phase6e_checker_gate       = "PHASE6C_L2_EPOCH/SHADOW_RESET plus reset SVA health";
    phase6e_expected_log_token = "PHASE6C_L2_EPOCH";
    phase6e_run_tier           = "l2tlb_smoke";
    num_txn                    = 8;
    timeout_ns                 = 8_000_000;
    m_post_drain               = 800ns;
    // Inline all stimulus: TLB invalidation + PFU pipe2 + cold loads
    // interleaved with RTU flushes.  We drive these directly through the
    // environment sequencers rather than through the virtual sequencer to
    // avoid sequencer-state races.
    // The load+flush interleaving is done inline in run_test_body below.
  endfunction

  // Override the 32-TXN floor — this test interleaves short sequences with
  // RTU flushes and does not need the default clamp.
  protected function int unsigned clamp_vseq_num_txn();
    if (num_txn < 1) return 1;
    if (num_txn > 50000) return 50000;
    return num_txn;
  endfunction

  virtual task run_test_body();
    tlb_inv_all_seq           inv_seq;
    lsu_prefetch_pipe2_seq    pfu_seq;
    mmu_vseq_lsu_one_ld_seq   ld;
    misc_rtu_flush_seq        fl;
    va_t                      va_base;
    int                       k;

    setup_plan();
    phase6e_emit_meta();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");

    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase6e_pre_stimulus();

    // --- Background traffic: TLB invalidation + PFU pipe2 ---
    inv_seq = tlb_inv_all_seq::type_id::create("inv_seq");
    inv_seq.num_txn = num_txn;
    inv_seq.start(m_env.m_lsu.m_sequencer);

    pfu_seq = lsu_prefetch_pipe2_seq::type_id::create("pfu_seq");
    pfu_seq.num_txn = num_txn;
    pfu_seq.start(m_env.m_lsu.m_sequencer);

    // --- Interleaved cold loads + RTU flushes ---
    va_base = va_t'(39'h0_D000_0000);
    for (k = 0; k < 8; k++) begin
      ld = mmu_vseq_lsu_one_ld_seq::type_id::create("ldm");
      ld.m_va = va_base + va_t'(k << 12);
      ld.start(m_env.m_lsu.m_sequencer);
      repeat (20) @(posedge m_env.m_lsu.vif.clk_i);
      fl = misc_rtu_flush_seq::type_id::create("fl");
      fl.start(m_env.m_misc.m_sequencer);
      repeat (20) @(posedge m_env.m_lsu.vif.clk_i);
    end

    #(m_post_drain);
    phase6e_post_stimulus();
    phase6e_check_gates();
  endtask
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

class test_l2tlb_p6e_reqq_arb_fine_overlap extends l2tlb_phase6e_test_base;
  `uvm_component_utils(test_l2tlb_p6e_reqq_arb_fine_overlap)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                   = "L2TLB-P6E-REQQ-ARB-FINE";
    p9_seq_desc                = "mmu_l2tlb_reqq_arb_fine_vseq";
    p9_checker                 = "credit_sb,mmu_arb_sva,credit_sva,phase6c_l2_shadow";
    phase6e_scenario_id        = "L2TLB_SCN_ARB_FINE_OVERLAP_017";
    phase6e_audit_ids          = "L2TLB_TP_004,L2TLB_TP_005,L2TLB_TP_006,L2TLB_TP_007,L2TLB_TP_008,L2TLB_TP_009,L2TLB_TP_010,L2TLB_TP_011,L2TLB_TP_019,L2TLB_TP_020,L2TLB_TP_021,L2TLB_TP_022,L2TLB_TP_023,L2TLB_TP_024,L2TLB_TP_051,L2TLB_TP_052,L2TLB_TP_053,L2TLB_TP_054,L2TLB_TP_055,L2TLB_SVA_003,L2TLB_SVA_004,L2TLB_SVA_005,L2TLB_SVA_006,L2TLB_SVA_019,L2TLB_SVA_020,L2TLB-P6-ISSUE-017";
    phase6e_trigger_gate       = "IFU/DTLB load/store/PFU/TLBOP/PTW overlap with arbiter block windows";
    phase6e_checker_gate       = "L2TLB_REQQ_FINE/L2TLB_ARB_FINE counters plus payload no-cross SVA and Phase6C shadow clean";
    phase6e_expected_log_token = "L2TLB_ARB_FINE,L2TLB_REQQ_FINE";
    phase6e_run_tier           = "l2tlb_directed_p0";
    num_txn                    = 96;
    timeout_ns                 = 12_000_000;
    m_post_drain               = 1500ns;
    m_vseq_names.push_back("mmu_l2tlb_reqq_arb_fine_vseq");
  endfunction
endclass : test_l2tlb_p6e_reqq_arb_fine_overlap

class test_l2tlb_p6e_ptw_disabled_fault_accerr extends l2tlb_p6e_ptw_source_harness_base;
  `uvm_component_utils(test_l2tlb_p6e_ptw_disabled_fault_accerr)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id                   = "L2TLB-P6E-PTW-SRC";
    p9_seq_desc                = "source-specific PTW disabled/page-fault/access-error directed harness";
    p9_checker                 = "phase6c_l2_source_result_bins,payload_ignore,no_ptw_request_when_disabled";
    phase6e_scenario_id        = "L2TLB_SCN_PTW_SRC_DISABLED_FAULT_ACCERR_018_025_026";
    phase6e_audit_ids          = "L2TLB_TP_018,L2TLB_TP_025,L2TLB_TP_026,L2TLB_TP_033,L2TLB_SVA_012,L2TLB_SVA_014";
    phase6e_kind               = "positive";
    phase6e_trigger_gate       = "ITLB/DTLB_LOAD/DTLB_STORE/PFU x PTW disabled/page-fault/access-error bins";
    phase6e_checker_gate       = "Phase6C source/result counters all nonzero; disabled path issues no PTW request; payload-ignore active";
    phase6e_expected_log_token = "PHASE6C_L2_SOURCE_RESULT,PHASE6C_L2_PTW_DISABLED,PHASE6C_PAYLOAD_IGNORE";
    phase6e_waiver_policy      = "no waiver";
    phase6e_run_tier           = "l2tlb_directed_p0";
    phase6e_require_trigger_gate = 1'b1;
    phase6e_is_future_or_waiver = 1'b0;
    num_txn                    = 12;
    timeout_ns                 = 12_000_000;
    m_enable_sv39_4k_bringup   = 1'b0;
    m_run_misc_init            = 1'b1;
    m_post_drain               = 1000ns;
  endfunction
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
    p9_seq_desc                 = "negative injector suite: bad PTW completion and control hazard";
    p9_checker                  = "l2tlb_negative_injector,expected_negative_classification";
    phase6e_scenario_id         = "L2TLB_SCN_PTW_NEG_PROTOCOL_027";
    phase6e_audit_ids           = "L2TLB_TP_027,L2TLB_TP_048,L2TLB_TP_056,L2TLB_TP_058,L2TLB_SVA_012,L2TLB_SVA_013,L2TLB_SVA_017,L2TLB_SVA_018";
    phase6e_kind                = "negative";
    phase6e_trigger_gate        = "L2TLB_NEG_TRIGGER for bad completion/control hazard";
    phase6e_checker_gate        = "L2TLB_NEG_EXPECTED_CLASS classification, no normal functional compare closure";
    phase6e_expected_log_token  = "L2TLB_NEG_TRIGGER,L2TLB_NEG_EXPECTED_CLASS";
    phase6e_waiver_policy       = "no waiver; negative stimulus isolated in l2tlb_negative list";
    phase6e_run_tier            = "l2tlb_negative";
    phase6e_is_negative         = 1'b1;
    phase6e_require_trigger_gate = 1'b1;
    phase6e_require_checker_gate = 1'b1;
    phase6e_is_future_or_waiver  = 1'b0;
    num_txn                     = 16;
    timeout_ns                  = 4_000_000;
    m_enable_sv39_4k_bringup    = 1'b0;
    m_run_misc_init             = 1'b1;
  endfunction

  protected task run_control_hazard_negative_with_traffic();
    if ((m_env != null) && (m_env.m_ptw_mem != null)
        && (m_env.m_ptw_mem.m_responder != null)) begin
      m_env.m_ptw_mem.m_responder.clear_directed_controls();
      m_env.m_ptw_mem.m_responder.set_delay_range(64, 64);
    end

    fork
      begin
        l2tlb_p6e_directed_lsu_one_seq seq;
        seq = l2tlb_p6e_directed_lsu_one_seq::type_id::create(
          "l2tlb_p6e_neg_ctrl_lsu_miss");
        seq.req_kind = LSU_PIPE0;
        seq.req_va = va_t'(m_va_base) + va_t'(17 << 12);
        seq.req_id = 7'd45;
        seq.req_store = 1'b0;
        seq.req_idle = 0;
        seq.start(m_env.m_lsu.m_sequencer);
      end
      begin
        repeat (2) @(m_env.m_lsu.m_driver.vif.driver_cb);
        phase6e_inject_control_hazard_negative(
          "control_hazard_satp_write",
          "control_hazard_outstanding_required");
        if ((m_env != null) && (m_env.m_ptw_mem != null)
            && (m_env.m_ptw_mem.m_responder != null)) begin
          m_env.m_ptw_mem.m_responder.clear_directed_controls();
          m_env.m_ptw_mem.m_responder.set_delay_range(1, 4);
        end
      end
    join

    if ((m_env != null) && (m_env.m_ptw_mem != null)
        && (m_env.m_ptw_mem.m_responder != null)) begin
      m_env.m_ptw_mem.m_responder.clear_directed_controls();
      m_env.m_ptw_mem.m_responder.set_delay_range(1, 4);
    end
  endtask

  virtual task run_test_body();
    setup_plan();
    phase6e_emit_meta();
    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    do_sv39_4k_bringup();
    phase6e_pre_stimulus();

    phase6e_inject_ptw_negative(
      L2TLB_NEG_PTW_NO_OUTSTANDING,
      "ptw_no_outstanding",
      "bad_completion_no_outstanding",
      7'h7f,
      3'b010,
      1'b0,
      1'b1,
      1'b0);

    phase6e_inject_ptw_negative(
      L2TLB_NEG_PTW_BAD_ID_TYPE,
      "ptw_bad_id_type",
      "bad_completion_id_type_mismatch",
      7'h7e,
      3'b111,
      1'b0,
      1'b0,
      1'b1);

    phase6e_inject_ptw_negative(
      L2TLB_NEG_PTW_ILLEGAL_COMBO,
      "ptw_illegal_result_combo",
      "illegal_completion_result_combo",
      7'h7d,
      3'b011,
      1'b1,
      1'b1,
      1'b0,
      14'h0001);

    run_control_hazard_negative_with_traffic();

    #(m_post_drain);
    phase6e_check_gates();
  endtask
endclass : test_l2tlb_p6e_negative_ptw_completion_control

class test_l2tlb_p6e_neg_ptw_no_outstanding extends test_l2tlb_p6e_negative_ptw_completion_control;
  `uvm_component_utils(test_l2tlb_p6e_neg_ptw_no_outstanding)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "L2TLB-P6E-NEG-PTW-NO-OUT";
    phase6e_scenario_id = "L2TLB_SCN_PTW_NEG_NO_OUTSTANDING_027";
    phase6e_audit_ids = "L2TLB_TP_027,L2TLB_TP_048,L2TLB_SVA_012,L2TLB_SVA_013";
    phase6e_trigger_gate = "L2TLB_NEG_TRIGGER no_outstanding=1";
    phase6e_checker_gate = "L2TLB_NEG_EXPECTED_CLASS bad_completion_no_outstanding";
  endfunction

  virtual task run_test_body();
    setup_plan();
    phase6e_emit_meta();
    phase6e_pre_stimulus();
    phase6e_inject_ptw_negative(
      L2TLB_NEG_PTW_NO_OUTSTANDING,
      "ptw_no_outstanding",
      "bad_completion_no_outstanding",
      7'h7f,
      3'b010,
      1'b0,
      1'b1,
      1'b0);
    #(m_post_drain);
    phase6e_check_gates();
  endtask
endclass : test_l2tlb_p6e_neg_ptw_no_outstanding

class test_l2tlb_p6e_neg_ptw_bad_id_type extends test_l2tlb_p6e_negative_ptw_completion_control;
  `uvm_component_utils(test_l2tlb_p6e_neg_ptw_bad_id_type)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "L2TLB-P6E-NEG-PTW-BAD-ID";
    phase6e_scenario_id = "L2TLB_SCN_PTW_NEG_BAD_ID_TYPE_027";
    phase6e_audit_ids = "L2TLB_TP_027,L2TLB_TP_048,L2TLB_TP_056,L2TLB_SVA_013,L2TLB_SVA_018";
    phase6e_trigger_gate = "L2TLB_NEG_TRIGGER bad_identity=1";
    phase6e_checker_gate = "L2TLB_NEG_EXPECTED_CLASS bad_completion_id_type_mismatch";
  endfunction

  virtual task run_test_body();
    setup_plan();
    phase6e_emit_meta();
    phase6e_pre_stimulus();
    phase6e_inject_ptw_negative(
      L2TLB_NEG_PTW_BAD_ID_TYPE,
      "ptw_bad_id_type",
      "bad_completion_id_type_mismatch",
      7'h7e,
      3'b111,
      1'b0,
      1'b0,
      1'b1);
    #(m_post_drain);
    phase6e_check_gates();
  endtask
endclass : test_l2tlb_p6e_neg_ptw_bad_id_type

class test_l2tlb_p6e_neg_ptw_illegal_combo extends test_l2tlb_p6e_negative_ptw_completion_control;
  `uvm_component_utils(test_l2tlb_p6e_neg_ptw_illegal_combo)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "L2TLB-P6E-NEG-PTW-COMBO";
    phase6e_scenario_id = "L2TLB_SCN_PTW_NEG_ILLEGAL_COMBO_027";
    phase6e_audit_ids = "L2TLB_TP_027,L2TLB_TP_048,L2TLB_SVA_012,L2TLB_SVA_018";
    phase6e_trigger_gate = "L2TLB_NEG_TRIGGER illegal_combo=1";
    phase6e_checker_gate = "L2TLB_NEG_EXPECTED_CLASS illegal_completion_result_combo";
  endfunction

  virtual task run_test_body();
    setup_plan();
    phase6e_emit_meta();
    phase6e_pre_stimulus();
    phase6e_inject_ptw_negative(
      L2TLB_NEG_PTW_ILLEGAL_COMBO,
      "ptw_illegal_result_combo",
      "illegal_completion_result_combo",
      7'h7d,
      3'b011,
      1'b1,
      1'b1,
      1'b0,
      14'h0001);
    #(m_post_drain);
    phase6e_check_gates();
  endtask
endclass : test_l2tlb_p6e_neg_ptw_illegal_combo

class test_l2tlb_p6e_neg_control_hazard extends test_l2tlb_p6e_negative_ptw_completion_control;
  `uvm_component_utils(test_l2tlb_p6e_neg_control_hazard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void setup_plan();
    super.setup_plan();
    p9_tc_id = "L2TLB-P6E-NEG-CTRL";
    phase6e_scenario_id = "L2TLB_SCN_CONTROL_HAZARD_NEG_058";
    phase6e_audit_ids = "L2TLB_TP_058,L2TLB_SVA_017";
    phase6e_trigger_gate = "L2TLB_NEG_TRIGGER outstanding_seen=1";
    phase6e_checker_gate = "L2TLB_NEG_EXPECTED_CLASS control_hazard_outstanding_required";
    timeout_ns = 8_000_000;
  endfunction

  virtual task run_test_body();
    setup_plan();
    phase6e_emit_meta();
    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    do_sv39_4k_bringup();
    phase6e_pre_stimulus();

    run_control_hazard_negative_with_traffic();

    #(m_post_drain);
    phase6e_check_gates();
  endtask
endclass : test_l2tlb_p6e_neg_control_hazard

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

  protected virtual task phase6e_post_stimulus();
    start_misc_seq_by_name("misc_rtu_flush_seq");
    m_env.wait_for_quiescent_midtest("phase6e_timeout_fairness_release", 262144, 16);
    super.phase6e_post_stimulus();
  endtask
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
    phase6f_class              = "debug_coverage,debug_assertion,v1_functional_visible,future_exact_model";
    phase6f_future_exact_items = "exact_victim,exact_rrpv_value,wbuf_latest_wins,wbuf_merge,same_cycle_bypass";
    phase6e_is_debug           = 1'b1;
    num_txn                    = 96;
    timeout_ns                 = 8_000_000;
    m_vseq_names.push_back("mmu_rrpv_aging_vseq");
  endfunction

  protected virtual task phase6e_post_stimulus();
    phase6e_note_observed_shadow_trigger();
    phase6e_note_waiver("RRPV exact victim/value/latest-wins are debug/future only; this run supplies pressure evidence, not v1 exact closure.");
    phase6e_note_checker("RRPV debug pressure completed; Phase6F class permits only visible result, debug SVA/coverage, and future exact-model classification");
  endtask
endclass : test_l2tlb_p6e_rrpv_debug_pressure

`endif // L2TLB_PHASE6E_TESTS_SVH

`include "test_mmu_l2tlb_pfu_pmp_deny_chk.svh"
`include "test_mmu_l1itlb_cov_sweep.svh"
`include "test_mmu_l2tlb_cov_mb_reqq.svh"
`include "test_mmu_l2tlb_cov_tag_inv.svh"
`include "test_mmu_l2tlb_cov_pfu_chk_deny.svh"
`include "test_mmu_l2tlb_cov_multiway_hit.svh"
`include "test_mmu_l2tlb_cov_acc_type_sweep.svh"
`include "test_mmu_l2tlb_cov_mb_full.svh"
`include "test_mmu_l2tlb_cov_par_fail.svh"
`include "test_mmu_l2tlb_cov_rrpv_wbuf_full.svh"
`include "test_mmu_l2tlb_cov_reqq_depth.svh"
`include "test_mmu_l2tlb_cov_mid_reset.svh"
`include "test_mmu_l2tlb_cov_cond_1234.svh"
`include "test_mmu_l2tlb_cov_cond_1234b.svh"
`include "test_mmu_l2tlb_cov_ptw_disabled.svh"
`include "test_mmu_l2tlb_cov_ptw_off.svh"
`include "test_mmu_l2tlb_cov_ptw_off_v2.svh"
`include "test_mmu_l2tlb_cov_ptw_off_v3.svh"
`include "test_mmu_l2tlb_cond_769.svh"
`include "test_diag_ptw_en.svh"
`include "test_mmu_l2tlb_cov_pfu_fault_sweep.svh"
`include "test_mmu_l2tlb_cov_arb_write_sweep.svh"
`include "test_mmu_l2tlb_cov_multiway_hit2.svh"
`include "test_mmu_l2tlb_cov_par_fail2.svh"
`include "test_mmu_l2tlb_cov_pgflt_ptw_off.svh"
`include "test_mmu_l2tlb_cov_sva_closure.svh"
`include "test_mmu_l2tlb_cov_mb_cond.svh"
`include "test_mmu_l2tlb_cov_toggle_sweep.svh"
`include "test_mmu_l2tlb_cov_sva_targeted.svh"
`include "test_mmu_l2tlb_cov_sva_oneshot.svh"
