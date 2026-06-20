`ifndef TEST_TWU_CONDITION_PAGEFAULT_COV_SVH
`define TEST_TWU_CONDITION_PAGEFAULT_COV_SVH

class test_twu_condition_pagefault_cov extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_condition_pagefault_cov)

  localparam bit [8:0] FLG_GOOD       = 9'h07f;
  localparam bit [8:0] FLG_NO_V       = 9'h07e;
  localparam bit [8:0] FLG_WRITE_ONLY = 9'h07d;
  localparam bit [8:0] FLG_NO_W       = 9'h07b;
  localparam bit [8:0] FLG_NO_X       = 9'h077;
  localparam bit [8:0] FLG_SUPV_PAGE  = 9'h06f;
  localparam bit [8:0] FLG_NO_A       = 9'h05f;
  localparam bit [8:0] FLG_NO_D       = 9'h03f;
  localparam bit [8:0] FLG_R_ONLY     = 9'h073;
  localparam bit [8:0] FLG_X_ONLY     = 9'h079;
  localparam bit [8:0] FLG_NO_RX      = 9'h075;

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 1_000_000;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu_code_cov";
    p12_trace_id = "TC-TWU-COND-PAGEFAULT-COV-001";
    p12_fid      = "PTW-CODE-TWU-COND";
    p12_priority = "P0";
    p12_seq_desc = "whitebox TWU page-fault condition coverage";
    p12_checker  = "twu condition coverage: fst/scd/thd page fault flag combinations";
    p12_reviewer = "A+B";
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init          = 1'b0;
    m_post_drain             = 100ns;
  endfunction

  protected virtual task force_modes(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("cp0_mmu_mprv",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("cp0_mmu_mpp",       uvm_hdl_data_t'(2'b00), ctx);
    phase12_twu_force_value("cp0_yy_priv_mode",  uvm_hdl_data_t'(2'b01), ctx);
    phase12_twu_force_value("cp0_mmu_mxr",       uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("cp0_mmu_sum",       uvm_hdl_data_t'(1'b1), ctx);
  endtask

  protected virtual task release_modes(input string ctx);
    phase12_twu_release_value("cp0_mmu_sum", ctx);
    phase12_twu_release_value("cp0_mmu_mxr", ctx);
    phase12_twu_release_value("cp0_yy_priv_mode", ctx);
    phase12_twu_release_value("cp0_mmu_mpp", ctx);
    phase12_twu_release_value("cp0_mmu_mprv", ctx);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
  endtask

  protected virtual task drive_pf_case(
    input string      ctx,
    input string      flg_sig,
    input string      data_sig,
    input string      type_sig,
    input bit [8:0]   flg,
    input logic [2:0] typ,
    input logic [63:0] data
  );
    phase12_twu_force_value(flg_sig,  uvm_hdl_data_t'(flg), ctx);
    phase12_twu_force_value(type_sig, uvm_hdl_data_t'(typ), ctx);
    phase12_twu_force_value(data_sig, uvm_hdl_data_t'(data), ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task cover_leaf_expr(input string ctx, input string flg_sig);
    phase12_twu_force_value(flg_sig, uvm_hdl_data_t'(FLG_X_ONLY), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_force_value(flg_sig, uvm_hdl_data_t'(FLG_R_ONLY), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_force_value(flg_sig, uvm_hdl_data_t'(FLG_NO_RX), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_release_value(flg_sig, ctx);
    phase12_twu_wait_cycles(1);
  endtask

  protected virtual task cover_priv_mode_terms(input string ctx);
    phase12_twu_force_value("fst_chk_type",      uvm_hdl_data_t'(3'b011), ctx);
    phase12_twu_force_value("cp0_yy_priv_mode",  uvm_hdl_data_t'(2'b00), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_force_value("cp0_yy_priv_mode",  uvm_hdl_data_t'(2'b01), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_force_value("cp0_yy_priv_mode",  uvm_hdl_data_t'(2'b11), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_release_value("fst_chk_type", ctx);
  endtask

  protected virtual task cover_stage_page_fault(
    input string ctx,
    input string flg_sig,
    input string leaf_sig,
    input string data_sig,
    input string type_sig,
    input bit    has_leaf_gate,
    input logic [63:0] align_bad_data
  );
    if (has_leaf_gate)
      phase12_twu_force_value(leaf_sig, uvm_hdl_data_t'(1'b1), ctx);

    drive_pf_case({ctx, "_good_load"}, flg_sig, data_sig, type_sig, FLG_GOOD, 3'b010, 64'h0);
    drive_pf_case({ctx, "_not_valid"}, flg_sig, data_sig, type_sig, FLG_NO_V, 3'b010, 64'h0);
    drive_pf_case({ctx, "_write_only"}, flg_sig, data_sig, type_sig, FLG_WRITE_ONLY, 3'b010, 64'h0);
    drive_pf_case({ctx, "_store_no_w"}, flg_sig, data_sig, type_sig, FLG_NO_W, 3'b110, 64'h0);
    drive_pf_case({ctx, "_fetch_no_x"}, flg_sig, data_sig, type_sig, FLG_NO_X, 3'b011, 64'h0);

    phase12_twu_force_value("cp0_yy_priv_mode", uvm_hdl_data_t'(2'b01), ctx);
    phase12_twu_force_value("cp0_mmu_sum",      uvm_hdl_data_t'(1'b0), ctx);
    drive_pf_case({ctx, "_supv_to_user"}, flg_sig, data_sig, type_sig, FLG_GOOD, 3'b010, 64'h0);

    phase12_twu_force_value("cp0_yy_priv_mode", uvm_hdl_data_t'(2'b00), ctx);
    phase12_twu_force_value("cp0_mmu_sum",      uvm_hdl_data_t'(1'b1), ctx);
    drive_pf_case({ctx, "_user_to_supv"}, flg_sig, data_sig, type_sig, FLG_SUPV_PAGE, 3'b010, 64'h0);

    phase12_twu_force_value("cp0_yy_priv_mode", uvm_hdl_data_t'(2'b01), ctx);
    drive_pf_case({ctx, "_no_a"}, flg_sig, data_sig, type_sig, FLG_NO_A, 3'b010, 64'h0);
    drive_pf_case({ctx, "_no_d_store"}, flg_sig, data_sig, type_sig, FLG_NO_D, 3'b110, 64'h0);
    drive_pf_case({ctx, "_align_bad"}, flg_sig, data_sig, type_sig, FLG_GOOD, 3'b010, align_bad_data);
    drive_pf_case({ctx, "_no_r_no_x"}, flg_sig, data_sig, type_sig, FLG_NO_RX, 3'b010, 64'h0);

    if (has_leaf_gate)
      phase12_twu_release_value(leaf_sig, ctx);
    phase12_twu_release_value(type_sig, ctx);
    phase12_twu_release_value(data_sig, ctx);
    phase12_twu_release_value(flg_sig, ctx);
    phase12_twu_wait_cycles(2);
  endtask

  virtual task run_test_body();
    string ctx;
    setup_plan();
    #100ns;
    ctx = "twu_condition_pagefault_cov";
    force_modes(ctx);

    cover_leaf_expr({ctx, "_fst_leaf"}, "fst_chk_flg");
    cover_leaf_expr({ctx, "_scd_leaf"}, "scd_chk_flg");
    cover_priv_mode_terms({ctx, "_priv_modes"});

    cover_stage_page_fault({ctx, "_fst_pf"},
      "fst_chk_flg", "fst_chk_leaf_vld", "fst_chk_data", "fst_chk_type", 1'b1, 64'h0000_0000_0000_0400);
    cover_stage_page_fault({ctx, "_scd_pf"},
      "scd_chk_flg", "scd_chk_leaf_vld", "scd_chk_data", "scd_chk_type", 1'b1, 64'h0000_0000_0000_0400);
    cover_stage_page_fault({ctx, "_thd_pf"},
      "thd_chk_flg", "", "thd_chk_data", "thd_chk_type", 1'b0, 64'h0);

    release_modes(ctx);
    #(m_post_drain);
  endtask
endclass

`endif
