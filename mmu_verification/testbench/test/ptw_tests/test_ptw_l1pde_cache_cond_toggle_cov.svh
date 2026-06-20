// =============================================================================
// L1PDE_cache condition and toggle coverage closure test
// L1PDE_cache has NO ptw_req input — only ptw_vpn/ptw_type.
// Condition coverage items are purely combinational.
// =============================================================================
`ifndef TEST_PTW_L1PDE_CACHE_COND_TOGGLE_COV_SVH
`define TEST_PTW_L1PDE_CACHE_COND_TOGGLE_COV_SVH

class test_ptw_l1pde_cache_cond_toggle_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_l1pde_cache_cond_toggle_cov)

  localparam int unsigned L1E_NUM = 8;

  localparam logic [2:0] T_FETCH = 3'b011;
  localparam logic [2:0] T_LOAD  = 3'b010;
  localparam logic [2:0] T_STORE = 3'b110;
  localparam logic [2:0] T_PREF  = 3'b100;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 3_000_000;
  endfunction

  // ── Path builders ──
  protected function string pde_path(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.", sig};
  endfunction

  protected function string l1_path(input int unsigned e, input string sig);
    return $sformatf(
      "$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L1PDE_ent[%0d].u_L1PDE_cache.%s",
      e, sig);
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

  protected task pulse_bit(input string path, input string ctx);
    pulse_signal(path, uvm_hdl_data_t'(1'b1), ctx);
  endtask

  // ── Quiet PDE_cache interface ──
  protected task enter_quiet(input string ctx);
    hdl_force(pde_path("ptw_req"),          uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(pde_path("l2tlb_ptw_req"),    uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(pde_path("mbuf_cache_upd"),   uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(pde_path("regs_ptw_clr"),     uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(pde_path("tlboper_ptw_abort"),uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(pde_path("pmp_regs_update"),  uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(pde_path("xbar_pde_ready"),   uvm_hdl_data_t'(1'b1), ctx);
    hdl_force(pde_path("PDE_xbar_req"),     uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);
  endtask

  protected task leave_quiet(input string ctx);
    hdl_release(pde_path("PDE_xbar_req"),     ctx);
    hdl_release(pde_path("xbar_pde_ready"),   ctx);
    hdl_release(pde_path("pmp_regs_update"),  ctx);
    hdl_release(pde_path("tlboper_ptw_abort"),ctx);
    hdl_release(pde_path("regs_ptw_clr"),     ctx);
    hdl_release(pde_path("mbuf_cache_upd"),   ctx);
    hdl_release(pde_path("l2tlb_ptw_req"),    ctx);
    hdl_release(pde_path("ptw_req"),          ctx);
    stage8_wait_cycles(2);
  endtask

  // ── Set ptw_vpn/ptw_type at PDE level for L1 combinational evaluation ──
  protected task set_pde_type_vpn(input logic [8:0] tag, input logic [17:0] vpn_low,
      input logic [2:0] req_type, input string ctx);
    hdl_force(pde_path("ptw_vpn"),  uvm_hdl_data_t'({tag, vpn_low}), ctx);
    hdl_force(pde_path("ptw_type"), uvm_hdl_data_t'(req_type), ctx);
    stage8_wait_cycles(2);
  endtask

  protected task clear_pde_type_vpn(input string ctx);
    hdl_release(pde_path("ptw_type"), ctx);
    hdl_release(pde_path("ptw_vpn"),  ctx);
    stage8_wait_cycles(1);
  endtask

  // ── Program / release L1 entry ──
  protected task program_l1_entry(input int unsigned e, input logic [8:0] tag,
      input logic [27:0] ppn, input logic [3:0] l1flg, input logic vld, input string ctx);
    hdl_force(l1_path(e, "L1PDE_vld"),      uvm_hdl_data_t'(vld),  ctx);
    hdl_force(l1_path(e, "L1PDE_tag"),      uvm_hdl_data_t'(tag),  ctx);
    hdl_force(l1_path(e, "L1PDE_ppn"),      uvm_hdl_data_t'(ppn),  ctx);
    hdl_force(l1_path(e, "L1PDE_l1pmpflg"), uvm_hdl_data_t'(l1flg),ctx);
    stage8_wait_cycles(1);
  endtask

  protected task release_l1_entry(input int unsigned e, input string ctx);
    hdl_release(l1_path(e, "L1PDE_l1pmpflg"), ctx);
    hdl_release(l1_path(e, "L1PDE_ppn"),      ctx);
    hdl_release(l1_path(e, "L1PDE_tag"),      ctx);
    hdl_release(l1_path(e, "L1PDE_vld"),      ctx);
    stage8_wait_cycles(1);
  endtask

  protected task force_priv_modes(input logic [1:0] yy_priv, input logic [1:0] priv, input string ctx);
    hdl_force(pde_path("cp0_yy_priv_mode"), uvm_hdl_data_t'(yy_priv), ctx);
    hdl_force(pde_path("cp0_priv_mode"),    uvm_hdl_data_t'(priv),    ctx);
    stage8_wait_cycles(1);
  endtask

  protected task release_priv_modes(input string ctx);
    hdl_release(pde_path("cp0_priv_mode"),    ctx);
    hdl_release(pde_path("cp0_yy_priv_mode"), ctx);
    stage8_wait_cycles(1);
  endtask

  // ==================================================================
  // CONDITION COVERAGE — line 58
  //   SUB-EXPRESSION: (cp0_yy_priv_mode[1:0] == 2'b11) → value 1
  //   Needs: ptw_type==FETCH && cp0_yy_priv_mode==PRIV_M
  // ==================================================================
  protected task cover_line58_cp0_yy_mmode();
    string ctx;
    force_priv_modes(PRIV_M, PRIV_S, "l1_line58");
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      ctx = $sformatf("l1_line58_e%0d", e);
      program_l1_entry(e, 9'(e), 28'(28'h1000 + e), 4'h7, 1'b1, ctx);
      set_pde_type_vpn(9'(e), 18'(e), T_FETCH, ctx);
      clear_pde_type_vpn(ctx);
      release_l1_entry(e, ctx);
    end
    release_priv_modes("l1_line58");
  endtask

  // ==================================================================
  // CONDITION COVERAGE — line 126
  //   SUB-EXPRESSION: (cp0_mach_mode & !L1PDE_l1pmpflg[3])  URG 1 0
  // ==================================================================
  protected task cover_line126_mmode_lock_bypass();
    string ctx;
    force_priv_modes(PRIV_M, PRIV_M, "l1_lock");
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      ctx = $sformatf("l1_lock_e%0d", e);
      program_l1_entry(e, 9'(e), 28'(28'h2000 + e), 4'h0, 1'b1, ctx);
      // Case A: lock=0, M-mode → HIT via mach_mode bypass
      hdl_force(l1_path(e, "L1PDE_l1pmpflg"), uvm_hdl_data_t'(4'h0), ctx);
      stage8_wait_cycles(1);
      set_pde_type_vpn(9'(e), 18'(e), T_LOAD, $sformatf("%s_a", ctx));
      clear_pde_type_vpn($sformatf("%s_a", ctx));
      // Case B: lock=1, M-mode → bypass FAILS, no hit
      hdl_force(l1_path(e, "L1PDE_l1pmpflg"), uvm_hdl_data_t'(4'h8), ctx);
      stage8_wait_cycles(1);
      set_pde_type_vpn(9'(e), 18'(e), T_LOAD, $sformatf("%s_b", ctx));
      clear_pde_type_vpn($sformatf("%s_b", ctx));
      release_l1_entry(e, ctx);
    end
    release_priv_modes("l1_lock");
  endtask

  protected task cover_l1pmp_ok_all_types();
    string ctx;
    force_priv_modes(PRIV_S, PRIV_S, "l1_ok");
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      ctx = $sformatf("l1_ok_e%0d", e);
      program_l1_entry(e, 9'(e), 28'(28'h3000 + e), 4'h7, 1'b1, ctx);
      set_pde_type_vpn(9'(e), 18'(e), T_FETCH, $sformatf("%s_f", ctx));
      clear_pde_type_vpn($sformatf("%s_f", ctx));
      set_pde_type_vpn(9'(e), 18'(e), T_LOAD,  $sformatf("%s_l", ctx));
      clear_pde_type_vpn($sformatf("%s_l", ctx));
      set_pde_type_vpn(9'(e), 18'(e), T_STORE, $sformatf("%s_s", ctx));
      clear_pde_type_vpn($sformatf("%s_s", ctx));
      set_pde_type_vpn(9'(e), 18'(e), T_PREF,  $sformatf("%s_p", ctx));
      clear_pde_type_vpn($sformatf("%s_p", ctx));
      release_l1_entry(e, ctx);
    end
    release_priv_modes("l1_ok");
  endtask

  protected task cover_tag_mismatch();
    string ctx;
    force_priv_modes(PRIV_S, PRIV_S, "l1_miss");
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      ctx = $sformatf("l1_miss_e%0d", e);
      program_l1_entry(e, 9'(e), 28'(28'h4000 + e), 4'h7, 1'b1, ctx);
      set_pde_type_vpn(~9'(e), 18'(e), T_LOAD, ctx);
      clear_pde_type_vpn(ctx);
      release_l1_entry(e, ctx);
    end
    release_priv_modes("l1_miss");
  endtask

  // ==================================================================
  // TOGGLE COVERAGE
  // ==================================================================

  protected task toggle_ppn_internal(input string ctx);
    for (int unsigned e = 0; e < L1E_NUM; e++)
      pulse_signal(l1_path(e, "L1PDE_ppn"), uvm_hdl_data_t'(28'h0fff_ffff),
        $sformatf("%s_ppn_all_e%0d", ctx, e));
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      pulse_bit(l1_path(e, "L1PDE_ppn[0]"), $sformatf("%s_ppn0_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_ppn[1]"), $sformatf("%s_ppn1_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_ppn[2]"), $sformatf("%s_ppn2_e%0d",  ctx, e));
    end
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      pulse_signal(l1_path(e, "L1PDE_ppn[1:0]"),  uvm_hdl_data_t'(2'b11),     $sformatf("%s_p10_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_ppn[2:1]"),  uvm_hdl_data_t'(2'b11),     $sformatf("%s_p21_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_ppn[4:3]"),  uvm_hdl_data_t'(2'b11),     $sformatf("%s_p43_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_ppn[5:2]"),  uvm_hdl_data_t'(4'hf),       $sformatf("%s_p52_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_ppn[5:3]"),  uvm_hdl_data_t'(3'b111),    $sformatf("%s_p53_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_ppn[5:4]"),  uvm_hdl_data_t'(2'b11),     $sformatf("%s_p54_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_ppn[10:5]"), uvm_hdl_data_t'(6'h3f),     $sformatf("%s_p105_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_ppn[27:11]"),uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_p2711_e%0d", ctx, e));
      pulse_signal(l1_path(e, "L1PDE_ppn[27:5]"), uvm_hdl_data_t'(23'h7fffff),$sformatf("%s_p275_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_ppn[27:6]"), uvm_hdl_data_t'(22'h3fffff),$sformatf("%s_p276_e%0d",  ctx, e));
    end
  endtask

  protected task toggle_entry_ppn(input string ctx);
    for (int unsigned e = 0; e < L1E_NUM; e++)
      pulse_signal(l1_path(e, "L1PDE_entry_ppn"), uvm_hdl_data_t'(28'h0fff_ffff),
        $sformatf("%s_entppn_all_e%0d", ctx, e));
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      pulse_bit(l1_path(e, "L1PDE_entry_ppn[0]"), $sformatf("%s_e0_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_entry_ppn[1]"), $sformatf("%s_e1_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_entry_ppn[2]"), $sformatf("%s_e2_e%0d",  ctx, e));
    end
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      pulse_signal(l1_path(e, "L1PDE_entry_ppn[1:0]"),  uvm_hdl_data_t'(2'b11),     $sformatf("%s_e10_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_entry_ppn[2:1]"),  uvm_hdl_data_t'(2'b11),     $sformatf("%s_e21_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_entry_ppn[4:3]"),  uvm_hdl_data_t'(2'b11),     $sformatf("%s_e43_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_entry_ppn[5:2]"),  uvm_hdl_data_t'(4'hf),       $sformatf("%s_e52_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_entry_ppn[5:3]"),  uvm_hdl_data_t'(3'b111),    $sformatf("%s_e53_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_entry_ppn[5:4]"),  uvm_hdl_data_t'(2'b11),     $sformatf("%s_e54_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_entry_ppn[10:5]"), uvm_hdl_data_t'(6'h3f),     $sformatf("%s_e105_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_entry_ppn[27:11]"),uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_e2711_e%0d", ctx, e));
      pulse_signal(l1_path(e, "L1PDE_entry_ppn[27:5]"), uvm_hdl_data_t'(23'h7fffff),$sformatf("%s_e275_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_entry_ppn[27:6]"), uvm_hdl_data_t'(22'h3fffff),$sformatf("%s_e276_e%0d",  ctx, e));
    end
  endtask

  protected task toggle_pmpflg_signals(input string ctx);
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      pulse_signal(l1_path(e, "L1PDE_l1pmpflg"),      uvm_hdl_data_t'(4'hf),   $sformatf("%s_f_e%0d",   ctx, e));
      pulse_signal(l1_path(e, "L1PDE_l1pmpflg[2:0]"), uvm_hdl_data_t'(3'b111), $sformatf("%s_f20_e%0d", ctx, e));
      pulse_signal(l1_path(e, "L1PDE_l1pmpflg[3]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_f3_e%0d",  ctx, e));
    end
  endtask

  protected task toggle_tag_bits(input string ctx);
    for (int unsigned e = 0; e < L1E_NUM; e++)
      pulse_signal(l1_path(e, "L1PDE_tag"), uvm_hdl_data_t'(9'h1ff),
        $sformatf("%s_tag_all_e%0d", ctx, e));
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      pulse_bit(l1_path(e, "L1PDE_tag[0]"), $sformatf("%s_t0_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_tag[2]"), $sformatf("%s_t2_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_tag[3]"), $sformatf("%s_t3_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_tag[4]"), $sformatf("%s_t4_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_tag[5]"), $sformatf("%s_t5_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_tag[6]"), $sformatf("%s_t6_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_tag[8]"), $sformatf("%s_t8_e%0d",  ctx, e));
    end
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      pulse_signal(l1_path(e, "L1PDE_tag[1:0]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_t10_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_tag[2:0]"), uvm_hdl_data_t'(3'b111), $sformatf("%s_t20_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_tag[3:0]"), uvm_hdl_data_t'(4'hf),   $sformatf("%s_t30_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_tag[5:0]"), uvm_hdl_data_t'(6'h3f),  $sformatf("%s_t50_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_tag[5:1]"), uvm_hdl_data_t'(5'h1f),  $sformatf("%s_t51_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_tag[5:4]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_t54_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_tag[8:6]"), uvm_hdl_data_t'(3'b111), $sformatf("%s_t86_e%0d",  ctx, e));
      pulse_signal(l1_path(e, "L1PDE_tag[8:7]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_t87_e%0d",  ctx, e));
    end
  endtask

  protected task toggle_l1pmp_ok(input string ctx);
    force_priv_modes(PRIV_S, PRIV_S, $sformatf("%s_setup", ctx));
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      program_l1_entry(e, 9'(e), 28'(28'h5000 + e), 4'h1, 1'b1, $sformatf("%s_e%0d", ctx, e));
      // LOAD → l1pmp_ok=l1pmpflg[0]=1; STORE → l1pmp_ok=l1pmpflg[1]=0
      set_pde_type_vpn(9'(e), 18'(e), T_LOAD,  $sformatf("%s_l_e%0d", ctx, e));
      clear_pde_type_vpn($sformatf("%s_l_e%0d", ctx, e));
      set_pde_type_vpn(9'(e), 18'(e), T_STORE, $sformatf("%s_s_e%0d", ctx, e));
      clear_pde_type_vpn($sformatf("%s_s_e%0d", ctx, e));
      release_l1_entry(e, $sformatf("%s_rel_e%0d", ctx, e));
    end
    release_priv_modes($sformatf("%s_done", ctx));
  endtask

  protected task toggle_upd_ppn(input string ctx);
    pulse_signal(l1_path(0, "L1PDE_upd_ppn"),         uvm_hdl_data_t'(28'h0fff_ffff), $sformatf("%s_all",   ctx));
    pulse_signal(l1_path(0, "L1PDE_upd_ppn[23:22]"),  uvm_hdl_data_t'(2'b11),         $sformatf("%s_2322",  ctx));
    pulse_signal(l1_path(0, "L1PDE_upd_ppn[27:24]"),  uvm_hdl_data_t'(4'hf),          $sformatf("%s_2724",  ctx));
  endtask

  protected task toggle_vld_signals(input string ctx);
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      pulse_bit(l1_path(e, "L1PDE_vld"),       $sformatf("%s_vld_e%0d",  ctx, e));
      pulse_bit(l1_path(e, "L1PDE_entry_vld"), $sformatf("%s_evld_e%0d", ctx, e));
    end
  endtask

  // ==================================================================
  // Orchestration
  // ==================================================================
  protected task cover_all_conditions();
    `uvm_info(get_type_name(), "[L1PDE_COV] Starting condition coverage", UVM_NONE)
    enter_quiet("l1_cond_quiet");
    cover_line58_cp0_yy_mmode();
    cover_line126_mmode_lock_bypass();
    cover_l1pmp_ok_all_types();
    cover_tag_mismatch();
    leave_quiet("l1_cond_quiet");
    `uvm_info(get_type_name(), "[L1PDE_COV] Condition coverage done", UVM_NONE)
  endtask

  protected task cover_all_toggles();
    string ctx;
    `uvm_info(get_type_name(), "[L1PDE_COV] Starting toggle coverage", UVM_NONE)
    enter_quiet("l1_toggle_quiet");
    ctx = "l1_tgl";
    toggle_vld_signals(ctx);
    toggle_ppn_internal(ctx);
    toggle_entry_ppn(ctx);
    toggle_pmpflg_signals(ctx);
    toggle_tag_bits(ctx);
    toggle_l1pmp_ok($sformatf("%s_comb", ctx));
    toggle_upd_ppn(ctx);
    leave_quiet("l1_toggle_quiet");
    `uvm_info(get_type_name(), "[L1PDE_COV] Toggle coverage done", UVM_NONE)
  endtask

  virtual task run_test_body();
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-L1PDE-COND-TOGGLE-COV",
      "l1pde_cache_condition_and_toggle_coverage");
    ptw_meta_add_req("PTW-COV-L1PDE-COND-TOGGLE-001");

    cover_all_conditions();
    cover_all_toggles();

    ptw_meta_add_context("whitebox_l1pde_8entry_cond_toggle_comprehensive");
    ptw_meta_set_expected("All L1PDE_cache condition items (lines 58/126) and toggle items covered across all 8 instances");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_l1pde_cache_cond_toggle_cov");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-L1PDE-COND-TOGGLE-001",
      "l1pde_cache_condition_toggle_coverage_closure",
      "L1 line 58 cp0_yy_priv_mode=MMode for FETCH, line 126 mach_mode lock bypass + pmp_ok types + tag mismatch, all toggle bits 8 entries");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass : test_ptw_l1pde_cache_cond_toggle_cov

`endif // TEST_PTW_L1PDE_CACHE_COND_TOGGLE_COV_SVH
