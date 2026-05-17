// =============================================================================
// PTW-ADD-039: L2 tag hit, cached L1 PMP deny direct access fault
// =============================================================================
`ifndef TEST_PTW_PDE_L2_PMP_L1_DENY_ACCERR_001_SVH
`define TEST_PTW_PDE_L2_PMP_L1_DENY_ACCERR_001_SVH

class test_ptw_pde_l2_pmp_l1_deny_accerr_001 extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_pde_l2_pmp_l1_deny_accerr_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t  l1_prime_va;
    va_t  l2_prime_va;
    va_t  deny_va;
    pa_t  l1_prime_pa;
    pa_t  l2_prime_pa;
    pa_t  deny_pa;
    pte_t fst_nonleaf;
    pte_t scd_nonleaf;
    pte_t thd_leaf;
    logic [3:0] rx_pmpflg;
    pa_t tmp_pte_pa;
    pa_t scd_pte_pa;

    l1_prime_va = 39'h0_3860_0000;
    l2_prime_va = 39'h0_3880_0000;
    deny_va     = 39'h0_3880_1000;
    l1_prime_pa = 40'h0_0860_0000;
    l2_prime_pa = 40'h0_0880_0000;
    deny_pa     = 40'h0_0880_1000;
    rx_pmpflg = ptw_make_pmpflg(.r(1), .w(0), .x(1), .lock(0));

    ptw_meta_begin("TC-PTW-STAGE8-PDE-PMP", "stage8_l2_cached_l1pmp_deny_accerr");
    ptw_meta_add_req("PTW-ADD-039");
    ptw_meta_add_req("PDE-TP-014");
    ptw_meta_add_req("PTW-FLOW-025");
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h20, STAGE8_ROOT_ASID + 16'h20,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage8_map_2m_and_read_fst(l1_prime_va, l1_prime_pa, fst_nonleaf,
      thd_leaf, "stage8_l2_l1deny_l1_prime_2m", .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_FETCH), .meta_id(0));
    if (!ptw_map_raw_leaf_pa(.va(l2_prime_va), .level(0), .pa(l2_prime_pa),
          .raw_pte(thd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage8_l2_l1deny l2 prime leaf map failed")
    if (!ptw_map_raw_leaf_pa(.va(deny_va), .level(0), .pa(deny_pa),
          .raw_pte(thd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage8_l2_l1deny deny leaf map failed")
    if (!m_env.m_pt_mem.m_builder.read_pte_for_level(l2_prime_va, 1,
          scd_nonleaf, scd_pte_pa))
      `uvm_fatal(get_type_name(), "stage8_l2_l1deny read scd nonleaf failed")

    ptw_meta_add_context({"construct_exact_l1deny_via_L1_hit_to_SCD_update: ",
      "first fetch primes L1 with RX pmpflg and a 2M leaf so no L2 entry exists; second fetch reuses L1 and RTL SCD direct path writes L2 l1pmpflg=0/l2pmpflg=RX; later load hits L2 tag and fails cached l1pmpflg only"});
    ptw_prime_l1_pde_cache_with_type(PTW_SRC_TYPE_FETCH, l1_prime_va,
      fst_nonleaf, rx_pmpflg, 0);

    ptw_meta_add_level(PTW_SRC_TYPE_FETCH, 0, l2_prime_va, 1, scd_nonleaf,
      scd_pte_pa, "stage8_l2_l1deny_second_fetch_expected_scd_nonleaf_update_l2");
    ptw_meta_set_expected("second fetch uses L1 PDE allow and updates L2 from SCD nonleaf; cached l1pmpflg is inherited as RTL direct-path 0 while l2pmpflg is RX");
    ptw_drive_source_req_by_type(PTW_SRC_TYPE_FETCH, l2_prime_va, 0);
    ptw_quiescent_wait("stage8_l2_l1deny_prime_l2_from_l1_hit");

    ptw_meta_set_expected("LOAD tag-matches the L2 entry; cached l1pmpflg=0 denies R while cached l2pmpflg=0x5 allows R, so L2_L1PMP_DENY direct accerr is expected with no extra PTW LSU read");
    fork
      begin
        ptw_drive_source_req_by_type(PTW_SRC_TYPE_LOAD, deny_va, 6'h18);
      end
      begin
        stage8_wait_cycles(1);
        ptw_expect_no_ptw_mem_req_window("stage8_l2_cached_l1pmp_deny_accerr_manual_window",
          4, 32);
      end
    join
    ptw_meta_set_actual("source_sb_expected_match_required_stage8");
    ptw_meta_set_result("stage8_directed");
    ptw_quiescent_wait("stage8_l2_cached_l1pmp_deny_accerr");
    ptw_meta_print();
    stage8_partial("PTW-ADD-039,PDE-TP-014,PTW-FLOW-025",
      "stage8_l2_cached_l1pmp_deny_accerr",
      "source/SB direct-accerr and no-extra-LSU evidence is generated; construction uses RTL L1-hit-to-SCD path to create a cached L1 deny payload",
      "current flag-only PMP agent cannot independently assign FST and SCD page-table regions in a normal full walk, so exact pure L1-deny closure depends on observed RTL direct-path pmpflg payload");
    stage8_summary();
    #200ns;
  endtask

endclass : test_ptw_pde_l2_pmp_l1_deny_accerr_001

`endif // TEST_PTW_PDE_L2_PMP_L1_DENY_ACCERR_001_SVH
