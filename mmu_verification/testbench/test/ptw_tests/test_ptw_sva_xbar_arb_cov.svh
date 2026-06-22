// =============================================================================
// SVA coverage: xbar dispatch, arbiter priority, PDE cache stress
// Functional test via source-directed PTW walks
// =============================================================================
`ifndef TEST_PTW_SVA_XBAR_ARB_COV_SVH
`define TEST_PTW_SVA_XBAR_ARB_COV_SVH

class test_ptw_sva_xbar_arb_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_sva_xbar_arb_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 80;
    timeout_ns = 18_000_000;
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;
    pte_t fst, scd, thd;
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;

    ptw_meta_begin("TC-PTW-SVA-XBAR-ARB", "sva_xbar_arb_coverage");
    ptw_meta_add_req("PTW-COV-SVA-XBAR-ARB-001");

    // ================================================================
    // 1. Back-to-back PDE cache hits (exercises xbar dispatch)
    //    Fill all entries then repeatedly hit them
    // ================================================================
    `uvm_info(get_type_name(), "[SVA_XA] PDE cache stress", UVM_NONE)
    for (int i = 0; i < 30; i++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(i+50), STAGE8_ROOT_ASID,
                     PRIV_S, 1'b0, 1'b0);
      va = 39'(i * 32'h200000);
      pa = 40'(40'h80000 + i * 32'h200000);
      stage8_map_4k_and_read_path(.va(va), .pa(pa),
        .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
        .kind("xa_pde"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("xa_pde"),
        .req_type(PTW_SRC_TYPE_LOAD), .va(va), .id(i+10));
    end

    // ================================================================
    // 2. Multi-ASID rapid switching (arbiter stress)
    // ================================================================
    `uvm_info(get_type_name(), "[SVA_XA] Multi-ASID arbiter stress", UVM_NONE)
    for (int a = 0; a < 6; a++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(a+100), STAGE8_ROOT_ASID + 16'(a),
                     PRIV_S, 1'b0, 1'b0);
      for (int p = 0; p < 6; p++) begin
        va = 39'(39'h100000 + a * 39'h100000 + p * 39'h1000);
        pa = 40'(40'h500000 + a * 40'h100000 + p * 40'h1000);
        stage8_map_4k_and_read_path(.va(va), .pa(pa),
          .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
          .kind("xa_arb"), .r(1'b1), .w(1'b1), .x(1'b1));
        stage8_drive_and_finish(.scenario_id("xa_arb"),
          .req_type((p%3==0)?PTW_SRC_TYPE_STORE:((p%3==1)?PTW_SRC_TYPE_FETCH:PTW_SRC_TYPE_LOAD)),
          .va(va), .id(a*10+p+50));
      end
    end

    // ================================================================
    // 3. Store-only stress (exercises write path + D-bit)
    // ================================================================
    `uvm_info(get_type_name(), "[SVA_XA] Store stress", UVM_NONE)
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h200, STAGE8_ROOT_ASID, PRIV_S, 1'b0, 1'b0);
    for (int i = 0; i < 12; i++) begin
      va = 39'(39'h200000 + i * 39'h1000);
      pa = 40'(40'h600000 + i * 40'h1000);
      stage8_map_4k_and_read_path(.va(va), .pa(pa),
        .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
        .kind("xa_st"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("xa_st"),
        .req_type(PTW_SRC_TYPE_STORE), .va(va), .id(200+i));
    end

    // ================================================================
    // 4. 2MB huge pages with store (exercises huge page D-bit/A-bit)
    // ================================================================
    `uvm_info(get_type_name(), "[SVA_XA] 2MB store stress", UVM_NONE)
    for (int i = 0; i < 8; i++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(i+250), STAGE8_ROOT_ASID + 16'(i%3),
                     PRIV_S, 1'b0, 1'b0);
      va = 39'(39'h400000 * (i+20));
      pa = 40'(40'h7000000 + i * 40'h400000);
      stage8_map_2m_and_read_fst(.va(va), .pa(pa),
        .fst_nonleaf(fst), .scd_leaf(scd),
        .kind("xa_2ms"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("xa_2ms"),
        .req_type(PTW_SRC_TYPE_STORE), .va(va), .id(250+i));
    end

    // ================================================================
    // 5. Page fault + access error mix
    // ================================================================
    `uvm_info(get_type_name(), "[SVA_XA] Page fault + access error", UVM_NONE)
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h300, STAGE8_ROOT_ASID, PRIV_S, 1'b0, 1'b0);
    stage8_map_4k_and_read_path(.va(39'hA0000), .pa(40'hA00000),
      .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
      .kind("xa_pfac"), .r(1'b1), .w(1'b1), .x(1'b1));
    stage8_drive_and_finish(.scenario_id("xa_pfac_valid"),
      .req_type(PTW_SRC_TYPE_LOAD), .va(39'hA0000), .id(300));
    for (int i = 0; i < 10; i++) begin
      ptw_drive_lsu_load(.va(39'(39'hB0000 + i * 39'h1000)), .id(301+i));
    end
    stage8_wait_cycles(500);

    ptw_meta_set_expected("SVA xbar+arb coverage: PDE stress, multi-ASID, store, 2M, page fault");
    ptw_meta_set_actual("functional_scenarios_completed");
    ptw_meta_set_result("functional_sva_xbar_arb_cov");
    ptw_meta_print();
    stage8_close("PTW-COV-SVA-XBAR-ARB-001", "sva_xbar_arb_cov",
      "SVA xbar+arbiter+store+huge page functional coverage");
    stage8_summary(1'b0);
    #1us;
  endtask

endclass

`endif
