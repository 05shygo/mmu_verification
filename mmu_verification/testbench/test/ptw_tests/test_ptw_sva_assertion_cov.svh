// =============================================================================
// Functional SVA assertion coverage test
// Drives real PTW scenarios to cover assertions in active SVA modules
// =============================================================================
`ifndef TEST_PTW_SVA_ASSERTION_COV_SVH
`define TEST_PTW_SVA_ASSERTION_COV_SVH

class test_ptw_sva_assertion_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_sva_assertion_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 32;
    timeout_ns = 10_000_000;
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;
    pte_t fst, scd, thd;

    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;

    ptw_meta_begin("TC-PTW-SVA-ASSERT", "sva_assertion_functional_coverage");
    ptw_meta_add_req("PTW-COV-SVA-ASSERT-001");

    // Scenario 1: Fill L1 PDE cache to trigger pplru full-valid assertions
    `uvm_info(get_type_name(), "[SVA_ASSERT] Scenario 1: Fill L1 PDE cache", UVM_NONE)
    for (int i = 0; i < 12; i++) begin
      va = 39'(i * 32'h200000);
      pa = 40'(40'h80000 + i * 32'h200000);
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(i), STAGE8_ROOT_ASID + 16'(i),
                     PRIV_S, 1'b0, 1'b0);
      stage8_map_4k_and_read_path(.va(va), .pa(pa),
        .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
        .kind("sva_assert"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("sva_l1fill"),
        .req_type(PTW_SRC_TYPE_LOAD), .va(va), .id(i));
    end

    // Scenario 2: Page fault paths
    `uvm_info(get_type_name(), "[SVA_ASSERT] Scenario 2: Page faults", UVM_NONE)
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h10, STAGE8_ROOT_ASID, PRIV_S, 1'b0, 1'b0);
    stage8_map_4k_and_read_path(.va(39'h1000), .pa(40'hA000),
      .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
      .kind("sva_pf"), .r(1'b1), .w(1'b1), .x(1'b1));
    stage8_drive_and_finish(.scenario_id("sva_pf_valid"),
      .req_type(PTW_SRC_TYPE_LOAD), .va(39'h1000), .id(1));
    for (int i = 0; i < 4; i++) begin
      va = 39'(39'h2000 + i * 39'h1000);
      ptw_drive_lsu_load(.va(va), .id(i+20));
    end
    stage8_wait_cycles(200);

    // Scenario 3: PMP deny paths
    `uvm_info(get_type_name(), "[SVA_ASSERT] Scenario 3: PMP deny", UVM_NONE)
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h20, STAGE8_ROOT_ASID, PRIV_S, 1'b0, 1'b0);
    stage8_map_4k_and_read_path(.va(39'h5000), .pa(40'hB000),
      .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
      .kind("sva_pmp1"), .r(1'b1), .w(1'b1), .x(1'b1));
    stage8_drive_and_finish(.scenario_id("sva_pmp_load"),
      .req_type(PTW_SRC_TYPE_LOAD), .va(39'h5000), .id(30));
    stage8_map_4k_and_read_path(.va(39'h6000), .pa(40'hC000),
      .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
      .kind("sva_pmp2"), .r(1'b1), .w(1'b1), .x(1'b1));
    stage8_drive_and_finish(.scenario_id("sva_pmp_store"),
      .req_type(PTW_SRC_TYPE_STORE), .va(39'h6000), .id(31));

    // Scenario 4: Mixed types with different ASIDs
    `uvm_info(get_type_name(), "[SVA_ASSERT] Scenario 4: Mixed types", UVM_NONE)
    for (int a = 0; a < 3; a++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(a+30), STAGE8_ROOT_ASID + 16'(a),
                     PRIV_S, 1'b0, 1'b0);
      for (int p = 0; p < 4; p++) begin
        va = 39'(39'h10000 + a * 39'h10000 + p * 39'h1000);
        pa = 40'(40'h10000 + a * 40'h10000 + p * 40'h1000);
        stage8_map_4k_and_read_path(.va(va), .pa(pa),
          .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
          .kind("sva_mix"), .r(1'b1), .w(1'b1), .x(1'b1));
        stage8_drive_and_finish(.scenario_id("sva_mix"),
          .req_type(p[0] ? PTW_SRC_TYPE_STORE : PTW_SRC_TYPE_LOAD), .va(va), .id(a*4+p+40));
      end
    end

    ptw_meta_set_expected("SVA assertion coverage: pplru full-valid, page fault, PMP, mixed types");
    ptw_meta_set_actual("functional_scenarios_completed");
    ptw_meta_set_result("functional_sva_assertion_cov");
    ptw_meta_print();

    stage8_close("PTW-COV-SVA-ASSERT-001", "sva_assertion_cov",
      "Functional SVA assertion coverage");
    stage8_summary(1'b0);
    #1us;
  endtask

endclass

`endif
