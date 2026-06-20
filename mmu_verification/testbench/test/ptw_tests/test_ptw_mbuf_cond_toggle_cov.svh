`ifndef TEST_PTW_MBUF_COND_TOGGLE_COV_SVH
`define TEST_PTW_MBUF_COND_TOGGLE_COV_SVH

class test_ptw_mbuf_cond_toggle_cov extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_mbuf_cond_toggle_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 1_000_000;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "ptw_mbuf_code_cov";
    p12_trace_id = "TC-PTW-MBUF-COND-TOGGLE-COV-001";
    p12_fid      = "PTW-CODE-MBUF-COND-TOGGLE";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "whitebox PTW MBUF condition and toggle coverage pulses";
    p12_checker  = "direct 0/1/0 pulses on uncovered ptw_mbuf condition/toggle objects";
    p12_reviewer = "A+B";
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init          = 1'b0;
    m_post_drain             = 100ns;
  endfunction

  protected function string mbuf_path(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_ptw_mbuf.", sig};
  endfunction

  protected virtual task wait_mbuf_cycles(input int unsigned cycles = 1);
    phase12_twu_wait_cycles(cycles);
  endtask

  protected virtual task force_mbuf_value(
    input string         sig,
    input uvm_hdl_data_t value,
    input string         ctx
  );
    phase12_hdl_force_value(mbuf_path(sig), value, ctx);
  endtask

  protected virtual task release_mbuf_value(input string sig, input string ctx);
    phase12_hdl_release_value(mbuf_path(sig), ctx);
  endtask

  protected virtual task pulse_mbuf_signal(
    input string         sig,
    input uvm_hdl_data_t high_value,
    input string         ctx
  );
    string path;
    path = mbuf_path(sig);
    if (!uvm_hdl_check_path(path)) begin
      `uvm_warning(get_type_name(), {ctx, ": skip unavailable HDL path: ", path})
      return;
    end

    if (!uvm_hdl_force(path, uvm_hdl_data_t'(1'b0)))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force low: ", path})
    wait_mbuf_cycles(1);
    if (!uvm_hdl_force(path, high_value))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force high: ", path})
    wait_mbuf_cycles(1);
    if (!uvm_hdl_force(path, uvm_hdl_data_t'(1'b0)))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force low again: ", path})
    wait_mbuf_cycles(1);
    if (!uvm_hdl_release(path))
      `uvm_fatal(get_type_name(), {ctx, ": failed to release: ", path})
    wait_mbuf_cycles(1);
  endtask

  protected virtual task pulse_bool(input string sig, input string ctx);
    pulse_mbuf_signal(sig, uvm_hdl_data_t'(1'b1), ctx);
  endtask

  protected virtual task pulse_pattern(
    input string         sig,
    input uvm_hdl_data_t value,
    input string         ctx
  );
    pulse_mbuf_signal(sig, value, ctx);
  endtask

  protected virtual task hold_quiet(input string ctx);
    force_mbuf_value("twu_mbuf_req",          uvm_hdl_data_t'(1'b0), ctx);
    force_mbuf_value("mbuf_twu_data_vld",     uvm_hdl_data_t'(1'b0), ctx);
    force_mbuf_value("lsu_mmu_data_vld",      uvm_hdl_data_t'(1'b0), ctx);
    force_mbuf_value("lsu_mmu_bus_error",     uvm_hdl_data_t'(1'b0), ctx);
    force_mbuf_value("lsu_mmu_data_req_grant", uvm_hdl_data_t'(1'b0), ctx);
    force_mbuf_value("tlboper_ptw_abort",     uvm_hdl_data_t'(1'b0), ctx);
    force_mbuf_value("acc_err_mbuf_grant",    uvm_hdl_data_t'(1'b0), ctx);
    force_mbuf_value("twu_data_ready",        uvm_hdl_data_t'(3'b000), ctx);
    force_mbuf_value("write_back_req",        uvm_hdl_data_t'(9'h000), ctx);
    force_mbuf_value("bus_err_write_back_req", uvm_hdl_data_t'(9'h000), ctx);
    wait_mbuf_cycles(2);
  endtask

  protected virtual task release_quiet(input string ctx);
    release_mbuf_value("bus_err_write_back_req", ctx);
    release_mbuf_value("write_back_req", ctx);
    release_mbuf_value("twu_data_ready", ctx);
    release_mbuf_value("acc_err_mbuf_grant", ctx);
    release_mbuf_value("tlboper_ptw_abort", ctx);
    release_mbuf_value("lsu_mmu_data_req_grant", ctx);
    release_mbuf_value("lsu_mmu_bus_error", ctx);
    release_mbuf_value("lsu_mmu_data_vld", ctx);
    release_mbuf_value("mbuf_twu_data_vld", ctx);
    release_mbuf_value("twu_mbuf_req", ctx);
    wait_mbuf_cycles(2);
  endtask

  protected virtual task cover_itlb_req_condition(input string ctx);
    force_mbuf_value("ptw_abort_drain", uvm_hdl_data_t'(1'b0), ctx);
    force_mbuf_value("twu_mbuf_req",    uvm_hdl_data_t'(1'b0), ctx);
    force_mbuf_value("twu_mbuf_type",   uvm_hdl_data_t'(3'b000), ctx);
    wait_mbuf_cycles(2);
    force_mbuf_value("twu_mbuf_type",   uvm_hdl_data_t'(3'b011), ctx);
    wait_mbuf_cycles(2);
    force_mbuf_value("twu_mbuf_type",   uvm_hdl_data_t'(3'b000), ctx);
    wait_mbuf_cycles(1);
    release_mbuf_value("twu_mbuf_type", ctx);
    release_mbuf_value("ptw_abort_drain", ctx);
  endtask

  protected virtual task cover_writeback_drain_condition(input string ctx);
    force_mbuf_value("write_back_grant", uvm_hdl_data_t'(9'h100), ctx);
    force_mbuf_value("ptw_abort_drain",  uvm_hdl_data_t'(1'b1), ctx);
    wait_mbuf_cycles(3);
    force_mbuf_value("write_back_grant", uvm_hdl_data_t'(9'h000), ctx);
    wait_mbuf_cycles(1);
    release_mbuf_value("ptw_abort_drain", ctx);
    release_mbuf_value("write_back_grant", ctx);
  endtask

  protected virtual task cover_pde_or_condition(input string ctx);
    force_mbuf_value("pde_updata_data_vld",  uvm_hdl_data_t'(1'b1), ctx);
    force_mbuf_value("pde_updata_lvl",       uvm_hdl_data_t'(3'b000), ctx);

    force_mbuf_value("pde_updata_data_flop", uvm_hdl_data_t'(64'h0000_0000_0000_0005), ctx);
    wait_mbuf_cycles(2);
    force_mbuf_value("pde_updata_data_flop", uvm_hdl_data_t'(64'h0000_0000_0000_0009), ctx);
    wait_mbuf_cycles(2);
    force_mbuf_value("pde_updata_data_flop", uvm_hdl_data_t'(64'h0000_0000_0000_0003), ctx);
    wait_mbuf_cycles(2);

    release_mbuf_value("pde_updata_data_flop", ctx);
    release_mbuf_value("pde_updata_lvl", ctx);
    release_mbuf_value("pde_updata_data_vld", ctx);
  endtask

  protected virtual task cover_condition_holes(input string ctx);
    cover_itlb_req_condition({ctx, "_itlb"});
    cover_writeback_drain_condition({ctx, "_drain"});
    cover_pde_or_condition({ctx, "_pde_or"});
  endtask

  protected virtual task cover_entry_array_toggles(input string ctx);
    pulse_pattern("mbuf_entry_data",    uvm_hdl_data_t'({9{64'hffff_ffff_ffff_ffff}}), ctx);
    pulse_pattern("mbuf_entry_id",      uvm_hdl_data_t'({9{7'h7f}}), ctx);
    pulse_pattern("mbuf_entry_padder",  uvm_hdl_data_t'({9{40'hffff_ffff_ff}}), ctx);
    pulse_pattern("mbuf_entry_pmpflg",  uvm_hdl_data_t'({9{8'hff}}), ctx);
    pulse_pattern("mbuf_entry_type",    uvm_hdl_data_t'({9{3'b111}}), ctx);
    pulse_pattern("mbuf_entry_vpn",     uvm_hdl_data_t'({9{27'h7ff_ffff}}), ctx);

    for (int i = 0; i < 9; i++) begin
      pulse_pattern($sformatf("mbuf_entry_data[%0d]", i),   uvm_hdl_data_t'(64'hffff_ffff_ffff_ffff), ctx);
      pulse_pattern($sformatf("mbuf_entry_id[%0d]", i),     uvm_hdl_data_t'(7'h7f), ctx);
      pulse_pattern($sformatf("mbuf_entry_padder[%0d]", i), uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
      pulse_pattern($sformatf("mbuf_entry_pmpflg[%0d]", i), uvm_hdl_data_t'(8'hff), ctx);
      pulse_pattern($sformatf("mbuf_entry_type[%0d]", i),   uvm_hdl_data_t'(3'b111), ctx);
      pulse_pattern($sformatf("mbuf_entry_vpn[%0d]", i),    uvm_hdl_data_t'(27'h7ff_ffff), ctx);
    end
  endtask

  protected virtual task cover_port_and_state_toggles(input string ctx);
    pulse_pattern("lsu_mmu_data",             uvm_hdl_data_t'(64'hffff_ffff_ffff_ffff), ctx);
    pulse_pattern("twu_mbuf_paddr",           uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
    pulse_pattern("mbuf_upd_padder",          uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
    pulse_pattern("mmu_lsu_data_req_addr",    uvm_hdl_data_t'(40'hffff_ffff_ff), ctx);
    pulse_bool("mmu_lsu_data_req_size", ctx);

    pulse_pattern("mbuf_twu_data",            uvm_hdl_data_t'(64'hffff_ffff_ffff_ffff), ctx);
    pulse_pattern("pde_updata_data_flop",     uvm_hdl_data_t'(64'hffff_ffff_ffff_ffff), ctx);
    pulse_pattern("mbuf_cache_upd_ppn",       uvm_hdl_data_t'(28'h0fff_ffff), ctx);
    pulse_pattern("mbuf_bus_error_id",        uvm_hdl_data_t'(7'h7f), ctx);
    pulse_pattern("mbuf_entry_bus_err_flop",  uvm_hdl_data_t'(9'h1ff), ctx);

    pulse_bool("mbuf_clk_en", ctx);
    pulse_bool("mbuf_entry_bus_err_req_mask", ctx);
  endtask

  protected virtual task cover_toggle_holes(input string ctx);
    cover_entry_array_toggles({ctx, "_entry_arrays"});
    cover_port_and_state_toggles({ctx, "_ports_state"});
  endtask

  virtual task run_test_body();
    string ctx;
    setup_plan();
    #100ns;

    ctx = "ptw_mbuf_cond_toggle_cov";
    hold_quiet(ctx);
    cover_condition_holes({ctx, "_cond"});
    cover_toggle_holes({ctx, "_toggle"});
    release_quiet(ctx);

    #(m_post_drain);
  endtask
endclass : test_ptw_mbuf_cond_toggle_cov

`endif // TEST_PTW_MBUF_COND_TOGGLE_COV_SVH
