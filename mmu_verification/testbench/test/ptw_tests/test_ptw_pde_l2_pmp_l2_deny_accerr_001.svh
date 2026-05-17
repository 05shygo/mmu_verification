// =============================================================================
// PTW-ADD-040: L2 tag hit, cached L2 PMP deny direct access fault
// =============================================================================
`ifndef TEST_PTW_PDE_L2_PMP_L2_DENY_ACCERR_001_SVH
`define TEST_PTW_PDE_L2_PMP_L2_DENY_ACCERR_001_SVH

class test_ptw_pde_l2_pmp_l2_deny_accerr_001 extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_pde_l2_pmp_l2_deny_accerr_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t  prime_va;
    va_t  l2_prime_va;
    va_t  deny_va;
    pa_t  prime_pa;
    pa_t  l2_prime_pa;
    pa_t  deny_pa;
    pte_t fst_nonleaf;
    pte_t scd_nonleaf;
    pte_t thd_leaf;
    logic [3:0] locked_x_only_pmpflg;
    pa_t tmp_pte_pa;
    pa_t scd_pte_pa;

    prime_va = 39'h0_3870_0000;
    l2_prime_va = 39'h0_38c0_0000;
    deny_va  = 39'h0_38c0_1000;
    prime_pa = 40'h0_0870_0000;
    l2_prime_pa = 40'h0_08c0_0000;
    deny_pa  = 40'h0_08c0_1000;
    locked_x_only_pmpflg = ptw_make_pmpflg(.r(0), .w(0), .x(1), .lock(1));

    ptw_meta_begin("TC-PTW-STAGE8-PDE-PMP", "stage8_l2_cached_l2pmp_deny_accerr");
    ptw_meta_add_req("PTW-ADD-040");
    ptw_meta_add_req("PDE-TP-015");
    ptw_meta_add_req("PTW-FLOW-026");
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h30, STAGE8_ROOT_ASID + 16'h30,
      PRIV_S, 1'b0, 1'b0, 1'b1, 1'b1, PRIV_M);
    stage8_map_2m_and_read_fst(prime_va, prime_pa, fst_nonleaf, thd_leaf,
      "stage8_l2_l2deny_l1_prime_2m", .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_FETCH), .meta_id(0));
    if (!ptw_map_raw_leaf_pa(.va(l2_prime_va), .level(0), .pa(l2_prime_pa),
          .raw_pte(thd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage8_l2_l2deny l2 prime leaf map failed")
    if (!ptw_map_raw_leaf_pa(.va(deny_va), .level(0), .pa(deny_pa),
          .raw_pte(thd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage8_l2_l2deny deny leaf map failed")
    if (!m_env.m_pt_mem.m_builder.read_pte_for_level(l2_prime_va, 1,
          scd_nonleaf, scd_pte_pa))
      `uvm_fatal(get_type_name(), "stage8_l2_l2deny read scd nonleaf failed")

    ptw_meta_add_context({"construct_l2deny_with_data_effective_M: ",
      "first fetch primes L1 with locked X-only 2M leaf; second fetch reuses L1 and writes L2 l1pmpflg=0/l2pmpflg=locked-X; later MPRV=1/MPP=M load bypasses l1pmpflg=0 but cannot bypass locked l2pmpflg"});
    ptw_prime_l1_pde_cache_with_type(PTW_SRC_TYPE_FETCH, prime_va, fst_nonleaf,
      locked_x_only_pmpflg, 0);

    ptw_meta_add_level(PTW_SRC_TYPE_FETCH, 0, l2_prime_va, 1, scd_nonleaf,
      scd_pte_pa, "stage8_l2_l2deny_second_fetch_expected_scd_nonleaf_update_l2");
    ptw_meta_set_expected("second fetch uses L1 PDE allow and updates L2 from SCD nonleaf with cached l1pmpflg=0 and locked-X l2pmpflg");
    ptw_drive_source_req_by_type(PTW_SRC_TYPE_FETCH, l2_prime_va, 0);
    ptw_quiescent_wait("stage8_l2_l2deny_prime_l2_from_l1_hit");

    ptw_meta_set_expected("effective-M data load tag-matches L2; cached l1pmpflg can pass by M-mode bypass, but cached l2pmpflg has lock=1 and R=0, so L2 direct access fault must occur without fallback SCD/FST LSU read");
    fork
      begin
        ptw_drive_source_req_by_type(PTW_SRC_TYPE_LOAD, deny_va, 6'h1a);
      end
      begin
        stage8_wait_cycles(1);
        ptw_expect_no_ptw_mem_req_window("stage8_l2_cached_l2pmp_deny_accerr_manual_window",
          4, 32);
      end
    join
    ptw_meta_set_actual("source_sb_expected_match_required_stage8");
    ptw_meta_set_result("stage8_directed");
    ptw_quiescent_wait("stage8_l2_cached_l2pmp_deny_accerr");
    ptw_meta_print();
    stage8_partial("PTW-ADD-040,PDE-TP-015,PTW-FLOW-026",
      "stage8_l2_cached_l2pmp_deny_accerr",
      "directed test isolates L2 cached PMP deny with data effective-M bypass for the cached L1 side and checks no-extra-LSU",
      "uses MPRV=1/MPP=M only as a construction aid; full effective-M lock/bypass matrix remains stage 9");
    stage8_summary();
    #200ns;
  endtask

endclass : test_ptw_pde_l2_pmp_l2_deny_accerr_001

`endif // TEST_PTW_PDE_L2_PMP_L2_DENY_ACCERR_001_SVH
