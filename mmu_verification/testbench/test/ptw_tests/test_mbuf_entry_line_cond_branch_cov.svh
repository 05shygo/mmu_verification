`ifndef TEST_MBUF_ENTRY_LINE_COND_BRANCH_COV_SVH
`define TEST_MBUF_ENTRY_LINE_COND_BRANCH_COV_SVH

class test_mbuf_entry_line_cond_branch_cov extends phase12_generated_test_base;
  `uvm_component_utils(test_mbuf_entry_line_cond_branch_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 1_000_000;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "mbuf_entry_code_cov";
    p12_trace_id = "TC-MBUF-ENTRY-LINE-COND-BRANCH-COV-001";
    p12_fid      = "PTW-CODE-MBUF-ENTRY-LINE-COND-BRANCH";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "whitebox mbuf_entry line, condition, and branch coverage pulses";
    p12_checker  = "code coverage only; requires +MMU_WHITEBOX_CODE_COV_ASSERT_OFF";
    p12_reviewer = "A+B";
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init          = 1'b0;
    m_post_drain             = 100ns;
  endfunction

  protected function string ptw_mbuf_path(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_ptw_mbuf.", sig};
  endfunction

  protected function string mbuf_entry_path(input int unsigned entry, input string sig);
    return $sformatf(
      "$root.tb_top.u_dut.x_ct_mmu_ptw.u_ptw_mbuf.u_MBUF_ent_0_8[%0d].mbuf_entry_x.%s",
      entry, sig);
  endfunction

  protected virtual task wait_mbuf_entry_cycles(input int unsigned cycles = 1);
    phase12_twu_wait_cycles(cycles);
  endtask

  protected virtual task require_whitebox_assertion_mode(input string ctx);
    if (!$test$plusargs("MMU_WHITEBOX_CODE_COV_ASSERT_OFF"))
      `uvm_fatal(get_type_name(),
        {ctx, ": missing +MMU_WHITEBOX_CODE_COV_ASSERT_OFF for local mbuf_entry code coverage forcing"})
  endtask

  protected virtual task force_path_value(
    input string         path,
    input uvm_hdl_data_t value,
    input string         ctx
  );
    phase12_hdl_force_value(path, value, ctx);
  endtask

  protected virtual task release_path_value(input string path, input string ctx);
    phase12_hdl_release_value(path, ctx);
  endtask

  protected virtual task force_ptw_mbuf_value(
    input string         sig,
    input uvm_hdl_data_t value,
    input string         ctx
  );
    force_path_value(ptw_mbuf_path(sig), value, ctx);
  endtask

  protected virtual task release_ptw_mbuf_value(input string sig, input string ctx);
    release_path_value(ptw_mbuf_path(sig), ctx);
  endtask

  protected virtual task force_entry_value(
    input int unsigned   entry,
    input string         sig,
    input uvm_hdl_data_t value,
    input string         ctx
  );
    force_path_value(mbuf_entry_path(entry, sig), value, ctx);
  endtask

  protected virtual task release_entry_value(
    input int unsigned entry,
    input string       sig,
    input string       ctx
  );
    release_path_value(mbuf_entry_path(entry, sig), ctx);
  endtask

  protected virtual task force_all_entries(
    input string         sig,
    input uvm_hdl_data_t value,
    input string         ctx
  );
    for (int unsigned i = 0; i < 9; i++)
      force_entry_value(i, sig, value, ctx);
  endtask

  protected virtual task release_all_entries(input string sig, input string ctx);
    for (int unsigned i = 0; i < 9; i++)
      release_entry_value(i, sig, ctx);
  endtask

  protected virtual task hold_parent_quiet(input string ctx);
    force_ptw_mbuf_value("twu_mbuf_req",           uvm_hdl_data_t'(1'b0), ctx);
    force_ptw_mbuf_value("lsu_mmu_data_vld",       uvm_hdl_data_t'(1'b0), ctx);
    force_ptw_mbuf_value("lsu_mmu_bus_error",      uvm_hdl_data_t'(1'b0), ctx);
    force_ptw_mbuf_value("lsu_mmu_data_req_grant", uvm_hdl_data_t'(1'b0), ctx);
    force_ptw_mbuf_value("tlboper_ptw_abort",      uvm_hdl_data_t'(1'b0), ctx);
    force_ptw_mbuf_value("acc_err_mbuf_grant",     uvm_hdl_data_t'(1'b0), ctx);
    force_ptw_mbuf_value("twu_data_ready",         uvm_hdl_data_t'(3'b000), ctx);
    wait_mbuf_entry_cycles(2);
  endtask

  protected virtual task release_parent_quiet(input string ctx);
    release_ptw_mbuf_value("twu_data_ready", ctx);
    release_ptw_mbuf_value("acc_err_mbuf_grant", ctx);
    release_ptw_mbuf_value("tlboper_ptw_abort", ctx);
    release_ptw_mbuf_value("lsu_mmu_data_req_grant", ctx);
    release_ptw_mbuf_value("lsu_mmu_bus_error", ctx);
    release_ptw_mbuf_value("lsu_mmu_data_vld", ctx);
    release_ptw_mbuf_value("twu_mbuf_req", ctx);
    wait_mbuf_entry_cycles(2);
  endtask

  protected virtual task set_entry_baseline(input string ctx);
    force_all_entries("mbuf_entry_upd",              uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_all_clr",                uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_data_vld",            uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_bus_error",           uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mmu_lsu_data_req_grant",      uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("write_back_grant",            uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_bus_error_grant",        uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_entry_bus_err_req_mask", uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("twu_data_ready",              uvm_hdl_data_t'(3'b000), ctx);
    force_all_entries("lsu_mmu_data",                uvm_hdl_data_t'(64'h0), ctx);

    force_all_entries("mbuf_vld",           uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_on",            uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_get",           uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_bus_err_flop",  uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_lvl",           uvm_hdl_data_t'(3'b001), ctx);
    wait_mbuf_entry_cycles(2);
  endtask

  protected virtual task release_entry_forces(input string ctx);
    release_all_entries("mbuf_lvl", ctx);
    release_all_entries("mbuf_bus_err_flop", ctx);
    release_all_entries("mbuf_get", ctx);
    release_all_entries("mbuf_on", ctx);
    release_all_entries("mbuf_vld", ctx);

    release_all_entries("lsu_mmu_data", ctx);
    release_all_entries("twu_data_ready", ctx);
    release_all_entries("mbuf_entry_bus_err_req_mask", ctx);
    release_all_entries("mbuf_bus_error_grant", ctx);
    release_all_entries("write_back_grant", ctx);
    release_all_entries("mmu_lsu_data_req_grant", ctx);
    release_all_entries("lsu_mmu_bus_error", ctx);
    release_all_entries("lsu_mmu_data_vld", ctx);
    release_all_entries("mbuf_all_clr", ctx);
    release_all_entries("mbuf_entry_upd", ctx);
    wait_mbuf_entry_cycles(2);
  endtask

  protected virtual task cover_cond_expr_holes(input string ctx);
    force_all_entries("mbuf_all_clr",        uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_on",             uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_data_vld",    uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_bus_error",   uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mbuf_bus_error_grant", uvm_hdl_data_t'(1'b0), ctx);
    wait_mbuf_entry_cycles(2);

    force_all_entries("lsu_mmu_data_vld",    uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("lsu_mmu_bus_error",   uvm_hdl_data_t'(1'b1), ctx);
    wait_mbuf_entry_cycles(2);

    force_all_entries("lsu_mmu_bus_error",      uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_all_clr",           uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mmu_lsu_data_req_grant", uvm_hdl_data_t'(1'b1), ctx);
    wait_mbuf_entry_cycles(2);

    force_all_entries("mbuf_all_clr",           uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mmu_lsu_data_req_grant", uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_on",                uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_data_vld",       uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("write_back_grant",       uvm_hdl_data_t'(1'b0), ctx);
    wait_mbuf_entry_cycles(2);

    force_all_entries("mbuf_all_clr",      uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mbuf_on",           uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("lsu_mmu_data_vld",  uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("write_back_grant",  uvm_hdl_data_t'(1'b0), ctx);
    wait_mbuf_entry_cycles(2);
  endtask

  protected virtual task cover_entry_update_path(input string ctx);
    release_all_entries("mbuf_vld", ctx);
    release_all_entries("mbuf_get", ctx);
    release_all_entries("mbuf_bus_err_flop", ctx);
    release_all_entries("mbuf_lvl", ctx);

    force_all_entries("mbuf_all_clr",          uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("write_back_grant",      uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_bus_error_grant",  uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_upd_padder",       uvm_hdl_data_t'(40'h00f00d1234), ctx);
    force_all_entries("mbuf_upd_vpn",          uvm_hdl_data_t'(27'h0123456), ctx);
    force_all_entries("mbuf_upd_type",         uvm_hdl_data_t'(3'b101), ctx);
    force_all_entries("mbuf_upd_id",           uvm_hdl_data_t'(7'h55), ctx);
    force_all_entries("mbuf_upd_lvl",          uvm_hdl_data_t'(3'b101), ctx);
    force_all_entries("mbuf_upd_pmpflg",       uvm_hdl_data_t'(8'ha5), ctx);
    force_all_entries("mbuf_entry_upd",        uvm_hdl_data_t'(1'b1), ctx);
    wait_mbuf_entry_cycles(2);

    force_all_entries("mbuf_entry_upd",        uvm_hdl_data_t'(1'b0), ctx);
    release_all_entries("mbuf_upd_pmpflg", ctx);
    release_all_entries("mbuf_upd_lvl", ctx);
    release_all_entries("mbuf_upd_id", ctx);
    release_all_entries("mbuf_upd_type", ctx);
    release_all_entries("mbuf_upd_vpn", ctx);
    release_all_entries("mbuf_upd_padder", ctx);
    set_entry_baseline({ctx, "_restore"});
  endtask

  protected virtual task cover_data_capture_path(input string ctx);
    release_all_entries("mbuf_get", ctx);

    force_all_entries("mbuf_all_clr",      uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_vld",          uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mbuf_on",           uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mbuf_lvl",          uvm_hdl_data_t'(3'b001), ctx);
    force_all_entries("twu_data_ready",    uvm_hdl_data_t'(3'b001), ctx);
    force_all_entries("lsu_mmu_data_vld",  uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("lsu_mmu_bus_error", uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("write_back_grant",  uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_data",      uvm_hdl_data_t'(64'h0123_4567_89ab_cdef), ctx);
    wait_mbuf_entry_cycles(3);

    set_entry_baseline({ctx, "_restore"});
  endtask

  protected virtual task cover_writeback_req_expr_holes(input string ctx);
    force_all_entries("mbuf_all_clr",    uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_vld",        uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("twu_data_ready",  uvm_hdl_data_t'(3'b001), ctx);
    force_all_entries("mbuf_lvl",        uvm_hdl_data_t'(3'b001), ctx);
    force_all_entries("mbuf_on",         uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_get",        uvm_hdl_data_t'(1'b1), ctx);
    wait_mbuf_entry_cycles(2);

    force_all_entries("mbuf_vld",      uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mbuf_all_clr",  uvm_hdl_data_t'(1'b1), ctx);
    wait_mbuf_entry_cycles(2);
  endtask

  protected virtual task cover_bus_error_req_expr_holes(input string ctx);
    force_all_entries("mbuf_get",                    uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_data_vld",            uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_bus_error",           uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_on",                     uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_bus_err_flop",           uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mbuf_entry_bus_err_req_mask", uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_all_clr",                uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_vld",                    uvm_hdl_data_t'(1'b0), ctx);
    wait_mbuf_entry_cycles(2);

    force_all_entries("mbuf_vld",      uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mbuf_all_clr",  uvm_hdl_data_t'(1'b1), ctx);
    wait_mbuf_entry_cycles(2);

    force_all_entries("mbuf_all_clr",                uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_entry_bus_err_req_mask", uvm_hdl_data_t'(1'b1), ctx);
    wait_mbuf_entry_cycles(2);
  endtask

  protected virtual task cover_bus_error_req_true_path(input string ctx);
    force_all_entries("mbuf_vld",                    uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mbuf_all_clr",                uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_on",                     uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("lsu_mmu_data_vld",            uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_bus_error",           uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mbuf_bus_err_flop",           uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_entry_bus_err_req_mask", uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_bus_error_grant",        uvm_hdl_data_t'(1'b0), ctx);
    wait_mbuf_entry_cycles(2);

    force_all_entries("mbuf_bus_error_grant",        uvm_hdl_data_t'(1'b1), ctx);
    wait_mbuf_entry_cycles(2);

    set_entry_baseline({ctx, "_restore"});
  endtask

  protected virtual task cover_bus_error_flop_line_and_branch(input string ctx);
    release_all_entries("mbuf_bus_err_flop", ctx);
    force_all_entries("mbuf_entry_upd",       uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_all_clr",         uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_on",              uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("lsu_mmu_data_vld",     uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_bus_error",    uvm_hdl_data_t'(1'b1), ctx);
    force_all_entries("mbuf_bus_error_grant", uvm_hdl_data_t'(1'b0), ctx);
    wait_mbuf_entry_cycles(3);

    force_all_entries("mbuf_on",              uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("lsu_mmu_bus_error",    uvm_hdl_data_t'(1'b0), ctx);
    force_all_entries("mbuf_bus_error_grant", uvm_hdl_data_t'(1'b1), ctx);
    wait_mbuf_entry_cycles(3);

    force_all_entries("mbuf_bus_error_grant", uvm_hdl_data_t'(1'b0), ctx);
  endtask

  virtual task run_test_body();
    string ctx;
    setup_plan();
    #100ns;

    ctx = "mbuf_entry_line_cond_branch_cov";
    require_whitebox_assertion_mode(ctx);
    hold_parent_quiet(ctx);
    set_entry_baseline(ctx);
    cover_entry_update_path({ctx, "_entry_update"});
    cover_cond_expr_holes({ctx, "_cond"});
    cover_data_capture_path({ctx, "_data_capture"});
    cover_writeback_req_expr_holes({ctx, "_writeback"});
    cover_bus_error_req_expr_holes({ctx, "_buserr_req"});
    cover_bus_error_req_true_path({ctx, "_buserr_true"});
    cover_bus_error_flop_line_and_branch({ctx, "_buserr_flop"});
    release_entry_forces(ctx);
    release_parent_quiet(ctx);

    #(m_post_drain);
  endtask
endclass : test_mbuf_entry_line_cond_branch_cov

`endif // TEST_MBUF_ENTRY_LINE_COND_BRANCH_COV_SVH
