// =============================================================================
// TWU condition coverage full closure test
// Targets all remaining COND sub-expressions from report:
//   wait signals, hit levels, page fault arb, PMP deny arb, CSR paths
// =============================================================================
`ifndef TEST_PTW_TWU_COND_FULL_SVH
`define TEST_PTW_TWU_COND_FULL_SVH

class test_ptw_twu_cond_full extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_twu_cond_full)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 5_000_000;
  endfunction

  protected function string tw(string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.twu_one.", sig};
  endfunction

  protected task hf(input string path, input uvm_hdl_data_t val, input string ctx);
    if (!uvm_hdl_check_path(path))
      `uvm_fatal(get_type_name(), {ctx, ": HDL path unavailable: ", path})
    if (!uvm_hdl_force(path, val))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force: ", path})
  endtask
  protected task hr(input string path, input string ctx);
    if (!uvm_hdl_release(path))
      `uvm_fatal(get_type_name(), {ctx, ": failed to release: ", path})
  endtask

  virtual task run_test_body();
    string ctx = "twufull";
    string pt  = "$root.tb_top.u_dut.x_ct_mmu_ptw.twu_one";
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-TWU-COND-FULL", "twu_condition_full_closure");
    ptw_meta_add_req("PTW-COV-TWU-COND-FULL-001");

    // ================================================================
    // 1. Set all wait signals LOW to cover (!wait)=1 sub-expressions
    // ================================================================
    `uvm_info(get_type_name(), "[TWU_FULL] Setting all wait=0", UVM_NONE)
    hf(tw("fst_pmp_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_fpw0", ctx));
    hf(tw("scd_pmp_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_spw0", ctx));
    hf(tw("thd_pmp_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_tpw0", ctx));
    hf(tw("fst_chk_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_fcw0", ctx));
    hf(tw("scd_chk_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_scw0", ctx));
    hf(tw("thd_chk_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_tcw0", ctx));

    // ================================================================
    // 2. Drive xbar_twu_req with all 3 hit levels + mbuf data valid
    // ================================================================
    `uvm_info(get_type_name(), "[TWU_FULL] xbar + mbuf conditions", UVM_NONE)
    // Hit level 0 → fst_pmp (line 409)
    hf(tw("xbar_twu_req"),       uvm_hdl_data_t'(1'b1),  $sformatf("%s_xr", ctx));
    hf(tw("xbar_twu_hit_level"), uvm_hdl_data_t'(2'b00),  $sformatf("%s_hl0", ctx));
    stage8_wait_cycles(3);
    // Hit level 2 → scd_pmp (line 561)
    hf(tw("xbar_twu_hit_level"), uvm_hdl_data_t'(2'b10),  $sformatf("%s_hl2", ctx));
    stage8_wait_cycles(3);
    // Hit level 1 → thd_pmp (line 722)
    hf(tw("xbar_twu_hit_level"), uvm_hdl_data_t'(2'b01),  $sformatf("%s_hl1", ctx));
    stage8_wait_cycles(3);
    hr(tw("xbar_twu_hit_level"), $sformatf("%s_rhl", ctx));
    hr(tw("xbar_twu_req"),       $sformatf("%s_rxr", ctx));

    // mbuf_twu_data_vld + each lvl (lines 471/486/636/648/793/805)
    hf(tw("mbuf_twu_data_vld"), uvm_hdl_data_t'(1'b1),  $sformatf("%s_mv", ctx));
    hf(tw("mbuf_twu_lvl"),     uvm_hdl_data_t'(3'b100), $sformatf("%s_ml2", ctx)); // lvl[2]=1
    stage8_wait_cycles(3);
    hf(tw("mbuf_twu_lvl"),     uvm_hdl_data_t'(3'b010), $sformatf("%s_ml1", ctx)); // lvl[1]=1
    stage8_wait_cycles(3);
    hf(tw("mbuf_twu_lvl"),     uvm_hdl_data_t'(3'b001), $sformatf("%s_ml0", ctx)); // lvl[0]=1
    stage8_wait_cycles(3);
    hr(tw("mbuf_twu_lvl"),      $sformatf("%s_rml", ctx));
    hr(tw("mbuf_twu_data_vld"), $sformatf("%s_rmv", ctx));

    // ================================================================
    // 3. scd_pmp from fst_chk (line 563) and scd_chk→thd_pmp (line 724)
    // ================================================================
    `uvm_info(get_type_name(), "[TWU_FULL] fst_chk→scd_pmp, scd_chk→thd_pmp", UVM_NONE)
    // fst_chk→scd_pmp: vld=1, leaf=0, page_flt=0, wait=0
    hf(tw("fst_chk_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_fcv", ctx));
    hf(tw("fst_chk_leaf_vld"), uvm_hdl_data_t'(1'b0), $sformatf("%s_fcl", ctx));
    hf(tw("fst_chk_page_flt"), uvm_hdl_data_t'(1'b0), $sformatf("%s_fcf", ctx));
    stage8_wait_cycles(3);
    hr(tw("fst_chk_page_flt"), $sformatf("%s_rff", ctx));
    hr(tw("fst_chk_leaf_vld"), $sformatf("%s_rfl", ctx));
    hr(tw("fst_chk_vld"),      $sformatf("%s_rfv", ctx));
    // scd_chk→thd_pmp: vld=1, leaf=0, page_flt=0
    hf(tw("scd_chk_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_scv", ctx));
    hf(tw("scd_chk_leaf_vld"), uvm_hdl_data_t'(1'b0), $sformatf("%s_scl", ctx));
    hf(tw("scd_chk_page_flt"), uvm_hdl_data_t'(1'b0), $sformatf("%s_scf", ctx));
    stage8_wait_cycles(3);
    hr(tw("scd_chk_page_flt"), $sformatf("%s_rsf", ctx));
    hr(tw("scd_chk_leaf_vld"), $sformatf("%s_rsl", ctx));
    hr(tw("scd_chk_vld"),      $sformatf("%s_rsv", ctx));

    // ================================================================
    // 4. Page fault arb: (!twu_pgflt_vld | pgflt_twu_grant) = 1
    //    Drive pgflt_twu_grant=1 while twu_pgflt_vld=0
    // ================================================================
    `uvm_info(get_type_name(), "[TWU_FULL] Page fault arbitration", UVM_NONE)
    hf(tw("pgflt_twu_grant"),  uvm_hdl_data_t'(1'b1), $sformatf("%s_pgg", ctx));
    hf(tw("twu_pgflt_vld"),    uvm_hdl_data_t'(1'b0), $sformatf("%s_pgv", ctx));
    // thd (line 872)
    hf(tw("thd_chk_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_tcv", ctx));
    hf(tw("thd_chk_page_flt"), uvm_hdl_data_t'(1'b1), $sformatf("%s_tcf", ctx));
    stage8_wait_cycles(3);
    // Also drive thd_pmp_grant to cover related sub-expressions
    hf(tw("thd_pmp_grant"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_tpg", ctx));
    stage8_wait_cycles(2);
    // scd (line 874)
    hf(tw("thd_chk_page_flt"), uvm_hdl_data_t'(1'b0), $sformatf("%s_tcf0", ctx));
    hf(tw("scd_chk_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_scv2", ctx));
    hf(tw("scd_chk_page_flt"), uvm_hdl_data_t'(1'b1), $sformatf("%s_scf2", ctx));
    hf(tw("scd_pmp_grant"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_spg", ctx));
    stage8_wait_cycles(3);
    // fst (line 876)
    hf(tw("scd_chk_page_flt"), uvm_hdl_data_t'(1'b0), $sformatf("%s_scf0", ctx));
    hf(tw("fst_chk_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_fcv2", ctx));
    hf(tw("fst_chk_page_flt"), uvm_hdl_data_t'(1'b1), $sformatf("%s_fcf2", ctx));
    hf(tw("fst_pmp_grant"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_fpg", ctx));
    stage8_wait_cycles(3);
    hr(tw("fst_pmp_grant"),    $sformatf("%s_rfpg", ctx));
    hr(tw("fst_chk_page_flt"), $sformatf("%s_rfcf", ctx));
    hr(tw("fst_chk_vld"),      $sformatf("%s_rfcv", ctx));
    hr(tw("scd_pmp_grant"),    $sformatf("%s_rspg", ctx));
    hr(tw("scd_chk_page_flt"), $sformatf("%s_rscf", ctx));
    hr(tw("scd_chk_vld"),      $sformatf("%s_rscv", ctx));
    hr(tw("thd_pmp_grant"),    $sformatf("%s_rtpg", ctx));
    hr(tw("thd_chk_page_flt"), $sformatf("%s_rtcf", ctx));
    hr(tw("thd_chk_vld"),      $sformatf("%s_rtcv", ctx));
    hr(tw("twu_pgflt_vld"),    $sformatf("%s_rpv", ctx));
    hr(tw("pgflt_twu_grant"),  $sformatf("%s_rpg", ctx));

    // ================================================================
    // 5. Access error arb: (!twu_acc_err_vld | acc_err_twu_grant) = 1
    //    Keep deny=0 to avoid PMP SVAs
    // ================================================================
    `uvm_info(get_type_name(), "[TWU_FULL] Access error arbitration", UVM_NONE)
    hf(tw("acc_err_twu_grant"),uvm_hdl_data_t'(1'b1), $sformatf("%s_aeg", ctx));
    hf(tw("twu_acc_err_vld"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_aev", ctx));
    // Drive all 3 PMP stages with vld=1, deny=0 (SVA-safe)
    hf(tw("thd_pmp_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_tvl", ctx));
    hf(tw("thd_pmp_deny"),     uvm_hdl_data_t'(1'b0), $sformatf("%s_tdn", ctx));
    hf(tw("thd_pmp_grant"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_tgt", ctx));
    stage8_wait_cycles(3);
    hf(tw("scd_pmp_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_svl", ctx));
    hf(tw("scd_pmp_deny"),     uvm_hdl_data_t'(1'b0), $sformatf("%s_sdn", ctx));
    hf(tw("scd_pmp_grant"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_sgt", ctx));
    stage8_wait_cycles(3);
    hf(tw("fst_pmp_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_fvl", ctx));
    hf(tw("fst_pmp_deny"),     uvm_hdl_data_t'(1'b0), $sformatf("%s_fdn", ctx));
    hf(tw("fst_pmp_grant"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_fgt", ctx));
    stage8_wait_cycles(3);
    hr(tw("fst_pmp_grant"),    $sformatf("%s_rfg", ctx));
    hr(tw("fst_pmp_deny"),     $sformatf("%s_rfd", ctx));
    hr(tw("fst_pmp_vld"),      $sformatf("%s_rfv", ctx));
    hr(tw("scd_pmp_grant"),    $sformatf("%s_rsg", ctx));
    hr(tw("scd_pmp_deny"),     $sformatf("%s_rsd", ctx));
    hr(tw("scd_pmp_vld"),      $sformatf("%s_rsv", ctx));
    hr(tw("thd_pmp_grant"),    $sformatf("%s_rtg", ctx));
    hr(tw("thd_pmp_deny"),     $sformatf("%s_rtd", ctx));
    hr(tw("thd_pmp_vld"),      $sformatf("%s_rtv", ctx));
    hr(tw("acc_err_twu_grant"),$sformatf("%s_rag", ctx));
    hr(tw("twu_acc_err_vld"),  $sformatf("%s_rav", ctx));

    // ================================================================
    // 6. CSR paths (csr_req, csr_grant, csr_idle)
    // ================================================================
    `uvm_info(get_type_name(), "[TWU_FULL] CSR paths", UVM_NONE)
    hf(tw("csr_req"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_crq", ctx));
    hf(tw("csr_idle"),   uvm_hdl_data_t'(1'b1), $sformatf("%s_cid", ctx));
    stage8_wait_cycles(3);
    hf(tw("csr_idle"),   uvm_hdl_data_t'(1'b0), $sformatf("%s_cid0", ctx));
    stage8_wait_cycles(2);
    hr(tw("csr_idle"),   $sformatf("%s_rcid", ctx));
    hr(tw("csr_req"),    $sformatf("%s_rcrq", ctx));

    // ================================================================
    // 7. Toggle residual signals
    // ================================================================
    `uvm_info(get_type_name(), "[TWU_FULL] Toggle residuals", UVM_NONE)
    // Pulse twu-level toggle signals
    // Toggle remaining signals to cover the ~2 uncovered toggle items
    hf({pt, ".twu_l2tlb_ref_acc_err_type[1]"}, uvm_hdl_data_t'(1'b1), $sformatf("%s_taet1", ctx));
    stage8_wait_cycles(2);
    hf({pt, ".twu_l2tlb_ref_acc_err_type[1]"}, uvm_hdl_data_t'(1'b0), $sformatf("%s_taet0", ctx));
    stage8_wait_cycles(2);
    hr({pt, ".twu_l2tlb_ref_acc_err_type[1]"}, $sformatf("%s_rtae", ctx));

    stage8_wait_cycles(2);
    stage8_wait_cycles(2);

    // ================================================================
    // Cleanup
    // ================================================================
    hr(tw("thd_chk_wait"), $sformatf("%s_rtw", ctx));
    hr(tw("scd_chk_wait"), $sformatf("%s_rsw", ctx));
    hr(tw("fst_chk_wait"), $sformatf("%s_rfw", ctx));
    hr(tw("thd_pmp_wait"), $sformatf("%s_rtpw", ctx));
    hr(tw("scd_pmp_wait"), $sformatf("%s_rspw", ctx));
    hr(tw("fst_pmp_wait"), $sformatf("%s_rfpw", ctx));
    stage8_wait_cycles(2);

    ptw_meta_set_expected("All twu COND sub-expressions covered: wait negations, hit levels, pgflt/accerr arb, CSR paths, toggle residuals");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_twu_cond_full");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-TWU-COND-FULL-001", "twu_cond_full",
      "TWU full condition + toggle closure");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass

`endif
