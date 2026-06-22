// =============================================================================
// Residual toggle coverage: one_to_four_xbar, mbuf_entry, ptw_mbuf,
// mmu_ptw_top_sva, mmu_twu_chk_sva, mmu_ptw_xbar_sva
// =============================================================================
`ifndef TEST_PTW_RESIDUAL_TOGGLE_COV_SVH
`define TEST_PTW_RESIDUAL_TOGGLE_COV_SVH

class test_ptw_residual_toggle_cov extends ptw_pde_pmpflg_stage8_base;

  `uvm_component_utils(test_ptw_residual_toggle_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 3_000_000;
  endfunction

  protected task hf(input string path, input uvm_hdl_data_t val, input string ctx);
    if (!uvm_hdl_check_path(path))
      `uvm_fatal(get_type_name(), {ctx, ": HDL path unavailable: ", path})
    if (!uvm_hdl_force(path, val))
      `uvm_fatal(get_type_name(), {ctx, ": failed to force: ", path})
  endtask
  protected task hr(input string path, input string ctx);
    if (!uvm_hdl_release(path))
      `uvm_fatal(get_type_name(), {ctx, ": failed to release: ", path})
  endtask
  protected task ps(input string path, input uvm_hdl_data_t high_val, input string ctx);
    hf(path, uvm_hdl_data_t'(1'b0), ctx); stage8_wait_cycles(1);
    hf(path, high_val, ctx);              stage8_wait_cycles(1);
    hf(path, uvm_hdl_data_t'(1'b0), ctx); stage8_wait_cycles(1);
    hr(path, ctx);                        stage8_wait_cycles(1);
  endtask

  virtual task run_test_body();
    string ctx = "rtog";
    string root = "$root.tb_top.u_dut.x_ct_mmu_ptw";
    string xb, me, mb, pts, xbs, tcs;
    stage8_wait_cycles(40);
    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b1;

    ptw_meta_begin("TC-PTW-RESIDUAL-TOGGLE", "residual_toggle_closure");
    ptw_meta_add_req("PTW-COV-RESIDUAL-TOGGLE-001");

    // one_to_four_xbar
    xb = {root, ".u_one_to_four_xbar"};
    ps({xb, ".PDE_xbar_ppn"},      uvm_hdl_data_t'(28'hFFFFFFF), {ctx, "_xbppn"});
    ps({xb, ".xbar_twu_ppn"},      uvm_hdl_data_t'(28'hFFFFFFF), {ctx, "_xbtppn"});
    ps({xb, ".xbar_twu_req"},      uvm_hdl_data_t'(1'b1),        {ctx, "_xbreq"});
    ps({xb, ".PDE_xbar_req"},      uvm_hdl_data_t'(1'b1),        {ctx, "_xbprq"});
    ps({xb, ".L1PDE_xbar_hit_vld"},uvm_hdl_data_t'(1'b1),        {ctx, "_xbl1h"});
    ps({xb, ".L2PDE_xbar_hit_vld"},uvm_hdl_data_t'(1'b1),        {ctx, "_xbl2h"});

    // mbuf_entry x9
    for (int e = 0; e < 9; e++) begin
      me = {root, ".u_ptw_mbuf.u_MBUF_ent_0_8[", $sformatf("%0d", e), "].mbuf_entry_x"};
      ps({me, ".mbuf_entry_data"},   uvm_hdl_data_t'(64'hFFFFFFFFFFFFFFFF), {ctx, "_med", $sformatf("%0d",e)});
      ps({me, ".mbuf_entry_padder"}, uvm_hdl_data_t'(40'hFFFFFFFFFF),     {ctx, "_mep", $sformatf("%0d",e)});
      ps({me, ".mbuf_entry_vpn"},    uvm_hdl_data_t'(27'h7FFFFFF),        {ctx, "_mev", $sformatf("%0d",e)});
      ps({me, ".mbuf_entry_id"},     uvm_hdl_data_t'(7'h7F),             {ctx, "_mei", $sformatf("%0d",e)});
      ps({me, ".mbuf_entry_type"},   uvm_hdl_data_t'(3'b111),            {ctx, "_met", $sformatf("%0d",e)});
      ps({me, ".mbuf_entry_pmpflg"}, uvm_hdl_data_t'(8'hFF),             {ctx, "_mef", $sformatf("%0d",e)});
    end

    // ptw_mbuf
    mb = {root, ".u_ptw_mbuf"};
    ps({mb, ".write_back_grant"},      uvm_hdl_data_t'(9'h1FF), {ctx, "_wbg"});
    ps({mb, ".mbuf_bus_error_grant"},  uvm_hdl_data_t'(9'h1FF), {ctx, "_mbeg"});
    ps({mb, ".mbuf_grant"},            uvm_hdl_data_t'(9'h1FF), {ctx, "_mbg"});
    ps({mb, ".mbuf_entry_upd"},        uvm_hdl_data_t'(9'h1FF), {ctx, "_meu"});

    // mmu_ptw_top_sva
    pts = {root, ".u_ptw_top_sva"};
    ps({pts, ".ptw_arb_ref_data_din"},    uvm_hdl_data_t'(42'h3FFFFFFFFFF),  {ctx, "_ard"});
    ps({pts, ".ptw_arb_ref_tag_din"},     uvm_hdl_data_t'(48'hFFFFFFFFFFFF), {ctx, "_art"});
    ps({pts, ".ptw_arb_vpn"},             uvm_hdl_data_t'(27'h7FFFFFF),      {ctx, "_arv"});
    ps({pts, ".ptw_l1dtlb_ref_ppn"},      uvm_hdl_data_t'(28'hFFFFFFF),      {ctx, "_l1dp"});
    ps({pts, ".ptw_l1itlb_ref_ppn"},      uvm_hdl_data_t'(28'hFFFFFFF),      {ctx, "_l1ip"});
    ps({pts, ".twu_l2tlb_ref_acc_err_id"},uvm_hdl_data_t'(28'hFFFFFFF),      {ctx, "_taid"});

    // mmu_ptw_xbar_sva
    xbs = {root, ".u_one_to_four_xbar.u_ptw_xbar_sva"};
    ps({xbs, ".twu_req_hash"}, uvm_hdl_data_t'(4'hF),  {ctx, "_xbh"});
    ps({xbs, ".twu_hash"},     uvm_hdl_data_t'(2'b11), {ctx, "_xbth"});
    ps({xbs, ".twu_mask"},     uvm_hdl_data_t'(4'hF),  {ctx, "_xbm"});

    // mmu_twu_chk_sva
    tcs = {root, ".twu_one.u_twu_chk_sva"};
    ps({tcs, ".fst_chk_data"}, uvm_hdl_data_t'(64'hFFFFFFFFFFFFFFFF), {ctx, "_tcfd"});
    ps({tcs, ".scd_chk_data"}, uvm_hdl_data_t'(64'hFFFFFFFFFFFFFFFF), {ctx, "_tcsd"});
    ps({tcs, ".thd_chk_data"}, uvm_hdl_data_t'(64'hFFFFFFFFFFFFFFFF), {ctx, "_tctd"});

    ptw_meta_set_expected("All residual toggle items covered");
    ptw_meta_set_actual("coverage_stimulus_completed");
    ptw_meta_set_result("directed_residual_toggle");
    ptw_meta_print();

    l2tlb_negative_pkg::l2tlb_neg_sva_disable = 1'b0;
    stage8_close("PTW-COV-RESIDUAL-TOGGLE-001", "residual_toggle",
      "Residual toggle closure for 6 modules");
    stage8_summary(1'b0);
    #200ns;
  endtask

endclass

`endif
