// =============================================================================
// SVA: PDE access error + PTW-LSU protocol + TWU chk assertions
// =============================================================================
`ifndef TEST_PTW_SVA_ACCERR_PROTOCOL_COV_SVH
`define TEST_PTW_SVA_ACCERR_PROTOCOL_COV_SVH

class test_ptw_sva_accerr_protocol_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_sva_accerr_protocol_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 60;
    timeout_ns = 15_000_000;
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;
    pte_t fst, scd, thd;
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;

    ptw_meta_begin("TC-PTW-SVA-ACCERR", "sva_accerr_protocol_coverage");
    ptw_meta_add_req("PTW-COV-SVA-ACCERR-001");

    // 1. Fill PDE cache then hit with PMP deny → creates access error
    for (int i = 0; i < 24; i++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(i+10), STAGE8_ROOT_ASID + 16'(i%3), PRIV_S, 1'b0, 1'b0);
      va = 39'(i * 32'h200000);
      pa = 40'(40'h80000 + i * 32'h200000);
      stage8_map_4k_and_read_path(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
        .kind("ae_pde"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("ae_pde"), .req_type(PTW_SRC_TYPE_LOAD), .va(va), .id(i+10));
    end

    // 2. Store operations across different ASIDs (exercises protocol + chk)
    for (int a = 0; a < 5; a++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(a+50), STAGE8_ROOT_ASID + 16'(a), PRIV_S, 1'b0, 1'b0);
      for (int p = 0; p < 5; p++) begin
        va = 39'(39'h50000 + a * 39'h100000 + p * 39'h1000);
        pa = 40'(40'h90000 + a * 40'h100000 + p * 40'h1000);
        stage8_map_4k_and_read_path(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
          .kind("ae_st"), .r(1'b1), .w(1'b1), .x(1'b1));
        stage8_drive_and_finish(.scenario_id("ae_st"), .req_type(PTW_SRC_TYPE_STORE), .va(va), .id(a*10+p+60));
      end
    end

    // 3. 2MB pages with mixed load/store/fetch (exercises huge page paths)
    for (int i = 0; i < 10; i++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(i+80), STAGE8_ROOT_ASID + 16'(i%2), PRIV_S, 1'b0, 1'b0);
      va = 39'(39'h400000 * (i+30));
      pa = 40'(40'hA00000 + i * 40'h400000);
      stage8_map_2m_and_read_fst(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_leaf(scd),
        .kind("ae_2m"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("ae_2m"),
        .req_type((i%3==0)?PTW_SRC_TYPE_STORE:((i%3==1)?PTW_SRC_TYPE_FETCH:PTW_SRC_TYPE_LOAD)),
        .va(va), .id(120+i));
    end

    // 4. Page faults for unmapped pages
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'hF0, STAGE8_ROOT_ASID, PRIV_S, 1'b0, 1'b0);
    stage8_map_4k_and_read_path(.va(39'hF0000), .pa(40'hF00000), .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
      .kind("ae_pf"), .r(1'b1), .w(1'b1), .x(1'b1));
    stage8_drive_and_finish(.scenario_id("ae_pf_valid"), .req_type(PTW_SRC_TYPE_LOAD), .va(39'hF0000), .id(150));
    for (int i = 0; i < 10; i++) begin
      ptw_drive_lsu_load(.va(39'(39'hF1000 + i * 39'h1000)), .id(151+i));
    end
    stage8_wait_cycles(500);

    ptw_meta_set_expected("SVA accerr+protocol: PDE fill, multi-ASID stores, 2M mixed, page faults");
    ptw_meta_set_actual("functional_scenarios_completed");
    ptw_meta_set_result("functional_sva_accerr_protocol_cov");
    ptw_meta_print();
    stage8_close("PTW-COV-SVA-ACCERR-001", "sva_accerr_protocol_cov", "SVA accerr+protocol coverage");
    stage8_summary(1'b0);
    #1us;
  endtask

endclass
`endif
