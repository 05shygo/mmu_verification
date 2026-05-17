// =============================================================================
// PTW-ADD-038: L1 PDE cache permission-qualified allow reuse matrix
// =============================================================================
`ifndef TEST_PTW_PDE_L1_PMP_TAG_ALLOW_REUSE_001_SVH
`define TEST_PTW_PDE_L1_PMP_TAG_ALLOW_REUSE_001_SVH

class test_ptw_pde_l1_pmp_tag_allow_reuse_001 extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_pde_l1_pmp_tag_allow_reuse_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected task run_l1_allow_case(
    input string             scenario_id,
    input ptw_src_req_type_e prime_type,
    input ptw_src_req_type_e reuse_type,
    input logic [3:0]        pmpflg,
    input va_t               base_va,
    input pa_t               base_pa,
    input int unsigned       id
  );
    pte_t fst_nonleaf;
    pte_t scd_leaf;
    va_t  reuse_va;
    pa_t  reuse_pa;
    pa_t  tmp_pte_pa;
    int unsigned prime_id;
    int unsigned reuse_id;

    reuse_va = base_va + 39'h0_0020_0000;
    reuse_pa = base_pa + 40'h0_0020_0000;
    prime_id = (prime_type == PTW_SRC_TYPE_FETCH) ? 0 : id;
    reuse_id = (reuse_type == PTW_SRC_TYPE_FETCH) ? 0 : (id + 8);
    ptw_meta_begin("TC-PTW-STAGE8-PDE-PMP", scenario_id);
    ptw_meta_add_req("PTW-ADD-038");
    ptw_meta_add_req("PDE-TP-013");
    ptw_meta_add_req("PTW-FLOW-027");
    ptw_setup_sv39(STAGE8_ROOT_PPN + ppn_t'(id), STAGE8_ROOT_ASID + asid_t'(id),
      PRIV_S, 1'b0, 1'b0, 1'b1);
    stage8_map_2m_and_read_fst(.va(base_va), .pa(base_pa),
      .fst_nonleaf(fst_nonleaf), .scd_leaf(scd_leaf),
      .kind({scenario_id, "_prime_2m"}), .r(1), .w(1), .x(1),
      .meta_req_type(prime_type), .meta_id(prime_id));
    if (!ptw_map_raw_leaf_pa(.va(reuse_va), .level(1), .pa(reuse_pa),
          .raw_pte(scd_leaf), .pte_pa(tmp_pte_pa),
          .r(1), .w(1), .x(1), .u(0), .g(0), .a(1), .d(1)))
      `uvm_fatal(get_type_name(), $sformatf("%s: reuse leaf map failed", scenario_id))
    ptw_meta_add_level(reuse_type, reuse_id, reuse_va, 1, scd_leaf, tmp_pte_pa,
      {scenario_id, "_reuse_2m_leaf"});
    ptw_meta_add_context($sformatf("%s stable_cached_l1pmpflg=0x%0h prime_type=%s reuse_type=%s no_pmp_cfg_change_after_prime",
      scenario_id, pmpflg, ptw_src_type_name(prime_type), ptw_src_type_name(reuse_type)));

    ptw_prime_l1_pde_cache_with_type(prime_type, base_va, fst_nonleaf,
      pmpflg, prime_id);
    ptw_meta_set_expected("L1 tag match and cached l1pmpflg allows current type; PDE lookup should be permission-qualified hit, skip FST page-table read, and use SCD leaf path");
    stage8_drive_and_finish(scenario_id, reuse_type, reuse_va, reuse_id);
  endtask

  virtual task run_test_body();
    run_l1_allow_case("stage8_l1_allow_load_to_pfu_r_bit",
      PTW_SRC_TYPE_LOAD, PTW_SRC_TYPE_PFU,
      ptw_make_pmpflg(.r(1), .w(0), .x(0), .lock(0)),
      39'h0_3830_0000, 40'h0_0830_0000, 6'h12);

    run_l1_allow_case("stage8_l1_allow_fetch_x_bit",
      PTW_SRC_TYPE_FETCH, PTW_SRC_TYPE_FETCH,
      ptw_make_pmpflg(.r(0), .w(0), .x(1), .lock(0)),
      39'h0_3840_0000, 40'h0_0840_0000, 6'h14);

    run_l1_allow_case("stage8_l1_allow_store_w_bit",
      PTW_SRC_TYPE_STORE, PTW_SRC_TYPE_STORE,
      ptw_make_pmpflg(.r(0), .w(1), .x(0), .lock(0)),
      39'h0_3850_0000, 40'h0_0850_0000, 6'h16);

    stage8_close("PTW-ADD-038,PDE-TP-013,PTW-FLOW-027", "stage8_l1_pmp_tag_allow_reuse",
      "directed cases cover R-bit load/PFU sharing, X-bit fetch reuse, and W-bit store reuse with source-SB/SVA permission-qualified L1 hit evidence");
    stage8_summary();
    #200ns;
  endtask

endclass : test_ptw_pde_l1_pmp_tag_allow_reuse_001

`endif // TEST_PTW_PDE_L1_PMP_TAG_ALLOW_REUSE_001_SVH
