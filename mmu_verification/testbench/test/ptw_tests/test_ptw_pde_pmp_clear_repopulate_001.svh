// =============================================================================
// PTW-ADD-045: PDE clear and pmpflg repopulate evidence
// =============================================================================
`ifndef TEST_PTW_PDE_PMP_CLEAR_REPOPULATE_001_SVH
`define TEST_PTW_PDE_PMP_CLEAR_REPOPULATE_001_SVH

class test_ptw_pde_pmp_clear_repopulate_001 extends ptw_pde_pmpflg_stage9_base;

  `uvm_component_utils(test_ptw_pde_pmp_clear_repopulate_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual task run_test_body();
    va_t  prime_va;
    va_t  repop_va;
    pa_t  prime_pa;
    pa_t  repop_pa;
    pte_t fst_nonleaf;
    pte_t scd_nonleaf;
    pte_t thd_leaf;
    pa_t  tmp_pte_pa;
    logic [3:0] locked_w_only;
    logic [3:0] load_allow_pmpflg;

    prime_va = 39'h0_3e80_0000;
    repop_va = 39'h0_3e80_1000;
    prime_pa = 40'h0_0e80_0000;
    repop_pa = 40'h0_0e80_1000;
    locked_w_only = ptw_make_pmpflg(.r(0), .w(1), .x(0), .lock(1));
    load_allow_pmpflg = ptw_make_pmpflg(.r(1), .w(0), .x(0), .lock(0));

    ptw_meta_begin("TC-PTW-STAGE9-PDE-PMP", "stage9_pmp_clear_repopulate");
    ptw_meta_add_req("PTW-ADD-045");
    ptw_meta_add_req("PDE-TP-010");
    ptw_meta_add_req("PDE-TP-016");
    ptw_setup_sv39(STAGE9_ROOT_PPN + 28'h30, STAGE9_ROOT_ASID + 16'h30,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage8_map_4k_and_read_path(.va(prime_va), .pa(prime_pa),
      .fst_nonleaf(fst_nonleaf), .scd_nonleaf(scd_nonleaf),
      .thd_leaf(thd_leaf), .kind("stage9_clear_repopulate_prime_locked_w"),
      .r(1), .w(1), .x(1),
      .meta_req_type(PTW_SRC_TYPE_STORE), .meta_id(6'h3c));
    if (!ptw_map_raw_leaf_pa(.va(repop_va), .level(0), .pa(repop_pa),
          .raw_pte(thd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage9_pmp_clear_repopulate repop leaf map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 6'h3d, repop_va, 0, thd_leaf,
      tmp_pte_pa, "stage9_clear_repopulate_load_leaf_template");
    ptw_meta_add_context("prime L2 with cached locked W-only pmpflg; if old entry remains valid after clear, the later LOAD would become stale L2 direct accerr");

    ptw_prime_l2_pde_cache_with_type(PTW_SRC_TYPE_STORE, prime_va,
      fst_nonleaf, scd_nonleaf, locked_w_only, locked_w_only, 6'h3c);
    stage9_cp0_tlb_allinv("stage9_pmp_clear_repopulate_tlb_clear");
    ptw_config_page_table_pmp_region(40'h0, 40'h0, load_allow_pmpflg,
      "stage9_repopulate_new_load_allow_pmpflg");
    ptw_meta_add_context("TB currently ties pmp_regs_update_probe to 0; this test uses the available regs_ptw_clr/tlboper clear path to prove stale cached pmpflg is invalidated and a later walk repopulates with new MBUF pmpflg");
    ptw_meta_set_expected("After clear, old locked-W L2 pmpflg must not be reused for LOAD; request must full-walk and repopulate PDE cache with load-allow MBUF pmpflg");

    fork
      begin
        stage9_expect_no_pde_accerr_for_req("stage9_clear_repopulate_no_stale_direct_accerr",
          PTW_SRC_TYPE_LOAD, 6'h3d, repop_va[38:12], 320);
      end
      begin
        stage9_drive_and_finish("stage9_pmp_clear_repopulate",
          PTW_SRC_TYPE_LOAD, repop_va, 6'h3d);
      end
    join

    stage9_partial("PTW-ADD-045,PDE-TP-010,PDE-TP-016",
      "stage9_pmp_clear_repopulate",
      "test proves clear invalidates stale cached pmpflg and repopulate uses new MBUF pmpflg through source monitor/ref/SB and PDE update cover",
      "exact PMP-config-update-driven clear remains a TB/RTL top wiring gap because pmp_regs_update is tied to 1'b0 in tb_top; Stage 10/signoff must keep this limitation visible until wiring is fixed");
    stage9_summary();
    #200ns;
  endtask

endclass : test_ptw_pde_pmp_clear_repopulate_001

`endif // TEST_PTW_PDE_PMP_CLEAR_REPOPULATE_001_SVH
