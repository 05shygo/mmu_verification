// =============================================================================
// PTW stage-6 P0 directed source-side suite
//
// Stage 6 scope only:
//   - Provide grouped P0 directed tests that exercise the source ref/SB and
//     Stage-5 SVA cover points.
//   - Emit explicit closure/open markers for PTW-ADD-001..034 and
//     PTW-FLOW-001..023.
//   - Do not complete Stage-7 ref-model precision items here.
// =============================================================================
`ifndef TEST_PTW_STAGE6_P0_SUITE_SVH
`define TEST_PTW_STAGE6_P0_SUITE_SVH

class ptw_stage6_p0_base extends ptw_source_directed_base;

  localparam ppn_t  STAGE6_ROOT_PPN  = 28'h160;
  localparam asid_t STAGE6_ROOT_ASID = 16'h0606;

  int unsigned m_stage6_closed;
  int unsigned m_stage6_open;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 32;
    timeout_ns = 3_000_000;
    m_stage6_closed = 0;
    m_stage6_open   = 0;
  endfunction

  protected function void stage6_close(
    input string req_ids,
    input string scenario_id,
    input string evidence
  );
    m_stage6_closed++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE6_CLOSURE status=closed test=%s scenario=%s req=%s evidence={%s}",
        get_type_name(), scenario_id, req_ids, evidence),
      UVM_NONE)
  endfunction

  protected function void stage6_open(
    input string req_ids,
    input string scenario_id,
    input string reason
  );
    m_stage6_open++;
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE6_CLOSURE status=open test=%s scenario=%s req=%s owner_stage=7 reason={%s}",
        get_type_name(), scenario_id, req_ids, reason),
      UVM_NONE)
  endfunction

  protected function void stage6_flow_bind(
    input string flow_id,
    input string status,
    input string scenario_id,
    input string test_name,
    input string evidence
  );
    `uvm_info(get_type_name(),
      $sformatf("PTW_FLOW_BIND flow=%s status=%s scenario=%s test=%s evidence={%s}",
        flow_id, status, scenario_id, test_name, evidence),
      UVM_NONE)
  endfunction

  protected task stage6_pmp_raw_twu_flags(input bit [3:0] twu_flg);
    pmp_flg_raw_seq seq;
    seq = pmp_flg_raw_seq::type_id::create("stage6_pmp_raw_twu_flags_seq");
    foreach (seq.raw_flg[i])
      seq.raw_flg[i] = 4'h7;
    seq.raw_flg[3] = twu_flg;
    seq.raw_flg[5] = twu_flg;
    seq.raw_flg[6] = twu_flg;
    seq.raw_flg[7] = twu_flg;
    seq.start(m_env.m_pmp.m_sequencer);
    if ((m_env != null) && (m_env.m_ref != null))
      m_env.m_ref.sync_shadow_state();
    ptw_meta_add_context($sformatf("pmp_raw_twu_flg=0x%0h", twu_flg));
  endtask

  protected task stage6_map_leaf(
    input va_t              va,
    input int unsigned      level,
    input pa_t              pa,
    input ptw_src_req_type_e req_type,
    input int unsigned      id,
    input string            kind,
    input bit               v = 1'b1,
    input bit               r = 1'b1,
    input bit               w = 1'b1,
    input bit               x = 1'b1,
    input bit               u = 1'b0,
    input bit               g = 1'b0,
    input bit               a = 1'b1,
    input bit               d = 1'b1,
    input bit [1:0]         rsw = 2'b00,
    input bit [20:0]        high_reserved = 21'h0,
    input bit [4:0]         ext_attr = 5'h0,
    input bit               allow_misaligned = 1'b0
  );
    pte_t raw_pte;
    pa_t  pte_pa;

    if (!ptw_map_raw_leaf_pa(.va(va), .level(level), .pa(pa),
          .raw_pte(raw_pte), .pte_pa(pte_pa),
          .v(v), .r(r), .w(w), .x(x), .u(u), .g(g), .a(a), .d(d),
          .rsw(rsw), .high_reserved(high_reserved), .ext_attr(ext_attr),
          .allow_misaligned(allow_misaligned)))
      `uvm_fatal(get_type_name(), $sformatf("stage6_map_leaf failed scenario=%s", ptw_scenario_id))
    ptw_meta_add_level(req_type, id, va, level, raw_pte, pte_pa, kind);
  endtask

  protected task stage6_write_raw_level(
    input va_t              va,
    input int unsigned      level,
    input pte_t             raw_pte,
    input ptw_src_req_type_e req_type,
    input int unsigned      id,
    input string            kind,
    input bit               create_path = 1'b1
  );
    pa_t pte_pa;
    if (!ptw_write_raw_pte_level(va, level, raw_pte, pte_pa, create_path))
      `uvm_fatal(get_type_name(), $sformatf("stage6_write_raw_level failed scenario=%s level=%0d",
        ptw_scenario_id, level))
    ptw_meta_add_level(req_type, id, va, level, raw_pte, pte_pa, kind);
  endtask

  protected task stage6_drive_req(
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
        `uvm_fatal(get_type_name(), $sformatf("Unsupported stage6 request type=%0d", int'(req_type)))
    endcase
  endtask

  protected task stage6_finish_scenario(input string scenario_id);
    ptw_meta_set_actual("source_sb_expected_match_required");
    ptw_meta_set_result("stage6_directed");
    ptw_quiescent_wait(scenario_id);
    ptw_meta_print();
  endtask

  protected function void stage6_summary();
    `uvm_info(get_type_name(),
      $sformatf("PTW_STAGE6_TEST_SUMMARY test=%s closed_markers=%0d open_markers=%0d source_sb_required=1",
        get_type_name(), m_stage6_closed, m_stage6_open),
      UVM_NONE)
  endfunction

endclass : ptw_stage6_p0_base

class test_ptw_p0_pte_layout_matrix extends ptw_stage6_p0_base;

  `uvm_component_utils(test_ptw_p0_pte_layout_matrix)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected task rsw_high_reserved_4k();
    va_t va;
    pa_t pa;

    va = 39'h0_3010_1000;
    pa = 40'h0_0310_1000;
    ptw_meta_begin("TC-PTW-STAGE6-PTE", "stage6_pte_rsw_high_reserved_4k");
    ptw_meta_add_req("PTW-ADD-001");
    ptw_meta_add_req("PTW-ADD-002");
    ptw_meta_add_req("PTW-ADD-034");
    ptw_meta_add_req("PTW-FLOW-003");
    ptw_setup_sv39(STAGE6_ROOT_PPN, STAGE6_ROOT_ASID, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD),
      .id(6'h01), .kind("4k_leaf_rsw_high_reserved"),
      .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1),
      .rsw(2'b10), .high_reserved(21'h15555), .ext_attr(5'h12));
    ptw_meta_set_expected("4k refill; RSW enters flg; high reserved ignored");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h01);
    stage6_finish_scenario("stage6_pte_rsw_high_reserved_4k");
    stage6_close("PTW-ADD-001,PTW-ADD-002,PTW-ADD-034,PTW-FLOW-003",
      "stage6_pte_rsw_high_reserved_4k",
      "source_sb refill flg/global/page_size compare; PTW-SVA-CHK-009/PTW-SVA-ARB-008 cover");
  endtask

  protected task leaf_and_nonleaf_global();
    va_t  va_leaf;
    va_t  va_nonleaf_g;
    pa_t  pa;
    ppn_t l1_ppn;
    ppn_t l0_ppn;
    pte_t raw_pte;

    va_leaf = 39'h0_4000_0000;
    pa      = 40'h0_4000_0000;
    ptw_meta_begin("TC-PTW-STAGE6-PTE", "stage6_pte_leaf_global_1g");
    ptw_meta_add_req("PTW-ADD-003");
    ptw_meta_add_req("PTW-ADD-034");
    ptw_meta_add_req("PTW-FLOW-001");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h1, STAGE6_ROOT_ASID + 16'h1, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va_leaf), .level(2), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD),
      .id(6'h02), .kind("1g_leaf_global"),
      .r(1), .w(1), .x(1), .u(0), .g(1), .a(1), .d(1),
      .rsw(2'b01), .high_reserved(21'h02100), .ext_attr(5'h09));
    ptw_meta_set_expected("1g refill global comes from leaf G only");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va_leaf, 6'h02);
    stage6_finish_scenario("stage6_pte_leaf_global_1g");
    stage6_close("PTW-ADD-003,PTW-ADD-034,PTW-FLOW-001",
      "stage6_pte_leaf_global_1g",
      "source_sb refill global/tag/data compare; PTW-SVA-ARB-008 cover");

    va_nonleaf_g = 39'h0_3020_3000;
    pa           = 40'h0_0320_3000;
    ptw_meta_begin("TC-PTW-STAGE6-PTE", "stage6_pte_nonleaf_global_not_or");
    ptw_meta_add_req("PTW-ADD-003");
    ptw_meta_add_req("PTW-ADD-034");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h2, STAGE6_ROOT_ASID + 16'h2, PRIV_S, 1'b0, 1'b0, 1'b1);
    l1_ppn  = m_env.m_pt_mem.m_builder.alloc_table_ppn();
    l0_ppn  = m_env.m_pt_mem.m_builder.alloc_table_ppn();
    raw_pte = m_env.m_pt_mem.m_builder.make_legal_pointer_pte(
      .next_ppn(l1_ppn), .rsw(2'b11), .g(1), .high_reserved(21'h01000), .ext_attr(5'h1c));
    stage6_write_raw_level(.va(va_nonleaf_g), .level(2), .raw_pte(raw_pte),
      .req_type(PTW_SRC_TYPE_LOAD), .id(6'h03), .kind("fst_nonleaf_g_set"),
      .create_path(1'b0));
    raw_pte = m_env.m_pt_mem.m_builder.make_legal_pointer_pte(
      .next_ppn(l0_ppn), .rsw(2'b10), .g(1), .high_reserved(21'h00800), .ext_attr(5'h0f));
    stage6_write_raw_level(.va(va_nonleaf_g), .level(1), .raw_pte(raw_pte),
      .req_type(PTW_SRC_TYPE_LOAD), .id(6'h03), .kind("scd_nonleaf_g_set"),
      .create_path(1'b0));
    stage6_map_leaf(.va(va_nonleaf_g), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD),
      .id(6'h03), .kind("4k_leaf_global_zero"),
      .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1),
      .rsw(2'b01), .high_reserved(21'h00300), .ext_attr(5'h05));
    ptw_meta_set_expected("nonleaf G/RSW/high-reserved do not override final leaf global/data");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va_nonleaf_g, 6'h03);
    stage6_finish_scenario("stage6_pte_nonleaf_global_not_or");
    stage6_close("PTW-ADD-003,PTW-ADD-034",
      "stage6_pte_nonleaf_global_not_or",
      "source_sb final leaf global=0 and flg from leaf; nonleaf G not ORed");
  endtask

  virtual task run_test_body();
    rsw_high_reserved_4k();
    leaf_and_nonleaf_global();
    stage6_summary();
    #200ns;
  endtask

endclass : test_ptw_p0_pte_layout_matrix

class test_ptw_p0_type_pfu_fault_matrix extends ptw_stage6_p0_base;

  `uvm_component_utils(test_ptw_p0_type_pfu_fault_matrix)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected task success_one(
    input string scenario_id,
    input ptw_src_req_type_e req_type,
    input int unsigned id,
    input va_t va,
    input pa_t pa,
    input bit r,
    input bit w,
    input bit x,
    input bit d,
    input string req_ids
  );
    ptw_meta_begin("TC-PTW-STAGE6-TYPE", scenario_id);
    ptw_meta_add_req("PTW-ADD-004");
    ptw_meta_add_req("PTW-ADD-034");
    ptw_setup_sv39(STAGE6_ROOT_PPN + ppn_t'(id) + 28'h10,
      STAGE6_ROOT_ASID + asid_t'(id) + 16'h10, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(req_type), .id(id),
      .kind("4k_type_success_leaf"),
      .r(r), .w(w), .x(x), .u(0), .g(0), .a(1), .d(d),
      .rsw(2'b00), .high_reserved(21'h00012), .ext_attr(5'h04));
    ptw_meta_set_expected("success target/refill by original request type");
    stage6_drive_req(req_type, va, id);
    stage6_finish_scenario(scenario_id);
    stage6_close(req_ids, scenario_id,
      "source_sb target/refill compare; PTW-SVA-ARB-005/006/007 cover");
  endtask

  protected task page_fault_one(
    input string scenario_id,
    input ptw_src_req_type_e req_type,
    input int unsigned id,
    input va_t va,
    input string req_ids,
    input bit r,
    input bit w,
    input bit x,
    input bit a,
    input bit d
  );
    pa_t pa;

    pa = {12'h033, va[27:12], 12'h000};
    ptw_meta_begin("TC-PTW-STAGE6-TYPE", scenario_id);
    ptw_meta_add_req("PTW-ADD-005");
    ptw_setup_sv39(STAGE6_ROOT_PPN + ppn_t'(id) + 28'h20,
      STAGE6_ROOT_ASID + asid_t'(id) + 16'h20, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(req_type), .id(id),
      .kind("4k_type_page_fault_leaf"),
      .r(r), .w(w), .x(x), .u(0), .g(0), .a(a), .d(d),
      .rsw(2'b00), .high_reserved(21'h0), .ext_attr(5'h0));
    ptw_meta_set_expected("page fault target/key by original request type");
    stage6_drive_req(req_type, va, id);
    stage6_finish_scenario(scenario_id);
    stage6_close(req_ids, scenario_id,
      "source_sb page-fault class/type/id/target compare; PTW-SVA-CHK and PTW-SVA-ARB cover");
  endtask

  protected task original_type_pmp_permission();
    va_t va_fetch;
    va_t va_load;
    pa_t pa;

    va_fetch = 39'h0_3050_0000;
    va_load  = 39'h0_3050_1000;
    ptw_meta_begin("TC-PTW-STAGE6-TYPE", "stage6_pmp_original_fetch_x_deny");
    ptw_meta_add_req("PTW-ADD-014");
    ptw_meta_add_req("PTW-ADD-005");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h30, STAGE6_ROOT_ASID + 16'h30, PRIV_S, 1'b0, 1'b0, 1'b1);
    pa = 40'h0_0350_0000;
    stage6_map_leaf(.va(va_fetch), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_FETCH), .id(0),
      .kind("fetch_leaf_before_x_deny"),
      .r(1), .w(0), .x(1), .u(0), .g(0), .a(1), .d(0));
    stage6_pmp_raw_twu_flags(4'h3);
    ptw_meta_set_expected("fetch uses original execute permission and gets PMP access fault");
    stage6_drive_req(PTW_SRC_TYPE_FETCH, va_fetch, 0);
    stage6_finish_scenario("stage6_pmp_original_fetch_x_deny");
    stage6_close("PTW-ADD-014,PTW-ADD-005", "stage6_pmp_original_fetch_x_deny",
      "source_sb access-fault target compare; PTW-SVA-PMP original-type cover");

    ptw_meta_begin("TC-PTW-STAGE6-TYPE", "stage6_pmp_original_load_r_allow");
    ptw_meta_add_req("PTW-ADD-014");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h31, STAGE6_ROOT_ASID + 16'h31, PRIV_S, 1'b0, 1'b0, 1'b1);
    pa = 40'h0_0350_1000;
    stage6_map_leaf(.va(va_load), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h0d),
      .kind("load_leaf_with_x_deny_r_allow"),
      .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1));
    stage6_pmp_raw_twu_flags(4'h3);
    ptw_meta_set_expected("load uses original read permission and is not blocked by X deny");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va_load, 6'h0d);
    stage6_finish_scenario("stage6_pmp_original_load_r_allow");
    stage6_close("PTW-ADD-014", "stage6_pmp_original_load_r_allow",
      "source_sb refill target compare under PTW-port X-deny/R-allow PMP flags");
  endtask

  virtual task run_test_body();
    success_one("stage6_type_fetch_success", PTW_SRC_TYPE_FETCH, 0,
      39'h0_3030_0000, 40'h0_0330_0000, 1'b0, 1'b0, 1'b1, 1'b0,
      "PTW-ADD-004,PTW-FLOW-003");
    success_one("stage6_type_load_success", PTW_SRC_TYPE_LOAD, 6'h04,
      39'h0_3030_1000, 40'h0_0330_1000, 1'b1, 1'b1, 1'b0, 1'b1,
      "PTW-ADD-004,PTW-FLOW-003");
    success_one("stage6_type_store_success", PTW_SRC_TYPE_STORE, 6'h05,
      39'h0_3030_2000, 40'h0_0330_2000, 1'b1, 1'b1, 1'b0, 1'b1,
      "PTW-ADD-004,PTW-FLOW-003");
    success_one("stage6_type_pfu_success_l2_only", PTW_SRC_TYPE_PFU, 6'h06,
      39'h0_3030_3000, 40'h0_0330_3000, 1'b1, 1'b0, 1'b0, 1'b0,
      "PTW-ADD-004,PTW-ADD-033,PTW-FLOW-020");

    page_fault_one("stage6_fault_fetch_no_x", PTW_SRC_TYPE_FETCH, 0,
      39'h0_3040_0000, "PTW-ADD-005,PTW-ADD-018", 1'b1, 1'b0, 1'b0, 1'b1, 1'b0);
    page_fault_one("stage6_fault_load_no_r", PTW_SRC_TYPE_LOAD, 6'h07,
      39'h0_3040_1000, "PTW-ADD-005,PTW-ADD-018", 1'b0, 1'b0, 1'b1, 1'b1, 1'b0);
    page_fault_one("stage6_fault_store_no_w", PTW_SRC_TYPE_STORE, 6'h08,
      39'h0_3040_2000, "PTW-ADD-005,PTW-ADD-018", 1'b1, 1'b0, 1'b0, 1'b1, 1'b1);
    page_fault_one("stage6_fault_pfu_a_zero", PTW_SRC_TYPE_PFU, 6'h09,
      39'h0_3040_3000, "PTW-ADD-005,PTW-ADD-033,PTW-FLOW-021", 1'b1, 1'b0, 1'b0, 1'b0, 1'b0);

    original_type_pmp_permission();
    stage6_summary();
    #200ns;
  endtask

endclass : test_ptw_p0_type_pfu_fault_matrix

class test_ptw_p0_permission_matrix extends ptw_stage6_p0_base;

  `uvm_component_utils(test_ptw_p0_permission_matrix)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected task write_only_mxr();
    va_t va;
    pa_t pa;

    va = 39'h0_3060_0000;
    pa = 40'h0_0360_0000;
    ptw_meta_begin("TC-PTW-STAGE6-PERM", "stage6_write_only_mxr0_fault");
    ptw_meta_add_req("PTW-ADD-017");
    ptw_meta_add_req("PTW-ADD-018");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h40, STAGE6_ROOT_ASID + 16'h40, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h10),
      .kind("write_only_x_leaf_mxr0"), .r(0), .w(1), .x(1), .u(0), .a(1), .d(1));
    ptw_meta_set_expected("W && !(R || MXR&&X) faults when MXR=0");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h10);
    stage6_finish_scenario("stage6_write_only_mxr0_fault");
    stage6_close("PTW-ADD-017,PTW-ADD-018", "stage6_write_only_mxr0_fault",
      "source_sb page-fault compare; PTW-SVA-CHK-001 cover");

    va = 39'h0_3060_1000;
    pa = 40'h0_0360_1000;
    ptw_meta_begin("TC-PTW-STAGE6-PERM", "stage6_write_only_mxr1_success");
    ptw_meta_add_req("PTW-ADD-017");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h41, STAGE6_ROOT_ASID + 16'h41, PRIV_S, 1'b1, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h11),
      .kind("write_only_x_leaf_mxr1"), .r(0), .w(1), .x(1), .u(0), .a(1), .d(1));
    ptw_meta_set_expected("MXR=1 makes W/R=0/X=1 load legal per PTW spec");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h11);
    stage6_finish_scenario("stage6_write_only_mxr1_success");
    stage6_close("PTW-ADD-017", "stage6_write_only_mxr1_success",
      "source_sb refill compare for MXR path");
  endtask

  protected task ad_us_sum_and_huge_align();
    va_t va;
    pa_t pa;

    va = 39'h0_3060_2000;
    pa = 40'h0_0360_2000;
    ptw_meta_begin("TC-PTW-STAGE6-PERM", "stage6_store_d_zero_fault");
    ptw_meta_add_req("PTW-ADD-019");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h42, STAGE6_ROOT_ASID + 16'h42, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_STORE), .id(6'h12),
      .kind("store_d_zero_leaf"), .r(1), .w(1), .x(0), .u(0), .a(1), .d(0));
    ptw_meta_set_expected("store page fault when D=0");
    stage6_drive_req(PTW_SRC_TYPE_STORE, va, 6'h12);
    stage6_finish_scenario("stage6_store_d_zero_fault");
    stage6_close("PTW-ADD-019", "stage6_store_d_zero_fault",
      "source_sb page-fault compare for D bit");

    va = 39'h0_3060_3000;
    pa = 40'h0_0360_3000;
    ptw_meta_begin("TC-PTW-STAGE6-PERM", "stage6_supervisor_u_sum0_fault");
    ptw_meta_add_req("PTW-ADD-019");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h43, STAGE6_ROOT_ASID + 16'h43, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h13),
      .kind("supervisor_u_leaf_sum0"), .r(1), .w(1), .x(0), .u(1), .a(1), .d(1));
    ptw_meta_set_expected("S-mode SUM=0 cannot access U leaf");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h13);
    stage6_finish_scenario("stage6_supervisor_u_sum0_fault");
    stage6_close("PTW-ADD-019", "stage6_supervisor_u_sum0_fault",
      "source_sb page-fault compare for U/S/SUM");

    va = 39'h0_3060_4000;
    pa = 40'h0_0360_4000;
    ptw_meta_begin("TC-PTW-STAGE6-PERM", "stage6_user_supervisor_leaf_fault");
    ptw_meta_add_req("PTW-ADD-019");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h44, STAGE6_ROOT_ASID + 16'h44, PRIV_U, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h14),
      .kind("user_access_supervisor_leaf"), .r(1), .w(1), .x(0), .u(0), .a(1), .d(1));
    ptw_meta_set_expected("U-mode cannot access U=0 leaf");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h14);
    stage6_finish_scenario("stage6_user_supervisor_leaf_fault");
    stage6_close("PTW-ADD-019", "stage6_user_supervisor_leaf_fault",
      "source_sb page-fault compare for user effective privilege");

    va = 39'h0_8000_0000;
    pa = 40'h0_8000_1000;
    ptw_meta_begin("TC-PTW-STAGE6-PERM", "stage6_huge_1g_align_before_degrade");
    ptw_meta_add_req("PTW-ADD-020");
    ptw_meta_add_req("PTW-FLOW-012");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h45, STAGE6_ROOT_ASID + 16'h45, PRIV_S, 1'b0, 1'b0, 1'b0);
    ptw_sysmap_one_region(3'd0, pa[39:12], 28'hfffffff, 5'h1b);
    stage6_map_leaf(.va(va), .level(2), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h15),
      .kind("misaligned_1g_leaf_maee0"), .r(1), .w(1), .x(1), .u(0), .a(1), .d(1),
      .allow_misaligned(1'b1));
    ptw_meta_set_expected("1G misaligned PPN faults before sysmap/degrade");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h15);
    stage6_finish_scenario("stage6_huge_1g_align_before_degrade");
    stage6_close("PTW-ADD-020,PTW-FLOW-012", "stage6_huge_1g_align_before_degrade",
      "source_sb page-fault compare; PTW-SVA-CHK-008/PTW-SVA-MAEE-008 cover");
  endtask

  protected task thd_nonleaf_page_fault();
    va_t  va;
    ppn_t next_ppn;
    pte_t raw_pte;

    va = 39'h0_3060_5000;
    ptw_meta_begin("TC-PTW-STAGE6-PERM", "stage6_thd_nonleaf_page_fault");
    ptw_meta_add_req("PTW-ADD-016");
    ptw_meta_add_req("PTW-FLOW-014");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h46, STAGE6_ROOT_ASID + 16'h46, PRIV_S, 1'b0, 1'b0, 1'b1);
    next_ppn = m_env.m_pt_mem.m_builder.alloc_table_ppn();
    raw_pte = m_env.m_pt_mem.m_builder.make_legal_pointer_pte(
      .next_ppn(next_ppn), .rsw(2'b01), .g(0),
      .high_reserved(21'h00400), .ext_attr(5'h03));
    stage6_write_raw_level(.va(va), .level(0), .raw_pte(raw_pte),
      .req_type(PTW_SRC_TYPE_LOAD), .id(6'h16), .kind("thd_nonleaf_pointer_fault"));
    ptw_meta_set_expected("legal pointer format at thd level is a page fault");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h16);
    stage6_finish_scenario("stage6_thd_nonleaf_page_fault");
    stage6_close("PTW-ADD-016,PTW-FLOW-014", "stage6_thd_nonleaf_page_fault",
      "source_sb page-fault compare for nonleaf-at-thd; PTW-SVA-CHK-002/011 cover");
  endtask

  protected task scd_page_fault_v0();
    va_t  va;
    pte_t raw_pte;

    va = 39'h0_3060_6000;
    ptw_meta_begin("TC-PTW-STAGE6-PERM", "stage6_scd_page_fault_v0");
    ptw_meta_add_req("PTW-ADD-016");
    ptw_meta_add_req("PTW-FLOW-013");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h47, STAGE6_ROOT_ASID + 16'h47, PRIV_S, 1'b0, 1'b0, 1'b1);
    raw_pte = m_env.m_pt_mem.m_builder.make_raw_pte(
      .ppn(28'h0360_060), .v(0), .r(0), .w(0), .x(0), .u(0),
      .g(0), .a(0), .d(0), .rsw(2'b10),
      .high_reserved(21'h00100), .ext_attr(5'h02));
    stage6_write_raw_level(.va(va), .level(1), .raw_pte(raw_pte),
      .req_type(PTW_SRC_TYPE_LOAD), .id(6'h17), .kind("scd_v0_page_fault"));
    ptw_meta_set_expected("second-level invalid PTE terminates as page fault before thd walk");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h17);
    stage6_finish_scenario("stage6_scd_page_fault_v0");
    stage6_close("PTW-ADD-016,PTW-FLOW-013", "stage6_scd_page_fault_v0",
      "source_sb page-fault compare for scd CHK fault; PTW-SVA-CHK-011 cover");
  endtask

  virtual task run_test_body();
    write_only_mxr();
    ad_us_sum_and_huge_align();
    scd_page_fault_v0();
    thd_nonleaf_page_fault();
    stage6_open("PTW-ADD-016", "stage6_nonleaf_malformed_full_matrix",
      "fst/scd malformed nonleaf variants are represented by CHK SVA and remain Stage-7 precision expansion");
    stage6_summary();
    #200ns;
  endtask

endclass : test_ptw_p0_permission_matrix

class test_ptw_p0_pde_mbuf_pmp_matrix extends ptw_stage6_p0_base;

  `uvm_component_utils(test_ptw_p0_pde_mbuf_pmp_matrix)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected task pde_hit_paths();
    va_t va0;
    va_t va1;
    pa_t pa0;
    pa_t pa1;

    va0 = 39'h0_1800_0000;
    va1 = 39'h0_1820_0000;
    pa0 = 40'h0_0180_0000;
    pa1 = 40'h0_0182_0000;
    ptw_meta_begin("TC-PTW-STAGE6-PDE", "stage6_pde_l1_hit_final_2m");
    ptw_meta_add_req("PTW-ADD-007");
    ptw_meta_add_req("PTW-ADD-009");
    ptw_meta_add_req("PTW-FLOW-015");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h50, STAGE6_ROOT_ASID + 16'h50, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va0), .level(1), .pa(pa0), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h20),
      .kind("2m_leaf_seed_l1_pde"), .r(1), .w(1), .x(0), .a(1), .d(1));
    stage6_map_leaf(.va(va1), .level(1), .pa(pa1), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h21),
      .kind("2m_leaf_after_l1_pde_hit"), .r(1), .w(1), .x(0), .a(1), .d(1));
    ptw_meta_set_expected("first walk updates fst nonleaf PDE; second same-vpn2 walk can hit L1 PDE");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va0, 6'h20);
    ptw_quiescent_wait("stage6_pde_l1_hit_seed");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va1, 6'h21);
    stage6_finish_scenario("stage6_pde_l1_hit_final_2m");
    stage6_close("PTW-ADD-007,PTW-ADD-009,PTW-FLOW-015", "stage6_pde_l1_hit_final_2m",
      "source_sb refill match and PDE SVA hit/update cover");

    va0 = 39'h0_1900_1000;
    va1 = 39'h0_1900_2000;
    pa0 = 40'h0_0190_1000;
    pa1 = 40'h0_0190_2000;
    ptw_meta_begin("TC-PTW-STAGE6-PDE", "stage6_pde_l2_hit_final_4k");
    ptw_meta_add_req("PTW-ADD-007");
    ptw_meta_add_req("PTW-ADD-009");
    ptw_meta_add_req("PTW-FLOW-016");
    ptw_meta_add_req("PTW-FLOW-017");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h51, STAGE6_ROOT_ASID + 16'h51, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va0), .level(0), .pa(pa0), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h22),
      .kind("4k_leaf_seed_l2_pde"), .r(1), .w(1), .x(0), .a(1), .d(1));
    stage6_map_leaf(.va(va1), .level(0), .pa(pa1), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h23),
      .kind("4k_leaf_after_l2_pde_hit"), .r(1), .w(1), .x(0), .a(1), .d(1));
    ptw_meta_set_expected("first 4K walk updates fst/scd PDE; second same-vpn2/vpn1 walk can hit L2 PDE");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va0, 6'h22);
    ptw_quiescent_wait("stage6_pde_l2_hit_seed");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va1, 6'h23);
    stage6_finish_scenario("stage6_pde_l2_hit_final_4k");
    stage6_close("PTW-ADD-007,PTW-ADD-009,PTW-FLOW-016,PTW-FLOW-017",
      "stage6_pde_l2_hit_final_4k",
      "source_sb refill match and PDE SVA hit/update cover");
  endtask

  protected task pmp_mbuf_buserr();
    va_t va;
    pa_t pa;
    pte_t raw_pte;
    pa_t  pte_pa;

    va = 39'h0_3070_0000;
    pa = 40'h0_0370_0000;
    ptw_meta_begin("TC-PTW-STAGE6-MBUF", "stage6_pmp_fst_deny_access_fault");
    ptw_meta_add_req("PTW-ADD-013");
    ptw_meta_add_req("PTW-FLOW-009");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h52, STAGE6_ROOT_ASID + 16'h52, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h24),
      .kind("4k_leaf_before_pmp_deny"), .r(1), .w(1), .x(0), .a(1), .d(1));
    ptw_pmp_deny_ptw_reads(4'b1111);
    ptw_meta_set_expected("PTW PTE PA PMP deny terminates as access fault without refill");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h24);
    stage6_finish_scenario("stage6_pmp_fst_deny_access_fault");
    stage6_close("PTW-ADD-013,PTW-FLOW-009", "stage6_pmp_fst_deny_access_fault",
      "source_sb access-fault compare; PTW-SVA-PMP deny/no-side-effect cover");
    ptw_pmp_allow_all();

    va = 39'h0_3070_1000;
    pa = 40'h0_0370_1000;
    ptw_meta_begin("TC-PTW-STAGE6-MBUF", "stage6_mbuf_chk_not_ready_hold");
    ptw_meta_add_req("PTW-ADD-021");
    ptw_meta_add_req("PTW-ADD-022");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h53, STAGE6_ROOT_ASID + 16'h53, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h25),
      .kind("4k_leaf_chk_slow"), .r(1), .w(1), .x(0), .a(1), .d(1));
    ptw_mem_chk_not_ready_slow(48);
    ptw_meta_set_expected("CHK not-ready/slow path holds data until normal refill");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h25);
    stage6_finish_scenario("stage6_mbuf_chk_not_ready_hold");
    stage6_close("PTW-ADD-021,PTW-ADD-022", "stage6_mbuf_chk_not_ready_hold",
      "source_sb refill compare; PTW-SVA-MBUF/WAIT hold cover");

    va = 39'h0_3070_2000;
    pa = 40'h0_0370_2000;
    ptw_meta_begin("TC-PTW-STAGE6-MBUF", "stage6_lsu_bus_error_priority_access_fault");
    ptw_meta_add_req("PTW-ADD-006");
    ptw_meta_add_req("PTW-ADD-023");
    ptw_meta_add_req("PTW-FLOW-018");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h54, STAGE6_ROOT_ASID + 16'h54, PRIV_S, 1'b0, 1'b0, 1'b1);
    if (!ptw_map_raw_leaf_pa(.va(va), .level(0), .pa(pa),
          .raw_pte(raw_pte), .pte_pa(pte_pa),
          .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage6 bus-error map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 6'h26, va, 0, raw_pte, pte_pa, "4k_leaf_before_bus_error");
    ptw_mem_bus_error_by_count(1);
    ptw_mem_delay_by_count(1, 0);
    ptw_meta_set_expected("LSU data_vld+bus_error gives visible access fault; no refill/PDE update");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h26);
    stage6_finish_scenario("stage6_lsu_bus_error_priority_access_fault");
    stage6_close("PTW-ADD-006,PTW-ADD-023,PTW-FLOW-018",
      "stage6_lsu_bus_error_priority_access_fault",
      "source_sb bus-error root cause matches visible access fault; PTW-SVA-MBUF-008/009 cover");
  endtask

  protected task mprv_mpp_effective_m();
    va_t va;
    pa_t pa;

    va = 39'h0_3070_3000;
    pa = 40'h0_0370_3000;
    ptw_meta_begin("TC-PTW-STAGE6-MPRV", "stage6_mprv_mpp_m_load_success");
    ptw_meta_add_req("PTW-ADD-015");
    ptw_meta_add_req("PTW-FLOW-023");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h55, STAGE6_ROOT_ASID + 16'h55, PRIV_S, 1'b0, 1'b0, 1'b1, 1'b1, PRIV_M);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h27),
      .kind("mprv_mpp_m_load_leaf"), .r(1), .w(1), .x(0), .u(0), .a(1), .d(1));
    ptw_meta_set_expected("load with MPRV=1 MPP=M uses machine effective privilege");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h27);
    stage6_finish_scenario("stage6_mprv_mpp_m_load_success");
    stage6_close("PTW-ADD-015,PTW-FLOW-023", "stage6_mprv_mpp_m_load_success",
      "source_sb context/refill compare; PTW-SVA-PMP effective-mode cover");

    va = 39'h0_3070_4000;
    pa = 40'h0_0370_4000;
    ptw_meta_begin("TC-PTW-STAGE6-MPRV", "stage6_mprv_mpp_m_pfu_success");
    ptw_meta_add_req("PTW-ADD-015");
    ptw_meta_add_req("PTW-ADD-033");
    ptw_meta_add_req("PTW-FLOW-023");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h56, STAGE6_ROOT_ASID + 16'h56, PRIV_S, 1'b0, 1'b0, 1'b1, 1'b1, PRIV_M);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_PFU), .id(6'h28),
      .kind("mprv_mpp_m_pfu_leaf"), .r(1), .w(0), .x(0), .u(0), .a(1), .d(0));
    ptw_meta_set_expected("PFU with MPRV=1 MPP=M uses machine effective privilege and L2/PFU target");
    stage6_drive_req(PTW_SRC_TYPE_PFU, va, 6'h28);
    stage6_finish_scenario("stage6_mprv_mpp_m_pfu_success");
    stage6_close("PTW-ADD-015,PTW-ADD-033,PTW-FLOW-023",
      "stage6_mprv_mpp_m_pfu_success",
      "source_sb PFU target/context compare under MPRV MPP=M");
  endtask

  virtual task run_test_body();
    pde_hit_paths();
    pmp_mbuf_buserr();
    mprv_mpp_effective_m();
    stage6_open("PTW-ADD-007", "stage6_pde_double_hit_l2_wins",
      "raw double-hit injection needs Stage-7 PDE whitebox/vector support; Stage-5 SVA exists");
    stage6_open("PTW-ADD-008", "stage6_pde_lookup_update_same_cycle_race",
      "plan assigns lookup/update old-state race source-model precision to Stage 7");
    stage6_open("PTW-ADD-010,PTW-FLOW-022", "stage6_pde_satp_pmp_clear_only_reupdate",
      "pmp_regs_update is still a recorded probe/TB gap; old-walk re-update precision is Stage 7");
    stage6_open("PTW-ADD-011,PTW-ADD-024,PTW-FLOW-019", "stage6_abort_full_matrix",
      "pre-existing exception grant and same-cycle abort bus-error/drop classification require Stage-7 ref/SB precision");
    stage6_summary();
    #200ns;
  endtask

endclass : test_ptw_p0_pde_mbuf_pmp_matrix

class test_ptw_p0_maee_sysmap_matrix extends ptw_stage6_p0_base;

  `uvm_component_utils(test_ptw_p0_maee_sysmap_matrix)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected task maee1_all_sizes();
    va_t va;
    pa_t pa;

    va = 39'h0_0000_0000;
    pa = 40'h0_0000_0000;
    ptw_meta_begin("TC-PTW-STAGE6-MAEE", "stage6_maee1_1g_ext_attr");
    ptw_meta_add_req("PTW-ADD-025");
    ptw_meta_add_req("PTW-FLOW-001");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h60, STAGE6_ROOT_ASID + 16'h60, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(2), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h30),
      .kind("maee1_1g_leaf_ext_attr"), .r(1), .w(1), .x(1), .a(1), .d(1),
      .rsw(2'b01), .ext_attr(5'h1a));
    ptw_meta_set_expected("MAEE=1 1G uses raw PTE ext_attr");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h30);
    stage6_finish_scenario("stage6_maee1_1g_ext_attr");
    stage6_close("PTW-ADD-025,PTW-FLOW-001", "stage6_maee1_1g_ext_attr",
      "source_sb refill flg compare; PTW-SVA-MAEE-001 cover");

    va = 39'h0_2200_0000;
    pa = 40'h0_0220_0000;
    ptw_meta_begin("TC-PTW-STAGE6-MAEE", "stage6_maee1_2m_ext_attr");
    ptw_meta_add_req("PTW-ADD-025");
    ptw_meta_add_req("PTW-FLOW-002");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h61, STAGE6_ROOT_ASID + 16'h61, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(1), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h31),
      .kind("maee1_2m_leaf_ext_attr"), .r(1), .w(1), .x(0), .a(1), .d(1),
      .rsw(2'b10), .ext_attr(5'h0d));
    ptw_meta_set_expected("MAEE=1 2M uses raw PTE ext_attr");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h31);
    stage6_finish_scenario("stage6_maee1_2m_ext_attr");
    stage6_close("PTW-ADD-025,PTW-FLOW-002", "stage6_maee1_2m_ext_attr",
      "source_sb refill flg compare; PTW-SVA-MAEE-001 cover");

    va = 39'h0_3080_0000;
    pa = 40'h0_0380_0000;
    ptw_meta_begin("TC-PTW-STAGE6-MAEE", "stage6_maee1_4k_ext_attr");
    ptw_meta_add_req("PTW-ADD-025");
    ptw_meta_add_req("PTW-FLOW-003");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h62, STAGE6_ROOT_ASID + 16'h62, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h32),
      .kind("maee1_4k_leaf_ext_attr"), .r(1), .w(1), .x(0), .a(1), .d(1),
      .rsw(2'b11), .ext_attr(5'h13));
    ptw_meta_set_expected("MAEE=1 4K uses raw PTE ext_attr");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h32);
    stage6_finish_scenario("stage6_maee1_4k_ext_attr");
    stage6_close("PTW-ADD-025,PTW-FLOW-003", "stage6_maee1_4k_ext_attr",
      "source_sb refill flg compare; PTW-SVA-MAEE-001 cover");
  endtask

  protected task maee0_4k_sysmap();
    va_t va;
    pa_t pa;

    va = 39'h0_3080_1000;
    pa = 40'h0_0380_1000;
    ptw_meta_begin("TC-PTW-STAGE6-MAEE", "stage6_maee0_4k_sysmap_refill");
    ptw_meta_add_req("PTW-ADD-026");
    ptw_meta_add_req("PTW-ADD-029");
    ptw_meta_add_req("PTW-FLOW-008");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h63, STAGE6_ROOT_ASID + 16'h63, PRIV_S, 1'b0, 1'b0, 1'b0);
    ptw_sysmap_one_region(3'd2, pa[39:12], 28'hfffffff, 5'h17);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h33),
      .kind("maee0_4k_sysmap_leaf"), .r(1), .w(1), .x(0), .a(1), .d(1),
      .rsw(2'b01), .ext_attr(5'h00));
    ptw_meta_set_expected("MAEE=0 4K refill attr comes from SysMap flg, not PTE ext_attr");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h33);
    stage6_finish_scenario("stage6_maee0_4k_sysmap_refill");
    stage6_close("PTW-ADD-026,PTW-ADD-029,PTW-FLOW-008",
      "stage6_maee0_4k_sysmap_refill",
      "source_sb sysmap flg compare; PTW-SVA-MAEE-002/004 cover");
  endtask

  virtual task run_test_body();
    maee1_all_sizes();
    maee0_4k_sysmap();
    stage6_open("PTW-ADD-027,PTW-ADD-028,PTW-FLOW-004,PTW-FLOW-005,PTW-FLOW-006,PTW-FLOW-007",
      "stage6_maee0_huge_degrade_matrix",
      "current Stage-4 ref model supports MAEE=0 4K sysmap but not 1G/2M degrade final page_size/PPN/no-lower-walk");
    stage6_open("PTW-ADD-029", "stage6_sysmap_default_malformed_constraints",
      "normal P0 tests cover flag order on 4K; malformed/no-hit/multi-hit constraints are Stage 7/8 signoff items");
    stage6_summary();
    #200ns;
  endtask

