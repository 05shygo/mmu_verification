// =============================================================================
// SVA: Arbiter priority + Xbar dispatch + cache abort stress
// =============================================================================
`ifndef TEST_PTW_SVA_ARB_XBAR_COV_SVH
`define TEST_PTW_SVA_ARB_XBAR_COV_SVH

class test_ptw_sva_arb_xbar_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_sva_arb_xbar_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 70;
    timeout_ns = 16_000_000;
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;
    pte_t fst, scd, thd;
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;

    ptw_meta_begin("TC-PTW-SVA-ARB-XBAR", "sva_arb_xbar_coverage");
    ptw_meta_add_req("PTW-COV-SVA-ARB-XBAR-001");

    // 1. Rapid back-to-back PDE hits (xbar stress)
    for (int i = 0; i < 30; i++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(i+20), STAGE8_ROOT_ASID, PRIV_S, 1'b0, 1'b0);
      va = 39'(i * 32'h200000);
      pa = 40'(40'hB0000 + i * 32'h200000);
      stage8_map_4k_and_read_path(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
        .kind("ax_pde"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("ax_pde"), .req_type(PTW_SRC_TYPE_LOAD), .va(va), .id(i+20));
    end

    // 2. Mixed types with store/fetch in rapid sequence (arb stress)
    for (int a = 0; a < 5; a++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(a+70), STAGE8_ROOT_ASID + 16'(a), PRIV_S, 1'b0, 1'b0);
      for (int p = 0; p < 6; p++) begin
        va = 39'(39'h70000 + a * 39'h100000 + p * 39'h1000);
        pa = 40'(40'hC0000 + a * 40'h100000 + p * 40'h1000);
        stage8_map_4k_and_read_path(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
          .kind("ax_arb"), .r(1'b1), .w(1'b1), .x(1'b1));
        stage8_drive_and_finish(.scenario_id("ax_arb"),
          .req_type(p%3==0?PTW_SRC_TYPE_STORE:(p%3==1?PTW_SRC_TYPE_FETCH:PTW_SRC_TYPE_LOAD)),
          .va(va), .id(a*10+p+60));
      end
    end

    // 3. 2MB pages with store + fetch
    for (int i = 0; i < 8; i++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(i+100), STAGE8_ROOT_ASID + 16'(i%2), PRIV_S, 1'b0, 1'b0);
      va = 39'(39'h800000 * (i+10));
      pa = 40'(40'hD00000 + i * 40'h800000);
      stage8_map_2m_and_read_fst(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_leaf(scd),
        .kind("ax_2m"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("ax_2m"),
        .req_type(i%2?PTW_SRC_TYPE_STORE:PTW_SRC_TYPE_FETCH), .va(va), .id(130+i));
    end

    // 4. Page faults
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'hF0, STAGE8_ROOT_ASID, PRIV_S, 1'b0, 1'b0);
    stage8_map_4k_and_read_path(.va(39'hE0000), .pa(40'hE00000), .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
      .kind("ax_pf"), .r(1'b1), .w(1'b1), .x(1'b1));
    stage8_drive_and_finish(.scenario_id("ax_pf_valid"), .req_type(PTW_SRC_TYPE_LOAD), .va(39'hE0000), .id(150));
    for (int i = 0; i < 8; i++) begin
      ptw_drive_lsu_load(.va(39'(39'hE1000 + i * 39'h1000)), .id(151+i));
    end
    stage8_wait_cycles(400);

    ptw_meta_set_expected("SVA arb+xbar: PDE stress, multi-type arb, 2M store/fetch, page faults");
    ptw_meta_set_actual("functional_scenarios_completed");
    ptw_meta_set_result("functional_sva_arb_xbar_cov");
    ptw_meta_print();
    stage8_close("PTW-COV-SVA-ARB-XBAR-001", "sva_arb_xbar_cov", "SVA arbiter+xbar coverage");
    stage8_summary(1'b0);
    #1us;
  endtask

endclass
`endif
