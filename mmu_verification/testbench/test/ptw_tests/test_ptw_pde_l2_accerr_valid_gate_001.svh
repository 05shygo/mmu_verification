// =============================================================================
// PTW-ADD-044: L2 direct accerr valid/request gate
// =============================================================================
`ifndef TEST_PTW_PDE_L2_ACCERR_VALID_GATE_001_SVH
`define TEST_PTW_PDE_L2_ACCERR_VALID_GATE_001_SVH

class test_ptw_pde_l2_accerr_valid_gate_001 extends ptw_pde_pmpflg_stage9_base;

  `uvm_component_utils(test_ptw_pde_l2_accerr_valid_gate_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected task run_invalid_reset_tag0_case();
    va_t  va;
    pa_t  pa;
    pte_t fst_nonleaf;
    pte_t scd_nonleaf;
    pte_t thd_leaf;

    va = 39'h0_0000_1000;
    pa = 40'h0_0e00_1000;

    ptw_meta_begin("TC-PTW-STAGE9-PDE-PMP", "stage9_l2_accerr_invalid_reset_tag0_gate");
    ptw_meta_add_req("PTW-ADD-044");
    ptw_meta_add_req("PDE-TP-019");
    ptw_setup_sv39(STAGE9_ROOT_PPN + 28'h20, STAGE9_ROOT_ASID + 16'h20,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage8_map_4k_and_read_path(.va(va), .pa(pa),
      .fst_nonleaf(fst_nonleaf), .scd_nonleaf(scd_nonleaf),
      .thd_leaf(thd_leaf), .kind("stage9_invalid_reset_tag0_full_walk"),
      .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_LOAD), .meta_id(6'h38));
    ptw_meta_add_context("after reset/setup, L2 entries are invalid and reset tag value may match vpn[2:1]=0; direct accerr must stay gated off until a valid entry and ptw_req-qualified deny exist");
    stage9_expect_no_pde_accerr_window("stage9_invalid_reset_tag0_idle_window", 8);
    ptw_meta_set_expected("Initial tag-0 lookup must be a normal full walk/refill path; invalid L2 reset tags and idle cycles must not create PDE direct accerr");
    fork
      begin
        stage9_expect_no_pde_accerr_for_req("stage9_invalid_reset_tag0_lookup_window",
          PTW_SRC_TYPE_LOAD, 6'h38, va[38:12], 256);
      end
      begin
        stage9_drive_and_finish("stage9_l2_accerr_invalid_reset_tag0_gate",
          PTW_SRC_TYPE_LOAD, va, 6'h38);
      end
    join
  endtask

  protected task run_invalid_stale_tag_after_clear_case();
    va_t  prime_va;
    va_t  deny_va;
    pa_t  prime_pa;
    pa_t  deny_pa;
    pte_t fst_nonleaf;
    pte_t scd_nonleaf;
    pte_t thd_leaf;
    pa_t  tmp_pte_pa;
    logic [3:0] locked_r_only;

    prime_va = 39'h0_3e20_0000;
    deny_va  = 39'h0_3e20_1000;
    prime_pa = 40'h0_0e20_0000;
    deny_pa  = 40'h0_0e20_1000;
    locked_r_only = ptw_make_pmpflg(.r(1), .w(0), .x(0), .lock(1));

    ptw_meta_begin("TC-PTW-STAGE9-PDE-PMP", "stage9_l2_accerr_invalid_stale_tag_gate");
    ptw_meta_add_req("PTW-ADD-044");
    ptw_meta_add_req("PDE-TP-019");
    ptw_setup_sv39(STAGE9_ROOT_PPN + 28'h21, STAGE9_ROOT_ASID + 16'h21,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage8_map_4k_and_read_path(.va(prime_va), .pa(prime_pa),
      .fst_nonleaf(fst_nonleaf), .scd_nonleaf(scd_nonleaf),
      .thd_leaf(thd_leaf), .kind("stage9_stale_tag_prime_locked_r"),
      .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_LOAD), .meta_id(6'h39));
    if (!ptw_map_raw_leaf_pa(.va(deny_va), .level(0), .pa(deny_pa),
          .raw_pte(thd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage9_l2_accerr_invalid_stale_tag deny leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_STORE, 6'h3a, deny_va, 0, thd_leaf,
      tmp_pte_pa, "stage9_stale_tag_store_leaf_template");

    ptw_prime_l2_pde_cache_with_type(PTW_SRC_TYPE_LOAD, prime_va,
      fst_nonleaf, scd_nonleaf, locked_r_only, locked_r_only, 6'h39);
    stage9_satp_rewrite_pde_clear("stage9_l2_accerr_invalid_stale_tag_clear");
    ptw_meta_add_context("after SATP rewrite clear, old locked R-only L2 tag/pmpflg bits may physically remain but valid=0; same-tag STORE must not produce PDE direct accerr and should fall through to live TWU PMP behavior");
    ptw_meta_set_expected("Invalid stale L2 entry must not assert L2PDE_entry_acc_err/PDE_cache_acc_err_vld; direct accerr is valid-gated by entry valid and ptw_req");
    fork
      begin
        stage9_expect_no_pde_accerr_for_req("stage9_invalid_stale_tag_lookup_window",
          PTW_SRC_TYPE_STORE, 6'h3a, deny_va[38:12], 256);
      end
      begin
        stage9_drive_and_finish("stage9_l2_accerr_invalid_stale_tag_gate",
          PTW_SRC_TYPE_STORE, deny_va, 6'h3a);
      end
    join
  endtask

  virtual task run_test_body();
    run_invalid_reset_tag0_case();
    run_invalid_stale_tag_after_clear_case();
    stage9_close("PTW-ADD-044,PDE-TP-019",
      "stage9_l2_accerr_valid_gate",
      "directed invalid reset-tag and stale-tag-after-clear windows check that L2 direct accerr is gated by valid entry and active request; PTW-SVA-PDE-014 is required as structural cover");
    stage9_summary();
    #200ns;
  endtask

endclass : test_ptw_pde_l2_accerr_valid_gate_001

`endif // TEST_PTW_PDE_L2_ACCERR_VALID_GATE_001_SVH
