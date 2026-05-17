// =============================================================================
// PTW-ADD-041: TWU->MBUF->PDE cache pmpflg propagation
// =============================================================================
`ifndef TEST_PTW_PDE_PMPFLG_PROPAGATION_UPDATE_001_SVH
`define TEST_PTW_PDE_PMPFLG_PROPAGATION_UPDATE_001_SVH

class test_ptw_pde_pmpflg_propagation_update_001 extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_pde_pmpflg_propagation_update_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected task fst_update_payload();
    va_t  va;
    pa_t  pa;
    pte_t fst_nonleaf;
    pte_t scd_leaf;
    logic [3:0] load_allow_pmpflg;

    va = 39'h0_3880_0000;
    pa = 40'h0_0880_0000;
    load_allow_pmpflg = ptw_make_pmpflg(.r(1), .w(0), .x(0), .lock(0));

    ptw_meta_begin("TC-PTW-STAGE8-PDE-PMP", "stage8_pmpflg_fst_update_l1_payload");
    ptw_meta_add_req("PTW-ADD-041");
    ptw_meta_add_req("PDE-TP-016");
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h40, STAGE8_ROOT_ASID + 16'h40,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage8_map_2m_and_read_fst(va, pa, fst_nonleaf, scd_leaf,
      "stage8_fst_update_payload_2m", .r(1), .w(1), .x(0),
      .meta_req_type(PTW_SRC_TYPE_LOAD), .meta_id(6'h20));
    ptw_config_page_table_pmp_region(40'h0, 40'h0, load_allow_pmpflg,
      "stage8_fst_update_payload_all_twu_ports");
    ptw_meta_set_expected("FST nonleaf should drive twu_mbuf_pmpflg={4'h0,l1pmpflg}; observed L1 PDE update must save l1pmpflg and l2pmpflg=0");
    stage8_drive_and_finish("stage8_pmpflg_fst_update_l1_payload",
      PTW_SRC_TYPE_LOAD, va, 6'h20);
  endtask

  protected task scd_update_payload();
    va_t  va;
    pa_t  pa;
    pte_t fst_nonleaf;
    pte_t scd_nonleaf;
    pte_t thd_leaf;
    logic [3:0] load_allow_pmpflg;

    va = 39'h0_3890_0000;
    pa = 40'h0_0890_0000;
    load_allow_pmpflg = ptw_make_pmpflg(.r(1), .w(0), .x(0), .lock(0));

    ptw_meta_begin("TC-PTW-STAGE8-PDE-PMP", "stage8_pmpflg_scd_update_l2_payload");
    ptw_meta_add_req("PTW-ADD-041");
    ptw_meta_add_req("PDE-TP-016");
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h41, STAGE8_ROOT_ASID + 16'h41,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage8_map_4k_and_read_path(va, pa, fst_nonleaf, scd_nonleaf, thd_leaf,
      "stage8_scd_update_payload", .r(1), .w(1), .x(0),
      .meta_req_type(PTW_SRC_TYPE_LOAD), .meta_id(6'h21));
    ptw_config_page_table_pmp_region(40'h0, 40'h0, load_allow_pmpflg,
      "stage8_scd_update_payload_all_twu_ports");
    ptw_meta_set_expected("Full FST->SCD walk under stable flag-only PMP should produce SCD twu_mbuf_pmpflg={l2pmpflg,l1pmpflg} with both nibbles equal to the driven read-allow pmpflg; observed L2 PDE update must save both");
    stage8_drive_and_finish("stage8_pmpflg_scd_update_l2_payload",
      PTW_SRC_TYPE_LOAD, va, 6'h21);
  endtask

  protected task thd_leaf_no_pde_update();
    va_t  prime_va;
    va_t  thd_va;
    pa_t  prime_pa;
    pa_t  thd_pa;
    pte_t fst_nonleaf;
    pte_t scd_nonleaf;
    pte_t thd_leaf;
    pa_t  thd_pte_pa;
    logic [3:0] load_allow_pmpflg;

    prime_va = 39'h0_38a0_0000;
    thd_va   = 39'h0_38a0_1000;
    prime_pa = 40'h0_08a0_0000;
    thd_pa   = 40'h0_08a0_1000;
    load_allow_pmpflg = ptw_make_pmpflg(.r(1), .w(0), .x(0), .lock(0));

    ptw_meta_begin("TC-PTW-STAGE8-PDE-PMP", "stage8_pmpflg_thd_leaf_no_update");
    ptw_meta_add_req("PTW-ADD-041");
    ptw_meta_add_req("PDE-TP-016");
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h42, STAGE8_ROOT_ASID + 16'h42,
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage8_map_4k_and_read_path(prime_va, prime_pa, fst_nonleaf, scd_nonleaf,
      thd_leaf, "stage8_thd_leaf_no_update_prime_l2",
      .r(1), .w(1), .x(0),
      .meta_req_type(PTW_SRC_TYPE_LOAD), .meta_id(6'h22));
    if (!ptw_map_raw_leaf_pa(.va(thd_va), .level(0), .pa(thd_pa),
          .raw_pte(thd_leaf), .pte_pa(thd_pte_pa),
          .r(1), .w(1), .x(0), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), "stage8_pmpflg_thd_leaf_no_update map failed")
    ptw_meta_add_level(PTW_SRC_TYPE_LOAD, 6'h23, thd_va, 0, thd_leaf, thd_pte_pa,
      "stage8_thd_leaf_no_pde_update");
    ptw_prime_l2_pde_cache_with_type(PTW_SRC_TYPE_LOAD, prime_va, fst_nonleaf,
      scd_nonleaf, load_allow_pmpflg, load_allow_pmpflg, 6'h22);
    ptw_meta_set_expected("After L2 PDE is primed, the second same-vpn[2:1] 4K load enters THD only; THD MBUF payload is 0 and must not create another PDE cache update");
    stage8_drive_and_finish("stage8_pmpflg_thd_leaf_no_update",
      PTW_SRC_TYPE_LOAD, thd_va, 6'h23);
  endtask

  virtual task run_test_body();
    fst_update_payload();
    scd_update_payload();
    thd_leaf_no_pde_update();
    stage8_close("PTW-ADD-041,PDE-TP-016", "stage8_pmpflg_propagation_update",
      "FST L1 update, SCD L2 update, and THD leaf no-update scenarios provide source monitor/ref/SB pmpflg payload evidence");
    stage8_summary();
    #200ns;
  endtask

endclass : test_ptw_pde_pmpflg_propagation_update_001

`endif // TEST_PTW_PDE_PMPFLG_PROPAGATION_UPDATE_001_SVH
