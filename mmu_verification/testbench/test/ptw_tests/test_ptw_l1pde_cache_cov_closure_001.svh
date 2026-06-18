// =============================================================================
// L1PDE_cache focused code-coverage closure
// =============================================================================
`ifndef TEST_PTW_L1PDE_CACHE_COV_CLOSURE_001_SVH
`define TEST_PTW_L1PDE_CACHE_COV_CLOSURE_001_SVH

class test_ptw_l1pde_cache_cov_closure_001 extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_l1pde_cache_cov_closure_001)

  localparam int unsigned L1_COV_ENTRY_NUM = 8;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 128;
    timeout_ns = 8_000_000;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg))
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");

    // This is a code-coverage closure test.  Some L1PDE tag/toggle stimulus
    // intentionally drives VPN2[8]=1 through source paths to reach the full
    // cache tag width; keep source-side PTW checkers on, but do not use the
    // generic architectural translation scoreboard for those requests.
    m_cfg.en_translation_sb = 1'b0;
    uvm_config_db #(mmu_top_cfg)::set(this, "", "m_cfg", m_cfg);
    uvm_config_db #(mmu_top_cfg)::set(this, "*", "m_cfg", m_cfg);
    super.build_phase(phase);
  endfunction

  protected function va_t l1cov_make_va(
    input logic [8:0] vpn2,
    input logic [8:0] vpn1,
    input logic [8:0] vpn0
  );
    return va_t'({vpn2, vpn1, vpn0, 12'h000});
  endfunction

  protected function pa_t l1cov_make_pa(input ppn_t ppn);
    return pa_t'({ppn, 12'h000});
  endfunction

  protected function logic [8:0] l1cov_tag(input int unsigned idx);
    case (idx)
      0: l1cov_tag = 9'h001;
      1: l1cov_tag = 9'h03f;
      2: l1cov_tag = 9'h055;
      3: l1cov_tag = 9'h0aa;
      4: l1cov_tag = 9'h100;
      5: l1cov_tag = 9'h155;
      6: l1cov_tag = 9'h1aa;
      default: l1cov_tag = 9'h1ff;
    endcase
  endfunction

  protected function logic [8:0] l1cov_inverted_tag(input int unsigned idx);
    l1cov_inverted_tag = ~l1cov_tag(idx);
  endfunction

  protected task l1cov_wait_l1_update(
    input string ctx,
    output bit [15:0] update_vec,
    input bit require_entry_update = 1'b1,
    input int unsigned max_cycles = 8192
  );
    bit seen;

    update_vec = '0;
    seen = 1'b0;
    if (ptw_probe_vif == null)
      `uvm_fatal(get_type_name(), {ctx, ": MMU_DUT_PROBES_VIF unavailable"})

    repeat (max_cycles) begin
      @(ptw_probe_vif.mon_cb);
      if ((ptw_probe_vif.mon_cb.pde_cache_update === 1'b1)
          && (ptw_probe_vif.mon_cb.pde_cache_update_level == 2'b10)) begin
        update_vec = ptw_probe_vif.mon_cb.pde_l1_update_vec;
        if (!require_entry_update || (|update_vec[7:0])) begin
          seen = 1'b1;
          break;
        end
      end
    end

    if (!seen)
      `uvm_error(get_type_name(),
        $sformatf("%s: no L1 mbuf update observed require_entry_update=%0b max_cycles=%0d",
          ctx, require_entry_update, max_cycles))
    else
      ptw_meta_add_context($sformatf("%s observed_l1_update_vec=0x%04h", ctx, update_vec));
  endtask

  protected task l1cov_wait_l1_hit(
    input string ctx,
    input int unsigned max_cycles = 4096
  );
    bit seen;

    seen = 1'b0;
    if (ptw_probe_vif == null)
      `uvm_fatal(get_type_name(), {ctx, ": MMU_DUT_PROBES_VIF unavailable"})

    repeat (max_cycles) begin
      @(ptw_probe_vif.mon_cb);
      if ((ptw_probe_vif.mon_cb.pde_cache_req === 1'b1)
          && (ptw_probe_vif.mon_cb.pde_l1_hit_vld === 1'b1)) begin
        seen = 1'b1;
        break;
      end
    end

    if (!seen)
      `uvm_error(get_type_name(),
        $sformatf("%s: no L1 PDE hit observed max_cycles=%0d", ctx, max_cycles))
    else
      ptw_meta_add_context({ctx, " observed_l1_hit=1"});
  endtask

  protected task l1cov_map_2m_with_l1_ppn(
    input string             ctx,
    input ptw_src_req_type_e req_type,
    input int unsigned       id,
    input va_t               va,
    input pa_t               leaf_pa,
    input ppn_t              l1_table_ppn,
    output pte_t             fst_nonleaf,
    output pte_t             scd_leaf,
    output pa_t              fst_pte_pa
  );
    pa_t scd_pte_pa;

    fst_nonleaf = m_env.m_pt_mem.m_builder.make_legal_pointer_pte(l1_table_ppn);
    if (!ptw_write_raw_pte_level(va, 2, fst_nonleaf, fst_pte_pa, 1'b1))
      `uvm_fatal(get_type_name(),
        $sformatf("%s: write controlled FST nonleaf failed va=0x%010h", ctx, va))
    if (!ptw_map_raw_leaf_pa(.va(va), .level(1), .pa(leaf_pa),
          .raw_pte(scd_leaf), .pte_pa(scd_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(),
        $sformatf("%s: write SCD 2M leaf failed va=0x%010h", ctx, va))

    ptw_meta_add_level(req_type, id, va, 2, fst_nonleaf, fst_pte_pa,
      {ctx, "_controlled_fst_nonleaf"});
    ptw_meta_add_level(req_type, id, va, 1, scd_leaf, scd_pte_pa,
      {ctx, "_2m_leaf"});
  endtask

  protected task l1cov_prime_l1_capture(
    input string             ctx,
    input ptw_src_req_type_e req_type,
    input va_t               va,
    input pte_t              fst_nonleaf,
    input logic [3:0]        l1pmpflg,
    input int unsigned       id,
    output bit [15:0]        update_vec
  );
    fork
      l1cov_wait_l1_update(ctx, update_vec, 1'b1);
      ptw_prime_l1_pde_cache_with_type(req_type, va, fst_nonleaf, l1pmpflg, id);
    join
  endtask

  protected task l1cov_drive_hit_and_finish(
    input string             ctx,
    input ptw_src_req_type_e req_type,
    input va_t               va,
    input int unsigned       id
  );
    fork
      l1cov_wait_l1_hit(ctx);
      stage8_drive_and_finish(ctx, req_type, va, id);
    join
  endtask

  protected task l1cov_force_reset_pulse(input string ctx);
    string pde_reset_path;

    pde_reset_path = "$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.cpurst_b";
    if (!uvm_hdl_check_path(pde_reset_path))
      `uvm_fatal(get_type_name(), {ctx, ": PDE_cache cpurst_b path unavailable"})

    if (!uvm_hdl_force(pde_reset_path, 1'b0))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force PDE_cache cpurst_b low"})
    stage8_wait_cycles(4);

    if (!uvm_hdl_release(pde_reset_path))
      `uvm_fatal(get_type_name(), {ctx, ": failed to release PDE_cache cpurst_b"})
    stage8_wait_cycles(24);

    if (ptw_probe_vif == null)
      `uvm_fatal(get_type_name(), {ctx, ": MMU_DUT_PROBES_VIF unavailable"})
    if (ptw_probe_vif.mon_cb.pde_l1_valid_vec[7:0] !== 8'h00)
      `uvm_error(get_type_name(),
        $sformatf("%s: L1PDE valid vec not cleared after reset, vec=0x%02h",
          ctx, ptw_probe_vif.mon_cb.pde_l1_valid_vec[7:0]))
    else
      ptw_meta_add_context({ctx, " forced_pde_cache_cpurst_b_low_with_valid_l1_entries=1 cleared=1"});
  endtask

  protected task l1cov_toggle_static_inputs();
    cp0_icg_disable_seq icg_off;
    cp0_icg_enable_seq  icg_on;

    ptw_set_priv(PRIV_U);
    stage8_wait_cycles(4);
    ptw_set_priv(PRIV_S);
    stage8_wait_cycles(4);
    ptw_meta_add_context("toggle_priv_mode_bit0_U_to_S");

    icg_off = cp0_icg_disable_seq::type_id::create("l1cov_icg_off");
    icg_on  = cp0_icg_enable_seq::type_id::create("l1cov_icg_on");
    icg_off.start(m_env.m_cp0.m_sequencer);
    stage8_wait_cycles(4);
    icg_on.start(m_env.m_cp0.m_sequencer);
    stage8_wait_cycles(4);
    ptw_meta_add_context("toggle_cp0_mmu_icg_en");

    if ((m_env == null) || (m_env.m_misc == null) || (m_env.m_misc.vif == null))
      `uvm_fatal(get_type_name(), "l1cov_toggle_static_inputs: misc vif unavailable")
    @(m_env.m_misc.vif.driver_cb);
    m_env.m_misc.vif.driver_cb.pad_yy_icg_scan_en <= 1'b1;
    repeat (2) @(m_env.m_misc.vif.driver_cb);
    m_env.m_misc.vif.driver_cb.pad_yy_icg_scan_en <= 1'b0;
    repeat (2) @(m_env.m_misc.vif.driver_cb);
    ptw_meta_add_context("toggle_pad_yy_icg_scan_en");
  endtask

  protected task l1cov_fill_all_entries_and_reset();
    va_t         va;
    va_t         reuse_va;
    pa_t         leaf_pa;
    pte_t        fst_nonleaf;
    pte_t        scd_leaf;
    pa_t         fst_pte_pa;
    bit [15:0]   update_vec;
    bit [7:0]    seen_update_vec;
    logic [3:0]  all_allow_lock_pmpflg;
    int unsigned req_id;

    seen_update_vec = '0;
    all_allow_lock_pmpflg = ptw_make_pmpflg(.r(1), .w(1), .x(1), .lock(1));

    ptw_meta_begin("TC-PTW-L1PDE-COV", "l1pde_fill_all_entries_toggle_reset");
    ptw_meta_add_req("PTW-COV-L1PDE-001");
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h80, STAGE8_ROOT_ASID + 16'h80,
      PRIV_S, 1'b0, 1'b0, 1'b1);

    for (int unsigned i = 0; i < L1_COV_ENTRY_NUM; i++) begin
      va = l1cov_make_va(l1cov_tag(i), 9'(i), 9'h000);
      leaf_pa = l1cov_make_pa(28'h020_0000 + ppn_t'(i << 9));
      req_id = (i == 0) ? 0 : i;
      l1cov_map_2m_with_l1_ppn(
        .ctx($sformatf("l1pde_fill_slot_%0d", i)),
        .req_type(PTW_SRC_TYPE_FETCH),
        .id(req_id),
        .va(va),
        .leaf_pa(leaf_pa),
        .l1_table_ppn(28'hFFF_FFFF),
        .fst_nonleaf(fst_nonleaf),
        .scd_leaf(scd_leaf),
        .fst_pte_pa(fst_pte_pa));
      l1cov_prime_l1_capture(
        .ctx($sformatf("l1pde_fill_slot_%0d", i)),
        .req_type(PTW_SRC_TYPE_FETCH),
        .va(va),
        .fst_nonleaf(fst_nonleaf),
        .l1pmpflg(all_allow_lock_pmpflg),
        .id(0),
        .update_vec(update_vec));
      seen_update_vec |= update_vec[7:0];
    end

    if (seen_update_vec != 8'hff)
      `uvm_error(get_type_name(),
        $sformatf("l1pde_fill_all_entries_toggle_reset: expected all 8 L1 update slots, seen=0x%02h",
          seen_update_vec))
    else
      ptw_meta_add_context("all_8_l1pde_update_slots_observed");

    reuse_va = l1cov_make_va(l1cov_tag(0), 9'h101, 9'h000);
    leaf_pa  = l1cov_make_pa(28'h021_0000);
    if (!ptw_map_raw_leaf_pa(.va(reuse_va), .level(1), .pa(leaf_pa),
          .raw_pte(scd_leaf), .pte_pa(fst_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "l1pde_fill_all_entries_toggle_reset: reuse leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 6'h31, reuse_va, 1, scd_leaf,
      fst_pte_pa, "l1pde_reuse_load_l1_hit");
    l1cov_drive_hit_and_finish("l1pde_smode_load_l1_hit_l1pmp_ok",
      PTW_SRC_TYPE_LOAD, reuse_va, 6'h31);

    reuse_va = l1cov_make_va(l1cov_tag(2), 9'h104, 9'h000);
    leaf_pa  = l1cov_make_pa(28'h021_1000);
    if (!ptw_map_raw_leaf_pa(.va(reuse_va), .level(1), .pa(leaf_pa),
          .raw_pte(scd_leaf), .pte_pa(fst_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "l1pde_fill_all_entries_toggle_reset: store reuse leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_STORE, 6'h33, reuse_va, 1, scd_leaf,
      fst_pte_pa, "l1pde_reuse_store_l1_hit");
    l1cov_drive_hit_and_finish("l1pde_smode_store_l1_hit_l1pmp_ok",
      PTW_SRC_TYPE_STORE, reuse_va, 6'h33);

    reuse_va = l1cov_make_va(l1cov_tag(3), 9'h105, 9'h000);
    leaf_pa  = l1cov_make_pa(28'h021_2000);
    if (!ptw_map_raw_leaf_pa(.va(reuse_va), .level(1), .pa(leaf_pa),
          .raw_pte(scd_leaf), .pte_pa(fst_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "l1pde_fill_all_entries_toggle_reset: pfu reuse leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_PFU, 6'h34, reuse_va, 1, scd_leaf,
      fst_pte_pa, "l1pde_reuse_pfu_l1_hit");
    l1cov_drive_hit_and_finish("l1pde_smode_pfu_l1_hit_l1pmp_ok",
      PTW_SRC_TYPE_PFU, reuse_va, 6'h34);

    // Keep the last PDE request as FETCH, then switch real privilege to M.
    // This evaluates cp0_yy_priv_mode==M and the locked M-bypass term in
    // L1PDE_cache without adding unreachable pure-M source expectations.
    reuse_va = l1cov_make_va(l1cov_tag(1), 9'h102, 9'h000);
    leaf_pa  = l1cov_make_pa(28'h022_0000);
    if (!ptw_map_raw_leaf_pa(.va(reuse_va), .level(1), .pa(leaf_pa),
          .raw_pte(scd_leaf), .pte_pa(fst_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "l1pde_fill_all_entries_toggle_reset: fetch reuse leaf map failed")
    l1cov_drive_hit_and_finish("l1pde_smode_fetch_l1_hit_before_m_switch",
      PTW_SRC_TYPE_FETCH, reuse_va, 0);
    ptw_set_priv(PRIV_M);
    stage8_wait_cycles(16);
    ptw_meta_add_context("cp0_yy_priv_mode_switched_to_M_after_fetch_l1_hit_locked_pmpflg");

    va = l1cov_make_va(9'h077, 9'h103, 9'h000);
    leaf_pa = l1cov_make_pa(28'h023_0000);
    l1cov_map_2m_with_l1_ppn(
      .ctx("l1pde_low_ppn_replacement_after_high"),
      .req_type(PTW_SRC_TYPE_FETCH),
      .id(0),
      .va(va),
      .leaf_pa(leaf_pa),
      .l1_table_ppn(28'h000_0100),
      .fst_nonleaf(fst_nonleaf),
      .scd_leaf(scd_leaf),
      .fst_pte_pa(fst_pte_pa));
    ptw_set_priv(PRIV_S);
    l1cov_prime_l1_capture(
      .ctx("l1pde_low_ppn_replacement_after_high"),
      .req_type(PTW_SRC_TYPE_FETCH),
      .va(va),
      .fst_nonleaf(fst_nonleaf),
      .l1pmpflg(ptw_make_pmpflg(.r(0), .w(0), .x(1), .lock(0))),
      .id(0),
      .update_vec(update_vec));

    l1cov_force_reset_pulse("l1pde_valid_entries_async_reset");

    seen_update_vec = '0;
    for (int unsigned i = 0; i < L1_COV_ENTRY_NUM; i++) begin
      va = l1cov_make_va(l1cov_inverted_tag(i), 9'(9'h180 + i), 9'h000);
      leaf_pa = l1cov_make_pa(28'h026_0000 + ppn_t'(i << 9));
      req_id = 6'h40 + i;
      l1cov_map_2m_with_l1_ppn(
        .ctx($sformatf("l1pde_refill_complement_slot_%0d", i)),
        .req_type(PTW_SRC_TYPE_FETCH),
        .id(req_id),
        .va(va),
        .leaf_pa(leaf_pa),
        .l1_table_ppn(28'h000_0300 + ppn_t'(i)),
        .fst_nonleaf(fst_nonleaf),
        .scd_leaf(scd_leaf),
        .fst_pte_pa(fst_pte_pa));
      l1cov_prime_l1_capture(
        .ctx($sformatf("l1pde_refill_complement_slot_%0d", i)),
        .req_type(PTW_SRC_TYPE_FETCH),
        .va(va),
        .fst_nonleaf(fst_nonleaf),
        .l1pmpflg(all_allow_lock_pmpflg),
        .id(req_id),
        .update_vec(update_vec));
      seen_update_vec |= update_vec[7:0];
    end
    if (seen_update_vec != 8'hff)
      `uvm_error(get_type_name(),
        $sformatf("l1pde_refill_complement_tags: expected all 8 L1 update slots, seen=0x%02h",
          seen_update_vec))
    else
      ptw_meta_add_context("all_8_l1pde_complement_update_slots_observed");
    l1cov_force_reset_pulse("l1pde_complement_entries_final_reset");

    l1cov_toggle_static_inputs();
    ptw_meta_set_expected("Fill all 8 L1PDE entries, refill complement tags after reset, toggle static inputs, cover load/store/pfu/fetch allow hit, M-mode locked term, and reset valid entries");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_l1pde_cov");
    ptw_meta_print();
  endtask

  protected task l1cov_before_update_hit_case();
    va_t         prime_va;
    va_t         same_tag_va;
    pa_t         leaf_pa;
    pte_t        fst_nonleaf;
    pte_t        scd_leaf;
    pa_t         fst_pte_pa;
    bit [15:0]   update_vec;
    logic [3:0]  x_only_pmpflg;
    logic [3:0]  load_allow_pmpflg;

    prime_va = l1cov_make_va(9'h022, 9'h011, 9'h000);
    same_tag_va = l1cov_make_va(9'h022, 9'h012, 9'h000);
    leaf_pa = l1cov_make_pa(28'h024_0000);
    x_only_pmpflg = ptw_make_pmpflg(.r(0), .w(0), .x(1), .lock(0));
    load_allow_pmpflg = ptw_make_pmpflg(.r(1), .w(0), .x(0), .lock(0));

    ptw_meta_begin("TC-PTW-L1PDE-COV", "l1pde_before_update_equal_and_pmp_deny");
    ptw_meta_add_req("PTW-COV-L1PDE-002");
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h90, STAGE8_ROOT_ASID + 16'h90,
      PRIV_S, 1'b0, 1'b0, 1'b1);

    l1cov_map_2m_with_l1_ppn(
      .ctx("l1pde_before_update_prime"),
      .req_type(PTW_SRC_TYPE_FETCH),
      .id(0),
      .va(prime_va),
      .leaf_pa(leaf_pa),
      .l1_table_ppn(28'h000_0200),
      .fst_nonleaf(fst_nonleaf),
      .scd_leaf(scd_leaf),
      .fst_pte_pa(fst_pte_pa));
    l1cov_prime_l1_capture(
      .ctx("l1pde_before_update_prime"),
      .req_type(PTW_SRC_TYPE_FETCH),
      .va(prime_va),
      .fst_nonleaf(fst_nonleaf),
      .l1pmpflg(x_only_pmpflg),
      .id(0),
      .update_vec(update_vec));

    leaf_pa = l1cov_make_pa(28'h025_0000);
    if (!ptw_map_raw_leaf_pa(.va(same_tag_va), .level(1), .pa(leaf_pa),
          .raw_pte(scd_leaf), .pte_pa(fst_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "l1pde_before_update_equal: same-tag leaf map failed")
    ptw_config_page_table_pmp_region(fst_pte_pa, pa_t'(8),
      load_allow_pmpflg, "l1pde_before_update_realtime_load_allow");

    fork
      l1cov_wait_l1_update("l1pde_before_update_equal_mbuf_update", update_vec, 1'b0);
      stage8_drive_and_finish("l1pde_before_update_equal_mbuf_update",
        PTW_SRC_TYPE_LOAD, same_tag_va, 6'h32);
    join
    if (update_vec[7:0] != 8'h00)
      `uvm_error(get_type_name(),
        $sformatf("l1pde_before_update_equal expected no replacement update vec, got 0x%02h",
          update_vec[7:0]))
    else
      ptw_meta_add_context("before_update_equal_hit_suppressed_l1_replacement");

    ptw_meta_set_expected("Cached X-only L1 tag denies LOAD, realtime PMP allows FST reread, and before-update equal tag suppresses replacement");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_l1pde_cov");
    ptw_meta_print();
  endtask

  virtual task run_test_body();
    l1cov_before_update_hit_case();
    l1cov_fill_all_entries_and_reset();
    stage8_close("PTW-COV-L1PDE-001,PTW-COV-L1PDE-002",
      "l1pde_cache_code_coverage_closure",
      "8-entry fill, complement tag refill, high/low tag/ppn/pmpflg/static-input toggles, load/store/pfu/fetch allow hits, before-update equal/mismatch, and valid-entry reset stimulus");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass : test_ptw_l1pde_cache_cov_closure_001

`endif // TEST_PTW_L1PDE_CACHE_COV_CLOSURE_001_SVH
