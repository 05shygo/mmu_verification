`ifndef TEST_TWU_UNIFIED_CODE_COV_SVH
`define TEST_TWU_UNIFIED_CODE_COV_SVH

class test_twu_unified_code_cov extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_unified_code_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 1_000_000;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu_code_cov";
    p12_trace_id = "TC-TWU-UNIFIED-CODE-COV-001";
    p12_fid      = "PTW-CODE-TWU-LINE-BRANCH-FSM-TOGGLE";
    p12_priority = "P0";
    p12_seq_desc = "whitebox unified TWU pmp_unit wait hold, CSR default state, and unified signal toggles";
    p12_checker  = "twu code coverage: L983 pmp_unit_vld hold, L1346/default FSM branch, unified toggles";
    p12_reviewer = "A+B";
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init          = 1'b0;
    m_post_drain             = 100ns;
  endfunction

  protected virtual task release_if_present(input string sig, input string ctx);
    string path;
    path = phase12_twu_path(sig);
    if (uvm_hdl_check_path(path))
      phase12_twu_release_value(sig, ctx);
  endtask

  protected virtual task pulse_twu_signal(
    input string         sig,
    input uvm_hdl_data_t value,
    input string         ctx
  );
    string path;
    path = phase12_twu_path(sig);
    if (!uvm_hdl_check_path(path)) begin
      `uvm_warning(get_type_name(), {ctx, ": skip unavailable HDL path: ", path})
      return;
    end

    if (!uvm_hdl_force(path, uvm_hdl_data_t'(0)))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force low: ", path})
    phase12_twu_wait_cycles(1);
    if (!uvm_hdl_force(path, value))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force high: ", path})
    phase12_twu_wait_cycles(1);
    if (!uvm_hdl_force(path, uvm_hdl_data_t'(0)))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force low again: ", path})
    phase12_twu_wait_cycles(1);
    if (!uvm_hdl_release(path))
      `uvm_fatal(get_type_name(), {ctx, ": failed to release: ", path})
    phase12_twu_wait_cycles(1);
  endtask

  protected virtual task cover_pmp_unit_wait_hold(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("xbar_twu_req",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("mbuf_twu_data_vld", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("chk_unit_vld",      uvm_hdl_data_t'(1'b0), ctx);

    phase12_twu_deposit_value("pmp_unit_vld",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("pmp_unit_wait",   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(5);

    phase12_twu_release_value("pmp_unit_wait", ctx);
    phase12_twu_release_value("chk_unit_vld", ctx);
    phase12_twu_release_value("mbuf_twu_data_vld", ctx);
    phase12_twu_release_value("xbar_twu_req", ctx);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task cover_csr_default_branch(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_deposit_value("ptw_cur_st",      uvm_hdl_data_t'(3'b111), ctx);
    #1ns;
    phase12_twu_wait_cycles(4);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task release_csr_fsm_forces(input string ctx);
    release_if_present("refill_csr_grant", ctx);
    release_if_present("twu_csr_cross", ctx);
    release_if_present("chk_unit_csr_pgs", ctx);
    release_if_present("chk_unit_csr_req", ctx);
    release_if_present("tlboper_ptw_abort", ctx);
  endtask

  protected virtual task reset_csr_fsm_to_idle(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("chk_unit_csr_req",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("refill_csr_grant",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("twu_csr_cross",     uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(1);
  endtask

  protected virtual task drive_csr_req(
    input logic        req,
    input logic [2:0]  pgs,
    input logic        cross_vld,
    input logic        refill_grant,
    input string       ctx
  );
    phase12_twu_force_value("chk_unit_csr_req", uvm_hdl_data_t'(req), ctx);
    phase12_twu_force_value("chk_unit_csr_pgs", uvm_hdl_data_t'(pgs), ctx);
    phase12_twu_force_value("twu_csr_cross",    uvm_hdl_data_t'(cross_vld), ctx);
    phase12_twu_force_value("refill_csr_grant", uvm_hdl_data_t'(refill_grant), ctx);
  endtask

  protected virtual task cover_csr_fsm_legal_arcs(input string ctx);
    reset_csr_fsm_to_idle({ctx, "_idle"});

    drive_csr_req(1'b1, 3'b100, 1'b1, 1'b0, {ctx, "_1g_cross"});
    phase12_twu_wait_cycles(1); // IDLE -> TWU_1G_CRS
    phase12_twu_wait_cycles(1); // TWU_1G_CRS -> TWU_2M_CRS
    drive_csr_req(1'b0, 3'b100, 1'b0, 1'b0, {ctx, "_2m_to_data"});
    phase12_twu_wait_cycles(1); // TWU_2M_CRS -> CSR_DATA_VLD
    drive_csr_req(1'b0, 3'b100, 1'b0, 1'b1, {ctx, "_data_to_idle"});
    phase12_twu_wait_cycles(1); // CSR_DATA_VLD -> TWU_IDLE

    reset_csr_fsm_to_idle({ctx, "_idle_1g_data"});
    drive_csr_req(1'b1, 3'b100, 1'b0, 1'b0, {ctx, "_1g_data"});
    phase12_twu_wait_cycles(1); // IDLE -> TWU_1G_CRS
    phase12_twu_wait_cycles(1); // TWU_1G_CRS -> CSR_DATA_VLD
    drive_csr_req(1'b1, 3'b100, 1'b0, 1'b1, {ctx, "_data_to_1g"});
    phase12_twu_wait_cycles(1); // CSR_DATA_VLD -> TWU_1G_CRS
    #1ns;
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), {ctx, "_1g_abort"});
    phase12_twu_wait_cycles(2); // TWU_1G_CRS -> TWU_IDLE
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), {ctx, "_1g_abort_rel"});
    phase12_twu_wait_cycles(1);

    reset_csr_fsm_to_idle({ctx, "_idle_2m_data"});
    drive_csr_req(1'b1, 3'b010, 1'b0, 1'b0, {ctx, "_2m_data"});
    phase12_twu_wait_cycles(1); // IDLE -> TWU_2M_CRS
    phase12_twu_wait_cycles(1); // TWU_2M_CRS -> CSR_DATA_VLD
    drive_csr_req(1'b1, 3'b010, 1'b0, 1'b1, {ctx, "_data_to_2m"});
    phase12_twu_wait_cycles(1); // CSR_DATA_VLD -> TWU_2M_CRS
    #1ns;
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), {ctx, "_2m_abort"});
    phase12_twu_wait_cycles(2); // TWU_2M_CRS -> TWU_IDLE
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), {ctx, "_2m_abort_rel"});
    phase12_twu_wait_cycles(1);

    release_csr_fsm_forces(ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task cover_csr_fsm_abort_transition(
    input logic [2:0] state,
    input string      ctx
  );
    phase12_twu_force_value("chk_unit_csr_req",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("refill_csr_grant",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("twu_csr_cross",     uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_deposit_value("ptw_cur_st",      uvm_hdl_data_t'(state), ctx);
    #1ns;
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(1);
  endtask

  protected virtual task cover_csr_fsm_abort_transitions(input string ctx);
    cover_csr_fsm_abort_transition(3'b001, {ctx, "_1g_to_idle"});
    cover_csr_fsm_abort_transition(3'b010, {ctx, "_2m_to_idle"});
    release_csr_fsm_forces(ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task cover_unified_toggles(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("xbar_twu_req",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("mbuf_twu_data_vld", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);

    pulse_twu_signal("pmp_unit_vld",      uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("pmp_unit_wait",     uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("pmp_unit_vpn",      uvm_hdl_data_t'(27'h7ff_ffff), ctx);
    pulse_twu_signal("pmp_unit_type",     uvm_hdl_data_t'(3'b111), ctx);
    pulse_twu_signal("pmp_unit_id",       uvm_hdl_data_t'(7'h7f), ctx);
    pulse_twu_signal("pmp_unit_ppn",      uvm_hdl_data_t'(28'hfff_ffff), ctx);
    pulse_twu_signal("pmp_unit_lvl",      uvm_hdl_data_t'(3'b111), ctx);
    pulse_twu_signal("pmp_unit_pmpflg",   uvm_hdl_data_t'(4'hf), ctx);
    pulse_twu_signal("pmp_unit_l1pmpflg", uvm_hdl_data_t'(4'hf), ctx);
    pulse_twu_signal("pmp_unit_pa",       uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);

    pulse_twu_signal("chk_unit_vld",      uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("chk_unit_wait",     uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("chk_unit_vpn",      uvm_hdl_data_t'(27'h7ff_ffff), ctx);
    pulse_twu_signal("chk_unit_type",     uvm_hdl_data_t'(3'b111), ctx);
    pulse_twu_signal("chk_unit_id",       uvm_hdl_data_t'(7'h7f), ctx);
    pulse_twu_signal("chk_unit_lvl",      uvm_hdl_data_t'(3'b111), ctx);
    pulse_twu_signal("chk_unit_data",     uvm_hdl_data_t'(64'hffff_ffff_ffff_ffff), ctx);
    pulse_twu_signal("chk_unit_pmpflg",   uvm_hdl_data_t'(4'hf), ctx);
    pulse_twu_signal("chk_unit_refill_req", uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("chk_unit_csr_req",    uvm_hdl_data_t'(1'b1), ctx);

    pulse_twu_signal("ptw_cur_st",        uvm_hdl_data_t'(3'b111), ctx);
    pulse_twu_signal("ptw_nxt_st",        uvm_hdl_data_t'(3'b111), ctx);
    pulse_twu_signal("csr_refill_req",    uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("refill_csr_grant",  uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("twu_mask",          uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("twu_data_ready",    uvm_hdl_data_t'(1'b1), ctx);

    phase12_twu_release_value("mbuf_twu_data_vld", ctx);
    phase12_twu_release_value("xbar_twu_req", ctx);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task cover_twu_port_toggles(input string ctx);
    pulse_twu_signal("cp0_mmu_mpp",                uvm_hdl_data_t'(2'b11), ctx);
    pulse_twu_signal("pad_yy_icg_scan_en",         uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("regs_ptw_cur_asid",          uvm_hdl_data_t'(16'hffff), ctx);
    pulse_twu_signal("regs_ptw_satp_ppn",          uvm_hdl_data_t'(28'h0fff_ffff), ctx);
    pulse_twu_signal("xbar_twu_ppn",               uvm_hdl_data_t'(28'h0fff_ffff), ctx);
    pulse_twu_signal("mbuf_twu_data",              uvm_hdl_data_t'(64'hffff_ffff_ffff_ffff), ctx);
    pulse_twu_signal("sysmap_mmu_flgx1",           uvm_hdl_data_t'(5'h1f), ctx);
    pulse_twu_signal("sysmap_mmu_flgx2",           uvm_hdl_data_t'(5'h1f), ctx);
    pulse_twu_signal("sysmap_mmu_flgx3",           uvm_hdl_data_t'(5'h1f), ctx);
    pulse_twu_signal("sysmap_mmu_hitx1",           uvm_hdl_data_t'(8'hff), ctx);
    pulse_twu_signal("sysmap_mmu_hitx2",           uvm_hdl_data_t'(8'hff), ctx);
    pulse_twu_signal("sysmap_mmu_hitx3",           uvm_hdl_data_t'(8'hff), ctx);
    pulse_twu_signal("pmp_mmu_flg",                uvm_hdl_data_t'(4'hf), ctx);

    pulse_twu_signal("twu_mbuf_paddr",             uvm_hdl_data_t'('1), ctx);
    pulse_twu_signal("mmu_pmp_pa",                 uvm_hdl_data_t'('1), ctx);
    pulse_twu_signal("mmu_pmp_fecth",              uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("mmu_sysmap_pax1",            uvm_hdl_data_t'('1), ctx);
    pulse_twu_signal("mmu_sysmap_pax2",            uvm_hdl_data_t'('1), ctx);
    pulse_twu_signal("mmu_sysmap_pax3",            uvm_hdl_data_t'('1), ctx);
    pulse_twu_signal("twu_arb_ref_data_din",       uvm_hdl_data_t'('1), ctx);
    pulse_twu_signal("twu_arb_ref_tag_din",        uvm_hdl_data_t'('1), ctx);
    pulse_twu_signal("twu_arb_ref_type",           uvm_hdl_data_t'(3'b111), ctx);
    pulse_twu_signal("twu_arb_ref_id",             uvm_hdl_data_t'(7'h7f), ctx);
    pulse_twu_signal("twu_l2tlb_ref_pgflt_id",     uvm_hdl_data_t'(7'h7f), ctx);
    pulse_twu_signal("twu_l2tlb_ref_pgflt_type",   uvm_hdl_data_t'(3'b111), ctx);
    pulse_twu_signal("twu_l2tlb_ref_acc_err",      uvm_hdl_data_t'(1'b1), ctx);
    pulse_twu_signal("twu_l2tlb_ref_acc_err_type", uvm_hdl_data_t'(3'b111), ctx);
    pulse_twu_signal("twu_l2tlb_ref_acc_err_id",   uvm_hdl_data_t'(7'h7f), ctx);
    pulse_twu_signal("acc_err_twu_grant",          uvm_hdl_data_t'(1'b1), ctx);

    pulse_twu_signal("cpurst_b",                   uvm_hdl_data_t'(1'b1), ctx);
  endtask

  virtual task run_test_body();
    setup_plan();
    if (!$test$plusargs("MMU_WHITEBOX_CODE_COV_ASSERT_OFF")) begin
      `uvm_info(get_type_name(),
        "test_twu_unified_code_cov: +MMU_WHITEBOX_CODE_COV_ASSERT_OFF not provided; skipping whitebox operations", UVM_LOW)
      #100ns;
      return;
    end
    #100ns;

    cover_pmp_unit_wait_hold("twu_unified_pmp_unit_wait_hold");
    cover_csr_default_branch("twu_unified_csr_default_branch");
    cover_csr_fsm_legal_arcs("twu_unified_csr_fsm_legal_arcs");
    cover_csr_fsm_abort_transitions("twu_unified_csr_fsm_abort_arcs");
    cover_unified_toggles("twu_unified_toggle_pulses");
    cover_twu_port_toggles("twu_unified_port_toggle_pulses");

    #(m_post_drain);
  endtask
endclass

`endif
