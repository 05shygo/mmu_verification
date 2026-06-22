// =============================================================================
// SVA assertion functional coverage test
// =============================================================================
`ifndef TEST_PTW_SVA_FULL_COV_SVH
`define TEST_PTW_SVA_FULL_COV_SVH

class test_ptw_sva_full_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_sva_full_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 40;
    timeout_ns = 12_000_000;
  endfunction

  virtual task run_test_body();
    va_t va;
    pa_t pa;
    pte_t fst, scd, thd;
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;

    ptw_meta_begin("TC-PTW-SVA-FULL", "sva_full_coverage");
    ptw_meta_add_req("PTW-COV-SVA-FULL-001");

    // 2MB huge pages
    for (int i = 0; i < 6; i++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(i+100), STAGE8_ROOT_ASID + 16'(i), PRIV_S, 1'b0, 1'b0);
      va = 39'(39'h200000 * (i+10));
      pa = 40'(40'h400000 * (i+10));
      stage8_map_2m_and_read_fst(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_leaf(scd),
        .kind("sva_2m"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("sva_2m"), .req_type(PTW_SRC_TYPE_LOAD), .va(va), .id(i+50));
    end

    // PDE cache fill
    for (int i = 0; i < 20; i++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(i+200), STAGE8_ROOT_ASID + 16'(i%4), PRIV_S, 1'b0, 1'b0);
      va = 39'(i * 32'h200000);
      pa = 40'(40'h100000 + i * 32'h200000);
      stage8_map_4k_and_read_path(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
        .kind("sva_pde"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("sva_pde"),
        .req_type((i%2) ? PTW_SRC_TYPE_STORE : PTW_SRC_TYPE_LOAD), .va(va), .id(i+100));
    end

    // Mixed 4K + 2M + ASIDs
    for (int a = 0; a < 4; a++) begin
      ptw_setup_sv39(STAGE8_ROOT_PPN + 28'(a+300), STAGE8_ROOT_ASID + 16'(a), PRIV_S, 1'b0, 1'b0);
      for (int p = 0; p < 3; p++) begin
        va = 39'(39'h80000 + a * 39'h400000 + p * 39'h1000);
        pa = 40'(40'h200000 + a * 40'h400000 + p * 40'h1000);
        stage8_map_4k_and_read_path(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
          .kind("sva_mix"), .r(1'b1), .w(1'b1), .x(1'b1));
        stage8_drive_and_finish(.scenario_id("sva_mix_4k"), .req_type(PTW_SRC_TYPE_LOAD), .va(va), .id(a*10+p+200));
      end
      va = 39'(39'hC00000 + a * 39'h400000);
      pa = 40'(40'h300000 + a * 40'h400000);
      stage8_map_2m_and_read_fst(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_leaf(scd),
        .kind("sva_mix_2m"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("sva_mix_2m"), .req_type(PTW_SRC_TYPE_LOAD), .va(va), .id(a*10+203));
    end

    // Page faults
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h400, STAGE8_ROOT_ASID, PRIV_S, 1'b0, 1'b0);
    stage8_map_4k_and_read_path(.va(39'hF000), .pa(40'h500000), .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
      .kind("sva_pf"), .r(1'b1), .w(1'b1), .x(1'b1));
    stage8_drive_and_finish(.scenario_id("sva_pf_valid"), .req_type(PTW_SRC_TYPE_LOAD), .va(39'hF000), .id(250));
    for (int i = 0; i < 6; i++) begin
      ptw_drive_lsu_load(.va(39'(39'h10000 + i * 39'h1000)), .id(251+i));
    end
    stage8_wait_cycles(300);

    // Abort during update
    ptw_setup_sv39(STAGE8_ROOT_PPN + 28'h500, STAGE8_ROOT_ASID, PRIV_S, 1'b0, 1'b0);
    for (int i = 0; i < 4; i++) begin
      va = 39'(39'h50000 + i * 39'h200000);
      pa = 40'(40'h600000 + i * 40'h200000);
      stage8_map_4k_and_read_path(.va(va), .pa(pa), .fst_nonleaf(fst), .scd_nonleaf(scd), .thd_leaf(thd),
        .kind("sva_abt"), .r(1'b1), .w(1'b1), .x(1'b1));
      stage8_drive_and_finish(.scenario_id("sva_abt"), .req_type(PTW_SRC_TYPE_LOAD), .va(va), .id(260+i));
    end

    ptw_meta_set_expected("SVA coverage: twu 2M cross, PDE fill, page faults, mixed sizes");
    ptw_meta_set_actual("functional_scenarios_completed");
    ptw_meta_set_result("functional_sva_full_cov");
    ptw_meta_print();
    stage8_close("PTW-COV-SVA-FULL-001", "sva_full_cov", "Functional SVA coverage");
    stage8_summary(1'b0);
    #1us;
  endtask

endclass
`endif