endclass : test_ptw_p0_maee_sysmap_matrix

class test_ptw_p0_flow_trace_umbrella extends ptw_stage6_p0_base;

  `uvm_component_utils(test_ptw_p0_flow_trace_umbrella)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected task flow_umbrella_smoke();
    va_t va;
    pa_t pa;

    va = 39'h0_3090_0000;
    pa = 40'h0_0390_0000;
    ptw_meta_begin("TC-PTW-STAGE6-FLOW", "stage6_flow_umbrella_smoke");
    ptw_meta_add_req("PTW-ADD-031");
    ptw_setup_sv39(STAGE6_ROOT_PPN + 28'h70, STAGE6_ROOT_ASID + 16'h70, PRIV_S, 1'b0, 1'b0, 1'b1);
    stage6_map_leaf(.va(va), .level(0), .pa(pa), .req_type(PTW_SRC_TYPE_LOAD), .id(6'h34),
      .kind("flow_umbrella_4k_leaf"), .r(1), .w(1), .x(0), .u(0), .a(1), .d(1));
    ptw_meta_set_expected("umbrella test produces one source-SB transaction and SVA cover sample");
    stage6_drive_req(PTW_SRC_TYPE_LOAD, va, 6'h34);
    stage6_finish_scenario("stage6_flow_umbrella_smoke");
    stage6_close("PTW-ADD-031", "stage6_flow_umbrella_smoke",
      "source_sb refill match and PTW_SVA_COVER hit anchor for umbrella log");
  endtask

  virtual task run_test_body();
    flow_umbrella_smoke();

    stage6_flow_bind("PTW-FLOW-001", "closed", "stage6_pte_leaf_global_1g/stage6_maee1_1g_ext_attr",
      "test_ptw_p0_pte_layout_matrix,test_ptw_p0_maee_sysmap_matrix",
      "1G refill source_sb match + CHK/PMP/ARB/MAEE cover");
    stage6_flow_bind("PTW-FLOW-002", "closed", "stage6_maee1_2m_ext_attr",
      "test_ptw_p0_maee_sysmap_matrix", "2M refill source_sb match + PDE/CHK/ARB cover");
    stage6_flow_bind("PTW-FLOW-003", "closed", "stage6_pte_rsw_high_reserved_4k/stage6_type_*",
      "test_ptw_p0_pte_layout_matrix,test_ptw_p0_type_pfu_fault_matrix",
      "4K refill source_sb match + CHK/ARB cover");
    stage6_flow_bind("PTW-FLOW-004", "open-stage7-model-gap", "stage6_maee0_huge_degrade_matrix",
      "test_ptw_p0_maee_sysmap_matrix", "MAEE=0 1G->2M degrade final page_size/PPN model not in Stage 4");
    stage6_flow_bind("PTW-FLOW-005", "open-stage7-model-gap", "stage6_maee0_huge_degrade_matrix",
      "test_ptw_p0_maee_sysmap_matrix", "MAEE=0 1G->4K degrade no-lower-walk model not in Stage 4");
    stage6_flow_bind("PTW-FLOW-006", "open-stage7-model-gap", "stage6_maee0_huge_degrade_matrix",
      "test_ptw_p0_maee_sysmap_matrix", "MAEE=0 2M->4K degrade no-thd-walk model not in Stage 4");
    stage6_flow_bind("PTW-FLOW-007", "open-stage7-model-gap", "stage6_maee0_huge_degrade_matrix",
      "test_ptw_p0_maee_sysmap_matrix", "MAEE=0 huge no-cross needs Stage-7 source model precision");
    stage6_flow_bind("PTW-FLOW-008", "closed", "stage6_maee0_4k_sysmap_refill",
      "test_ptw_p0_maee_sysmap_matrix", "4K sysmap source_sb flg match + MAEE/SysMap cover");
    stage6_flow_bind("PTW-FLOW-009", "closed", "stage6_pmp_fst_deny_access_fault",
      "test_ptw_p0_pde_mbuf_pmp_matrix", "fst PTE PA PMP deny source_sb access fault match");
    stage6_flow_bind("PTW-FLOW-010", "open-stage7-vector-gap", "stage6_pmp_scd_deny_access_fault",
      "test_ptw_p0_pde_mbuf_pmp_matrix", "current helper denies all TWU ports before scd-specific PTE PA can be isolated");
    stage6_flow_bind("PTW-FLOW-011", "open-stage7-vector-gap", "stage6_pmp_thd_deny_access_fault",
      "test_ptw_p0_pde_mbuf_pmp_matrix", "current helper denies all TWU ports before thd-specific PTE PA can be isolated");
    stage6_flow_bind("PTW-FLOW-012", "closed", "stage6_huge_1g_align_before_degrade",
      "test_ptw_p0_permission_matrix", "fst CHK page fault source_sb match; huge align first evidence");
    stage6_flow_bind("PTW-FLOW-013", "closed", "stage6_scd_page_fault_v0",
      "test_ptw_p0_permission_matrix", "scd page-fault source_sb match");
    stage6_flow_bind("PTW-FLOW-014", "closed", "stage6_thd_nonleaf_page_fault/stage6_fault_pfu_a_zero",
      "test_ptw_p0_permission_matrix,test_ptw_p0_type_pfu_fault_matrix", "thd page-fault/PFU source_sb match");
    stage6_flow_bind("PTW-FLOW-015", "closed", "stage6_pde_l1_hit_final_2m",
      "test_ptw_p0_pde_mbuf_pmp_matrix", "L1 PDE hit final 2M source_sb match + PDE cover");
    stage6_flow_bind("PTW-FLOW-016", "closed", "stage6_pde_l2_hit_final_4k",
      "test_ptw_p0_pde_mbuf_pmp_matrix", "fst PDE hit into 4K source_sb match + PDE cover");
    stage6_flow_bind("PTW-FLOW-017", "closed", "stage6_pde_l2_hit_final_4k",
      "test_ptw_p0_pde_mbuf_pmp_matrix", "L2 PDE hit final 4K source_sb match + PDE cover");
    stage6_flow_bind("PTW-FLOW-018", "closed", "stage6_lsu_bus_error_priority_access_fault",
      "test_ptw_p0_pde_mbuf_pmp_matrix", "LSU data_vld+bus_error access-fault source_sb match + MBUF cover");
    stage6_flow_bind("PTW-FLOW-019", "open-stage7-model-gap", "stage6_abort_full_matrix",
      "test_ptw_p0_pde_mbuf_pmp_matrix", "late data, abort bus-error, and pre-existing exception grant require Stage-7 ref/SB precision");
    stage6_flow_bind("PTW-FLOW-020", "closed", "stage6_type_pfu_success_l2_only",
      "test_ptw_p0_type_pfu_fault_matrix", "PFU success L2/PFU target source_sb match + ARB cover");
    stage6_flow_bind("PTW-FLOW-021", "closed", "stage6_fault_pfu_a_zero",
      "test_ptw_p0_type_pfu_fault_matrix", "PFU exception target source_sb match + CHK/ARB cover");
    stage6_flow_bind("PTW-FLOW-022", "open-stage7-tb-gap", "stage6_pde_satp_pmp_clear_only_reupdate",
      "test_ptw_p0_pde_mbuf_pmp_matrix", "pmp_regs_update and clear-only old-walk re-update remain Stage-7/TB gap");
    stage6_flow_bind("PTW-FLOW-023", "closed", "stage6_mprv_mpp_m_load_success/stage6_mprv_mpp_m_pfu_success",
      "test_ptw_p0_pde_mbuf_pmp_matrix", "data/PFU MPRV=1 MPP=M source_sb context/refill match");

    stage6_close("PTW-ADD-031,PTW-FLOW-001..023", "stage6_flow_trace_umbrella",
      "all flows have directed binding plus closed/open reason markers; source-SB evidence comes from grouped P0 tests");
    stage6_open("PTW-ADD-030", "stage6_context_sampling_points",
      "same-cycle ASID/MXR/SUM/MAEE usage-point sampling is assigned to Stage 7");
    stage6_open("PTW-ADD-032", "stage6_l1dtlb_consumer_trace",
      "L1DTLB evidence is consumer-only and must not replace source-side closure");
    stage6_summary();
    #200ns;
  endtask

endclass : test_ptw_p0_flow_trace_umbrella

`endif // TEST_PTW_STAGE6_P0_SUITE_SVH
