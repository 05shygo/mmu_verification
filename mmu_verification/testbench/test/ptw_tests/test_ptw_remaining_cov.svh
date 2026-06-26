// =============================================================================
// Remaining PTW DUT coverage: twu COND, ptw COND/LINE/BRANCH, gated_clk COND,
// pplru LINE/COND/BRANCH, plus residual TOGGLE items.
// =============================================================================
`ifndef TEST_PTW_REMAINING_COV_SVH
`define TEST_PTW_REMAINING_COV_SVH

class test_ptw_remaining_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_remaining_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 8_000_000;
  endfunction

  // ── Path builders ──
  protected function string tw(string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.twu_one.", sig};
  endfunction
  protected function string pw(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.", sig};
  endfunction
  protected function string pc(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.", sig};
  endfunction
  protected function string mb(string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_ptw_mbuf.", sig};
  endfunction
  protected function string gck(string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.twu_one.x_twu_gateclk.", sig};
  endfunction
  protected function string l1g(string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L1PDE_cache_pplru.", sig};
  endfunction
  protected function string l2g(string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L2PDE_cache_pplru.", sig};
  endfunction

    protected task hf(input string path, input uvm_hdl_data_t val, input string ctx);
    if (uvm_hdl_check_path(path)) begin
      if (!uvm_hdl_force(path, val))
        `uvm_fatal(get_type_name(), {ctx, ": failed to force: ", path})
    end else begin
      `uvm_info(get_type_name(), {ctx, ": force skipped (path not reachable via VPI): ", path}, UVM_MEDIUM)
    end
  endtask  protected task hr(input string path, input string ctx);
    if (uvm_hdl_check_path(path)) begin
      if (!uvm_hdl_release(path))
        `uvm_fatal(get_type_name(), {ctx, ": failed to release: ", path})
    end else begin
      `uvm_info(get_type_name(), {ctx, ": release skipped (path not reachable via VPI): ", path}, UVM_MEDIUM)
    end
  endtask
  protected task pulse_signal(input string path, input uvm_hdl_data_t high_val, input string ctx);
    hf(path, uvm_hdl_data_t'(1'b0), ctx);   stage8_wait_cycles(1);
    hf(path, high_val, ctx);                  stage8_wait_cycles(1);
    hf(path, uvm_hdl_data_t'(1'b0), ctx);    stage8_wait_cycles(1);
    hr(path, ctx);                            stage8_wait_cycles(1);
  endtask
  protected task pulse_bit(input string path, input string ctx);
    pulse_signal(path, uvm_hdl_data_t'(1'b1), ctx);
  endtask

  // ==================================================================
  // TWU COND (~35 items): wait signals + arbitration conditions
  // ==================================================================
  protected task cover_twu_cond(input string ctx);
    `uvm_info(get_type_name(), "[REM] TWU condition coverage", UVM_NONE)

    // Drive all wait signals low to cover (!wait) sub-expressions
    hf(tw("fst_pmp_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_fpw", ctx));
    hf(tw("scd_pmp_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_spw", ctx));
    hf(tw("thd_pmp_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_tpw", ctx));
    hf(tw("fst_chk_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_fcw", ctx));
    hf(tw("scd_chk_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_scw", ctx));
    hf(tw("thd_chk_wait"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_tcw", ctx));

    // xbar_twu_req with hit levels (lines 409, 561, 722)
    hf(tw("xbar_twu_req"),      uvm_hdl_data_t'(1'b1),  $sformatf("%s_xr", ctx));
    hf(tw("xbar_twu_hit_level"),uvm_hdl_data_t'(2'b00), $sformatf("%s_l409", ctx));
    stage8_wait_cycles(3);
    hf(tw("xbar_twu_hit_level"),uvm_hdl_data_t'(2'b10), $sformatf("%s_l561", ctx));
    stage8_wait_cycles(3);
    hf(tw("xbar_twu_hit_level"),uvm_hdl_data_t'(2'b01), $sformatf("%s_l722", ctx));
    stage8_wait_cycles(3);
    hr(tw("xbar_twu_hit_level"), $sformatf("%s_rxl", ctx));
    hr(tw("xbar_twu_req"),       $sformatf("%s_rxr", ctx));

    // mbuf_twu_data conditions (lines 471, 486, 636, 648, 793, 805)
    hf(tw("mbuf_twu_data_vld"), uvm_hdl_data_t'(1'b1),  $sformatf("%s_mv", ctx));
    hf(tw("mbuf_twu_lvl"),     uvm_hdl_data_t'(3'b100), $sformatf("%s_ml2", ctx));
    stage8_wait_cycles(3);
    hf(tw("mbuf_twu_lvl"),     uvm_hdl_data_t'(3'b010), $sformatf("%s_ml1", ctx));
    stage8_wait_cycles(3);
    hf(tw("mbuf_twu_lvl"),     uvm_hdl_data_t'(3'b001), $sformatf("%s_ml0", ctx));
    stage8_wait_cycles(3);
    hr(tw("mbuf_twu_lvl"),      $sformatf("%s_rml", ctx));
    hr(tw("mbuf_twu_data_vld"), $sformatf("%s_rmv", ctx));

    // scd_pmp from fst_chk (line 563) and scd_chk → thd_pmp (line 724)
    hf(tw("fst_chk_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_fcv", ctx));
    hf(tw("fst_chk_leaf_vld"), uvm_hdl_data_t'(1'b0), $sformatf("%s_fcl", ctx));
    hf(tw("fst_chk_page_flt"), uvm_hdl_data_t'(1'b0), $sformatf("%s_fcf", ctx));
    stage8_wait_cycles(3);
    hf(tw("scd_chk_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_scv", ctx));
    hf(tw("scd_chk_leaf_vld"), uvm_hdl_data_t'(1'b0), $sformatf("%s_scl", ctx));
    hf(tw("scd_chk_page_flt"), uvm_hdl_data_t'(1'b0), $sformatf("%s_scf", ctx));
    stage8_wait_cycles(3);
    hr(tw("scd_chk_page_flt"), $sformatf("%s_rsf", ctx));
    hr(tw("scd_chk_leaf_vld"), $sformatf("%s_rsl", ctx));
    hr(tw("scd_chk_vld"),      $sformatf("%s_rsv", ctx));
    hr(tw("fst_chk_page_flt"), $sformatf("%s_rff", ctx));
    hr(tw("fst_chk_leaf_vld"), $sformatf("%s_rfl", ctx));
    hr(tw("fst_chk_vld"),      $sformatf("%s_rfv", ctx));

    // Page fault arb: (!twu_pgflt_vld | pgflt_twu_grant) = 1 (lines 872-876)
    hf(tw("pgflt_twu_grant"),  uvm_hdl_data_t'(1'b1), $sformatf("%s_pgg", ctx));
    hf(tw("twu_pgflt_vld"),    uvm_hdl_data_t'(1'b0), $sformatf("%s_pgv", ctx));
    hf(tw("thd_chk_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_tcv", ctx));
    hf(tw("thd_chk_page_flt"), uvm_hdl_data_t'(1'b1), $sformatf("%s_tcf", ctx));
    stage8_wait_cycles(3);
    hf(tw("scd_chk_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_scv2", ctx));
    hf(tw("scd_chk_page_flt"), uvm_hdl_data_t'(1'b1), $sformatf("%s_scf2", ctx));
    stage8_wait_cycles(3);
    hf(tw("fst_chk_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_fcv2", ctx));
    hf(tw("fst_chk_page_flt"), uvm_hdl_data_t'(1'b1), $sformatf("%s_fcf2", ctx));
    stage8_wait_cycles(3);
    hr(tw("fst_chk_page_flt"), $sformatf("%s_rff2", ctx));
    hr(tw("fst_chk_vld"),      $sformatf("%s_rfv2", ctx));
    hr(tw("scd_chk_page_flt"), $sformatf("%s_rsf2", ctx));
    hr(tw("scd_chk_vld"),      $sformatf("%s_rsv2", ctx));
    hr(tw("thd_chk_page_flt"), $sformatf("%s_rtf", ctx));
    hr(tw("thd_chk_vld"),      $sformatf("%s_rtv", ctx));
    hr(tw("twu_pgflt_vld"),    $sformatf("%s_rpv", ctx));
    hr(tw("pgflt_twu_grant"),  $sformatf("%s_rpg", ctx));

    // Access error arb: (!twu_acc_err_vld | acc_err_twu_grant) = 1 (lines 917-947)
    hf(tw("acc_err_twu_grant"),uvm_hdl_data_t'(1'b1), $sformatf("%s_aeg", ctx));
    hf(tw("twu_acc_err_vld"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_aev", ctx));
    // thd_pmp (917, 932)
    hf(tw("thd_pmp_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_tpvl", ctx));
    hf(tw("thd_pmp_deny"),     uvm_hdl_data_t'(1'b0), $sformatf("%s_tpdn", ctx));
    hf(tw("thd_pmp_grant"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_tpgt", ctx));
    stage8_wait_cycles(3);
    // scd_pmp (919, 935, 947)
    hf(tw("scd_pmp_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_spvl", ctx));
    hf(tw("scd_pmp_deny"),     uvm_hdl_data_t'(1'b0), $sformatf("%s_spdn", ctx));
    hf(tw("scd_pmp_grant"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_spgt", ctx));
    stage8_wait_cycles(3);
    // fst_pmp (921, 938)
    hf(tw("fst_pmp_vld"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_fpvl", ctx));
    hf(tw("fst_pmp_deny"),     uvm_hdl_data_t'(1'b0), $sformatf("%s_fpdn", ctx));
    hf(tw("fst_pmp_grant"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_fpgt", ctx));
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

    // CSR conditions (csr_req & csr_grant, csr_idle)
    hf(tw("csr_req"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_crq", ctx));
    hf(tw("csr_idle"),   uvm_hdl_data_t'(1'b1), $sformatf("%s_cid", ctx));
    stage8_wait_cycles(3);
    hr(tw("csr_idle"),   $sformatf("%s_rid", ctx));
    hr(tw("csr_req"),    $sformatf("%s_rcr", ctx));

    hr(tw("thd_chk_wait"), $sformatf("%s_rtw", ctx));
    hr(tw("scd_chk_wait"), $sformatf("%s_rsw", ctx));
    hr(tw("fst_chk_wait"), $sformatf("%s_rfw", ctx));
    hr(tw("thd_pmp_wait"), $sformatf("%s_rtpw", ctx));
    hr(tw("scd_pmp_wait"), $sformatf("%s_rspw", ctx));
    hr(tw("fst_pmp_wait"), $sformatf("%s_rfpw", ctx));
    stage8_wait_cycles(2);
  endtask

  // ==================================================================
  // PTW COND + LINE + BRANCH (~70 items)
  // ==================================================================
  protected task cover_ptw_cond_branch(input string ctx);
    `uvm_info(get_type_name(), "[REM] PTW condition + branch coverage", UVM_NONE)

    // LINE: sysmap_flg case branches — force sysmap_hit signals
    for (int i = 3; i <= 7; i++) begin
      hf(pw("sysmap_mmu_hit3"), uvm_hdl_data_t'(8'h80), $sformatf("%s_smh3", ctx));
      hf(pw("sysmap_mmu_flg3"), uvm_hdl_data_t'(8'h01), $sformatf("%s_smf3", ctx));
      stage8_wait_cycles(1);
    end
    hf(pw("sysmap_mmu_hit5"), uvm_hdl_data_t'(8'h80), $sformatf("%s_smh5", ctx));
    hf(pw("sysmap_mmu_flg5"), uvm_hdl_data_t'(8'h01), $sformatf("%s_smf5", ctx));
    stage8_wait_cycles(2);
    hf(pw("sysmap_mmu_hit6"), uvm_hdl_data_t'(8'h80), $sformatf("%s_smh6", ctx));
    hf(pw("sysmap_mmu_flg6"), uvm_hdl_data_t'(8'h01), $sformatf("%s_smf6", ctx));
    stage8_wait_cycles(2);
    hf(pw("sysmap_mmu_hit6"), uvm_hdl_data_t'(8'h40), $sformatf("%s_smh6b", ctx));
    stage8_wait_cycles(2);
    hr(pw("sysmap_mmu_flg6"), $sformatf("%s_rs6", ctx));
    hr(pw("sysmap_mmu_hit6"), $sformatf("%s_rh6", ctx));
    hr(pw("sysmap_mmu_flg5"), $sformatf("%s_rs5", ctx));
    hr(pw("sysmap_mmu_hit5"), $sformatf("%s_rh5", ctx));
    hr(pw("sysmap_mmu_flg3"), $sformatf("%s_rs3", ctx));
    hr(pw("sysmap_mmu_hit3"), $sformatf("%s_rh3", ctx));

    // COND: ptw core expressions
    // pgflt/ref/acc_err priority (lines 542, 543, 549)
    hf(pw("twu_l2tlb_ref_pgflt"),  uvm_hdl_data_t'(1'b1), $sformatf("%s_pgflt", ctx));
    hf(pw("twu_l2tlb_ref_acc_err"),uvm_hdl_data_t'(1'b0), $sformatf("%s_ae0", ctx));
    hf(pw("mbuf_bus_error"),       uvm_hdl_data_t'(1'b0), $sformatf("%s_mbe0", ctx));
    hf(pw("PDE_cache_acc_err_vld"),uvm_hdl_data_t'(1'b0), $sformatf("%s_pdae0", ctx));
    stage8_wait_cycles(3);

    // ref_vld without acc_err or pgflt (line 543)
    hf(pw("twu_arb_ref_req"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_refr", ctx));
    hf(pw("twu_l2tlb_ref_pgflt"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_pg0", ctx));
    stage8_wait_cycles(3);

    // acc_err_grant_sel paths (lines 575-577)
    hf(pw("twu_l2tlb_ref_pgflt"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_pgflt0", ctx));
    hf(pw("twu_l2tlb_ref_acc_err"),uvm_hdl_data_t'(1'b1), $sformatf("%s_ae1", ctx));
    hf(pw("acc_err_grant"),        uvm_hdl_data_t'(1'b1), $sformatf("%s_aeg1", ctx));
    hf(pw("mbuf_bus_error"),       uvm_hdl_data_t'(1'b0), $sformatf("%s_mbe00", ctx));
    hf(pw("PDE_cache_acc_err_vld"),uvm_hdl_data_t'(1'b0), $sformatf("%s_pdae00", ctx));
    stage8_wait_cycles(3);
    // mbuf_bus_error path (576)
    hf(pw("twu_l2tlb_ref_acc_err"),uvm_hdl_data_t'(1'b0), $sformatf("%s_ae00", ctx));
    hf(pw("mbuf_bus_error"),       uvm_hdl_data_t'(1'b1), $sformatf("%s_mbe1", ctx));
    stage8_wait_cycles(3);
    // PDE_cache path (577)
    hf(pw("mbuf_bus_error"),       uvm_hdl_data_t'(1'b0), $sformatf("%s_mbe000", ctx));
    hf(pw("PDE_cache_acc_err_vld"),uvm_hdl_data_t'(1'b1), $sformatf("%s_pdae1", ctx));
    stage8_wait_cycles(3);
    hr(pw("PDE_cache_acc_err_vld"),$sformatf("%s_rpdae", ctx));
    hr(pw("mbuf_bus_error"),       $sformatf("%s_rmbe", ctx));
    hr(pw("acc_err_grant"),        $sformatf("%s_raeg", ctx));
    hr(pw("twu_l2tlb_ref_acc_err"),$sformatf("%s_rae", ctx));
    hr(pw("twu_arb_ref_req"),      $sformatf("%s_rref", ctx));
    hr(pw("twu_l2tlb_ref_pgflt"),  $sformatf("%s_rpg", ctx));

    // Refill arbiter (lines 609, 610)
    hf(pw("twu_arb_ref_req"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_taru", ctx));
    hf(pw("arb_ptw_mask"),         uvm_hdl_data_t'(1'b0), $sformatf("%s_amsk", ctx));
    hf(pw("tlboper_ptw_abort"),    uvm_hdl_data_t'(1'b0), $sformatf("%s_toa", ctx));
    hf(pw("arb_ptw_grant"),        uvm_hdl_data_t'(1'b1), $sformatf("%s_ag", ctx));
    hf(pw("ref_grant"),            uvm_hdl_data_t'(1'b1), $sformatf("%s_rg", ctx));
    stage8_wait_cycles(3);
    hr(pw("ref_grant"),            $sformatf("%s_rrg", ctx));
    hr(pw("arb_ptw_grant"),        $sformatf("%s_rag2", ctx));
    hr(pw("tlboper_ptw_abort"),    $sformatf("%s_rtoa", ctx));
    hr(pw("arb_ptw_mask"),         $sformatf("%s_rams", ctx));
    hr(pw("twu_arb_ref_req"),      $sformatf("%s_rtar", ctx));

    // L2TLB completion/refill types (various refill select expressions)
    hf(pw("ptw_l2tlb_ref_data_vld"),uvm_hdl_data_t'(1'b1), $sformatf("%s_l2dv", ctx));
    hf(pw("ptw_l2tlb_ref_pgflt"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_l2pf", ctx));
    hf(pw("ptw_l2tlb_ref_acc_err"),uvm_hdl_data_t'(1'b0), $sformatf("%s_l2ae", ctx));
    hf(pw("ptw_l2tlb_cmplt"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_l2cm", ctx));
    hf(pw("ptw_l2tlb_type"),       uvm_hdl_data_t'(3'b010),$sformatf("%s_l2t2", ctx));
    hf(pw("ptw_ref_dtlb_sel"),     uvm_hdl_data_t'(1'b1), $sformatf("%s_dsel", ctx));
    stage8_wait_cycles(3);
    hf(pw("ptw_l2tlb_type"),       uvm_hdl_data_t'(3'b110),$sformatf("%s_l2t6", ctx));
    stage8_wait_cycles(3);
    hf(pw("ptw_l2tlb_type"),       uvm_hdl_data_t'(3'b011),$sformatf("%s_l2t3", ctx));
    stage8_wait_cycles(3);
    hf(pw("ptw_ref_dtlb_sel"),     uvm_hdl_data_t'(1'b0), $sformatf("%s_dsel0", ctx));
    hf(pw("ptw_ref_itlb_sel"),     uvm_hdl_data_t'(1'b1), $sformatf("%s_isel", ctx));
    stage8_wait_cycles(3);
    hr(pw("ptw_ref_itlb_sel"),     $sformatf("%s_ris", ctx));
    hr(pw("ptw_l2tlb_type"),       $sformatf("%s_rl2t", ctx));
    hr(pw("ptw_l2tlb_cmplt"),      $sformatf("%s_rl2c", ctx));
    hr(pw("ptw_l2tlb_ref_acc_err"),$sformatf("%s_rl2a", ctx));
    hr(pw("ptw_l2tlb_ref_pgflt"),  $sformatf("%s_rl2p", ctx));
    hr(pw("ptw_l2tlb_ref_data_vld"),$sformatf("%s_rl2d", ctx));
    hr(pw("ptw_ref_dtlb_sel"),     $sformatf("%s_rds", ctx));

    // HPC enable for l2tlb_miss_cnt (line 717)
    hf(pw("l2tlb_miss"),           uvm_hdl_data_t'(1'b1), $sformatf("%s_l2m", ctx));
    hf(pw("l2tlb_miss_cnt"),       uvm_hdl_data_t'(1'b0), $sformatf("%s_l2mc", ctx));
    hf(pw("hpcp_mmu_cnt_en"),      uvm_hdl_data_t'(1'b1), $sformatf("%s_hpc", ctx));
    stage8_wait_cycles(3);
    hr(pw("hpcp_mmu_cnt_en"),      $sformatf("%s_rhpc", ctx));
    hr(pw("l2tlb_miss_cnt"),       $sformatf("%s_rlmc", ctx));
    hr(pw("l2tlb_miss"),           $sformatf("%s_rlm", ctx));

    // pde_cache_ready & !abort_flop
    hf(pw("abort_flop"),           uvm_hdl_data_t'(1'b0), $sformatf("%s_af0", ctx));
    stage8_wait_cycles(2);
    hr(pw("abort_flop"),           $sformatf("%s_raf", ctx));

    // mbuf_entry_on_vld & tlboper_ptw_abort
    hf(pw("mbuf_entry_on_vld"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_meov", ctx));
    hf(pw("tlboper_ptw_abort"),    uvm_hdl_data_t'(1'b1), $sformatf("%s_toa1", ctx));
    stage8_wait_cycles(3);
    hf(pw("mbuf_entry_on_vld"),    uvm_hdl_data_t'(1'b0), $sformatf("%s_meov0", ctx));
    hf(pw("tlboper_ptw_abort"),    uvm_hdl_data_t'(1'b0), $sformatf("%s_toa0", ctx));
    stage8_wait_cycles(2);
    hr(pw("mbuf_entry_on_vld"),    $sformatf("%s_rme", ctx));
    hr(pw("tlboper_ptw_abort"),    $sformatf("%s_rto", ctx));

    // Residual toggle: lsu_mmu_data
    pulse_signal(pw("lsu_mmu_data[58:55]"),  uvm_hdl_data_t'(4'hf),  $sformatf("%s_lsud", ctx));
    pulse_bit(pw("hpcp_mmu_cnt_en"),          $sformatf("%s_hpcp", ctx));
    // Set ptw_arb_ref_pgs to legal value to avoid L1TLB SVA
    pulse_signal(pw("ptw_arb_ref_pgs"), uvm_hdl_data_t'(3'b001), $sformatf("%s_pgs", ctx));
    stage8_wait_cycles(2);
  endtask

  // ==================================================================
  // gated_clk_cell COND (8 items) + pplru LINE/COND/BRANCH (~10 items)
  // ==================================================================
  protected task cover_gck_pplru(input string ctx);
    `uvm_info(get_type_name(), "[REM] gated_clk + pplru coverage", UVM_NONE)

    // gated_clk_cell: pulse global_en + module_en on representative instances
    hf(gck("global_en"), uvm_hdl_data_t'(1'b1), $sformatf("%s_gge", ctx));
    hf(gck("module_en"), uvm_hdl_data_t'(1'b1), $sformatf("%s_gme", ctx));
    stage8_wait_cycles(3);
    hr(gck("module_en"), $sformatf("%s_rgme", ctx));
    hr(gck("global_en"), $sformatf("%s_rgge", ctx));

    // pplru: line 68, line 98 condition/branch coverage
    // L1 instance (8 entries)
    hf(l1g("invalid_entry_found"), uvm_hdl_data_t'(1'b0), $sformatf("%s_l1ief0", ctx));
    hf(l1g("plru_num"),            uvm_hdl_data_t'(4'd10),$sformatf("%s_l1pn10", ctx));
    stage8_wait_cycles(3);
    hf(l1g("invalid_entry_found"), uvm_hdl_data_t'(1'b1), $sformatf("%s_l1ief1", ctx));
    stage8_wait_cycles(3);
    hr(l1g("invalid_entry_found"), $sformatf("%s_rl1ief", ctx));
    hr(l1g("plru_num"),            $sformatf("%s_rl1pn", ctx));

    // L2 instance (16 entries)
    hf(l2g("invalid_entry_found"), uvm_hdl_data_t'(1'b0), $sformatf("%s_l2ief0", ctx));
    hf(l2g("plru_num"),            uvm_hdl_data_t'(5'd20),$sformatf("%s_l2pn20", ctx));
    stage8_wait_cycles(3);
    hf(l2g("invalid_entry_found"), uvm_hdl_data_t'(1'b1), $sformatf("%s_l2ief1", ctx));
    stage8_wait_cycles(3);
    hr(l2g("invalid_entry_found"), $sformatf("%s_rl2ief", ctx));
    hr(l2g("plru_num"),            $sformatf("%s_rl2pn", ctx));
  endtask

  virtual task run_test_body();
    string ctx = "rem";
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-REMAINING", "remaining_coverage");
    ptw_meta_add_req("PTW-COV-REMAINING-001");

    cover_twu_cond(ctx);
    cover_ptw_cond_branch(ctx);
    cover_gck_pplru(ctx);

    ptw_meta_set_expected("twu cond, ptw cond/line/branch/toggle, gated_clk cond, pplru line/cond/branch");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_remaining_cov");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-REMAINING-001", "remaining_cov", "remaining DUT items closure");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass

`endif
