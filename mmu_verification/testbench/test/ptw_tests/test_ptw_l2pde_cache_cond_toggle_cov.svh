// =============================================================================
// L2PDE_cache condition and toggle coverage closure test
// Uses PDE-level ptw_req driving + clear_acc_err between operations
// to match the proven pattern from test_ptw_l2pde_pde_cache_cov_closure_001.
// =============================================================================
`ifndef TEST_PTW_L2PDE_CACHE_COND_TOGGLE_COV_SVH
`define TEST_PTW_L2PDE_CACHE_COND_TOGGLE_COV_SVH

class test_ptw_l2pde_cache_cond_toggle_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_l2pde_cache_cond_toggle_cov)

  localparam int unsigned L2E_NUM = 16;

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

  protected function string l2_path(input int unsigned e, input string sig);
    return $sformatf(
      "$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L2PDE_ent[%0d].u_L2PDE_cache.%s",
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

  // ── Drive PDE req + clear acc_err ──
  protected task drive_pde_req(input logic [17:0] tag, input logic [8:0] vpn0,
      input logic [2:0] req_type, input bit req_vld, input string ctx);
    hdl_force(pde_path("ptw_vpn"),  uvm_hdl_data_t'({tag, vpn0}), ctx);
    hdl_force(pde_path("ptw_type"), uvm_hdl_data_t'(req_type), ctx);
    hdl_force(pde_path("ptw_req"),  uvm_hdl_data_t'(req_vld), ctx);
    stage8_wait_cycles(2);
  endtask

  protected task release_pde_req(input string ctx);
    hdl_force(pde_path("ptw_req"),  uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(1);
    hdl_release(pde_path("ptw_req"),  ctx);
    hdl_release(pde_path("ptw_type"), ctx);
    hdl_release(pde_path("ptw_vpn"),  ctx);
    stage8_wait_cycles(1);
  endtask

  protected task clear_acc_err(input string ctx);
    hdl_force(pde_path("PDE_cache_acc_err_grant"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(2);
    hdl_force(pde_path("PDE_cache_acc_err_grant"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);
    hdl_release(pde_path("PDE_cache_acc_err_grant"), ctx);
  endtask

  // ── Program / release L2 entry ──
  protected task program_l2_entry(input int unsigned e, input logic [17:0] tag,
      input logic [27:0] ppn, input logic [3:0] l1flg, input logic [3:0] l2flg,
      input logic vld, input string ctx);
    hdl_force(l2_path(e, "L2PDE_vld"),      uvm_hdl_data_t'(vld),  ctx);
    hdl_force(l2_path(e, "L2PDE_tag"),      uvm_hdl_data_t'(tag),  ctx);
    hdl_force(l2_path(e, "L2PDE_ppn"),      uvm_hdl_data_t'(ppn),  ctx);
    hdl_force(l2_path(e, "L2PDE_l1pmpflg"), uvm_hdl_data_t'(l1flg),ctx);
    hdl_force(l2_path(e, "L2PDE_l2pmpflg"), uvm_hdl_data_t'(l2flg),ctx);
    stage8_wait_cycles(1);
  endtask

  protected task release_l2_entry(input int unsigned e, input string ctx);
    hdl_release(l2_path(e, "L2PDE_l2pmpflg"), ctx);
    hdl_release(l2_path(e, "L2PDE_l1pmpflg"), ctx);
    hdl_release(l2_path(e, "L2PDE_ppn"),      ctx);
    hdl_release(l2_path(e, "L2PDE_tag"),      ctx);
    hdl_release(l2_path(e, "L2PDE_vld"),      ctx);
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
  // CONDITION COVERAGE
  // ==================================================================

  // Line 61: (cp0_yy_priv_mode == 2'b11) value=1
  protected task cover_line61();
    string ctx;
    force_priv_modes(PRIV_M, PRIV_S, "l2_l61");
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      ctx = $sformatf("l2_l61_e%0d", e);
      program_l2_entry(e, 18'(e), 28'(28'h1000 + e), 4'h7, 4'h7, 1'b1, ctx);
      drive_pde_req(18'(e), 9'(e), T_FETCH, 1'b1, ctx);
      release_pde_req(ctx);
      release_l2_entry(e, ctx);
    end
    release_priv_modes("l2_l61");
  endtask

  // Line 143/144: l1pmp_ok & l2pmp_ok  URG 1 0
  protected task cover_l1l2_ok();
    string ctx;
    force_priv_modes(PRIV_S, PRIV_S, "l2_ok");
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      ctx = $sformatf("l2_ok_e%0d", e);
      program_l2_entry(e, 18'(e), 28'(28'h2000 + e), 4'h7, 4'h7, 1'b1, ctx);
      drive_pde_req(18'(e), 9'(e), T_FETCH, 1'b1, $sformatf("%s_f",ctx));
      release_pde_req($sformatf("%s_f",ctx));
      drive_pde_req(18'(e), 9'(e), T_LOAD,  1'b1, $sformatf("%s_l",ctx));
      release_pde_req($sformatf("%s_l",ctx));
      drive_pde_req(18'(e), 9'(e), T_STORE, 1'b1, $sformatf("%s_s",ctx));
      release_pde_req($sformatf("%s_s",ctx));
      drive_pde_req(18'(e), 9'(e), T_PREF,  1'b1, $sformatf("%s_p",ctx));
      release_pde_req($sformatf("%s_p",ctx));
      release_l2_entry(e, ctx);
    end
    release_priv_modes("l2_ok");
  endtask

  // Line 143/144: cp0_mach_mode & !l1pmpflg[3] & !l2pmpflg[3]  URG 1 0 1 / 1 1 0
  protected task cover_mmode_lock();
    string ctx;
    force_priv_modes(PRIV_M, PRIV_M, "l2_lock");
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      ctx = $sformatf("l2_lock_e%0d", e);
      program_l2_entry(e, 18'(e), 28'(28'h3000 + e), 4'h0, 4'h0, 1'b1, ctx);
      // A: both unlocked, M-mode → HIT
      hdl_force(l2_path(e, "L2PDE_l1pmpflg"), uvm_hdl_data_t'(4'h0), ctx);
      hdl_force(l2_path(e, "L2PDE_l2pmpflg"), uvm_hdl_data_t'(4'h0), ctx); stage8_wait_cycles(1);
      drive_pde_req(18'(e), 9'(e), T_LOAD, 1'b1, $sformatf("%s_a",ctx)); release_pde_req($sformatf("%s_a",ctx));
      // B: l1 locked, l2 unlocked → toggle !l1pmpflg[3]
      hdl_force(l2_path(e, "L2PDE_l1pmpflg"), uvm_hdl_data_t'(4'h8), ctx);
      hdl_force(l2_path(e, "L2PDE_l2pmpflg"), uvm_hdl_data_t'(4'h0), ctx); stage8_wait_cycles(1);
      drive_pde_req(18'(e), 9'(e), T_LOAD, 1'b1, $sformatf("%s_b",ctx)); release_pde_req($sformatf("%s_b",ctx)); clear_acc_err($sformatf("%s_bc",ctx));
      // C: l1 unlocked, l2 locked → toggle !l2pmpflg[3]
      hdl_force(l2_path(e, "L2PDE_l1pmpflg"), uvm_hdl_data_t'(4'h0), ctx);
      hdl_force(l2_path(e, "L2PDE_l2pmpflg"), uvm_hdl_data_t'(4'h8), ctx); stage8_wait_cycles(1);
      drive_pde_req(18'(e), 9'(e), T_LOAD, 1'b1, $sformatf("%s_c",ctx)); release_pde_req($sformatf("%s_c",ctx)); clear_acc_err($sformatf("%s_cc",ctx));
      // D: both locked → no bypass
      hdl_force(l2_path(e, "L2PDE_l1pmpflg"), uvm_hdl_data_t'(4'h8), ctx);
      hdl_force(l2_path(e, "L2PDE_l2pmpflg"), uvm_hdl_data_t'(4'h8), ctx); stage8_wait_cycles(1);
      drive_pde_req(18'(e), 9'(e), T_LOAD, 1'b1, $sformatf("%s_d",ctx)); release_pde_req($sformatf("%s_d",ctx)); clear_acc_err($sformatf("%s_dc",ctx));
      release_l2_entry(e, ctx);
    end
    release_priv_modes("l2_lock");
  endtask

  // Line 144: full expr URG 1 1 1 0 — accerr permission deny
  protected task cover_accerr_deny();
    string ctx;
    force_priv_modes(PRIV_S, PRIV_S, "l2_accerr");
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      ctx = $sformatf("l2_accerr_e%0d", e);
      program_l2_entry(e, 18'(e), 28'(28'h4000 + e), 4'h0, 4'h0, 1'b1, ctx);
      drive_pde_req(18'(e), 9'(e), T_LOAD, 1'b1, ctx);
      release_pde_req(ctx);
      clear_acc_err($sformatf("%s_clr", ctx));
      release_l2_entry(e, ctx);
    end
    force_priv_modes(PRIV_M, PRIV_M, "l2_accerr_mm");
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      ctx = $sformatf("l2_accerr_mm_e%0d", e);
      program_l2_entry(e, 18'(e), 28'(28'h5000 + e), 4'h8, 4'h8, 1'b1, ctx);
      drive_pde_req(18'(e), 9'(e), T_LOAD, 1'b1, ctx);
      release_pde_req(ctx);
      clear_acc_err($sformatf("%s_clr", ctx));
      release_l2_entry(e, ctx);
    end
    release_priv_modes("l2_accerr");
  endtask

  // Line 143: hit conditions
  protected task cover_hit_conditions();
    string ctx;
    force_priv_modes(PRIV_S, PRIV_S, "l2_hit");
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      ctx = $sformatf("l2_hit_e%0d", e);
      program_l2_entry(e, 18'(e), 28'(28'h6000 + e), 4'h7, 4'h7, 1'b1, ctx);
      drive_pde_req(18'(e), 9'(e), T_LOAD, 1'b1, ctx); release_pde_req(ctx);
      release_l2_entry(e, ctx);
    end
    force_priv_modes(PRIV_M, PRIV_M, "l2_hit_mm");
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      ctx = $sformatf("l2_hit_mm_e%0d", e);
      program_l2_entry(e, 18'(e), 28'(28'h7000 + e), 4'h0, 4'h0, 1'b1, ctx);
      drive_pde_req(18'(e), 9'(e), T_LOAD, 1'b1, ctx); release_pde_req(ctx);
      release_l2_entry(e, ctx);
    end
    // Tag mismatch
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      ctx = $sformatf("l2_miss_e%0d", e);
      program_l2_entry(e, 18'(e), 28'(28'h8000 + e), 4'h7, 4'h7, 1'b1, ctx);
      drive_pde_req(~18'(e), 9'(e), T_LOAD, 1'b1, ctx); release_pde_req(ctx);
      release_l2_entry(e, ctx);
    end
    release_priv_modes("l2_hit");
  endtask

  // ==================================================================
  // TOGGLE COVERAGE
  // ==================================================================

  protected task toggle_vld_signals(input string ctx);
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      pulse_bit(l2_path(e, "L2PDE_vld"),       $sformatf("%s_v_e%0d",  ctx, e));
      pulse_bit(l2_path(e, "L2PDE_entry_vld"), $sformatf("%s_ev_e%0d", ctx, e));
    end
  endtask

  protected task toggle_ppn_internal(input string ctx);
    for (int unsigned e = 0; e < L2E_NUM; e++)
      pulse_signal(l2_path(e, "L2PDE_ppn"), uvm_hdl_data_t'(28'h0fff_ffff), $sformatf("%s_pa_e%0d", ctx, e));
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      pulse_bit(l2_path(e, "L2PDE_ppn[1]"), $sformatf("%s_p1_e%0d", ctx, e)); pulse_bit(l2_path(e, "L2PDE_ppn[2]"), $sformatf("%s_p2_e%0d", ctx, e));
      pulse_bit(l2_path(e, "L2PDE_ppn[3]"), $sformatf("%s_p3_e%0d", ctx, e)); pulse_bit(l2_path(e, "L2PDE_ppn[5]"), $sformatf("%s_p5_e%0d", ctx, e));
      pulse_bit(l2_path(e, "L2PDE_ppn[6]"), $sformatf("%s_p6_e%0d", ctx, e));
    end
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      pulse_signal(l2_path(e, "L2PDE_ppn[3:2]"),   uvm_hdl_data_t'(2'b11),     $sformatf("%s_p32_e%0d",  ctx, e));
      pulse_signal(l2_path(e, "L2PDE_ppn[10:6]"),  uvm_hdl_data_t'(5'h1f),     $sformatf("%s_p106_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_ppn[27:11]"), uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_p2711_e%0d",ctx, e));
      pulse_signal(l2_path(e, "L2PDE_ppn[27:7]"),  uvm_hdl_data_t'(21'h1fffff),$sformatf("%s_p277_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_ppn[27:6]"),  uvm_hdl_data_t'(22'h3fffff),$sformatf("%s_p276_e%0d", ctx, e));
    end
  endtask

  protected task toggle_entry_ppn(input string ctx);
    for (int unsigned e = 0; e < L2E_NUM; e++)
      pulse_signal(l2_path(e, "L2PDE_entry_ppn"), uvm_hdl_data_t'(28'h0fff_ffff), $sformatf("%s_ea_e%0d", ctx, e));
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      pulse_bit(l2_path(e, "L2PDE_entry_ppn[1]"), $sformatf("%s_ep1_e%0d", ctx, e)); pulse_bit(l2_path(e, "L2PDE_entry_ppn[2]"), $sformatf("%s_ep2_e%0d", ctx, e));
      pulse_bit(l2_path(e, "L2PDE_entry_ppn[3]"), $sformatf("%s_ep3_e%0d", ctx, e)); pulse_bit(l2_path(e, "L2PDE_entry_ppn[5]"), $sformatf("%s_ep5_e%0d", ctx, e));
      pulse_bit(l2_path(e, "L2PDE_entry_ppn[6]"), $sformatf("%s_ep6_e%0d", ctx, e));
    end
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      pulse_signal(l2_path(e, "L2PDE_entry_ppn[3:2]"),   uvm_hdl_data_t'(2'b11),     $sformatf("%s_e32_e%0d",  ctx, e));
      pulse_signal(l2_path(e, "L2PDE_entry_ppn[10:6]"),  uvm_hdl_data_t'(5'h1f),     $sformatf("%s_e106_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_entry_ppn[27:11]"), uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_e2711_e%0d",ctx, e));
      pulse_signal(l2_path(e, "L2PDE_entry_ppn[27:7]"),  uvm_hdl_data_t'(21'h1fffff),$sformatf("%s_e277_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_entry_ppn[27:6]"),  uvm_hdl_data_t'(22'h3fffff),$sformatf("%s_e276_e%0d", ctx, e));
    end
  endtask

  protected task toggle_tag_bits(input string ctx);
    for (int unsigned e = 0; e < L2E_NUM; e++)
      pulse_signal(l2_path(e, "L2PDE_tag"), uvm_hdl_data_t'(18'h3ffff), $sformatf("%s_ta_e%0d", ctx, e));
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      pulse_bit(l2_path(e, "L2PDE_tag[0]"),  $sformatf("%s_t0_e%0d",  ctx, e));  pulse_bit(l2_path(e, "L2PDE_tag[1]"),  $sformatf("%s_t1_e%0d",  ctx, e));
      pulse_bit(l2_path(e, "L2PDE_tag[2]"),  $sformatf("%s_t2_e%0d",  ctx, e));  pulse_bit(l2_path(e, "L2PDE_tag[3]"),  $sformatf("%s_t3_e%0d",  ctx, e));
      pulse_bit(l2_path(e, "L2PDE_tag[5]"),  $sformatf("%s_t5_e%0d",  ctx, e));  pulse_bit(l2_path(e, "L2PDE_tag[6]"),  $sformatf("%s_t6_e%0d",  ctx, e));
      pulse_bit(l2_path(e, "L2PDE_tag[9]"),  $sformatf("%s_t9_e%0d",  ctx, e));  pulse_bit(l2_path(e, "L2PDE_tag[11]"), $sformatf("%s_t11_e%0d", ctx, e));
      pulse_bit(l2_path(e, "L2PDE_tag[12]"), $sformatf("%s_t12_e%0d", ctx, e));  pulse_bit(l2_path(e, "L2PDE_tag[13]"), $sformatf("%s_t13_e%0d", ctx, e));
      pulse_bit(l2_path(e, "L2PDE_tag[14]"), $sformatf("%s_t14_e%0d", ctx, e));  pulse_bit(l2_path(e, "L2PDE_tag[15]"), $sformatf("%s_t15_e%0d", ctx, e));
      pulse_bit(l2_path(e, "L2PDE_tag[16]"), $sformatf("%s_t16_e%0d", ctx, e));  pulse_bit(l2_path(e, "L2PDE_tag[17]"), $sformatf("%s_t17_e%0d", ctx, e));
    end
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      pulse_signal(l2_path(e, "L2PDE_tag[1:0]"),   uvm_hdl_data_t'(2'b11),  $sformatf("%s_t10_e%0d",   ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[2:0]"),   uvm_hdl_data_t'(3'b111), $sformatf("%s_t20_e%0d",   ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[3:0]"),   uvm_hdl_data_t'(4'hf),   $sformatf("%s_t30_e%0d",   ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[3:1]"),   uvm_hdl_data_t'(3'b111), $sformatf("%s_t31_e%0d",   ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[3:2]"),   uvm_hdl_data_t'(2'b11),  $sformatf("%s_t32_e%0d",   ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[9:8]"),   uvm_hdl_data_t'(2'b11),  $sformatf("%s_t98_e%0d",   ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[13:12]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_t1312_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[14:12]"), uvm_hdl_data_t'(3'b111), $sformatf("%s_t1412_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[14:13]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_t1413_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[16:13]"), uvm_hdl_data_t'(4'hf),   $sformatf("%s_t1613_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[17:12]"), uvm_hdl_data_t'(6'h3f),  $sformatf("%s_t1712_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[17:15]"), uvm_hdl_data_t'(3'b111), $sformatf("%s_t1715_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_tag[17:16]"), uvm_hdl_data_t'(2'b11),  $sformatf("%s_t1716_e%0d", ctx, e));
    end
  endtask

  protected task toggle_pmpflg_signals(input string ctx);
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      pulse_signal(l2_path(e, "L2PDE_l1pmpflg"),      uvm_hdl_data_t'(4'hf),   $sformatf("%s_l1f_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_l1pmpflg[2:0]"), uvm_hdl_data_t'(3'b111), $sformatf("%s_1f20_e%0d",ctx, e));
      pulse_signal(l2_path(e, "L2PDE_l1pmpflg[3]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_1f3_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_l2pmpflg"),      uvm_hdl_data_t'(4'hf),   $sformatf("%s_l2f_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_l2pmpflg[0]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_2f0_e%0d", ctx, e));
      pulse_signal(l2_path(e, "L2PDE_l2pmpflg[2:0]"), uvm_hdl_data_t'(3'b111), $sformatf("%s_2f20_e%0d",ctx, e));
      pulse_signal(l2_path(e, "L2PDE_l2pmpflg[3]"),   uvm_hdl_data_t'(1'b1),   $sformatf("%s_2f3_e%0d", ctx, e));
    end
  endtask

  protected task toggle_combinational_ok(input string ctx);
    force_priv_modes(PRIV_S, PRIV_S, $sformatf("%s_setup", ctx));
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      program_l2_entry(e, 18'(e), 28'(28'ha000 + e), 4'h1, 4'h7, 1'b1, $sformatf("%s_e%0d", ctx, e));
      drive_pde_req(18'(e), 9'(e), T_LOAD,  1'b1, $sformatf("%s_l", ctx)); release_pde_req($sformatf("%s_l", ctx));
      drive_pde_req(18'(e), 9'(e), T_STORE, 1'b1, $sformatf("%s_s", ctx)); release_pde_req($sformatf("%s_s", ctx));
      release_l2_entry(e, $sformatf("%s_rel", ctx));
      program_l2_entry(e, 18'(e), 28'(28'hb000 + e), 4'h7, 4'h1, 1'b1, $sformatf("%s2_e%0d", ctx, e));
      drive_pde_req(18'(e), 9'(e), T_LOAD,  1'b1, $sformatf("%s2_l", ctx)); release_pde_req($sformatf("%s2_l", ctx));
      drive_pde_req(18'(e), 9'(e), T_STORE, 1'b1, $sformatf("%s2_s", ctx)); release_pde_req($sformatf("%s2_s", ctx));
      release_l2_entry(e, $sformatf("%s2_rel", ctx));
    end
    release_priv_modes($sformatf("%s_done", ctx));
  endtask

  protected task toggle_upd_ppn(input string ctx);
    pulse_signal(l2_path(0, "L2PDE_upd_ppn"),         uvm_hdl_data_t'(28'h0fff_ffff), $sformatf("%s_all",  ctx));
    pulse_signal(l2_path(0, "L2PDE_upd_ppn[23:22]"),  uvm_hdl_data_t'(2'b11),         $sformatf("%s_2322", ctx));
    pulse_signal(l2_path(0, "L2PDE_upd_ppn[27:24]"),  uvm_hdl_data_t'(4'hf),          $sformatf("%s_2724", ctx));
  endtask

  // ==================================================================
  // Orchestration
  // ==================================================================
  protected task cover_all_conditions();
    `uvm_info(get_type_name(), "[L2PDE_COV] Starting conditions", UVM_NONE)
    enter_quiet("l2cq");
    cover_line61();
    cover_l1l2_ok();
    cover_mmode_lock();
    cover_accerr_deny();
    cover_hit_conditions();
    leave_quiet("l2cq");
    `uvm_info(get_type_name(), "[L2PDE_COV] Conditions done", UVM_NONE)
  endtask

  protected task cover_all_toggles();
    string ctx;
    `uvm_info(get_type_name(), "[L2PDE_COV] Starting toggles", UVM_NONE)
    enter_quiet("l2tq");
    ctx = "l2t";
    toggle_vld_signals(ctx);
    toggle_ppn_internal(ctx);
    toggle_entry_ppn(ctx);
    toggle_tag_bits(ctx);
    toggle_pmpflg_signals(ctx);
    toggle_combinational_ok($sformatf("%s_c", ctx));
    toggle_upd_ppn(ctx);
    leave_quiet("l2tq");
    `uvm_info(get_type_name(), "[L2PDE_COV] Toggles done", UVM_NONE)
  endtask

  virtual task run_test_body();
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-L2PDE-COND-TOGGLE-COV", "l2pde_cond_toggle_cov");
    ptw_meta_add_req("PTW-COV-L2PDE-COND-TOGGLE-001");

    cover_all_conditions();
    cover_all_toggles();

    ptw_meta_add_context("whitebox_l2pde_16entry");
    ptw_meta_set_expected("All L2PDE condition (61/143/144) and toggle items");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_l2pde_cond_toggle_cov");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-L2PDE-COND-TOGGLE-001", "l2pde_cov", "condition+toggle closure");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass : test_ptw_l2pde_cache_cond_toggle_cov

`endif // TEST_PTW_L2PDE_CACHE_COND_TOGGLE_COV_SVH
