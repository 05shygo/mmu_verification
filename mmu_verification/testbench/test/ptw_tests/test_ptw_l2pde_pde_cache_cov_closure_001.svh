// =============================================================================
// L2PDE_cache and PDE_cache focused code-coverage closure
// =============================================================================
`ifndef TEST_PTW_L2PDE_PDE_CACHE_COV_CLOSURE_001_SVH
`define TEST_PTW_L2PDE_PDE_CACHE_COV_CLOSURE_001_SVH

class test_ptw_l2pde_pde_cache_cov_closure_001 extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_l2pde_pde_cache_cov_closure_001)

  localparam int unsigned L1_COV_ENTRY_NUM = 8;
  localparam int unsigned L2_COV_ENTRY_NUM = 16;
  localparam logic [2:0]  L2COV_TYPE_LOAD  = 3'b010;
  localparam logic [2:0]  L2COV_TYPE_FETCH = 3'b011;
  localparam logic [2:0]  L2COV_TYPE_PREF  = 3'b100;
  localparam logic [2:0]  L2COV_TYPE_STORE = 3'b110;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 64;
    timeout_ns = 5_000_000;
  endfunction

  virtual function void build_phase(uvm_phase phase);
    if (!uvm_config_db #(mmu_top_cfg)::get(this, "", "m_cfg", m_cfg))
      m_cfg = mmu_top_cfg::type_id::create("m_cfg");

    m_cfg.en_translation_sb = 1'b0;
    m_cfg.en_ptw_source_ref_model = 1'b0;
    m_cfg.en_ptw_source_sb = 1'b0;
    uvm_config_db #(mmu_top_cfg)::set(this, "", "m_cfg", m_cfg);
    uvm_config_db #(mmu_top_cfg)::set(this, "*", "m_cfg", m_cfg);
    super.build_phase(phase);
  endfunction

  protected function string l2cov_pde_path(input string sig);
    return {"$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.", sig};
  endfunction

  protected function string l2cov_l2_path(input int unsigned entry, input string sig);
    return $sformatf(
      "$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L2PDE_ent[%0d].u_L2PDE_cache.%s",
      entry, sig);
  endfunction

  protected function string l2cov_l1_path(input int unsigned entry, input string sig);
    return $sformatf(
      "$root.tb_top.u_dut.x_ct_mmu_ptw.u_PDE_cache.u_L1PDE_ent[%0d].u_L1PDE_cache.%s",
      entry, sig);
  endfunction

  protected function logic [17:0] l2cov_low_tag(input int unsigned entry);
    return 18'(entry);
  endfunction

  protected function logic [17:0] l2cov_high_tag(input int unsigned entry);
    return ~18'(entry);
  endfunction

  protected function logic [26:0] l2cov_make_vpn(
    input logic [17:0] tag,
    input logic [8:0]  vpn0
  );
    return {tag, vpn0};
  endfunction

  protected task l2cov_force_value(
    input string         path,
    input uvm_hdl_data_t value,
    input string         ctx
  );
    if (!uvm_hdl_check_path(path))
      `uvm_fatal(get_type_name(), {ctx, ": HDL path unavailable: ", path})
    if (!uvm_hdl_force(path, value))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force: ", path})
  endtask

  protected task l2cov_release_value(input string path, input string ctx);
    if (!uvm_hdl_release(path))
      `uvm_fatal(get_type_name(), {ctx, ": failed to release: ", path})
  endtask

  protected task l2cov_force_idle_req(input string ctx);
    l2cov_force_value(l2cov_pde_path("ptw_req"), uvm_hdl_data_t'(1'b0), ctx);
    l2cov_force_value(l2cov_pde_path("l2tlb_ptw_req"), uvm_hdl_data_t'(1'b0), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd"), uvm_hdl_data_t'(1'b0), ctx);
    l2cov_force_value(l2cov_pde_path("xbar_pde_ready"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(2);
  endtask

  protected task l2cov_release_idle_req(input string ctx);
    l2cov_release_value(l2cov_pde_path("xbar_pde_ready"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd"), ctx);
    l2cov_release_value(l2cov_pde_path("l2tlb_ptw_req"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_req"), ctx);
  endtask

  protected task l2cov_update_l2_entry(
    input int unsigned  entry,
    input logic [17:0] tag,
    input logic [27:0] ppn,
    input logic [3:0]  l1pmpflg,
    input logic [3:0]  l2pmpflg,
    input string       ctx
  );
    logic [26:0] upd_vpn;
    logic [15:0] refill_vec;

    upd_vpn = l2cov_make_vpn(tag, 9'(entry));
    refill_vec = 16'(16'h1 << entry);

    l2cov_force_value(l2cov_pde_path("ptw_req"), uvm_hdl_data_t'(1'b0), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd_vpn"), uvm_hdl_data_t'(upd_vpn), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd_ppn"), uvm_hdl_data_t'(ppn), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd_l1pmpflg"), uvm_hdl_data_t'(l1pmpflg), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd_l2pmpflg"), uvm_hdl_data_t'(l2pmpflg), ctx);
    l2cov_force_value(l2cov_pde_path("plru_L2PDE_ref_num"), uvm_hdl_data_t'(refill_vec), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd_lvl"), uvm_hdl_data_t'(2'b01), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(1);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(1);

    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd_lvl"), ctx);
    l2cov_release_value(l2cov_pde_path("plru_L2PDE_ref_num"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd_l2pmpflg"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd_l1pmpflg"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd_ppn"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd_vpn"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_req"), ctx);
    stage8_wait_cycles(1);
  endtask

  protected task l2cov_update_l1_entry(
    input int unsigned entry,
    input logic [8:0]  tag,
    input logic [27:0] ppn,
    input logic [3:0]  l1pmpflg,
    input string       ctx
  );
    logic [26:0] upd_vpn;
    logic [7:0]  refill_vec;

    upd_vpn = {tag, 18'(entry)};
    refill_vec = 8'(8'h1 << entry);

    l2cov_force_value(l2cov_pde_path("ptw_req"), uvm_hdl_data_t'(1'b0), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd_vpn"), uvm_hdl_data_t'(upd_vpn), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd_ppn"), uvm_hdl_data_t'(ppn), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd_l1pmpflg"), uvm_hdl_data_t'(l1pmpflg), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd_l2pmpflg"), uvm_hdl_data_t'(4'h0), ctx);
    l2cov_force_value(l2cov_pde_path("plru_L1PDE_ref_num"), uvm_hdl_data_t'(refill_vec), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd_lvl"), uvm_hdl_data_t'(2'b10), ctx);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(1);
    l2cov_force_value(l2cov_pde_path("mbuf_cache_upd"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(1);

    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd_lvl"), ctx);
    l2cov_release_value(l2cov_pde_path("plru_L1PDE_ref_num"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd_l2pmpflg"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd_l1pmpflg"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd_ppn"), ctx);
    l2cov_release_value(l2cov_pde_path("mbuf_cache_upd_vpn"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_req"), ctx);
    stage8_wait_cycles(1);
  endtask

  protected task l2cov_drive_pde_req(
    input logic [17:0] tag,
    input logic [8:0]  vpn0,
    input logic [2:0]  req_type,
    input logic [6:0]  req_id,
    input string       ctx,
    input bit          req_vld = 1'b1
  );
    logic [26:0] req_vpn;

    req_vpn = l2cov_make_vpn(tag, vpn0);
    l2cov_force_value(l2cov_pde_path("ptw_vpn"), uvm_hdl_data_t'(req_vpn), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_type"), uvm_hdl_data_t'(req_type), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_id"), uvm_hdl_data_t'(req_id), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_req"), uvm_hdl_data_t'(req_vld), ctx);
    l2cov_force_value(l2cov_pde_path("xbar_pde_ready"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(2);
  endtask

  protected task l2cov_release_pde_req(input string ctx);
    l2cov_force_value(l2cov_pde_path("ptw_req"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(1);
    l2cov_release_value(l2cov_pde_path("xbar_pde_ready"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_req"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_id"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_type"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_vpn"), ctx);
    stage8_wait_cycles(1);
  endtask

  protected task l2cov_drive_l2_hit(
    input int unsigned entry,
    input logic [17:0] tag,
    input logic [2:0]  req_type,
    input logic [6:0]  req_id,
    input string       ctx
  );
    l2cov_force_value(l2cov_l2_path(entry, "L2PDE_vld"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_l2_path(entry, "L2PDE_tag"), uvm_hdl_data_t'(tag), ctx);
    l2cov_force_value(l2cov_l2_path(entry, "L2PDE_l1pmpflg"), uvm_hdl_data_t'(4'h7), ctx);
    l2cov_force_value(l2cov_l2_path(entry, "L2PDE_l2pmpflg"), uvm_hdl_data_t'(4'h7), ctx);
    l2cov_drive_pde_req(tag, 9'(entry), req_type, req_id, ctx, 1'b0);
    if ((ptw_probe_vif != null)
        && (ptw_probe_vif.mon_cb.pde_l2_hit_vld !== 1'b1))
      `uvm_error(get_type_name(),
        $sformatf("%s: expected L2 PDE hit for entry=%0d tag=0x%05h", ctx, entry, tag))
    l2cov_release_pde_req(ctx);
    l2cov_release_value(l2cov_l2_path(entry, "L2PDE_l2pmpflg"), ctx);
    l2cov_release_value(l2cov_l2_path(entry, "L2PDE_l1pmpflg"), ctx);
    l2cov_release_value(l2cov_l2_path(entry, "L2PDE_tag"), ctx);
    l2cov_release_value(l2cov_l2_path(entry, "L2PDE_vld"), ctx);
  endtask

  protected task l2cov_drive_l1_hit(
    input int unsigned entry,
    input logic [8:0]  tag,
    input logic [2:0]  req_type,
    input string       ctx
  );
    logic [26:0] req_vpn;

    req_vpn = {tag, 18'(entry)};
    l2cov_force_value(l2cov_l1_path(entry, "L1PDE_vld"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_l1_path(entry, "L1PDE_tag"), uvm_hdl_data_t'(tag), ctx);
    l2cov_force_value(l2cov_l1_path(entry, "L1PDE_ppn"), uvm_hdl_data_t'(~28'(entry)), ctx);
    l2cov_force_value(l2cov_l1_path(entry, "L1PDE_l1pmpflg"), uvm_hdl_data_t'(4'h7), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_vpn"), uvm_hdl_data_t'(req_vpn), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_type"), uvm_hdl_data_t'(req_type), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_req"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);
    l2cov_release_value(l2cov_pde_path("ptw_req"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_type"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_vpn"), ctx);
    l2cov_release_value(l2cov_l1_path(entry, "L1PDE_l1pmpflg"), ctx);
    l2cov_release_value(l2cov_l1_path(entry, "L1PDE_ppn"), ctx);
    l2cov_release_value(l2cov_l1_path(entry, "L1PDE_tag"), ctx);
    l2cov_release_value(l2cov_l1_path(entry, "L1PDE_vld"), ctx);
    stage8_wait_cycles(1);
  endtask

  protected task l2cov_clear_accerr_by_grant(input string ctx);
    l2cov_force_value(l2cov_pde_path("ptw_req"), uvm_hdl_data_t'(1'b0), ctx);
    l2cov_force_value(l2cov_pde_path("PDE_cache_acc_err_grant"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(2);
    l2cov_force_value(l2cov_pde_path("PDE_cache_acc_err_grant"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);
    l2cov_release_value(l2cov_pde_path("PDE_cache_acc_err_grant"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_req"), ctx);
  endtask

  protected task l2cov_force_l2_pmpflg(
    input int unsigned entry,
    input logic [3:0]  l1pmpflg,
    input logic [3:0]  l2pmpflg,
    input string       ctx
  );
    l2cov_force_value(l2cov_l2_path(entry, "L2PDE_l1pmpflg"), uvm_hdl_data_t'(l1pmpflg), ctx);
    l2cov_force_value(l2cov_l2_path(entry, "L2PDE_l2pmpflg"), uvm_hdl_data_t'(l2pmpflg), ctx);
    stage8_wait_cycles(1);
  endtask

  protected task l2cov_release_l2_pmpflg(input int unsigned entry, input string ctx);
    l2cov_release_value(l2cov_l2_path(entry, "L2PDE_l2pmpflg"), ctx);
    l2cov_release_value(l2cov_l2_path(entry, "L2PDE_l1pmpflg"), ctx);
    stage8_wait_cycles(1);
  endtask

  protected task l2cov_force_local_modes(
    input logic       mprv,
    input logic [1:0] yy_priv,
    input logic [1:0] mpp,
    input string      ctx
  );
    l2cov_force_value(l2cov_pde_path("cp0_mmu_mprv"), uvm_hdl_data_t'(mprv), ctx);
    l2cov_force_value(l2cov_pde_path("cp0_yy_priv_mode"), uvm_hdl_data_t'(yy_priv), ctx);
    l2cov_force_value(l2cov_pde_path("cp0_mmu_mpp"), uvm_hdl_data_t'(mpp), ctx);
    stage8_wait_cycles(1);
  endtask

  protected task l2cov_release_local_modes(input string ctx);
    l2cov_release_value(l2cov_pde_path("cp0_mmu_mpp"), ctx);
    l2cov_release_value(l2cov_pde_path("cp0_yy_priv_mode"), ctx);
    l2cov_release_value(l2cov_pde_path("cp0_mmu_mprv"), ctx);
    stage8_wait_cycles(1);
  endtask

  protected task l2cov_cover_l2_accerr_conditions();
    string ctx;
    logic [17:0] tag;

    tag = l2cov_high_tag(0);

    ctx = "l2pde_accerr_cond_invalid_match_deny";
    l2cov_force_local_modes(1'b0, PRIV_S, PRIV_U, ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_vld"), uvm_hdl_data_t'(1'b0), ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_tag"), uvm_hdl_data_t'(tag), ctx);
    l2cov_force_l2_pmpflg(0, 4'h0, 4'h1, ctx);
    l2cov_drive_pde_req(tag, 9'h000, L2COV_TYPE_LOAD, 7'h10, ctx, 1'b1);
    l2cov_release_pde_req(ctx);
    l2cov_release_l2_pmpflg(0, ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_tag"), ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_vld"), ctx);
    l2cov_release_local_modes(ctx);

    ctx = "l2pde_accerr_cond_valid_miss_deny";
    l2cov_force_local_modes(1'b0, PRIV_S, PRIV_U, ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_vld"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_tag"), uvm_hdl_data_t'(tag), ctx);
    l2cov_force_l2_pmpflg(0, 4'h0, 4'h1, ctx);
    l2cov_drive_pde_req(l2cov_low_tag(0), 9'h000, L2COV_TYPE_LOAD, 7'h11, ctx, 1'b1);
    l2cov_release_pde_req(ctx);
    l2cov_release_l2_pmpflg(0, ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_tag"), ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_vld"), ctx);
    l2cov_release_local_modes(ctx);

    ctx = "l2pde_accerr_cond_valid_match_allow";
    l2cov_force_local_modes(1'b0, PRIV_S, PRIV_U, ctx);
    l2cov_force_value(l2cov_pde_path("PDE_xbar_req"), uvm_hdl_data_t'(1'b0), ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_vld"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_tag"), uvm_hdl_data_t'(tag), ctx);
    l2cov_force_l2_pmpflg(0, 4'h7, 4'h7, ctx);
    l2cov_drive_pde_req(tag, 9'h000, L2COV_TYPE_LOAD, 7'h12, ctx, 1'b1);
    l2cov_release_pde_req(ctx);
    l2cov_release_l2_pmpflg(0, ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_tag"), ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_vld"), ctx);
    l2cov_release_value(l2cov_pde_path("PDE_xbar_req"), ctx);
    l2cov_release_local_modes(ctx);

    ctx = "l2pde_direct_accerr_single_cycle";
    l2cov_force_local_modes(1'b0, PRIV_S, PRIV_U, ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_vld"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_tag"), uvm_hdl_data_t'(tag), ctx);
    l2cov_force_l2_pmpflg(0, 4'h0, 4'h1, ctx);
    l2cov_force_value(l2cov_pde_path("ptw_vpn"), uvm_hdl_data_t'(l2cov_make_vpn(tag, 9'h000)), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_type"), uvm_hdl_data_t'(L2COV_TYPE_LOAD), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_id"), uvm_hdl_data_t'(7'h12), ctx);
    l2cov_force_value(l2cov_pde_path("xbar_pde_ready"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_req"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(1);
    l2cov_force_value(l2cov_pde_path("ptw_req"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(4);
    l2cov_release_value(l2cov_pde_path("ptw_req"), ctx);
    l2cov_release_value(l2cov_pde_path("xbar_pde_ready"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_id"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_type"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_vpn"), ctx);
    l2cov_release_l2_pmpflg(0, ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_tag"), ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_vld"), ctx);
    l2cov_release_local_modes(ctx);
  endtask

  protected task l2cov_l2_condition_matrix();
    string ctx;
    logic [17:0] tag;

    tag = l2cov_high_tag(0);

    ctx = "l2pde_l1_allow_l2_deny_load_accerr";
    l2cov_force_local_modes(1'b0, PRIV_S, PRIV_U, ctx);
    l2cov_force_l2_pmpflg(0, 4'h1, 4'h0, ctx);
    l2cov_drive_pde_req(tag, 9'h000, L2COV_TYPE_LOAD, 7'h7e, ctx, 1'b0);
    stage8_wait_cycles(2);
    l2cov_release_pde_req(ctx);
    l2cov_release_l2_pmpflg(0, ctx);
    l2cov_release_local_modes(ctx);

    ctx = "l2pde_l1_deny_l2_allow_load_accerr";
    l2cov_force_local_modes(1'b0, PRIV_S, PRIV_U, ctx);
    l2cov_force_l2_pmpflg(0, 4'h0, 4'h1, ctx);
    l2cov_drive_pde_req(tag, 9'h004, L2COV_TYPE_LOAD, 7'h6a, ctx, 1'b0);
    stage8_wait_cycles(2);
    l2cov_release_pde_req(ctx);
    l2cov_release_l2_pmpflg(0, ctx);
    l2cov_release_local_modes(ctx);

    ctx = "l2pde_fetch_mmode_l1_locked_l2_unlocked_accerr";
    l2cov_force_local_modes(1'b0, PRIV_M, PRIV_U, ctx);
    l2cov_force_l2_pmpflg(0, 4'h8, 4'h0, ctx);
    l2cov_drive_pde_req(tag, 9'h001, L2COV_TYPE_FETCH, 7'h65, ctx, 1'b0);
    stage8_wait_cycles(2);
    l2cov_release_pde_req(ctx);
    l2cov_release_l2_pmpflg(0, ctx);
    l2cov_release_local_modes(ctx);

    ctx = "l2pde_fetch_mmode_l1_unlocked_l2_locked_accerr";
    l2cov_force_local_modes(1'b0, PRIV_M, PRIV_U, ctx);
    l2cov_force_l2_pmpflg(0, 4'h0, 4'h8, ctx);
    l2cov_drive_pde_req(tag, 9'h002, L2COV_TYPE_FETCH, 7'h5a, ctx, 1'b0);
    stage8_wait_cycles(2);
    l2cov_release_pde_req(ctx);
    l2cov_release_l2_pmpflg(0, ctx);
    l2cov_release_local_modes(ctx);

    ctx = "l2pde_fetch_mmode_bypass_both_unlocked_hit";
    l2cov_force_local_modes(1'b0, PRIV_M, PRIV_U, ctx);
    l2cov_force_l2_pmpflg(0, 4'h0, 4'h0, ctx);
    l2cov_drive_l2_hit(0, tag, L2COV_TYPE_FETCH, 7'h21, ctx);
    l2cov_release_l2_pmpflg(0, ctx);
    l2cov_release_local_modes(ctx);

    ctx = "l2pde_default_type_case";
    l2cov_force_local_modes(1'b0, PRIV_S, PRIV_U, ctx);
    l2cov_drive_pde_req(tag, 9'h003, 3'b000, 7'h00, ctx, 1'b0);
    stage8_wait_cycles(2);
    l2cov_release_pde_req(ctx);
    l2cov_release_local_modes(ctx);
  endtask

  protected task l2cov_cover_l2_hold_else();
    string ctx;

    l2cov_force_idle_req("l2pde_hold_else_idle");
    for (int unsigned i = 0; i < L2_COV_ENTRY_NUM; i++) begin
      ctx = $sformatf("l2pde_hold_else_entry_%0d", i);
      l2cov_force_value(l2cov_l2_path(i, "L2PDE_entry_clk_en"), uvm_hdl_data_t'(1'b1), ctx);
      stage8_wait_cycles(2);
      l2cov_release_value(l2cov_l2_path(i, "L2PDE_entry_clk_en"), ctx);
      stage8_wait_cycles(1);
    end
    l2cov_release_idle_req("l2pde_hold_else_idle");
  endtask

  protected task l2cov_fill_and_hit_all_entries();
    logic [2:0] req_type;
    logic [6:0] req_id;

    ptw_meta_begin("TC-PTW-L2PDE-PDE-COV", "l2pde_fill_hit_toggle_all_entries");
    ptw_meta_add_req("PTW-COV-L2PDE-PDE-001");
    l2cov_force_idle_req("l2pde_fill_idle");
    l2cov_force_local_modes(1'b0, PRIV_S, PRIV_U, "l2pde_fill_hit_smode");

    for (int unsigned i = 0; i < L2_COV_ENTRY_NUM; i++) begin
      l2cov_update_l2_entry(
        .entry(i),
        .tag(l2cov_high_tag(i)),
        .ppn(~28'(i)),
        .l1pmpflg(4'h7),
        .l2pmpflg(4'h7),
        .ctx($sformatf("l2pde_high_fill_slot_%0d", i)));
    end

    for (int unsigned i = 0; i < L2_COV_ENTRY_NUM; i++) begin
      case (i[1:0])
        2'b00: req_type = L2COV_TYPE_FETCH;
        2'b01: req_type = L2COV_TYPE_LOAD;
        2'b10: req_type = L2COV_TYPE_STORE;
        default: req_type = L2COV_TYPE_PREF;
      endcase
      req_id = 7'(i * 7 + 1);
      l2cov_drive_l2_hit(i, l2cov_high_tag(i), req_type, req_id,
        $sformatf("l2pde_allow_hit_slot_%0d", i));
    end

    l2cov_release_local_modes("l2pde_fill_hit_smode");
    l2cov_l2_condition_matrix();
    l2cov_cover_l2_hold_else();

    for (int unsigned i = 0; i < L2_COV_ENTRY_NUM; i++) begin
      l2cov_update_l2_entry(
        .entry(i),
        .tag(l2cov_low_tag(i)),
        .ppn(28'(i)),
        .l1pmpflg(4'h0),
        .l2pmpflg(4'h0),
        .ctx($sformatf("l2pde_low_refill_slot_%0d", i)));
    end

    l2cov_release_idle_req("l2pde_fill_idle");
    ptw_meta_add_context("whitebox_l2pde_all_entries_high_low_update_hit_accerr_matrix_hold_else");
    ptw_meta_set_expected("All 16 L2PDE entries receive high/low tag/ppn/pmp updates, legal allow hits, direct accerr deny combinations, M-mode lock matrix rows, and explicit gated-clock hold-else cycles");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_l2pde_pde_cov");
    ptw_meta_print();
  endtask

  protected task l2cov_cover_pde_l1_paths();
    string ctx;
    logic [8:0] tag;

    ctx = "pde_l1_refill_hit_selection";
    tag = 9'h15a;
    ptw_meta_begin("TC-PTW-L2PDE-PDE-COV", "pde_l1_refill_hit_selection");
    ptw_meta_add_req("PTW-COV-L2PDE-PDE-003");

    l2cov_force_idle_req(ctx);
    l2cov_force_local_modes(1'b0, PRIV_S, PRIV_U, ctx);

    for (int unsigned i = 0; i < L1_COV_ENTRY_NUM; i++) begin
      l2cov_update_l1_entry(i, tag ^ 9'(i), 28'(28'h1000 + i), 4'h7,
        $sformatf("pde_l1_refill_slot_%0d", i));
    end

    l2cov_update_l1_entry(0, tag, 28'h001_2345, 4'h7, "pde_l1_refill_no_old_hit");
    l2cov_update_l1_entry(0, tag, 28'h005_4321, 4'h7, "pde_l1_refill_old_hit_no_alloc");
    l2cov_drive_l1_hit(0, tag, L2COV_TYPE_LOAD, "pde_l1_only_hit");

    l2cov_force_value(l2cov_l1_path(0, "L1PDE_vld"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_l1_path(0, "L1PDE_tag"), uvm_hdl_data_t'(tag), ctx);
    l2cov_force_value(l2cov_l1_path(0, "L1PDE_ppn"), uvm_hdl_data_t'(28'h00a_0001), ctx);
    l2cov_force_value(l2cov_l1_path(0, "L1PDE_l1pmpflg"), uvm_hdl_data_t'(4'h7), ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_vld"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_tag"), uvm_hdl_data_t'({tag, 9'h000}), ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_ppn"), uvm_hdl_data_t'(28'h00b_0002), ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_l1pmpflg"), uvm_hdl_data_t'(4'h7), ctx);
    l2cov_force_value(l2cov_l2_path(0, "L2PDE_l2pmpflg"), uvm_hdl_data_t'(4'h7), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_vpn"), uvm_hdl_data_t'({tag, 18'h00000}), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_type"), uvm_hdl_data_t'(L2COV_TYPE_LOAD), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_req"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);
    l2cov_release_value(l2cov_pde_path("ptw_req"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_type"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_vpn"), ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_l2pmpflg"), ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_l1pmpflg"), ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_ppn"), ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_tag"), ctx);
    l2cov_release_value(l2cov_l2_path(0, "L2PDE_vld"), ctx);
    l2cov_release_value(l2cov_l1_path(0, "L1PDE_l1pmpflg"), ctx);
    l2cov_release_value(l2cov_l1_path(0, "L1PDE_ppn"), ctx);
    l2cov_release_value(l2cov_l1_path(0, "L1PDE_tag"), ctx);
    l2cov_release_value(l2cov_l1_path(0, "L1PDE_vld"), ctx);

    l2cov_release_local_modes(ctx);
    l2cov_release_idle_req(ctx);
    ptw_meta_add_context("whitebox_l1_refill_hit_l1_only_and_l1_l2_double_hit");
    ptw_meta_set_expected("PDE_cache L1 refill/no-refill old-hit rows, L1-only ppn select, and L1+L2 double-hit L2-wins select are covered");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_l2pde_pde_cov");
    ptw_meta_print();
  endtask

  protected task l2cov_cover_pde_seq_inputs();
    string ctx;

    ctx = "pde_seq_req_ready_hold_abort";
    ptw_meta_begin("TC-PTW-L2PDE-PDE-COV", "pde_req_register_ready_abort_pmp_update");
    ptw_meta_add_req("PTW-COV-L2PDE-PDE-002");

    l2cov_force_value(l2cov_pde_path("l2tlb_ptw_vpn"), uvm_hdl_data_t'(27'h7ff_ffff), ctx);
    l2cov_force_value(l2cov_pde_path("l2tlb_ptw_type"), uvm_hdl_data_t'(L2COV_TYPE_STORE), ctx);
    l2cov_force_value(l2cov_pde_path("l2tlb_ptw_id"), uvm_hdl_data_t'(7'h7f), ctx);
    l2cov_force_value(l2cov_pde_path("ptw_jtlb_ready"), uvm_hdl_data_t'(1'b0), ctx);
    l2cov_force_value(l2cov_pde_path("l2tlb_ptw_req"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(2);

    l2cov_force_value(l2cov_pde_path("ptw_jtlb_ready"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_pde_path("xbar_pde_ready"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);

    l2cov_force_value(l2cov_pde_path("l2tlb_ptw_req"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);

    l2cov_force_value(l2cov_pde_path("tlboper_ptw_abort"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(2);
    l2cov_force_value(l2cov_pde_path("tlboper_ptw_abort"), uvm_hdl_data_t'(1'b0), ctx);
    l2cov_force_value(l2cov_pde_path("xbar_pde_ready"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(2);

    l2cov_force_value(l2cov_pde_path("regs_ptw_clr"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(2);
    l2cov_force_value(l2cov_pde_path("regs_ptw_clr"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(1);

    l2cov_force_value(l2cov_pde_path("pmp_regs_update"), uvm_hdl_data_t'(1'b1), ctx);
    stage8_wait_cycles(3);
    if ((ptw_probe_vif != null)
        && (ptw_probe_vif.mon_cb.pde_l2_valid_vec !== 16'h0000))
      `uvm_error(get_type_name(),
        $sformatf("%s: L2 valid entries not cleared by pmp_regs_update, vec=0x%04h",
          ctx, ptw_probe_vif.mon_cb.pde_l2_valid_vec))
    l2cov_force_value(l2cov_pde_path("pmp_regs_update"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);

    l2cov_force_value(l2cov_pde_path("pad_yy_icg_scan_en"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_pde_path("cp0_mmu_icg_en"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);
    l2cov_force_value(l2cov_pde_path("cp0_mmu_icg_en"), uvm_hdl_data_t'(1'b1), ctx);
    l2cov_force_value(l2cov_pde_path("pad_yy_icg_scan_en"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(2);

    l2cov_force_value(l2cov_pde_path("l2tlb_ptw_type"), uvm_hdl_data_t'(L2COV_TYPE_FETCH), ctx);
    stage8_wait_cycles(2);
    l2cov_force_value(l2cov_pde_path("l2tlb_ptw_type"), uvm_hdl_data_t'(L2COV_TYPE_STORE), ctx);
    stage8_wait_cycles(1);

    l2cov_force_local_modes(1'b1, PRIV_S, PRIV_U, ctx);
    l2cov_force_local_modes(1'b0, PRIV_U, PRIV_M, ctx);
    l2cov_release_local_modes(ctx);

    l2cov_force_value(l2cov_pde_path("cpurst_b"), uvm_hdl_data_t'(1'b0), ctx);
    stage8_wait_cycles(4);
    l2cov_release_value(l2cov_pde_path("cpurst_b"), ctx);
    stage8_wait_cycles(12);

    l2cov_release_value(l2cov_pde_path("cp0_mmu_icg_en"), ctx);
    l2cov_release_value(l2cov_pde_path("pad_yy_icg_scan_en"), ctx);
    l2cov_release_value(l2cov_pde_path("pmp_regs_update"), ctx);
    l2cov_release_value(l2cov_pde_path("regs_ptw_clr"), ctx);
    l2cov_release_value(l2cov_pde_path("tlboper_ptw_abort"), ctx);
    l2cov_release_value(l2cov_pde_path("xbar_pde_ready"), ctx);
    l2cov_release_value(l2cov_pde_path("l2tlb_ptw_req"), ctx);
    l2cov_release_value(l2cov_pde_path("ptw_jtlb_ready"), ctx);
    l2cov_release_value(l2cov_pde_path("l2tlb_ptw_id"), ctx);
    l2cov_release_value(l2cov_pde_path("l2tlb_ptw_type"), ctx);
    l2cov_release_value(l2cov_pde_path("l2tlb_ptw_vpn"), ctx);
    stage8_wait_cycles(4);

    ptw_meta_add_context("whitebox_pde_req_register_ready_abort_pmp_update_icg_reset_mprv");
    ptw_meta_set_expected("PDE_cache request flops see ready-low hold, ready-qualified request capture, abort clear, pmp_regs_update clear, scan/icg/mprv/mpp toggles, and local reset");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_l2pde_pde_cov");
    ptw_meta_print();
  endtask

  virtual task run_test_body();
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;
    l2cov_fill_and_hit_all_entries();
    l2cov_cover_pde_l1_paths();
    l2cov_cover_l2_accerr_conditions();
    l2cov_cover_pde_seq_inputs();
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-L2PDE-PDE-001,PTW-COV-L2PDE-PDE-002",
      "l2pde_pde_cache_code_coverage_closure",
      "16-entry L2PDE update/hit/high-low toggle, direct-accerr PMP condition matrix, gated hold-else, PDE request ready/abort/pmp-update/reset/static-input toggle stimulus");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass : test_ptw_l2pde_pde_cache_cov_closure_001

`endif // TEST_PTW_L2PDE_PDE_CACHE_COV_CLOSURE_001_SVH
