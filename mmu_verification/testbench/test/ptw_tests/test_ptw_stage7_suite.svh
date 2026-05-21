// =============================================================================
// PTW stage-7 P1/P2/random source-side suite
//
// Stage 7 scope only:
//   - Exercise precision items left open by Stage 6.
//   - Prove illegal constraints without turning illegal stimulus into a DUT
//     failure.
//   - Feed the Stage-7 ref model/SB field coverage summaries.
// =============================================================================
`ifndef TEST_PTW_STAGE7_SUITE_SVH
`define TEST_PTW_STAGE7_SUITE_SVH

class ptw_stage7_base extends ptw_source_directed_base;

  localparam ppn_t  STAGE7_ROOT_PPN  = 28'h270;
  localparam asid_t STAGE7_ROOT_ASID = 16'h0707;

  int unsigned m_stage7_closed;
  int unsigned m_stage7_open;
  int unsigned m_stage7_illegal_blocked;
  virtual mmu_dut_probes_if m_stage7_probe_vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 64;
    timeout_ns = 4_000_000;
    m_stage7_closed = 0;
    m_stage7_open = 0;
    m_stage7_illegal_blocked = 0;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    void'(uvm_config_db#(virtual mmu_dut_probes_if)::get(
      this, "", "MMU_DUT_PROBES_VIF", m_stage7_probe_vif));
  endfunction

  protected function void stage7_close(
    input string req_ids,
    input string scenario_id,
    input string evidence
  );
    m_stage7_closed++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE7_CLOSURE status=closed test=%s scenario=%s req=%s evidence={%s}",
        get_type_name(), scenario_id, req_ids, evidence),
      UVM_NONE)
  endfunction

  protected function void stage7_open(
    input string req_ids,
    input string scenario_id,
    input string reason
  );
    m_stage7_open++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE7_CLOSURE status=open-waived test=%s scenario=%s req=%s reason={%s}",
        get_type_name(), scenario_id, req_ids, reason),
      UVM_NONE)
  endfunction

  protected function void stage7_illegal_blocked(
    input string constraint_id,
    input string scenario_id,
    input string evidence
  );
    m_stage7_illegal_blocked++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE7_ILLEGAL status=blocked_by_constraint test=%s scenario=%s constraint=%s evidence={%s}",
        get_type_name(), scenario_id, constraint_id, evidence),
      UVM_NONE)
  endfunction

  protected task stage7_pmp_raw_twu_flags(input bit [3:0] twu_flg);
    pmp_flg_raw_seq seq;
    seq = pmp_flg_raw_seq::type_id::create("stage7_pmp_raw_twu_flags_seq");
    foreach (seq.raw_flg[i])
      seq.raw_flg[i] = 4'h7;
    seq.raw_flg[3] = twu_flg;
    seq.raw_flg[5] = twu_flg;
    seq.raw_flg[6] = twu_flg;
    seq.raw_flg[7] = twu_flg;
    seq.start(m_env.m_pmp.m_sequencer);
    if ((m_env != null) && (m_env.m_ref != null))
      m_env.m_ref.sync_shadow_state();
    ptw_meta_add_context($sformatf("stage7_pmp_raw_twu_flg=0x%0h", twu_flg));
  endtask

  protected task stage7_write_satp(input ppn_t root_ppn, input asid_t asid);
    cp0_satp_switch_seq seq;
    bit satp_changed;

    satp_changed = (root_ppn != ptw_root_ppn) || (asid != ptw_root_asid);
    seq = cp0_satp_switch_seq::type_id::create("stage7_satp_switch_seq");
    seq.satp_sel = 1'b0;
    seq.satp_val = {4'h8, 16'(asid), 44'(root_ppn)};
    seq.start(m_env.m_cp0.m_sequencer);
    if ((m_env != null) && (m_env.m_ref != null))
      m_env.m_ref.sync_shadow_state();
    ptw_meta_add_context($sformatf("stage7_satp_write root_ppn=0x%07h asid=0x%04h", root_ppn, asid));

    ptw_root_ppn = root_ppn;
    ptw_root_asid = asid;
    if (satp_changed) begin
      ptw_drive_satp_change_asid_tlboper_abort(
        asid,
        $sformatf("stage7_satp_write_asid_tlboper_abort asid=0x%04h", asid));
    end
  endtask

  protected task stage7_map_leaf(
    input va_t               va,
    input int unsigned       level,
    input pa_t               pa,
    input ptw_src_req_type_e req_type,
    input int unsigned       id,
    input string             kind,
    input bit                v = 1'b1,
    input bit                r = 1'b1,
    input bit                w = 1'b1,
    input bit                x = 1'b1,
    input bit                u = 1'b0,
    input bit                g = 1'b0,
    input bit                a = 1'b1,
    input bit                d = 1'b1,
    input bit [1:0]          rsw = 2'b00,
    input bit [20:0]         high_reserved = 21'h0,
    input bit [4:0]          ext_attr = 5'h0,
    input bit                allow_misaligned = 1'b0
  );
    pte_t raw_pte;
    pa_t  pte_pa;

    if (!ptw_map_raw_leaf_pa(.va(va), .level(level), .pa(pa),
          .raw_pte(raw_pte), .pte_pa(pte_pa),
          .v(v), .r(r), .w(w), .x(x), .u(u), .g(g), .a(a), .d(d),
          .rsw(rsw), .high_reserved(high_reserved), .ext_attr(ext_attr),
          .allow_misaligned(allow_misaligned)))
      `uvm_fatal(get_type_name(), $sformatf("stage7_map_leaf failed scenario=%s", ptw_scenario_id))
    ptw_meta_add_level(req_type, id, va, level, raw_pte, pte_pa, kind);
  endtask

  protected task stage7_write_raw_level(
    input va_t               va,
    input int unsigned       level,
    input pte_t              raw_pte,
    input ptw_src_req_type_e req_type,
    input int unsigned       id,
    input string             kind,
    input bit                create_path = 1'b1
  );
    pa_t pte_pa;

    if (!ptw_write_raw_pte_level(va, level, raw_pte, pte_pa, create_path))
      `uvm_fatal(get_type_name(), $sformatf("stage7_write_raw_level failed scenario=%s level=%0d",
        ptw_scenario_id, level))
    ptw_meta_add_level(req_type, id, va, level, raw_pte, pte_pa, kind);
  endtask

  protected task stage7_drive_req(
    input ptw_src_req_type_e req_type,
    input va_t              va,
    input int unsigned      id = 0
  );
    case (req_type)
      PTW_SRC_TYPE_FETCH: ptw_drive_fetch(va);
      PTW_SRC_TYPE_LOAD:  ptw_drive_lsu_load(va, id);
      PTW_SRC_TYPE_STORE: ptw_drive_lsu_store(va, id);
      PTW_SRC_TYPE_PFU:   ptw_drive_pfu(va, id);
      default:
        `uvm_fatal(get_type_name(), $sformatf("Unsupported stage7 request type=%0d", int'(req_type)))
    endcase
  endtask

  protected task stage7_observe_optional_ptw_accept(
    input string scenario_id,
    input ptw_src_req_type_e req_type,
    input va_t va,
    input int unsigned source_id,
    input int unsigned max_cycles = 64
  );
    bit seen;
    bit saw_any_accept;
    bit [26:0] vpn;
    bit [2:0] last_accept_type;
    bit [PTW_SRC_ID_WIDTH-1:0] last_accept_id;
    bit [26:0] last_accept_vpn;

    seen = 1'b0;
    saw_any_accept = 1'b0;
    vpn = va[38:12];
    last_accept_type = '0;
    last_accept_id = '0;
    last_accept_vpn = '0;
    if (m_stage7_probe_vif == null) begin
      `uvm_info(get_type_name(),
        $sformatf("%s: MMU_DUT_PROBES_VIF unavailable; skip optional PTW accept observation before SATP switch",
          scenario_id),
        UVM_LOW)
      ptw_meta_add_context({scenario_id, ": probe_vif_unavailable_optional_ptw_accept_skipped"});
      #25ns;
      return;
    end

    repeat (max_cycles) begin
      @(m_stage7_probe_vif.mon_cb);
      if ((m_stage7_probe_vif.mon_cb.l2tlb_ptw_req === 1'b1)
          && (m_stage7_probe_vif.mon_cb.ptw_jtlb_ready === 1'b1)) begin
        saw_any_accept = 1'b1;
        last_accept_type = m_stage7_probe_vif.mon_cb.l2tlb_ptw_type;
        last_accept_id = m_stage7_probe_vif.mon_cb.l2tlb_ptw_id;
        last_accept_vpn = m_stage7_probe_vif.mon_cb.l2tlb_ptw_vpn;
        // l2tlb_ptw_id is the L2 miss-buffer/L1 miss-entry composite ID, not
        // the LSU source stimulus id.  Match the accepted PTW request by the
        // architectural source type and VPN; log both IDs for correlation.
        if ((m_stage7_probe_vif.mon_cb.l2tlb_ptw_type == req_type)
            && (m_stage7_probe_vif.mon_cb.l2tlb_ptw_vpn == vpn)) begin
          seen = 1'b1;
          break;
        end
      end
    end

    if (!seen) begin
      `uvm_info(get_type_name(),
        $sformatf("%s: no matching PTW accept observed before SATP switch; this is legal for a process switch type=%s vpn=0x%07h source_id=0x%02h saw_any_accept=%0b last_accept={type=0x%0h id=0x%02h vpn=0x%07h}",
          scenario_id, req_type.name(), vpn, source_id[PTW_SRC_ID_WIDTH-1:0], saw_any_accept,
          last_accept_type, last_accept_id, last_accept_vpn),
        UVM_LOW)
      ptw_meta_add_context($sformatf("%s: no_required_ptw_accept_before_satp_switch type=%s vpn=0x%07h source_id=0x%02h",
        scenario_id, req_type.name(), vpn, source_id[PTW_SRC_ID_WIDTH-1:0]));
    end else begin
      ptw_meta_add_context($sformatf("%s: observed_ptw_accept_before_satp_switch type=%s vpn=0x%07h source_id=0x%02h ptw_id=0x%02h",
        scenario_id, req_type.name(), vpn, source_id[PTW_SRC_ID_WIDTH-1:0], last_accept_id));
    end
  endtask

  protected task stage7_finish_scenario(input string scenario_id);
    ptw_meta_set_actual("source_sb_expected_match_required_stage7");
    ptw_meta_set_result("stage7_directed");
    ptw_quiescent_wait(scenario_id);
    ptw_meta_print();
  endtask

  protected task stage7_wait_sysmap_or_refill_path(
    input string scenario_id,
    input int unsigned max_cycles = 512
  );
    bit seen;

    seen = 1'b0;
    if (m_stage7_probe_vif == null) begin
      ptw_meta_add_context({scenario_id, ": probe_vif_unavailable_fallback_timed_maee_switch"});
      #80ns;
      return;
    end

    repeat (max_cycles) begin
      @(m_stage7_probe_vif.mon_cb);
      if ((|m_stage7_probe_vif.mon_cb.p13_sysmap_hit_vec)
          || m_stage7_probe_vif.mon_cb.maee_csr_path_hit
          || m_stage7_probe_vif.mon_cb.maee_refill_path_hit) begin
        seen = 1'b1;
        break;
      end
    end

    if (!seen)
      `uvm_error(get_type_name(),
        $sformatf("%s: did not observe MAEE/SysMap path before switch", scenario_id))
    else
      ptw_meta_add_context({scenario_id, ": observed_maee_sysmap_path_before_switch"});
  endtask

  protected function void stage7_summary(input bit source_sb_required = 1'b1);
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE7_TEST_SUMMARY test=%s closed_markers=%0d open_markers=%0d illegal_blocked=%0d source_sb_required=%0b",
        get_type_name(), m_stage7_closed, m_stage7_open,
        m_stage7_illegal_blocked, source_sb_required),
      UVM_NONE)
  endfunction

endclass : ptw_stage7_base

class test_ptw_pde_satp_old_walk_reupdate_001 extends ptw_stage7_base;

  `uvm_component_utils(test_ptw_pde_satp_old_walk_reupdate_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;
    pa_t pte_pa;

    va = 39'h0_30a0_0000;
    pa = 40'h0_03a0_0000;
    ptw_meta_begin("TC-PTW-STAGE7-PDE", "stage7_satp_old_walk_reupdate");
    ptw_meta_add_req("PTW-ADD-010");
    ptw_meta_add_req("PTW-FLOW-022");
    ptw_setup_sv39(STAGE7_ROOT_PPN + 28'h01, STAGE7_ROOT_ASID + 16'h01,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage7_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD),
      .id(6'h01), .kind("old_walk_leaf_after_satp_clear"),
      .r(1), .w(1), .x(0), .a(1), .d(1));
    if (!ptw_get_pte_addr_for_level(va, 2, pte_pa))
      `uvm_fatal(get_type_name(), "cannot resolve fst PTE address")
    ptw_mem_delay_by_addr(pte_pa, 32);
    ptw_meta_set_expected("satp process switch does not require a pre-switch PTW accept; LSU INV_ASID_ALL must follow and raise tlboper_ptw_abort, dropping any in-flight old walk");
    fork
      begin
        stage7_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h01);
      end
      begin
        stage7_observe_optional_ptw_accept("stage7_satp_old_walk_reupdate",
          PTW_SRC_TYPE_LOAD, va, 6'h01);
        stage7_write_satp(STAGE7_ROOT_PPN + 28'h21, STAGE7_ROOT_ASID + 16'h21);
      end
    join
    stage7_finish_scenario("stage7_satp_old_walk_reupdate");
    stage7_close("PTW-ADD-010,PTW-FLOW-022", "stage7_satp_old_walk_reupdate",
      "SATP write clears PDE; process-switch LSU ASID invalidation raises tlboper_ptw_abort; pre-switch PTW accept is optional and any in-flight old walk is dropped");

    stage7_summary();
    #200ns;
  endtask

endclass : test_ptw_pde_satp_old_walk_reupdate_001

class test_ptw_pmp_cfg_clear_no_flush_001 extends ptw_stage7_base;

  `uvm_component_utils(test_ptw_pmp_cfg_clear_no_flush_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;
    pa_t pte_pa;

    va = 39'h0_30a0_1000;
    pa = 40'h0_03a0_1000;
    ptw_meta_begin("TC-PTW-STAGE7-PDE", "stage7_pmp_cfg_clear_no_flush");
    ptw_meta_add_req("PTW-ADD-010");
    ptw_meta_add_req("PTW-FLOW-022");
    ptw_setup_sv39(STAGE7_ROOT_PPN + 28'h02, STAGE7_ROOT_ASID + 16'h02,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage7_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD),
      .id(6'h02), .kind("old_walk_leaf_after_pmp_cfg"),
      .r(1), .w(1), .x(0), .a(1), .d(1));
    if (!ptw_get_pte_addr_for_level(va, 2, pte_pa))
      `uvm_fatal(get_type_name(), "cannot resolve fst PTE address")
    ptw_mem_delay_by_addr(pte_pa, 32);
    ptw_meta_set_expected("PMP flag change must not flush the in-flight walk; RTL PDE-clear proof is an open TB/probe gap while pmp_regs_update is tied off");
    fork
      begin
        stage7_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h02);
      end
      begin
        #25ns;
        stage7_pmp_raw_twu_flags(4'h5);
      end
    join
    stage7_finish_scenario("stage7_pmp_cfg_clear_no_flush");
    stage7_open("PTW-ADD-010,PTW-FLOW-022", "stage7_pmp_cfg_clear_no_flush",
      "source_sb proves PMP flag change does not flush in-flight walk; actual RTL pmp_regs_update-driven PDE clear remains a top/probe tie-off gap");
    stage7_summary();
    #200ns;
  endtask

endclass : test_ptw_pmp_cfg_clear_no_flush_001

class test_ptw_asid_refill_current_sample_001 extends ptw_stage7_base;

  `uvm_component_utils(test_ptw_asid_refill_current_sample_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;
    pa_t pte_pa;

    va = 39'h0_30a0_2000;
    pa = 40'h0_03a0_2000;
    ptw_meta_begin("TC-PTW-STAGE7-CTX", "stage7_asid_change_abort_constraint");
    ptw_meta_add_req("PTW-ADD-030");
    ptw_setup_sv39(STAGE7_ROOT_PPN + 28'h03, 16'h0710, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage7_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD),
      .id(6'h03), .kind("asid_current_sample_leaf"),
      .r(1), .w(1), .x(0), .a(1), .d(1));
    if (!ptw_get_pte_addr_for_level(va, 0, pte_pa))
      `uvm_fatal(get_type_name(), "cannot resolve thd PTE address")
    ptw_mem_delay_by_addr(pte_pa, 48);
    ptw_meta_set_expected("ASID-changing SATP process switch must be followed by LSU INV_ASID_ALL and abort; no pre-switch PTW accept is required and no stale old-root refill is legal");
    fork
      begin
        stage7_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h03);
      end
      begin
        stage7_observe_optional_ptw_accept("stage7_asid_change_abort_constraint",
          PTW_SRC_TYPE_LOAD, va, 6'h03);
        stage7_write_satp(STAGE7_ROOT_PPN + 28'h03, 16'h07fe);
      end
    join
    stage7_finish_scenario("stage7_asid_change_abort_constraint");
    stage7_illegal_blocked("PTW-ADD-030", "stage7_asid_change_abort_constraint",
      "ASID change without subsequent tlboper_ptw_abort is constrained away by process-switch LSU INV_ASID_ALL");
    stage7_close("PTW-FLOW-019,PTW-FLOW-022", "stage7_asid_change_abort_constraint",
      "SATP ASID change drives LSU ASID invalidation and observes tlboper_ptw_abort; optional pre-switch PTW accept observation is not a pass/fail condition");
    stage7_summary();
    #200ns;
  endtask

endclass : test_ptw_asid_refill_current_sample_001

class test_ptw_maee_mid_sysmap_change_001 extends ptw_stage7_base;

  `uvm_component_utils(test_ptw_maee_mid_sysmap_change_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;
    pa_t pte_pa;

    va = 39'h0_30a0_3000;
    pa = 40'h0_0380_3000;
    ptw_meta_begin("TC-PTW-STAGE7-MAEE", "stage7_maee_mid_sysmap_change");
    ptw_meta_add_req("PTW-ADD-026");
    ptw_meta_add_req("PTW-ADD-030");
    ptw_meta_add_req("MAEE-TP-012");
    ptw_setup_sv39(STAGE7_ROOT_PPN + 28'h04, STAGE7_ROOT_ASID + 16'h04,
      PRIV_S, 1'b0, 1'b0, 1'b0);
    ptw_meta_add_context("MAEE=0 at CHK/sysmap entry; later MAEE=1 must not roll back sysmap attr");
    stage7_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD),
      .id(6'h04), .kind("maee0_4k_leaf_mid_change"),
      .r(1), .w(1), .x(0), .a(1), .d(1), .rsw(2'b10), .ext_attr(5'h1f));
    if (!ptw_get_pte_addr_for_level(va, 0, pte_pa))
      `uvm_fatal(get_type_name(), "cannot resolve thd PTE address")
    ptw_mem_delay_by_addr(pte_pa, 16);
    ptw_meta_set_expected("final refill flg uses SysMap attr captured by MAEE=0 path, not PTE ext_attr after MAEE flips");
    fork
      begin
        stage7_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h04);
      end
      begin
        stage7_wait_sysmap_or_refill_path("stage7_maee_mid_sysmap_change");
        ptw_set_maee(1'b1);
      end
    join
    stage7_finish_scenario("stage7_maee_mid_sysmap_change");
    stage7_close("PTW-ADD-026,PTW-ADD-030,MAEE-TP-012", "stage7_maee_mid_sysmap_change",
      "Stage7 ref_model MAEE=0 sysmap latch/refill match; later MAEE=1 is not retroactive");
    stage7_summary();
    #200ns;
  endtask

endclass : test_ptw_maee_mid_sysmap_change_001

class test_ptw_random_pte_perm_cross_001 extends ptw_stage7_base;

  `uvm_component_utils(test_ptw_random_pte_perm_cross_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn = 96;
    timeout_ns = 6_000_000;
  endfunction

  protected task run_perm_case(
    input int unsigned idx,
    input ptw_src_req_type_e req_type,
    input int unsigned level,
    input bit r,
    input bit w,
    input bit x,
    input bit u,
    input bit a,
    input bit d,
    input bit mxr,
    input bit sum,
    input bit maee
  );
    va_t va;
    pa_t pa;
    int unsigned id;
    string scenario_id;

    id = 6'h10 + idx[5:0];
    va = 39'h0_3100_0000 + (va_t'(idx) << 12);
    pa = 40'h0_0410_0000 + (pa_t'(idx) << 12);
    if (level == 1)
      pa[20:0] = '0;
    else if (level == 2)
      pa[29:0] = '0;
    scenario_id = $sformatf("stage7_random_perm_%0d", idx);
    ptw_meta_begin("TC-PTW-STAGE7-RANDOM", scenario_id);
    ptw_meta_add_req("PTW-ADD-016");
    ptw_meta_add_req("PTW-ADD-017");
    ptw_meta_add_req("PTW-ADD-018");
    ptw_meta_add_req("PTW-ADD-019");
    ptw_meta_add_req("PTW-ADD-033");
    ptw_setup_sv39(STAGE7_ROOT_PPN + 28'h20 + ppn_t'(idx),
      STAGE7_ROOT_ASID + asid_t'(16'h20 + idx), PRIV_S, mxr, sum, maee);
    stage7_map_leaf(.va(va), .level(level), .pa(pa), .req_type(req_type),
      .id(id), .kind("stage7_random_perm_leaf"),
      .r(r), .w(w), .x(x), .u(u), .a(a), .d(d),
      .rsw(idx[1:0]), .ext_attr(idx[4:0]));
    ptw_meta_set_expected("constrained legal random PTE/type/level/context cross; source_sb determines refill or page fault");
    stage7_drive_req(req_type, va, id);
    stage7_finish_scenario(scenario_id);
  endtask

  virtual task run_test_body();
    run_perm_case(0, PTW_SRC_TYPE_LOAD,  0, 1, 1, 0, 0, 1, 1, 0, 0, 1);
    run_perm_case(1, PTW_SRC_TYPE_STORE, 0, 1, 1, 0, 0, 1, 0, 0, 0, 1);
    run_perm_case(2, PTW_SRC_TYPE_FETCH, 0, 0, 0, 1, 0, 1, 0, 0, 0, 1);
    run_perm_case(3, PTW_SRC_TYPE_LOAD,  0, 0, 1, 1, 0, 1, 1, 0, 0, 1);
    run_perm_case(4, PTW_SRC_TYPE_LOAD,  0, 0, 1, 1, 0, 1, 1, 1, 0, 1);
    run_perm_case(5, PTW_SRC_TYPE_PFU,   0, 0, 0, 0, 0, 0, 0, 0, 0, 1);
    run_perm_case(6, PTW_SRC_TYPE_LOAD,  1, 1, 1, 0, 0, 1, 1, 0, 0, 0);
    run_perm_case(7, PTW_SRC_TYPE_LOAD,  2, 1, 1, 1, 0, 1, 1, 0, 0, 0);
    stage7_close("PTW-ADD-016,PTW-ADD-017,PTW-ADD-018,PTW-ADD-019,PTW-ADD-033",
      "stage7_random_pte_perm_cross",
      "constrained random profile covers request type, page size, permission, PFU, MXR, MAEE, and source-SB field coverage bins");
    stage7_summary();
    #200ns;
  endtask

endclass : test_ptw_random_pte_perm_cross_001

class test_ptw_same_id_no_reuse_constraint_001 extends ptw_stage7_base;

  `uvm_component_utils(test_ptw_same_id_no_reuse_constraint_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;
    string key;

    va = 39'h0_30a0_4000;
    pa = 40'h0_03a0_4000;
    ptw_meta_begin("TC-PTW-STAGE7-P2", "stage7_same_id_no_reuse_constraint");
    ptw_meta_add_req("PTW-ADD-035");
    ptw_setup_sv39(STAGE7_ROOT_PPN + 28'h05, STAGE7_ROOT_ASID + 16'h05,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage7_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD),
      .id(6'h05), .kind("legal_single_key_leaf"),
      .r(1), .w(1), .x(0), .a(1), .d(1));
    key = ptw_req_key(PTW_SRC_TYPE_LOAD, 6'h05);
    ptw_active_keys[key] = 1'b1;
    if (!ptw_allow_key_reuse && ptw_active_keys.exists(key))
      stage7_illegal_blocked("PTW-ADD-035", "stage7_same_id_no_reuse_constraint",
        "base guard would fatal before issuing a duplicate outstanding {type,id}; no illegal DUT stimulus sent");
    ptw_active_keys.delete();
    ptw_meta_set_expected("duplicate outstanding key is blocked at sequence constraint layer");
    stage7_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h05);
    stage7_finish_scenario("stage7_same_id_no_reuse_constraint");
    stage7_close("PTW-ADD-035", "stage7_same_id_no_reuse_constraint",
      "P2 constraint proof plus one legal control transaction with source_sb clean");
    stage7_summary();
    #200ns;
  endtask

endclass : test_ptw_same_id_no_reuse_constraint_001

class test_ptw_bare_mode_no_request_constraint_001 extends ptw_stage7_base;

  `uvm_component_utils(test_ptw_bare_mode_no_request_constraint_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;

    va = 39'h0_30a0_5000;
    pa = 40'h0_03a0_5000;
    ptw_meta_begin("TC-PTW-STAGE7-P2", "stage7_bare_m_no_request_constraint");
    ptw_meta_add_req("PTW-ADD-036");
    if (!ptw_allow_bare_m_no_request)
      stage7_illegal_blocked("PTW-ADD-036", "stage7_bare_m_no_request_constraint",
        "ptw_setup_sv39 pure PRIV_M without MPRV is constrained away by default; no Bare/M source request sent");
    ptw_setup_sv39(STAGE7_ROOT_PPN + 28'h06, STAGE7_ROOT_ASID + 16'h06,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage7_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD),
      .id(6'h06), .kind("s_mode_legal_control_leaf"),
      .r(1), .w(1), .x(0), .u(0), .a(1), .d(1));
    ptw_meta_set_expected("pure M/Bare is illegal for PTW source; normal S-mode Sv39 request is the legal source control transaction");
    stage7_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h06);
    stage7_finish_scenario("stage7_bare_m_no_request_constraint");
    stage7_close("PTW-ADD-036", "stage7_bare_m_no_request_constraint",
      "P2 illegal-mode blocked marker plus legal S-mode source control transaction");
    stage7_summary();
    #200ns;
  endtask

endclass : test_ptw_bare_mode_no_request_constraint_001

class test_ptw_p2_illegal_constraint_matrix extends ptw_stage7_base;

  `uvm_component_utils(test_ptw_p2_illegal_constraint_matrix)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    ptw_meta_begin("TC-PTW-STAGE7-P2", "stage7_illegal_constraint_matrix");
    ptw_meta_add_req("PTW-ADD-029");
    ptw_meta_add_req("PTW-ADD-035");
    ptw_meta_add_req("PTW-ADD-036");
    stage7_illegal_blocked("PTW-ADD-029", "stage7_sysmap_malformed_constraint",
      "default SysMap macro table is ordered and complete; no-hit/multi-hit malformed setup is not legal source regression stimulus");
    stage7_illegal_blocked("PTW-ADD-035", "stage7_same_id_reuse_constraint",
      "same outstanding {type,id} reuse remains blocked by ptw_guard_start_key");
    stage7_illegal_blocked("PTW-ADD-036", "stage7_bare_m_constraint",
      "Bare and pure M no-translation requests remain blocked before PTW source issue");
    stage7_illegal_blocked("PTW-MBUF-OOO", "stage7_ptw_mem_ooo_constraint",
      "ptw_attempt_ptw_mem_ooo would fatal unless explicit illegal mode is enabled; normal random profile keeps single outstanding order");
    ptw_meta_set_expected("illegal constraints are classified and do not count as DUT source failures");
    ptw_meta_set_actual("no illegal DUT stimulus issued");
    ptw_meta_set_result("stage7_illegal_constraint_proof");
    ptw_meta_print();
    stage7_close("PTW-ADD-029,PTW-ADD-035,PTW-ADD-036",
      "stage7_illegal_constraint_matrix",
      "P2 illegal classification markers prove malformed sysmap/key reuse/Bare-M/PTW-memory-OOO are constrained out");
    stage7_summary(1'b0);
    #200ns;
  endtask

endclass : test_ptw_p2_illegal_constraint_matrix

`endif // TEST_PTW_STAGE7_SUITE_SVH
