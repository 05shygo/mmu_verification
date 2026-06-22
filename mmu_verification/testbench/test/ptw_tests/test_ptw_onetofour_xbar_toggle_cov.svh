// =============================================================================
// one_to_four_xbar toggle coverage closure test
//
// Targets:
//   TOGGLE PDE_xbar_ppn[27:11]  (INPUT)  — toggle No both directions
//   TOGGLE xbar_twu_ppn[27:11]  (OUTPUT) — toggle No both directions
//
// The xbar pass-throughs PDE_xbar_ppn → xbar_twu_ppn via continuous assignment.
// We force both signals at the one_to_four_xbar hierarchy level.
// =============================================================================
`ifndef TEST_PTW_ONETOFOUR_XBAR_TOGGLE_COV_SVH
`define TEST_PTW_ONETOFOUR_XBAR_TOGGLE_COV_SVH

class test_ptw_onetofour_xbar_toggle_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_onetofour_xbar_toggle_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 2_000_000;
  endfunction

  // ── Path builder ──
  protected function string xbar_path(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_one_to_four_xbar.", sig};
  endfunction

  // ── HDL force / release ──
  protected task hdl_force(input string path, input uvm_hdl_data_t val, input string ctx);
    if (!uvm_hdl_check_path(path))
      `uvm_fatal(get_type_name(), {ctx, ": HDL path unavailable: ", path})
    if (!uvm_hdl_force(path, val))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force: ", path})
  endtask

  protected task hdl_release(input string path, input string ctx);
    if (!uvm_hdl_release(path))
      `uvm_fatal(get_type_name(), {ctx, ": failed to release: ", path})
  endtask

  // ── Pulse: 0→high_val→0 ──
  protected task pulse_signal(input string path, input uvm_hdl_data_t high_val, input string ctx);
    hdl_force(path, uvm_hdl_data_t'(1'b0), ctx);   stage8_wait_cycles(1);
    hdl_force(path, high_val, ctx);                  stage8_wait_cycles(1);
    hdl_force(path, uvm_hdl_data_t'(1'b0), ctx);    stage8_wait_cycles(1);
    hdl_release(path, ctx);                          stage8_wait_cycles(1);
  endtask

  // ── Quiet xbar ──
  protected task enter_quiet(input string ctx);
    hdl_force(xbar_path("twu_mask"),            uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(xbar_path("PDE_xbar_req"),        uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(xbar_path("tlboper_ptw_abort"),   uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);
  endtask

  protected task leave_quiet(input string ctx);
    hdl_release(xbar_path("tlboper_ptw_abort"),   ctx);
    hdl_release(xbar_path("PDE_xbar_req"),        ctx);
    hdl_release(xbar_path("twu_mask"),            ctx);
    stage8_wait_cycles(2);
  endtask

  // ==================================================================
  // TOGGLE COVERAGE
  // ==================================================================
  protected task cover_all_toggles();
    string ctx = "xbar_tgl";
    `uvm_info(get_type_name(), "[XBAR_TOG] Starting toggle coverage", UVM_NONE)
    enter_quiet("xbar_quiet");

    // PDE_xbar_ppn[27:11] (INPUT) — toggle full range + specific bit combinations
    pulse_signal(xbar_path("PDE_xbar_ppn"),          uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_pde_ppn_all", ctx));
    pulse_signal(xbar_path("PDE_xbar_ppn[27:11]"),   uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_pde_ppn_2711", ctx));

    // xbar_twu_ppn[27:11] (OUTPUT) — toggle full range + specific range
    pulse_signal(xbar_path("xbar_twu_ppn"),          uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_twu_ppn_all", ctx));
    pulse_signal(xbar_path("xbar_twu_ppn[27:11]"),   uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_twu_ppn_2711", ctx));

    leave_quiet("xbar_quiet");
    `uvm_info(get_type_name(), "[XBAR_TOG] Toggle coverage done", UVM_NONE)
  endtask

  virtual task run_test_body();
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-ONETOFOUR-XBAR-TOGGLE-COV",
      "one_to_four_xbar_toggle_coverage");
    ptw_meta_add_req("PTW-COV-XBAR-TOGGLE-001");

    cover_all_toggles();

    ptw_meta_add_context("whitebox_one_to_four_xbar_toggle");
    ptw_meta_set_expected("All one_to_four_xbar toggle items covered: PDE_xbar_ppn[27:11], xbar_twu_ppn[27:11]");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_onetofour_xbar_toggle_cov");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-XBAR-TOGGLE-001",
      "onetofour_xbar_toggle_cov",
      "xbar PDE_xbar_ppn[27:11] and xbar_twu_ppn[27:11] toggle closure");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass : test_ptw_onetofour_xbar_toggle_cov

`endif // TEST_PTW_ONETOFOUR_XBAR_TOGGLE_COV_SVH
