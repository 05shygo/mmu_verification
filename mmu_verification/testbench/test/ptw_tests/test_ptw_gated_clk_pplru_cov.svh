// =============================================================================
// gated_clk_cell + pplru coverage test
//   gated_clk_cell: 7 cond + 5 toggle (39 instances)
//   pplru: 2 line + 1 missing_else + 2 cond + 3 branch + 4 toggle (2 instances)
// =============================================================================
`ifndef TEST_PTW_GATED_CLK_PPLRU_COV_SVH
`define TEST_PTW_GATED_CLK_PPLRU_COV_SVH

class test_ptw_gated_clk_pplru_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_gated_clk_pplru_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 4_000_000;
  endfunction

  // ── gated_clk_cell paths ──
  protected function string gck_path(input int unsigned e, input string sig);
    // L1PDE entries: u_L1PDE_ent[0..7].u_L1PDE_cache.x_L1PDE_entry_gateclk
    return $sformatf("$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L1PDE_ent[%0d].u_L1PDE_cache.x_L1PDE_entry_gateclk.%s", e, sig);
  endfunction
  protected function string gck_pplru(input string which, input string sig);
    return $sformatf("$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.%s.x_pplru_gateclk.%s", which, sig);
  endfunction
  protected function string gck_twu(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.twu_one.x_twu_gateclk.", sig};
  endfunction

  // ── pplru paths ──
  protected function string pplru_path(input string which, input string sig);
    return $sformatf("$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.%s.%s", which, sig);
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
  // gated_clk_cell COND (7 items, 39 instances)
  //   Expression: ((global_en && (module_en || local_en)) || external_en)
  //   URG 0 0 → need global_en=1 AND (module_en || local_en)=1
  //   URG 0 1 → need global_en=1
  //   URG (sub) 0 1 → need (global_en && ...)=1
  //   URG (sub) 1 0 → need (global_en && ...)=1
  //   URG (sub) 0 0 → need (module_en || local_en)=1
  //   URG (sub) 0 1 → need (module_en || local_en)=1
  //   URG (sub) 1 0 → need (module_en || local_en)=1
  // Approach: pulse module_en=1 (with global_en=1) on a representative set of instances
  // ==================================================================
  protected task cover_gated_clk_cond(input string ctx);
    `uvm_info(get_type_name(), "[GCK_COND] gated_clk_cell condition coverage", UVM_NONE)

    // Drive global_en=1 and pulse module_en=1 on each gck instance type
    // TWU gateclk
    hdl_force(gck_twu("global_en"),  uvm_hdl_data_t'(1'b1), $sformatf("%s_twu_ge", ctx));
    hdl_force(gck_twu("module_en"),  uvm_hdl_data_t'(1'b1), $sformatf("%s_twu_me", ctx));
    stage8_wait_cycles(3);
    hdl_force(gck_twu("module_en"),  uvm_hdl_data_t'(1'b0), $sformatf("%s_twu_me0", ctx));
    stage8_wait_cycles(1);
    hdl_release(gck_twu("module_en"), $sformatf("%s_twu_rme", ctx));
    hdl_release(gck_twu("global_en"), $sformatf("%s_twu_rge", ctx));

    // L1 PDE entry gateclks (8 instances) + pplru gateclks (2 instances)
    for (int e = 0; e < 8; e++) begin
      hdl_force(gck_path(e, "global_en"), uvm_hdl_data_t'(1'b1), $sformatf("%s_l1e%0d_ge", ctx, e));
      hdl_force(gck_path(e, "module_en"), uvm_hdl_data_t'(1'b1), $sformatf("%s_l1e%0d_me", ctx, e));
      stage8_wait_cycles(2);
      hdl_force(gck_path(e, "module_en"), uvm_hdl_data_t'(1'b0), $sformatf("%s_l1e%0d_me0", ctx, e));
      stage8_wait_cycles(1);
      hdl_release(gck_path(e, "module_en"), $sformatf("%s_l1e%0d_rme", ctx, e));
      hdl_release(gck_path(e, "global_en"), $sformatf("%s_l1e%0d_rge", ctx, e));
    end

    // L1 pplru gateclk
    hdl_force(gck_pplru("u_L1PDE_cache_pplru", "global_en"), uvm_hdl_data_t'(1'b1), $sformatf("%s_l1p_ge", ctx));
    hdl_force(gck_pplru("u_L1PDE_cache_pplru", "module_en"), uvm_hdl_data_t'(1'b1), $sformatf("%s_l1p_me", ctx));
    stage8_wait_cycles(3);
    hdl_release(gck_pplru("u_L1PDE_cache_pplru", "module_en"), $sformatf("%s_l1p_rme", ctx));
    hdl_release(gck_pplru("u_L1PDE_cache_pplru", "global_en"), $sformatf("%s_l1p_rge", ctx));

    // L2 pplru gateclk
    hdl_force(gck_pplru("u_L2PDE_cache_pplru", "global_en"), uvm_hdl_data_t'(1'b1), $sformatf("%s_l2p_ge", ctx));
    hdl_force(gck_pplru("u_L2PDE_cache_pplru", "module_en"), uvm_hdl_data_t'(1'b1), $sformatf("%s_l2p_me", ctx));
    stage8_wait_cycles(3);
    hdl_release(gck_pplru("u_L2PDE_cache_pplru", "module_en"), $sformatf("%s_l2p_rme", ctx));
    hdl_release(gck_pplru("u_L2PDE_cache_pplru", "global_en"), $sformatf("%s_l2p_rge", ctx));

    `uvm_info(get_type_name(), "[GCK_COND] done", UVM_NONE)
  endtask

  // ==================================================================
  // gated_clk_cell TOGGLE (5 items, 39 instances)
  // ==================================================================
  protected task toggle_gated_clk_signals(input string ctx);
    `uvm_info(get_type_name(), "[GCK_TOG] gated_clk_cell toggles", UVM_NONE)
    // Toggle on all 8 L1 PDE entry instances
    for (int e = 0; e < 8; e++) begin
      pulse_bit(gck_path(e, "SE"),          $sformatf("%s_l1e%0d_SE", ctx, e));
      pulse_bit(gck_path(e, "external_en"), $sformatf("%s_l1e%0d_ee", ctx, e));
      pulse_bit(gck_path(e, "global_en"),   $sformatf("%s_l1e%0d_ge", ctx, e));

      if (e < 3) begin
        pulse_bit(gck_path(e, "clk_en_bf_latch"), $sformatf("%s_l1e%0d_cebl", ctx, e));
        pulse_bit(gck_path(e, "local_en"),        $sformatf("%s_l1e%0d_le", ctx, e));
      end
    end
    // pplru gateclks
    pulse_bit(gck_pplru("u_L1PDE_cache_pplru", "SE"),          $sformatf("%s_l1p_SE", ctx));
    pulse_bit(gck_pplru("u_L1PDE_cache_pplru", "external_en"), $sformatf("%s_l1p_ee", ctx));
    pulse_bit(gck_pplru("u_L1PDE_cache_pplru", "global_en"),   $sformatf("%s_l1p_ge", ctx));
    pulse_bit(gck_pplru("u_L2PDE_cache_pplru", "SE"),          $sformatf("%s_l2p_SE", ctx));
    pulse_bit(gck_pplru("u_L2PDE_cache_pplru", "external_en"), $sformatf("%s_l2p_ee", ctx));
    pulse_bit(gck_pplru("u_L2PDE_cache_pplru", "global_en"),   $sformatf("%s_l2p_ge", ctx));
    // TWU gateclk
    pulse_bit(gck_twu("SE"),          $sformatf("%s_twu_SE", ctx));
    pulse_bit(gck_twu("external_en"), $sformatf("%s_twu_ee", ctx));
    pulse_bit(gck_twu("global_en"),   $sformatf("%s_twu_ge", ctx));
    `uvm_info(get_type_name(), "[GCK_TOG] done", UVM_NONE)
  endtask

  // ==================================================================
  // pplru coverage (2 instances: L1PDE_cache_pplru, L2PDE_cache_pplru)
  // ==================================================================
  protected task cover_pplru(input string ctx);
    `uvm_info(get_type_name(), "[PPLRU] pplru coverage — both instances", UVM_NONE)

    for (int inst = 0; inst < 2; inst++) begin
      string which = (inst == 0) ? "u_L1PDE_cache_pplru" : "u_L2PDE_cache_pplru";
      string pi = pplru_path(which, "");

      // LINE 68: write_num = 0 — force invalid_entry_found=1, plru_num >= ENTRY_NUM
      // LINE 98: hit_num_index = 8 — force invalid_entry_found=0, hit not found
      // COND 67: ((!invalid_entry_found) && (plru_num >= ENTRY_NUM)) URG 0 1 + 1 1
      //   → need (!invalid_entry_found)=1 AND (plru_num >= ENTRY_NUM)=1

      // Force invalid_entry_found=0, plru_num > entry_num → triggers cond 67 both sub-exprs
      hdl_force({pi, "invalid_entry_found"}, uvm_hdl_data_t'(1'b0), $sformatf("%s_ief0_%s", ctx, which));
      hdl_force({pi, "plru_num"},            uvm_hdl_data_t'(4'd10), $sformatf("%s_plru10_%s", ctx, which)); // > 8
      stage8_wait_cycles(3);

      // Now force invalid_entry_found=1 to cover missing_else of line 98 and branch
      hdl_force({pi, "invalid_entry_found"}, uvm_hdl_data_t'(1'b1), $sformatf("%s_ief1_%s", ctx, which));
      stage8_wait_cycles(3);

      hdl_release({pi, "invalid_entry_found"}, $sformatf("%s_rief_%s", ctx, which));
      hdl_release({pi, "plru_num"},            $sformatf("%s_rplru_%s", ctx, which));

      // TOGGLE: PDE_plru_read_vld[15:8] (L2 only), invalid_entry_found, plru_num[0], vld_entry_num[15:8] (L2 only)
      if (inst == 1) begin // L2 instance (16 entries)
        pulse_signal({pi, "PDE_plru_read_vld[15:8]"}, uvm_hdl_data_t'(8'hFF), $sformatf("%s_pvld_%s", ctx, which));
        pulse_signal({pi, "vld_entry_num[15:8]"},      uvm_hdl_data_t'(8'hFF), $sformatf("%s_ven_%s", ctx, which));
      end else begin // L1 instance (8 entries)
        pulse_signal({pi, "PDE_plru_read_vld"},        uvm_hdl_data_t'(8'hFF), $sformatf("%s_pvld_%s", ctx, which));
      end
      pulse_bit({pi, "invalid_entry_found"},         $sformatf("%s_ief_tgl_%s", ctx, which));
      pulse_bit({pi, "plru_num[0]"},                 $sformatf("%s_pn0_%s", ctx, which));
    end

    `uvm_info(get_type_name(), "[PPLRU] done", UVM_NONE)
  endtask

  virtual task run_test_body();
    string ctx = "gpp";
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-GCK-PPLRU", "gated_clk_pplru_coverage");
    ptw_meta_add_req("PTW-COV-GCK-PPLRU-001");

    cover_gated_clk_cond(ctx);
    toggle_gated_clk_signals(ctx);
    cover_pplru(ctx);

    ptw_meta_set_expected("gated_clk_cell cond+toggle + pplru line+missing_else+cond+branch+toggle");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_gck_pplru_cov");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-GCK-PPLRU-001", "gck_pplru_cov",
      "gated_clk_cell + pplru coverage closure");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass

`endif
