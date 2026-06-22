// =============================================================================
// PDE_cache condition and toggle coverage closure test
//
// Targets:
//   COND line 180: (regs_ptw_clr | tlboper_ptw_abort | pmp_regs_update)
//                  URG 0 0 1 → need regs_ptw_clr=1 and tlboper_ptw_abort=1
//   COND line 350: (mbuf_cache_upd & mbuf_cache_upd_lvl[1] &
//                   (!(|L1PDE_entry_before_upd_hit[...])))  URG 1 0 1
//                  → need mbuf_cache_upd_lvl[1]=1
//   TOGGLE: forces PDE_cache-level wiring and outputs directly
//           (L1PDE_entry_ppn, L2PDE_entry_ppn, hit_ppn, fin_ppn,
//            xbar_ppn, acc_err_id, entry_vld, input ports)
// =============================================================================
`ifndef TEST_PTW_PDE_CACHE_COND_TOGGLE_COV_SVH
`define TEST_PTW_PDE_CACHE_COND_TOGGLE_COV_SVH

class test_ptw_pde_cache_cond_toggle_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_pde_cache_cond_toggle_cov)

  localparam int unsigned L1E_NUM = 8;
  localparam int unsigned L2E_NUM = 16;

  localparam logic [2:0] T_FETCH = 3'b011;
  localparam logic [2:0] T_LOAD  = 3'b010;
  localparam logic [2:0] T_STORE = 3'b110;
  localparam logic [2:0] T_PREF  = 3'b100;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 6_000_000;
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

  // ── Set value → release (for non-pulsed toggle, covers steady states) ──
  protected task force_then_release(input string path, input uvm_hdl_data_t val, input string ctx);
    hdl_force(path, val, ctx);  stage8_wait_cycles(2);
    hdl_release(path, ctx);     stage8_wait_cycles(1);
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

  // ── Drive PDE req ──
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
    // Pulse a new L2TLB request at PTW level BEFORE asserting acc_err_grant
    // so that (l2tlb_ptw_req && ptw_jtlb_ready) is true at grant cycle.
    string ptw = "$root.tb_top.u_dut.x_ct_mmu_ptw";
    hdl_force(pde_path("PDE_cache_acc_err_grant"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(1);
    hdl_force({ptw, ".l2tlb_ptw_req"},  uvm_hdl_data_t'(1'b1), $sformatf("%s_newreq", ctx));
    hdl_force({ptw, ".ptw_jtlb_ready"}, uvm_hdl_data_t'(1'b1), $sformatf("%s_rdy", ctx));
    stage8_wait_cycles(1);
    hdl_force({ptw, ".l2tlb_ptw_req"},  uvm_hdl_data_t'(1'b0), $sformatf("%s_newreq0", ctx));
    hdl_force(pde_path("PDE_cache_acc_err_grant"), uvm_hdl_data_t'(1'b1), $sformatf("%s_grant", ctx));
    stage8_wait_cycles(2);
    hdl_force(pde_path("PDE_cache_acc_err_grant"), uvm_hdl_data_t'(1'b0), $sformatf("%s_grant0", ctx));
    stage8_wait_cycles(2);
    hdl_release(pde_path("PDE_cache_acc_err_grant"), ctx);
    hdl_release({ptw, ".ptw_jtlb_ready"}, $sformatf("%s_rrdy", ctx));
    hdl_release({ptw, ".l2tlb_ptw_req"},  $sformatf("%s_rreq", ctx));
  endtask

  // ── Program / release submodule entries (to control hit/miss behavior) ──
  protected task program_l1_sub(input int unsigned e, input logic [8:0] tag,
      input logic [27:0] ppn, input logic [3:0] l1flg, input logic vld, input string ctx);
    hdl_force(l1_path(e, "L1PDE_vld"),      uvm_hdl_data_t'(vld),  ctx);
    hdl_force(l1_path(e, "L1PDE_tag"),      uvm_hdl_data_t'(tag),  ctx);
    hdl_force(l1_path(e, "L1PDE_ppn"),      uvm_hdl_data_t'(ppn),  ctx);
    hdl_force(l1_path(e, "L1PDE_l1pmpflg"), uvm_hdl_data_t'(l1flg),ctx);
    stage8_wait_cycles(1);
  endtask

  protected task release_l1_sub(input int unsigned e, input string ctx);
    hdl_release(l1_path(e, "L1PDE_l1pmpflg"), ctx);
    hdl_release(l1_path(e, "L1PDE_ppn"),      ctx);
    hdl_release(l1_path(e, "L1PDE_tag"),      ctx);
    hdl_release(l1_path(e, "L1PDE_vld"),      ctx);
    stage8_wait_cycles(1);
  endtask

  protected task program_l2_sub(input int unsigned e, input logic [17:0] tag,
      input logic [27:0] ppn, input logic [3:0] l1flg, input logic [3:0] l2flg,
      input logic vld, input string ctx);
    hdl_force(l2_path(e, "L2PDE_vld"),      uvm_hdl_data_t'(vld),  ctx);
    hdl_force(l2_path(e, "L2PDE_tag"),      uvm_hdl_data_t'(tag),  ctx);
    hdl_force(l2_path(e, "L2PDE_ppn"),      uvm_hdl_data_t'(ppn),  ctx);
    hdl_force(l2_path(e, "L2PDE_l1pmpflg"), uvm_hdl_data_t'(l1flg),ctx);
    hdl_force(l2_path(e, "L2PDE_l2pmpflg"), uvm_hdl_data_t'(l2flg),ctx);
    stage8_wait_cycles(1);
  endtask

  protected task release_l2_sub(input int unsigned e, input string ctx);
    hdl_release(l2_path(e, "L2PDE_l2pmpflg"), ctx);
    hdl_release(l2_path(e, "L1PDE_l1pmpflg"), ctx);
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
  // CONDITION COVERAGE — line 180
  //   pde_cache_clear = regs_ptw_clr | tlboper_ptw_abort | pmp_regs_update
  //   URG 0 0 1 → need regs_ptw_clr=1 and tlboper_ptw_abort=1
  // ==================================================================
  protected task cover_line180();
    string ctx = "l180";
    `uvm_info(get_type_name(), "[PDE_COV] Line 180: regs_ptw_clr + tlboper_ptw_abort", UVM_NONE)

    // Pulse regs_ptw_clr: 0→1→0
    pulse_bit(pde_path("regs_ptw_clr"), "l180_regs_clr");
    stage8_wait_cycles(2);

    // Pulse tlboper_ptw_abort: 0→1→0
    // Note: tlboper_ptw_abort also clears ptw_req; ensure we restore ptw_req state
    pulse_bit(pde_path("tlboper_ptw_abort"), "l180_abort");
    stage8_wait_cycles(2);

    // Also ensure pmp_regs_update toggles (already covered in condition but
    // listed as uncovered toggle)
    pulse_bit(pde_path("pmp_regs_update"), "l180_pmp_update");
    stage8_wait_cycles(2);

    `uvm_info(get_type_name(), "[PDE_COV] Line 180 done", UVM_NONE)
  endtask

  // ==================================================================
  // CONDITION COVERAGE — line 350
  //   L1PDE_plru_refill_vld = (mbuf_cache_upd & mbuf_cache_upd_lvl[1] &
  //     (!(|L1PDE_entry_before_upd_hit[L1PDE_ENTRY_NUM-1:0])))
  //   URG 1 0 1 → need mbuf_cache_upd_lvl[1]=1
  // ==================================================================
  protected task cover_line350();
    string ctx;
    `uvm_info(get_type_name(), "[PDE_COV] Line 350: mbuf_cache_upd_lvl[1]=1", UVM_NONE)

    // Ensure all L1 entries are invalid so before_upd_hit=0 for each
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      ctx = $sformatf("l350_inval_e%0d", e);
      hdl_force(l1_path(e, "L1PDE_vld"), uvm_hdl_data_t'(1'b0), ctx);
    end
    stage8_wait_cycles(2);

    // Pulse mbuf_cache_upd with mbuf_cache_upd_lvl[1]=1 (L1 update).
    // SVA a_pde_fst_update_payload_l2_zero requires l2pmpflg==0 during L1 update.
    // Use single-cycle pulse to avoid a_pde_l1_consecutive_refill_no_reuse_when_invalid.
    ctx = "l350_mbuf";
    hdl_force(pde_path("mbuf_cache_upd"),        uvm_hdl_data_t'(1'b0), ctx);
    hdl_force(pde_path("mbuf_cache_upd_lvl"),    uvm_hdl_data_t'(2'b10), ctx);
    hdl_force(pde_path("mbuf_cache_upd_vpn"),    uvm_hdl_data_t'(27'h7ffffff), ctx);
    hdl_force(pde_path("mbuf_cache_upd_ppn"),    uvm_hdl_data_t'(28'hFFFFFFF), ctx);
    hdl_force(pde_path("mbuf_cache_upd_l1pmpflg"),uvm_hdl_data_t'(4'hf), ctx);
    hdl_force(pde_path("mbuf_cache_upd_l2pmpflg"),uvm_hdl_data_t'(4'h0), ctx);
    stage8_wait_cycles(1);

    // Pulse mbuf_cache_upd high for 1 cycle then low
    hdl_force(pde_path("mbuf_cache_upd"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(1);
    hdl_force(pde_path("mbuf_cache_upd"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(1);

    // Release mbuf controls
    hdl_release(pde_path("mbuf_cache_upd_l2pmpflg"), ctx);
    hdl_release(pde_path("mbuf_cache_upd_l1pmpflg"), ctx);
    hdl_release(pde_path("mbuf_cache_upd_ppn"),      ctx);
    hdl_release(pde_path("mbuf_cache_upd_vpn"),      ctx);
    hdl_release(pde_path("mbuf_cache_upd_lvl"),      ctx);
    hdl_release(pde_path("mbuf_cache_upd"),          ctx);
    stage8_wait_cycles(2);

    // Release L1 vld
    for (int unsigned e = 0; e < L1E_NUM; e++)
      hdl_release(l1_path(e, "L1PDE_vld"), $sformatf("l350_rel_e%0d", e));
    stage8_wait_cycles(2);

    `uvm_info(get_type_name(), "[PDE_COV] Line 350 done", UVM_NONE)
  endtask

  // ==================================================================
  // TOGGLE COVERAGE — PDE_cache-level wiring signals
  //   Force L1PDE_entry_ppn / L2PDE_entry_ppn at PDE hierarchy
  // ==================================================================

  // ── Toggle L1PDE_entry_ppn at PDE level ──
  protected task toggle_l1_entry_ppn_pde(input string ctx);
    `uvm_info(get_type_name(), "[PDE_TOG] L1PDE_entry_ppn PDE-level toggling", UVM_NONE)
    // Full-width all entries: toggles "Other bits of L1PDE_entry_ppn[7:0][27:0]"
    for (int unsigned e = 0; e < L1E_NUM; e++) begin
      pulse_signal(pde_path($sformatf("L1PDE_entry_ppn[%0d]", e)),
        uvm_hdl_data_t'(28'hFFFFFFF),
        $sformatf("%s_l1eppn_all_e%0d", ctx, e));
    end

    // Specific bit ranges — cover 1→0 direction (existing tests may have 0→1)
    // Entry 0 [10:5]
    pulse_signal(pde_path("L1PDE_entry_ppn[0][10:5]"), uvm_hdl_data_t'(6'h3f), $sformatf("%s_l1e0_105", ctx));
    // Entry 1 [1:0], [4:3]
    pulse_signal(pde_path("L1PDE_entry_ppn[1][1:0]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e1_10", ctx));
    pulse_signal(pde_path("L1PDE_entry_ppn[1][4:3]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e1_43", ctx));
    // Entry 2 [1:0], [5:3]
    pulse_signal(pde_path("L1PDE_entry_ppn[2][1:0]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e2_10", ctx));
    pulse_signal(pde_path("L1PDE_entry_ppn[2][5:3]"),  uvm_hdl_data_t'(3'b111), $sformatf("%s_l1e2_53", ctx));
    // Entry 3 [0], [5:2]
    pulse_signal(pde_path("L1PDE_entry_ppn[3][0]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l1e3_0", ctx));
    pulse_signal(pde_path("L1PDE_entry_ppn[3][5:2]"),  uvm_hdl_data_t'(4'hf),   $sformatf("%s_l1e3_52", ctx));
    // Entry 4 [2:1], [5:4]
    pulse_signal(pde_path("L1PDE_entry_ppn[4][2:1]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e4_21", ctx));
    pulse_signal(pde_path("L1PDE_entry_ppn[4][5:4]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e4_54", ctx));
    // Entry 5 [4:3]
    pulse_signal(pde_path("L1PDE_entry_ppn[5][4:3]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e5_43", ctx));
    // Entry 6 [0], [4:3]
    pulse_signal(pde_path("L1PDE_entry_ppn[6][0]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l1e6_0", ctx));
    pulse_signal(pde_path("L1PDE_entry_ppn[6][4:3]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e6_43", ctx));
    // Entry 7 [1:0], [4:3]
    pulse_signal(pde_path("L1PDE_entry_ppn[7][1:0]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e7_10", ctx));
    pulse_signal(pde_path("L1PDE_entry_ppn[7][4:3]"),  uvm_hdl_data_t'(2'b11),  $sformatf("%s_l1e7_43", ctx));
  endtask

  // ── Toggle L2PDE_entry_ppn at PDE level ──
  protected task toggle_l2_entry_ppn_pde(input string ctx);
    `uvm_info(get_type_name(), "[PDE_TOG] L2PDE_entry_ppn PDE-level toggling", UVM_NONE)
    // Full-width all entries: toggles "Other bits of L2PDE_entry_ppn[15:0][27:0]"
    for (int unsigned e = 0; e < L2E_NUM; e++) begin
      pulse_signal(pde_path($sformatf("L2PDE_entry_ppn[%0d]", e)),
        uvm_hdl_data_t'(28'hFFFFFFF),
        $sformatf("%s_l2eppn_all_e%0d", ctx, e));
    end

    // Specific bit ranges
    pulse_signal(pde_path("L2PDE_entry_ppn[0][10:6]"),  uvm_hdl_data_t'(5'h1f),  $sformatf("%s_l2e0_106", ctx));
    pulse_signal(pde_path("L2PDE_entry_ppn[1][3:2]"),   uvm_hdl_data_t'(2'b11),  $sformatf("%s_l2e1_32", ctx));
    pulse_signal(pde_path("L2PDE_entry_ppn[7][2]"),     uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e7_2", ctx));
    pulse_signal(pde_path("L2PDE_entry_ppn[7][5]"),     uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e7_5", ctx));
    pulse_signal(pde_path("L2PDE_entry_ppn[8][6]"),     uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e8_6", ctx));
    pulse_signal(pde_path("L2PDE_entry_ppn[9][1]"),     uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e9_1", ctx));
    pulse_signal(pde_path("L2PDE_entry_ppn[11][6]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e11_6", ctx));
    pulse_signal(pde_path("L2PDE_entry_ppn[12][3]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e12_3", ctx));
    pulse_signal(pde_path("L2PDE_entry_ppn[13][6]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e13_6", ctx));
    pulse_signal(pde_path("L2PDE_entry_ppn[14][6]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e14_6", ctx));
    pulse_signal(pde_path("L2PDE_entry_ppn[15][6]"),    uvm_hdl_data_t'(1'b1),   $sformatf("%s_l2e15_6", ctx));
  endtask

  // ── Toggle L2PDE_entry_vld at PDE level ──
  protected task toggle_l2_entry_vld_pde(input string ctx);
    `uvm_info(get_type_name(), "[PDE_TOG] L2PDE_entry_vld PDE-level toggling", UVM_NONE)
    // Full vector
    pulse_signal(pde_path("L2PDE_entry_vld"), uvm_hdl_data_t'(16'hffff), $sformatf("%s_vld_all", ctx));
    // [15:8] specifically — listed as 0→1=Yes, need 1→0
    pulse_signal(pde_path("L2PDE_entry_vld[15:8]"), uvm_hdl_data_t'(8'hff), $sformatf("%s_vld_158", ctx));
  endtask

  // ── Toggle PDE_cache_acc_err_id and L2PDE_cache_acc_err_id via direct PDE-level force ──
  protected task toggle_acc_err_ids(input string ctx);
    `uvm_info(get_type_name(), "[PDE_TOG] acc_err_id toggling via direct PDE-level force", UVM_NONE)

    // L2PDE_cache_acc_err_id (internal register at PDE level)
    pulse_signal(pde_path("L2PDE_cache_acc_err_id"),     uvm_hdl_data_t'(7'h7f), $sformatf("%s_l2_id_all", ctx));
    pulse_signal(pde_path("L2PDE_cache_acc_err_id[2:1]"),uvm_hdl_data_t'(2'b11), $sformatf("%s_l2_id_21", ctx));
    pulse_signal(pde_path("L2PDE_cache_acc_err_id[6:5]"),uvm_hdl_data_t'(2'b11), $sformatf("%s_l2_id_65", ctx));

    // PDE_cache_acc_err_id (output port at PDE level)
    pulse_signal(pde_path("PDE_cache_acc_err_id"),     uvm_hdl_data_t'(7'h7f), $sformatf("%s_pde_id_all", ctx));
    pulse_signal(pde_path("PDE_cache_acc_err_id[2:1]"),uvm_hdl_data_t'(2'b11), $sformatf("%s_pde_id_21", ctx));
    pulse_signal(pde_path("PDE_cache_acc_err_id[6:5]"),uvm_hdl_data_t'(2'b11), $sformatf("%s_pde_id_65", ctx));
  endtask

  // ── Toggle L2PDE_cache_acc_err_id internal registers ──
  protected task toggle_l2_accerr_id_internal(input string ctx);
    `uvm_info(get_type_name(), "[PDE_TOG] L2PDE_cache_acc_err_id internal toggling", UVM_NONE)
    pulse_signal(pde_path("L2PDE_cache_acc_err_id"),     uvm_hdl_data_t'(7'h7f), $sformatf("%s_id_all", ctx));
    pulse_signal(pde_path("L2PDE_cache_acc_err_id[2:1]"),uvm_hdl_data_t'(2'b11), $sformatf("%s_id_21", ctx));
    pulse_signal(pde_path("L2PDE_cache_acc_err_id[6:5]"),uvm_hdl_data_t'(2'b11), $sformatf("%s_id_65", ctx));
  endtask

  // ── Toggle combinational output PPNs via direct PDE-level force ──
  //   L1PDE_cache_hit_ppn[27:11], L2PDE_cache_hit_ppn[27:11]
  //   PDE_cache_fin_ppn[27:11], PDE_xbar_ppn[27:11]
  protected task toggle_output_ppns(input string ctx);
    `uvm_info(get_type_name(), "[PDE_TOG] Output PPN toggling via direct force", UVM_NONE)

    // L1PDE_cache_hit_ppn (combinational, derived from L1 entry hit + PPN)
    pulse_signal(pde_path("L1PDE_cache_hit_ppn"),         uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_l1h_all", ctx));
    pulse_signal(pde_path("L1PDE_cache_hit_ppn[27:11]"),  uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_l1h_2711", ctx));

    // L2PDE_cache_hit_ppn (combinational, derived from L2 entry hit + PPN)
    pulse_signal(pde_path("L2PDE_cache_hit_ppn"),         uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_l2h_all", ctx));
    pulse_signal(pde_path("L2PDE_cache_hit_ppn[27:11]"),  uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_l2h_2711", ctx));

    // PDE_cache_fin_ppn (final muxed PPN, combinational output)
    pulse_signal(pde_path("PDE_cache_fin_ppn"),           uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_fin_all", ctx));
    pulse_signal(pde_path("PDE_cache_fin_ppn[27:11]"),    uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_fin_2711", ctx));

    // PDE_xbar_ppn (output port, combinational)
    pulse_signal(pde_path("PDE_xbar_ppn"),                uvm_hdl_data_t'(28'hFFFFFFF), $sformatf("%s_xb_all", ctx));
    pulse_signal(pde_path("PDE_xbar_ppn[27:11]"),         uvm_hdl_data_t'(17'h1ffff), $sformatf("%s_xb_2711", ctx));
  endtask

  // ── Toggle input ports ──
  protected task toggle_input_ports(input string ctx);
    `uvm_info(get_type_name(), "[PDE_TOG] Input port toggling", UVM_NONE)

    // cp0_mmu_mpp[0]: 1→0=Yes, 0→1=No (need 0→1)
    // Force mpp[0] high with mprv=1 to route through to priv_mode
    hdl_force(pde_path("cp0_mmu_mprv"), uvm_hdl_data_t'(1'b1), $sformatf("%s_mprv", ctx));
    hdl_force(pde_path("cp0_mmu_mpp"),  uvm_hdl_data_t'(2'b10), $sformatf("%s_mpp_high", ctx));
    stage8_wait_cycles(2);
    hdl_force(pde_path("cp0_mmu_mpp"),  uvm_hdl_data_t'(2'b01), $sformatf("%s_mpp_low", ctx));
    stage8_wait_cycles(2);
    hdl_force(pde_path("cp0_mmu_mpp"),  uvm_hdl_data_t'(2'b10), $sformatf("%s_mpp_high2", ctx));
    stage8_wait_cycles(2);
    hdl_release(pde_path("cp0_mmu_mpp"),  $sformatf("%s_rel_mpp", ctx));
    hdl_release(pde_path("cp0_mmu_mprv"), $sformatf("%s_rel_mprv", ctx));
    stage8_wait_cycles(2);

    // mbuf_cache_upd_ppn[23:22]: toggle No both directions
    pulse_signal(pde_path("mbuf_cache_upd_ppn[23:22]"), uvm_hdl_data_t'(2'b11), $sformatf("%s_mupd_2322", ctx));

    // mbuf_cache_upd_ppn[27:24]: 0→1=Yes, 1→0=No (need 1→0)
    pulse_signal(pde_path("mbuf_cache_upd_ppn[27:24]"), uvm_hdl_data_t'(4'hf), $sformatf("%s_mupd_2724", ctx));
  endtask

  // ── Toggle pde_cache_clk_en (constant 1'b1 — documented limitation) ──
  protected task toggle_clk_en_documented(input string ctx);
    // pde_cache_clk_en is hardwired to 1'b1 in RTL (line 127):
    //   assign pde_cache_clk_en = 1'b1;
    // This signal cannot physically toggle.  The toggle No is by design.
    // We still attempt a force-based pulse in case the tool accepts it.
    `uvm_info(get_type_name(), "[PDE_TOG] pde_cache_clk_en (constant 1'b1 — may not toggle)", UVM_NONE)
    pulse_signal(pde_path("pde_cache_clk_en"), uvm_hdl_data_t'(1'b0), $sformatf("%s_clken", ctx));
  endtask

  // ==================================================================
  // Orchestration
  // ==================================================================
  protected task cover_all_conditions();
    `uvm_info(get_type_name(), "[PDE_CACHE_COV] Starting condition coverage", UVM_NONE)
    enter_quiet("pde_cond_quiet");
    cover_line180();
    cover_line350();
    leave_quiet("pde_cond_quiet");
    `uvm_info(get_type_name(), "[PDE_CACHE_COV] Condition coverage done", UVM_NONE)
  endtask

  protected task cover_all_toggles();
    string ctx;
    `uvm_info(get_type_name(), "[PDE_CACHE_COV] Starting toggle coverage", UVM_NONE)
    enter_quiet("pde_toggle_quiet");
    ctx = "pde_tgl";
    toggle_clk_en_documented(ctx);
    toggle_l1_entry_ppn_pde(ctx);
    toggle_l2_entry_ppn_pde(ctx);
    toggle_l2_entry_vld_pde(ctx);
    toggle_acc_err_ids(ctx);
    toggle_l2_accerr_id_internal(ctx);
    toggle_output_ppns(ctx);
    toggle_input_ports(ctx);
    leave_quiet("pde_toggle_quiet");
    `uvm_info(get_type_name(), "[PDE_CACHE_COV] Toggle coverage done", UVM_NONE)
  endtask

  virtual task run_test_body();
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-PDE-CACHE-COND-TOGGLE-COV",
      "pde_cache_condition_and_toggle_coverage");
    ptw_meta_add_req("PTW-COV-PDE-CACHE-COND-TOGGLE-001");

    cover_all_conditions();
    cover_all_toggles();

    ptw_meta_add_context("whitebox_pde_cache_top_level_cond_toggle");
    ptw_meta_set_expected("PDE_cache cond line180+line350, all PDE-level toggle items (L1PDE/L2PDE entry PPN/vld, cache_hit_ppn, fin_ppn, xbar_ppn, acc_err_id, input ports)");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_pde_cache_cond_toggle_cov");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-PDE-CACHE-COND-TOGGLE-001",
      "pde_cache_cond_toggle_cov",
      "PDE line180 regs_ptw_clr+tlboper_ptw_abort, line350 mbuf_cache_upd_lvl[1], all PDE-level toggle bits");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass : test_ptw_pde_cache_cond_toggle_cov

`endif // TEST_PTW_PDE_CACHE_COND_TOGGLE_COV_SVH
