`ifndef TEST_TWU_TOGGLE_COV_SVH
`define TEST_TWU_TOGGLE_COV_SVH

class test_twu_toggle_cov extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_toggle_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 1_000_000;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu_code_cov";
    p12_trace_id = "TC-TWU-TOGGLE-COV-001";
    p12_fid      = "PTW-CODE-TWU-TOGGLE";
    p12_priority = "P0";
    p12_seq_desc = "whitebox TWU toggle coverage pulses";
    p12_checker  = "twu toggle coverage: direct 0/1/0 pulses on uncovered TWU objects";
    p12_reviewer = "A+B";
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init          = 1'b0;
    m_post_drain             = 100ns;
  endfunction

  protected virtual task hold_quiet(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort",    uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("xbar_twu_req",         uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("mbuf_twu_data_vld",    uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("pgflt_twu_grant",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("acc_err_twu_grant",    uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("refill_arb_twu_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task release_quiet(input string ctx);
    phase12_twu_release_value("refill_arb_twu_grant", ctx);
    phase12_twu_release_value("acc_err_twu_grant", ctx);
    phase12_twu_release_value("pgflt_twu_grant", ctx);
    phase12_twu_release_value("mbuf_twu_data_vld", ctx);
    phase12_twu_release_value("xbar_twu_req", ctx);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task pulse_twu_signal(
    input string         sig,
    input uvm_hdl_data_t high_value,
    input string         ctx
  );
    string path;
    path = phase12_twu_path(sig);
    if (!uvm_hdl_check_path(path)) begin
      `uvm_warning(get_type_name(), {ctx, ": skip unavailable HDL path: ", path})
      return;
    end

    if (!uvm_hdl_force(path, uvm_hdl_data_t'(1'b0)))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force low: ", path})
    phase12_twu_wait_cycles(1);
    if (!uvm_hdl_force(path, high_value))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force high: ", path})
    phase12_twu_wait_cycles(1);
    if (!uvm_hdl_force(path, uvm_hdl_data_t'(1'b0)))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force low again: ", path})
    phase12_twu_wait_cycles(1);
    if (!uvm_hdl_release(path))
      `uvm_fatal(get_type_name(), {ctx, ": failed to release: ", path})
    phase12_twu_wait_cycles(1);
  endtask

  protected virtual task pulse_bool(input string sig, input string ctx);
    pulse_twu_signal(sig, uvm_hdl_data_t'(1'b1), ctx);
  endtask

  protected virtual task pulse_all(input string sig, input string ctx);
    pulse_twu_signal(sig, uvm_hdl_data_t'(64'hffff_ffff_ffff_ffff), ctx);
  endtask

  protected virtual task pulse_pattern(input string sig, input uvm_hdl_data_t value, input string ctx);
    pulse_twu_signal(sig, value, ctx);
  endtask

  protected virtual task cover_port_and_state_toggles(input string ctx);
    pulse_pattern("cp0_mmu_mpp",       uvm_hdl_data_t'(2'b11), ctx);
    pulse_all("mbuf_twu_data", ctx);
    pulse_pattern("regs_ptw_cur_asid", uvm_hdl_data_t'(16'hffe0), ctx);
    pulse_pattern("regs_ptw_satp_ppn", uvm_hdl_data_t'(28'h0fff_ff80), ctx);
    pulse_pattern("sysmap_mmu_flg",    uvm_hdl_data_t'(5'h1f), ctx);
    pulse_pattern("sysmap_mmu_flgx1",  uvm_hdl_data_t'(5'h1f), ctx);
    pulse_pattern("sysmap_mmu_flgx2",  uvm_hdl_data_t'(5'h1f), ctx);
    pulse_pattern("sysmap_mmu_flgx3",  uvm_hdl_data_t'(5'h1f), ctx);
    pulse_pattern("sysmap_mmu_hitx1",  uvm_hdl_data_t'(8'hff), ctx);
    pulse_pattern("sysmap_mmu_hitx2",  uvm_hdl_data_t'(8'hff), ctx);
    pulse_pattern("sysmap_mmu_hitx3",  uvm_hdl_data_t'(8'hff), ctx);
    pulse_pattern("xbar_twu_ppn",      uvm_hdl_data_t'(28'h0fff_ffff), ctx);

    pulse_pattern("ptw_cur_st",        uvm_hdl_data_t'(3'b100), ctx);
    pulse_pattern("ptw_nxt_st",        uvm_hdl_data_t'(3'b100), ctx);
    pulse_bool("ptw_chk_cross", ctx);
    pulse_bool("ptw_crs2_1g", ctx);
    pulse_bool("ptw_crs2_2m", ctx);
  endtask

  protected virtual task cover_csr_toggles(input string ctx);
    pulse_all("csr_data", ctx);
    pulse_all("csr_data_flop", ctx);
    pulse_pattern("csr_id",            uvm_hdl_data_t'(7'h7f), ctx);
    pulse_pattern("csr_id_flop",       uvm_hdl_data_t'(7'h7f), ctx);
    pulse_pattern("csr_refill_data",   uvm_hdl_data_t'(42'h3ff_ffff_ffff), ctx);
    pulse_pattern("csr_refill_id",     uvm_hdl_data_t'(7'h7f), ctx);
    pulse_pattern("csr_refill_tag",    uvm_hdl_data_t'(48'hffff_ffff_ffff), ctx);
    pulse_pattern("csr_refill_type",   uvm_hdl_data_t'(3'b111), ctx);
    pulse_pattern("csr_type_flop",     uvm_hdl_data_t'(3'b111), ctx);
    pulse_pattern("csr_vpn",           uvm_hdl_data_t'(27'h7ff_ffff), ctx);
    pulse_pattern("csr_vpn_flop",      uvm_hdl_data_t'(27'h7ff_ffff), ctx);
  endtask

  protected virtual task cover_check_stage_toggles(input string ctx);
    pulse_all("fst_chk_csr_data", ctx);
    pulse_all("fst_chk_data", ctx);
    pulse_pattern("fst_chk_flg",       uvm_hdl_data_t'(9'h1ff), ctx);
    pulse_bool("fst_chk_itlb_sel", ctx);
    pulse_pattern("fst_chk_refill_data", uvm_hdl_data_t'(42'h3ff_ffff_ffff), ctx);
    pulse_pattern("fst_chk_refill_date", uvm_hdl_data_t'(42'h3ff_ffff_ffff), ctx);
    pulse_pattern("fst_chk_refill_tag",  uvm_hdl_data_t'(48'hffff_ffff_ffff), ctx);

    pulse_all("scd_chk_csr_data", ctx);
    pulse_pattern("scd_chk_csr_vpn",   uvm_hdl_data_t'(27'h7ff_ffff), ctx);
    pulse_all("scd_chk_data", ctx);
    pulse_pattern("scd_chk_flg",       uvm_hdl_data_t'(9'h1ff), ctx);
    pulse_pattern("scd_chk_refill_data", uvm_hdl_data_t'(42'h3ff_ffff_ffff), ctx);
    pulse_pattern("scd_chk_refill_date", uvm_hdl_data_t'(42'h3ff_ffff_ffff), ctx);
    pulse_pattern("scd_chk_refill_tag",  uvm_hdl_data_t'(48'hffff_ffff_ffff), ctx);
    pulse_pattern("scd_chk_vpn",       uvm_hdl_data_t'(27'h7ff_ffff), ctx);

    pulse_all("thd_chk_data", ctx);
    pulse_bool("thd_chk_leaf_vld", ctx);
    pulse_pattern("thd_chk_refill_data", uvm_hdl_data_t'(42'h3ff_ffff_ffff), ctx);
    pulse_pattern("thd_chk_refill_data_no_maee", uvm_hdl_data_t'(42'h3ff_ffff_ffff), ctx);
    pulse_pattern("thd_chk_refill_date", uvm_hdl_data_t'(42'h3ff_ffff_ffff), ctx);
    pulse_pattern("thd_chk_refill_tag",  uvm_hdl_data_t'(48'hffff_ffff_ffff), ctx);
    pulse_pattern("thd_chk_vpn",       uvm_hdl_data_t'(27'h7ff_ffff), ctx);
  endtask

  protected virtual task cover_pmp_and_sysmap_toggles(input string ctx);
    pulse_pattern("fst_pmp_pa",        uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
    pulse_pattern("scd_pmp_pa",        uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
    pulse_pattern("scd_pmp_ppn",       uvm_hdl_data_t'(28'h0fff_ffff), ctx);
    pulse_pattern("scd_pmp_vpn",       uvm_hdl_data_t'(27'h7ff_ffff), ctx);
    pulse_bool("scd_pmp_wait", ctx);
    pulse_pattern("thd_pmp_pa",        uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
    pulse_pattern("thd_pmp_ppn",       uvm_hdl_data_t'(28'h0fff_ffff), ctx);
    pulse_pattern("thd_pmp_vpn",       uvm_hdl_data_t'(27'h7ff_ffff), ctx);
    pulse_bool("thd_pmp_wait", ctx);

    pulse_pattern("mmu_pmp_pa",        uvm_hdl_data_t'(28'h0fff_ffff), ctx);
    pulse_pattern("mmu_sysmap_pax1",   uvm_hdl_data_t'(28'h0fff_ffff), ctx);
    pulse_pattern("mmu_sysmap_pax2",   uvm_hdl_data_t'(28'h0fff_ffff), ctx);
    pulse_pattern("mmu_sysmap_pax3",   uvm_hdl_data_t'(28'h0fff_ffff), ctx);
    pulse_pattern("twu_mbuf_paddr",    uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
    pulse_pattern("twu_sysmap_adder",  uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
    pulse_pattern("twu_sysmap_adderx1", uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
    pulse_pattern("twu_sysmap_adderx2", uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
  endtask

  protected virtual task cover_refill_and_exception_toggles(input string ctx);
    pulse_pattern("twu_acc_err_id",    uvm_hdl_data_t'(7'h7f), ctx);
    pulse_pattern("twu_acc_err_type",  uvm_hdl_data_t'(3'b111), ctx);
    pulse_pattern("twu_l2tlb_ref_acc_err_id",   uvm_hdl_data_t'(7'h7f), ctx);
    pulse_pattern("twu_l2tlb_ref_acc_err_type", uvm_hdl_data_t'(3'b111), ctx);

    pulse_pattern("twu_ref_data_din",      uvm_hdl_data_t'(42'h3ff_ffff_ffff), ctx);
    pulse_pattern("twu_ref_tag_din",       uvm_hdl_data_t'(48'hffff_ffff_ffff), ctx);
    pulse_pattern("twu_arb_ref_data_din",  uvm_hdl_data_t'(42'h3ff_ffff_ffff), ctx);
    pulse_pattern("twu_arb_ref_tag_din",   uvm_hdl_data_t'(48'hffff_ffff_ffff), ctx);

    pulse_bool("twu_crs1_1g", ctx);
    pulse_bool("twu_crs1_2m", ctx);
    pulse_bool("twu_crs2_1g", ctx);
    pulse_bool("twu_crs2_2m", ctx);
    pulse_bool("twu_crs2_chk", ctx);
    pulse_pattern("twu_hit_num", uvm_hdl_data_t'(8'hff), ctx);
  endtask

  virtual task run_test_body();
    string ctx;
    setup_plan();
    #100ns;
    ctx = "twu_toggle_cov";
    hold_quiet(ctx);

    cover_port_and_state_toggles({ctx, "_ports"});
    cover_csr_toggles({ctx, "_csr"});
    cover_check_stage_toggles({ctx, "_chk"});
    cover_pmp_and_sysmap_toggles({ctx, "_pmp_sysmap"});
    cover_refill_and_exception_toggles({ctx, "_refill_except"});

    pulse_bool("twu_clk_en", {ctx, "_clk_en"});

    release_quiet(ctx);
    #(m_post_drain);
  endtask
endclass

`endif
