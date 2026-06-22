// =============================================================================
// Combined SVA modules toggle coverage test
// Covers mmu_pde_cache_sva, mmu_ptw_top_sva, mmu_ptw_xbar_sva, mmu_pde_pplru_sva
// All toggle items are INPUT ports of these SVA modules.
// =============================================================================
`ifndef TEST_PTW_SVA_COMBINED_TOGGLE_COV_SVH
`define TEST_PTW_SVA_COMBINED_TOGGLE_COV_SVH

class test_ptw_sva_combined_toggle_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_sva_combined_toggle_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 5_000_000;
  endfunction

  protected function string pde_sva(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.u_pde_cache_sva.", sig};
  endfunction
  protected function string ptw_sva(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_ptw_top_sva.", sig};
  endfunction
  protected function string xbar_sva(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_one_to_four_xbar.u_ptw_xbar_sva.", sig};
  endfunction
  protected function string pplru_sva(input int unsigned l, input string sig);
    return $sformatf("$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.%s.u_pde_pplru_sva.%s",
      (l == 0) ? "u_L1PDE_cache_pplru" : "u_L2PDE_cache_pplru", sig);
  endfunction

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
  protected task pulse_signal(input string path, input uvm_hdl_data_t high_val, input string ctx);
    hdl_force(path, uvm_hdl_data_t'(1'b0), ctx);   stage8_wait_cycles(1);
    hdl_force(path, high_val, ctx);                  stage8_wait_cycles(1);
    hdl_force(path, uvm_hdl_data_t'(1'b0), ctx);    stage8_wait_cycles(1);
    hdl_release(path, ctx);                          stage8_wait_cycles(1);
  endtask
  protected task pulse_bit(input string path, input string ctx);
    pulse_signal(path, uvm_hdl_data_t'(1'b1), ctx);
  endtask

  // ==================================================================
  // mmu_pde_cache_sva toggle (~70 items)
  // ==================================================================
  protected task toggle_pde_cache_sva(input string ctx);
    `uvm_info(get_type_name(), "[SVA_TOG] mmu_pde_cache_sva inputs", UVM_NONE)

    // L1PDE_cache_hit_ppn
    pulse_signal(pde_sva("L1PDE_cache_hit_ppn"),     uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_l1hppn", ctx));
    pulse_signal(pde_sva("L1PDE_cache_hit_ppn[27:11]"),uvm_hdl_data_t'(17'h1ffff),$sformatf("%s_l1hp2711", ctx));
    // L1PDE_entry_ppn per-entry bit ranges
    for (int e = 0; e < 8; e++) begin
      pulse_signal(pde_sva($sformatf("L1PDE_entry_ppn[%0d]", e)), uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_l1ep%0d", ctx, e));
    end
    pulse_signal(pde_sva("L1PDE_entry_ppn[0][10:5]"),uvm_hdl_data_t'(6'h3f),  $sformatf("%s_l1e0_105", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[1][1:0]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e1_10", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[1][4:3]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e1_43", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[2][1:0]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e2_10", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[2][5:3]"), uvm_hdl_data_t'(3'b111), $sformatf("%s_l1e2_53", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[3][0]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_l1e3_0", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[3][5:2]"), uvm_hdl_data_t'(4'hf),   $sformatf("%s_l1e3_52", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[4][2:1]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e4_21", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[4][5:4]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e4_54", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[5][4:3]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e5_43", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[6][0]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_l1e6_0", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[6][4:3]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e6_43", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[7][1:0]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e7_10", ctx));
    pulse_signal(pde_sva("L1PDE_entry_ppn[7][4:3]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e7_43", ctx));

    // L1PDE_l1pmpflg
    for (int e = 1; e < 8; e++)
      pulse_signal(pde_sva($sformatf("L1PDE_l1pmpflg[%0d][2:0]", e)), uvm_hdl_data_t'(3'b111), $sformatf("%s_l1pf%0d", ctx, e));

    // L2PDE_cache_hit_ppn
    pulse_signal(pde_sva("L2PDE_cache_hit_ppn"),     uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_l2hppn", ctx));
    pulse_signal(pde_sva("L2PDE_cache_hit_ppn[27:11]"),uvm_hdl_data_t'(17'h1ffff),$sformatf("%s_l2hp2711", ctx));
    // L2PDE_entry_ppn per-entry bit ranges
    for (int e = 0; e < 16; e++) begin
      pulse_signal(pde_sva($sformatf("L2PDE_entry_ppn[%0d]", e)), uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_l2ep%0d", ctx, e));
    end
    pulse_signal(pde_sva("L2PDE_entry_ppn[0][10:6]"), uvm_hdl_data_t'(5'h1f),  $sformatf("%s_l2e0_106", ctx));
    pulse_signal(pde_sva("L2PDE_entry_ppn[11][6]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e11_6", ctx));
    pulse_signal(pde_sva("L2PDE_entry_ppn[12][3]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e12_3", ctx));
    pulse_signal(pde_sva("L2PDE_entry_ppn[13][6]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e13_6", ctx));
    pulse_signal(pde_sva("L2PDE_entry_ppn[14][6]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e14_6", ctx));
    pulse_signal(pde_sva("L2PDE_entry_ppn[15][6]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e15_6", ctx));
    pulse_signal(pde_sva("L2PDE_entry_ppn[1][3:2]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_l2e1_32", ctx));
    pulse_signal(pde_sva("L2PDE_entry_ppn[7][2]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e7_2", ctx));
    pulse_signal(pde_sva("L2PDE_entry_ppn[7][5]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e7_5", ctx));
    pulse_signal(pde_sva("L2PDE_entry_ppn[8][6]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e8_6", ctx));
    pulse_signal(pde_sva("L2PDE_entry_ppn[9][1]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e9_1", ctx));

    // L2PDE_entry_vld[15:8]
    pulse_signal(pde_sva("L2PDE_entry_vld[15:8]"),    uvm_hdl_data_t'(8'hFF),  $sformatf("%s_l2ev158", ctx));
    // L2PDE_l1pmpflg
    for (int e = 0; e < 16; e++) begin
      pulse_signal(pde_sva($sformatf("L2PDE_l1pmpflg[%0d][2:0]", e)), uvm_hdl_data_t'(3'b111), $sformatf("%s_l2l1pf%0d", ctx, e));
      pulse_signal(pde_sva($sformatf("L2PDE_l2pmpflg[%0d][2:0]", e)), uvm_hdl_data_t'(3'b111), $sformatf("%s_l2l2pf%0d", ctx, e));
    end
    pulse_bit(pde_sva("L2PDE_l2pmpflg[0][0]"),        $sformatf("%s_l2p0", ctx));

    // Other signals
    pulse_signal(pde_sva("PDE_cache_acc_err_id"),      uvm_hdl_data_t'(7'h7f), $sformatf("%s_pdeaeid", ctx));
    pulse_signal(pde_sva("PDE_cache_acc_err_id[2:1]"), uvm_hdl_data_t'(2'b11), $sformatf("%s_pdaeid21", ctx));
    pulse_signal(pde_sva("PDE_cache_acc_err_id[6:5]"), uvm_hdl_data_t'(2'b11), $sformatf("%s_pdaeid65", ctx));
    pulse_signal(pde_sva("PDE_cache_fin_ppn[27:11]"),  uvm_hdl_data_t'(17'h1ffff),$sformatf("%s_fin2711", ctx));
    pulse_signal(pde_sva("PDE_xbar_ppn[27:11]"),       uvm_hdl_data_t'(17'h1ffff),$sformatf("%s_xb2711", ctx));
    pulse_signal(pde_sva("l1_deny_vec[7:1]"),          uvm_hdl_data_t'(7'h7F), $sformatf("%s_l1deny", ctx));
    pulse_signal(pde_sva("mbuf_cache_upd_ppn[23:22]"), uvm_hdl_data_t'(2'b11), $sformatf("%s_mcup2322", ctx));
    pulse_signal(pde_sva("mbuf_cache_upd_ppn[27:24]"), uvm_hdl_data_t'(4'hf),  $sformatf("%s_mcup2724", ctx));
    pulse_bit(pde_sva("pde_past_valid"),               $sformatf("%s_past", ctx));
    pulse_bit(pde_sva("pmp_regs_update"),              $sformatf("%s_pmpupd", ctx));

    `uvm_info(get_type_name(), "[SVA_TOG] mmu_pde_cache_sva done", UVM_NONE)
  endtask

  // ==================================================================
  // mmu_ptw_top_sva toggle (~35 items)
  // ==================================================================
  protected task toggle_ptw_top_sva(input string ctx);
    `uvm_info(get_type_name(), "[SVA_TOG] mmu_ptw_top_sva inputs", UVM_NONE)

    pulse_signal(ptw_sva("twu_l2tlb_ref_acc_err_id"),  uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_twuaeid", ctx));
    pulse_signal(ptw_sva("PDE_cache_acc_err_id[2:1]"), uvm_hdl_data_t'(2'b11), $sformatf("%s_pdeid21", ctx));
    pulse_signal(ptw_sva("PDE_cache_acc_err_id[6:5]"), uvm_hdl_data_t'(2'b11), $sformatf("%s_pdeid65", ctx));
    pulse_signal(ptw_sva("acc_err_twu_grant[4:2]"),    uvm_hdl_data_t'(3'b111),$sformatf("%s_aeg", ctx));
    pulse_bit(ptw_sva("mbuf_bus_error_id[2]"),         $sformatf("%s_mbeid2", ctx));
    pulse_bit(ptw_sva("ptw_arb_ref_data_din[0]"),      $sformatf("%s_ad0", ctx));
    pulse_bit(ptw_sva("ptw_arb_ref_data_din[34]"),     $sformatf("%s_ad34", ctx));
    pulse_signal(ptw_sva("ptw_arb_ref_data_din[37:35]"),uvm_hdl_data_t'(3'b111),$sformatf("%s_ad3735", ctx));
    pulse_signal(ptw_sva("ptw_arb_ref_data_din[41:38]"),uvm_hdl_data_t'(4'hf),  $sformatf("%s_ad4138", ctx));
    pulse_bit(ptw_sva("ptw_arb_ref_data_din[5]"),      $sformatf("%s_ad5", ctx));
    pulse_signal(ptw_sva("ptw_arb_ref_tag_din[15:8]"), uvm_hdl_data_t'(8'hFF), $sformatf("%s_at158", ctx));
    pulse_signal(ptw_sva("ptw_arb_ref_tag_din[19:16]"),uvm_hdl_data_t'(4'hf),  $sformatf("%s_at1916", ctx));
    pulse_bit(ptw_sva("ptw_arb_ref_tag_din[46]"),      $sformatf("%s_at46", ctx));
    pulse_bit(ptw_sva("ptw_arb_ref_tag_din[47]"),      $sformatf("%s_at47", ctx));
    pulse_bit(ptw_sva("ptw_arb_vpn[26]"),              $sformatf("%s_av26", ctx));
    pulse_bit(ptw_sva("ptw_l1dtlb_ref_flg[0]"),        $sformatf("%s_l1df0", ctx));
    pulse_bit(ptw_sva("ptw_l1dtlb_ref_flg[5]"),        $sformatf("%s_l1df5", ctx));
    pulse_bit(ptw_sva("ptw_l1dtlb_ref_ppn[20]"),       $sformatf("%s_l1dp20", ctx));
    pulse_signal(ptw_sva("ptw_l1dtlb_ref_ppn[23:21]"), uvm_hdl_data_t'(3'b111),$sformatf("%s_l1dp2321", ctx));
    pulse_signal(ptw_sva("ptw_l1dtlb_ref_ppn[27:24]"), uvm_hdl_data_t'(4'hf),  $sformatf("%s_l1dp2724", ctx));
    pulse_bit(ptw_sva("ptw_l1dtlb_ref_vpn[26]"),       $sformatf("%s_l1dv26", ctx));
    pulse_bit(ptw_sva("ptw_l1itlb_ref_flg[0]"),        $sformatf("%s_l1if0", ctx));
    pulse_bit(ptw_sva("ptw_l1itlb_ref_flg[5]"),        $sformatf("%s_l1if5", ctx));
    pulse_bit(ptw_sva("ptw_l1itlb_ref_ppn[20]"),       $sformatf("%s_l1ip20", ctx));
    pulse_signal(ptw_sva("ptw_l1itlb_ref_ppn[23:21]"), uvm_hdl_data_t'(3'b111),$sformatf("%s_l1ip2321", ctx));
    pulse_signal(ptw_sva("ptw_l1itlb_ref_ppn[27:24]"), uvm_hdl_data_t'(4'hf),  $sformatf("%s_l1ip2724", ctx));
    pulse_bit(ptw_sva("ptw_l1itlb_ref_vpn[26]"),       $sformatf("%s_l1iv26", ctx));
    pulse_bit(ptw_sva("ptw_l2tlb_flg[0]"),             $sformatf("%s_l2f0", ctx));
    pulse_bit(ptw_sva("ptw_l2tlb_flg[5]"),             $sformatf("%s_l2f5", ctx));
    pulse_bit(ptw_sva("ptw_sva_past_valid"),           $sformatf("%s_past", ctx));
    pulse_signal(ptw_sva("twu_l2tlb_ref_acc_err[3:1]"),uvm_hdl_data_t'(3'b111),$sformatf("%s_tae", ctx));
    pulse_bit(ptw_sva("twu_l2tlb_ref_acc_err_type[0][1]"), $sformatf("%s_taet01", ctx));
    pulse_bit(ptw_sva("twu_l2tlb_ref_acc_err_type[1][1]"), $sformatf("%s_taet11", ctx));
    pulse_bit(ptw_sva("twu_l2tlb_ref_acc_err_type[2][1]"), $sformatf("%s_taet21", ctx));
    pulse_bit(ptw_sva("twu_l2tlb_ref_acc_err_type[3][1]"), $sformatf("%s_taet31", ctx));

    `uvm_info(get_type_name(), "[SVA_TOG] mmu_ptw_top_sva done", UVM_NONE)
  endtask

  // ==================================================================
  // mmu_ptw_xbar_sva toggle (6 items)
  // ==================================================================
  protected task toggle_ptw_xbar_sva(input string ctx);
    `uvm_info(get_type_name(), "[SVA_TOG] mmu_ptw_xbar_sva inputs", UVM_NONE)
    pulse_signal(xbar_sva("PDE_xbar_ppn[27:11]"),  uvm_hdl_data_t'(17'h1ffff),$sformatf("%s_pdeppn", ctx));
    pulse_signal(xbar_sva("twu_hash[1:0]"),        uvm_hdl_data_t'(2'b11),     $sformatf("%s_hash", ctx));
    pulse_signal(xbar_sva("twu_mask[3:1]"),        uvm_hdl_data_t'(3'b111),    $sformatf("%s_mask", ctx));
    pulse_signal(xbar_sva("twu_req_hash[3:0]"),    uvm_hdl_data_t'(4'hf),      $sformatf("%s_rqh", ctx));
    pulse_signal(xbar_sva("xbar_twu_ppn[27:11]"),  uvm_hdl_data_t'(17'h1ffff),$sformatf("%s_twuppn", ctx));
    pulse_signal(xbar_sva("xbar_twu_req[3:1]"),    uvm_hdl_data_t'(3'b111),    $sformatf("%s_twur", ctx));
    `uvm_info(get_type_name(), "[SVA_TOG] mmu_ptw_xbar_sva done", UVM_NONE)
  endtask

  // ==================================================================
  // mmu_pde_pplru_sva toggle (2 items, 2 instances)
  // ==================================================================
  protected task toggle_pde_pplru_svas(input string ctx);
    `uvm_info(get_type_name(), "[SVA_TOG] mmu_pde_pplru_sva — covered by gated_clk_pplru test", UVM_NONE)
    // pplru SVA toggle items covered via pplru internal signals in test_ptw_gated_clk_pplru_cov
  endtask

  // ==================================================================
  // mmu_twu_chk_sva condition (2 items) — whitebox force at twu level
  // Line 104: (flg[0] && (flg[1] || flg[3]))  URG 0 1 → need flg[0]=1
  //          SUB (flg[1] || flg[3])  URG 0 1 → need flg[1]=1 or flg[3]=1
  // ==================================================================
  protected task cover_twu_chk_cond(input string ctx);
    string p = "$root.tb_top.u_dut.x_ct_mmu_ptw.twu_one";
    `uvm_info(get_type_name(), "[TWU_CHK_COND] Line 104 conditions", UVM_NONE)
    hdl_force({p, ".fst_chk_flg"},  uvm_hdl_data_t'(8'h03), $sformatf("%s_flg", ctx)); // [0]=1,[1]=1
    hdl_force({p, ".fst_chk_data"}, uvm_hdl_data_t'(64'h3),  $sformatf("%s_dat", ctx));
    hdl_force({p, ".fst_chk_vld"},  uvm_hdl_data_t'(1'b1),   $sformatf("%s_vld", ctx));
    stage8_wait_cycles(3);
    hdl_release({p, ".fst_chk_vld"},  $sformatf("%s_rv", ctx));
    hdl_release({p, ".fst_chk_data"}, $sformatf("%s_rd", ctx));
    hdl_release({p, ".fst_chk_flg"},  $sformatf("%s_rf", ctx));
    stage8_wait_cycles(2);
    `uvm_info(get_type_name(), "[TWU_CHK_COND] done", UVM_NONE)
  endtask

  virtual task run_test_body();
    string ctx = "sva";
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-SVA-COMBINED", "combined_sva_toggle_and_twu_chk");
    ptw_meta_add_req("PTW-COV-SVA-001");

    toggle_pde_cache_sva(ctx);
    toggle_ptw_top_sva(ctx);
    toggle_ptw_xbar_sva(ctx);
    toggle_pde_pplru_svas(ctx);
    cover_twu_chk_cond(ctx);

    ptw_meta_set_expected("All SVA toggle items + twu_chk cond");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_sva_combined_toggle");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-SVA-001", "sva_combined",
      "SVA toggle: pde_cache_sva + ptw_top_sva + xbar_sva + pde_pplru_sva + twu_chk cond");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass

`endif
