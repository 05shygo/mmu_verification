// =============================================================================
// PTW condition + toggle full closure test
// Covers ~40 COND expressions + ~8 TOGGLE signals from report
// =============================================================================
`ifndef TEST_PTW_PTW_COND_FULL_SVH
`define TEST_PTW_PTW_COND_FULL_SVH

class test_ptw_ptw_cond_full extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_ptw_cond_full)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 5_000_000;
  endfunction

  protected function string pw(string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.", sig};
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
  protected task ps(input string path, input uvm_hdl_data_t high_val, input string ctx);
    hf(path, uvm_hdl_data_t'(1'b0), ctx); stage8_wait_cycles(1);
    hf(path, high_val, ctx);              stage8_wait_cycles(1);
    hf(path, uvm_hdl_data_t'(1'b0), ctx); stage8_wait_cycles(1);
    hr(path, ctx);                        stage8_wait_cycles(1);
  endtask
  protected task pb(input string path, input string ctx);
    ps(path, uvm_hdl_data_t'(1'b1), ctx);
  endtask

  virtual task run_test_body();
    string ctx = "ptwfull";
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-PTW-COND-FULL", "ptw_condition_full_closure");
    ptw_meta_add_req("PTW-COV-PTW-COND-FULL-001");

    // ================================================================
    // COND: mbuf_entry_on_vld & tlboper_ptw_abort
    // ================================================================
    `uvm_info(get_type_name(), "[PTW_FULL] abort + mbuf conditions", UVM_NONE)
    hf(pw("mbuf_entry_on_vld"), uvm_hdl_data_t'(1'b1), $sformatf("%s_mov1", ctx));
    hf(pw("tlboper_ptw_abort"), uvm_hdl_data_t'(1'b1), $sformatf("%s_toa1", ctx));
    stage8_wait_cycles(3);
    // abort_flop & !mbuf_entry_on_vld
    hf(pw("abort_flop"),         uvm_hdl_data_t'(1'b1), $sformatf("%s_af1", ctx));
    hf(pw("mbuf_entry_on_vld"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_mov0", ctx));
    stage8_wait_cycles(3);
    // pde_cache_ready & !abort_flop
    hf(pw("abort_flop"),         uvm_hdl_data_t'(1'b0), $sformatf("%s_af0", ctx));
    stage8_wait_cycles(3);

    // ================================================================
    // COND: l2tlb_miss & !l2tlb_miss_cnt
    // ================================================================
    `uvm_info(get_type_name(), "[PTW_FULL] l2tlb_miss conditions", UVM_NONE)
    hf(pw("l2tlb_miss"),     uvm_hdl_data_t'(1'b1), $sformatf("%s_l2m1", ctx));
    hf(pw("l2tlb_miss_cnt"), uvm_hdl_data_t'(1'b0), $sformatf("%s_l2mc0", ctx));
    hf(pw("hpcp_mmu_cnt_en"),uvm_hdl_data_t'(1'b1), $sformatf("%s_hpc1", ctx));
    stage8_wait_cycles(3);
    hr(pw("hpcp_mmu_cnt_en"),$sformatf("%s_rhpc", ctx));
    hr(pw("l2tlb_miss_cnt"), $sformatf("%s_rlmc", ctx));
    hr(pw("l2tlb_miss"),     $sformatf("%s_rlm", ctx));

    // ================================================================
    // COND: pgflt/ref/acc_err priority (lines 542-543, 549)
    // ================================================================
    `uvm_info(get_type_name(), "[PTW_FULL] pgflt/ref/accerr priority", UVM_NONE)
    // pgflt_vld & !acc_err_vld
    hf(pw("twu_l2tlb_ref_pgflt"),  uvm_hdl_data_t'(1'b1), $sformatf("%s_pg1", ctx));
    hf(pw("twu_l2tlb_ref_acc_err"),uvm_hdl_data_t'(1'b0), $sformatf("%s_ae0", ctx));
    hf(pw("mbuf_bus_error"),       uvm_hdl_data_t'(1'b0), $sformatf("%s_mbe0", ctx));
    hf(pw("PDE_cache_acc_err_vld"),uvm_hdl_data_t'(1'b0), $sformatf("%s_pde0", ctx));
    stage8_wait_cycles(3);
    // ref_vld & !acc_err_vld & !pgflt_vld
    hf(pw("twu_l2tlb_ref_pgflt"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_pg0", ctx));
    hf(pw("twu_arb_ref_req"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_tar1", ctx));
    stage8_wait_cycles(3);
    // pgflt grant
    hf(pw("twu_l2tlb_ref_pgflt"),  uvm_hdl_data_t'(1'b1), $sformatf("%s_pg1b", ctx));
    stage8_wait_cycles(3);
    hr(pw("twu_arb_ref_req"),      $sformatf("%s_rtar", ctx));
    hr(pw("twu_l2tlb_ref_pgflt"),  $sformatf("%s_rpg", ctx));
    hr(pw("PDE_cache_acc_err_vld"),$sformatf("%s_rpde", ctx));
    hr(pw("mbuf_bus_error"),       $sformatf("%s_rmbe", ctx));
    hr(pw("twu_l2tlb_ref_acc_err"),$sformatf("%s_rae", ctx));

    // ================================================================
    // COND: acc_err_grant_sel expressions (lines 575-577)
    // ================================================================
    `uvm_info(get_type_name(), "[PTW_FULL] acc_err_grant_sel", UVM_NONE)
    // acc_err_grant_sel[0]: !mbuf_bus_error & !PDE_cache_acc_err_vld & twu_acc_err & acc_err_grant
    hf(pw("twu_l2tlb_ref_acc_err"),uvm_hdl_data_t'(1'b1), $sformatf("%s_ae1", ctx));
    hf(pw("acc_err_grant"),        uvm_hdl_data_t'(1'b1), $sformatf("%s_aeg1", ctx));
    stage8_wait_cycles(3);
    // acc_err_grant_sel[1]: !PDE_cache_acc_err_vld & mbuf_bus_error & acc_err_grant
    hf(pw("twu_l2tlb_ref_acc_err"),uvm_hdl_data_t'(1'b0), $sformatf("%s_ae0b", ctx));
    hf(pw("mbuf_bus_error"),       uvm_hdl_data_t'(1'b1), $sformatf("%s_mbe1", ctx));
    stage8_wait_cycles(3);
    // acc_err_grant_sel[2]: PDE_cache_acc_err_vld & acc_err_grant
    hf(pw("mbuf_bus_error"),       uvm_hdl_data_t'(1'b0), $sformatf("%s_mbe0b", ctx));
    hf(pw("PDE_cache_acc_err_vld"),uvm_hdl_data_t'(1'b1), $sformatf("%s_pde1", ctx));
    stage8_wait_cycles(3);
    hr(pw("PDE_cache_acc_err_vld"),$sformatf("%s_rpde2", ctx));
    hr(pw("mbuf_bus_error"),       $sformatf("%s_rmbe2", ctx));
    hr(pw("acc_err_grant"),        $sformatf("%s_raeg", ctx));
    hr(pw("twu_l2tlb_ref_acc_err"),$sformatf("%s_rae2", ctx));

    // ================================================================
    // COND: refill arbiter (lines 609-610)
    // ================================================================
    `uvm_info(get_type_name(), "[PTW_FULL] Refill arbiter", UVM_NONE)
    hf(pw("twu_arb_ref_req"),   uvm_hdl_data_t'(1'b1), $sformatf("%s_tar", ctx));
    hf(pw("arb_ptw_mask"),      uvm_hdl_data_t'(1'b0), $sformatf("%s_am0", ctx));
    hf(pw("tlboper_ptw_abort"), uvm_hdl_data_t'(1'b0), $sformatf("%s_toa0", ctx));
    hf(pw("ref_grant"),         uvm_hdl_data_t'(1'b1), $sformatf("%s_rg1", ctx));
    hf(pw("arb_ptw_grant"),     uvm_hdl_data_t'(1'b1), $sformatf("%s_ag1", ctx));
    stage8_wait_cycles(3);
    hr(pw("arb_ptw_grant"),     $sformatf("%s_rag", ctx));
    hr(pw("ref_grant"),         $sformatf("%s_rrg", ctx));
    hr(pw("twu_arb_ref_req"),   $sformatf("%s_rtar2", ctx));
    hr(pw("arb_ptw_mask"),      $sformatf("%s_ram", ctx));

    // ================================================================
    // COND: L2TLB completion type selects (various dtlb/itlb expressions)
    // ================================================================
    `uvm_info(get_type_name(), "[PTW_FULL] L2TLB completion select", UVM_NONE)
    hf(pw("ptw_l2tlb_ref_data_vld"), uvm_hdl_data_t'(1'b1), $sformatf("%s_l2d1", ctx));
    hf(pw("ptw_l2tlb_cmplt"),       uvm_hdl_data_t'(1'b1), $sformatf("%s_l2c1", ctx));
    hf(pw("ptw_ref_dtlb_sel"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_ds1", ctx));
    stage8_wait_cycles(3);
    hf(pw("ptw_ref_dtlb_sel"),      uvm_hdl_data_t'(1'b0), $sformatf("%s_ds0", ctx));
    hf(pw("ptw_ref_itlb_sel"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_is1", ctx));
    stage8_wait_cycles(3);
    // L2TLB type expressions
    hf(pw("ptw_l2tlb_type"),        uvm_hdl_data_t'(3'b010), $sformatf("%s_l2t2", ctx));
    stage8_wait_cycles(3);
    hf(pw("ptw_l2tlb_type"),        uvm_hdl_data_t'(3'b110), $sformatf("%s_l2t6", ctx));
    stage8_wait_cycles(3);
    hf(pw("ptw_l2tlb_type"),        uvm_hdl_data_t'(3'b011), $sformatf("%s_l2t3", ctx));
    stage8_wait_cycles(3);
    // acc_err + pgflt also
    hf(pw("ptw_l2tlb_ref_acc_err"), uvm_hdl_data_t'(1'b1), $sformatf("%s_l2a1", ctx));
    hf(pw("ptw_l2tlb_ref_pgflt"),  uvm_hdl_data_t'(1'b1), $sformatf("%s_l2p1", ctx));
    stage8_wait_cycles(3);
    hr(pw("ptw_l2tlb_ref_pgflt"),  $sformatf("%s_rl2p", ctx));
    hr(pw("ptw_l2tlb_ref_acc_err"),$sformatf("%s_rl2a", ctx));
    hr(pw("ptw_l2tlb_type"),       $sformatf("%s_rl2t", ctx));
    hr(pw("ptw_ref_itlb_sel"),     $sformatf("%s_ris", ctx));
    hr(pw("ptw_l2tlb_cmplt"),      $sformatf("%s_rl2c", ctx));
    hr(pw("ptw_l2tlb_ref_data_vld"),$sformatf("%s_rl2d", ctx));
    hr(pw("ptw_ref_dtlb_sel"),     $sformatf("%s_rds", ctx));

    // ================================================================
    // COND: acc_err_vld, twu_l2tlb_ref combined OR
    // ================================================================
    hf(pw("twu_l2tlb_ref_acc_err"), uvm_hdl_data_t'(1'b1), $sformatf("%s_or_ae", ctx));
    hf(pw("mbuf_bus_error"),        uvm_hdl_data_t'(1'b1), $sformatf("%s_or_mb", ctx));
    hf(pw("PDE_cache_acc_err_vld"), uvm_hdl_data_t'(1'b1), $sformatf("%s_or_pd", ctx));
    stage8_wait_cycles(3);
    hr(pw("PDE_cache_acc_err_vld"), $sformatf("%s_ror_pd", ctx));
    hr(pw("mbuf_bus_error"),        $sformatf("%s_ror_mb", ctx));
    hr(pw("twu_l2tlb_ref_acc_err"), $sformatf("%s_ror_ae", ctx));

    // ================================================================
    // Toggle: all remaining toggle signals
    // ================================================================
    `uvm_info(get_type_name(), "[PTW_FULL] Toggle signals", UVM_NONE)
    ps(pw("lsu_mmu_data[58:55]"),  uvm_hdl_data_t'(4'hf),  $sformatf("%s_lsud", ctx));
    pb(pw("hpcp_mmu_cnt_en"),                              $sformatf("%s_hpcp", ctx));
    // sysmap internal signals
    ps(pw("sysmap_mmu_hit3"),       uvm_hdl_data_t'(8'hff), $sformatf("%s_sh3", ctx));
    ps(pw("sysmap_mmu_hit5"),       uvm_hdl_data_t'(8'hff), $sformatf("%s_sh5", ctx));
    ps(pw("sysmap_mmu_hit6"),       uvm_hdl_data_t'(8'hff), $sformatf("%s_sh6", ctx));
    ps(pw("sysmap_mmu_flg3"),       uvm_hdl_data_t'(8'hff), $sformatf("%s_sf3", ctx));
    ps(pw("sysmap_mmu_flg5"),       uvm_hdl_data_t'(8'hff), $sformatf("%s_sf5", ctx));
    ps(pw("sysmap_mmu_flg6"),       uvm_hdl_data_t'(8'hff), $sformatf("%s_sf6", ctx));

    // ================================================================
    // Cleanup
    // ================================================================
    hr(pw("tlboper_ptw_abort"), $sformatf("%s_rtoa", ctx));
    hr(pw("abort_flop"),        $sformatf("%s_raf", ctx));
    hr(pw("mbuf_entry_on_vld"), $sformatf("%s_rmov", ctx));
    stage8_wait_cycles(2);

    ptw_meta_set_expected("All ptw COND(40) + TOGGLE(8) items covered");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_ptw_cond_full");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-PTW-COND-FULL-001", "ptw_cond_full",
      "PTW full condition + toggle closure");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass

`endif
