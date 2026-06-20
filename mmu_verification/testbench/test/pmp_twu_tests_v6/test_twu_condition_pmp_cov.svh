`ifndef TEST_TWU_CONDITION_PMP_COV_SVH
`define TEST_TWU_CONDITION_PMP_COV_SVH

class test_twu_condition_pmp_cov extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_condition_pmp_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 1_000_000;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu_code_cov";
    p12_trace_id = "TC-TWU-COND-PMP-COV-001";
    p12_fid      = "PTW-CODE-TWU-COND";
    p12_priority = "P0";
    p12_seq_desc = "whitebox TWU PMP/request condition coverage";
    p12_checker  = "twu condition coverage: pmp request, deny, mbuf, pmp arbiter";
    p12_reviewer = "A+B";
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init          = 1'b0;
    m_post_drain             = 100ns;
  endfunction

  protected virtual task force_quiet(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("xbar_twu_req",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("mbuf_twu_data_vld", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("mbuf_grant",        uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("pmp_mmu_flg",       uvm_hdl_data_t'(4'h7), ctx);
    phase12_twu_force_value("cp0_mmu_mprv",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("cp0_mmu_mpp",       uvm_hdl_data_t'(2'b00), ctx);
    phase12_twu_force_value("cp0_yy_priv_mode",  uvm_hdl_data_t'(2'b01), ctx);
  endtask

  protected virtual task release_quiet(input string ctx);
    phase12_twu_release_value("cp0_yy_priv_mode", ctx);
    phase12_twu_release_value("cp0_mmu_mpp", ctx);
    phase12_twu_release_value("cp0_mmu_mprv", ctx);
    phase12_twu_release_value("pmp_mmu_flg", ctx);
    phase12_twu_release_value("mbuf_grant", ctx);
    phase12_twu_release_value("mbuf_twu_data_vld", ctx);
    phase12_twu_release_value("xbar_twu_req", ctx);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
  endtask

  protected virtual task cover_xbar_wait_terms(
    input string ctx,
    input logic [1:0] hit_level,
    input string      vld_sig,
    input string      type_sig
  );
    phase12_twu_force_value("xbar_twu_req",       uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("xbar_twu_hit_level", uvm_hdl_data_t'(hit_level), ctx);
    phase12_twu_force_value("pmp_grant",          uvm_hdl_data_t'(3'b000), ctx);
    phase12_twu_deposit_value(type_sig,           uvm_hdl_data_t'(3'b010), ctx);
    phase12_twu_deposit_value(vld_sig,            uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(4);

    phase12_twu_deposit_value(vld_sig, uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_release_value("pmp_grant", ctx);
    phase12_twu_release_value("xbar_twu_hit_level", ctx);
    phase12_twu_force_value("xbar_twu_req", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
  endtask

  protected virtual task cover_chk_to_pmp_wait_terms(
    input string ctx,
    input string chk_vld_sig,
    input string chk_leaf_sig,
    input string chk_pgflt_sig,
    input string pmp_wait_sig
  );
    phase12_twu_force_value(chk_vld_sig,   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value(chk_leaf_sig,  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value(chk_pgflt_sig, uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value(pmp_wait_sig,  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(4);

    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_release_value(pmp_wait_sig, ctx);
    phase12_twu_release_value(chk_pgflt_sig, ctx);
    phase12_twu_release_value(chk_leaf_sig, ctx);
    phase12_twu_release_value(chk_vld_sig, ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
  endtask

  protected virtual task cover_pmp_deny_stage(
    input string ctx,
    input string type_sig
  );
    phase12_twu_force_value("cp0_yy_priv_mode", uvm_hdl_data_t'(2'b11), ctx);
    phase12_twu_force_value("cp0_mmu_mprv",     uvm_hdl_data_t'(1'b0), ctx);

    phase12_twu_force_value("pmp_mmu_flg", uvm_hdl_data_t'(4'h8), ctx);
    phase12_twu_deposit_value(type_sig,    uvm_hdl_data_t'(3'b010), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("cp0_yy_priv_mode", uvm_hdl_data_t'(2'b01), ctx);
    phase12_twu_force_value("pmp_mmu_flg",      uvm_hdl_data_t'(4'h6), ctx);
    phase12_twu_deposit_value(type_sig,         uvm_hdl_data_t'(3'b100), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("cp0_yy_priv_mode", uvm_hdl_data_t'(2'b11), ctx);
    phase12_twu_deposit_value(type_sig,         uvm_hdl_data_t'(3'b011), ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task cover_thd_mbuf_wait_terms(input string ctx);
    phase12_twu_force_value("thd_pmp_vld",   uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_pmp_deny",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_pmp_grant", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("thd_pmp_deny",          uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("acc_err_thd_pmp_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_release_value("acc_err_thd_pmp_grant", ctx);
    phase12_twu_release_value("thd_pmp_grant", ctx);
    phase12_twu_release_value("thd_pmp_deny", ctx);
    phase12_twu_release_value("thd_pmp_vld", ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task cover_pmp_arb_terms(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("pmp_mmu_flg",       uvm_hdl_data_t'(4'h0), ctx);
    phase12_twu_force_value("fst_pmp_type", uvm_hdl_data_t'(3'b010), ctx);
    phase12_twu_force_value("scd_pmp_type", uvm_hdl_data_t'(3'b010), ctx);
    phase12_twu_force_value("thd_pmp_type", uvm_hdl_data_t'(3'b010), ctx);
    phase12_twu_force_value("fst_pmp_vld",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_pmp_vld",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("thd_pmp_vld",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("scd_pmp_vld", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_pmp_vld", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("scd_pmp_vld", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_release_value("thd_pmp_vld", ctx);
    phase12_twu_release_value("scd_pmp_vld", ctx);
    phase12_twu_release_value("fst_pmp_vld", ctx);
    phase12_twu_release_value("thd_pmp_type", ctx);
    phase12_twu_release_value("scd_pmp_type", ctx);
    phase12_twu_release_value("fst_pmp_type", ctx);
    phase12_twu_force_value("pmp_mmu_flg", uvm_hdl_data_t'(4'h7), ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);
  endtask

  virtual task run_test_body();
    string ctx;
    setup_plan();
    #100ns;
    ctx = "twu_condition_pmp_cov";
    force_quiet(ctx);

    cover_xbar_wait_terms({ctx, "_fst_xbar_wait"}, 2'b00, "fst_pmp_vld", "fst_pmp_type");
    cover_xbar_wait_terms({ctx, "_scd_xbar_wait"}, 2'b10, "scd_pmp_vld", "scd_pmp_type");
    cover_xbar_wait_terms({ctx, "_thd_xbar_wait"}, 2'b01, "thd_pmp_vld", "thd_pmp_type");

    cover_chk_to_pmp_wait_terms({ctx, "_fst_to_scd_wait"},
      "fst_chk_vld", "fst_chk_leaf_vld", "fst_chk_page_flt", "scd_pmp_wait");
    cover_chk_to_pmp_wait_terms({ctx, "_scd_to_thd_wait"},
      "scd_chk_vld", "scd_chk_leaf_vld", "scd_chk_page_flt", "thd_pmp_wait");

    cover_pmp_deny_stage({ctx, "_fst_deny"}, "fst_pmp_type");
    cover_pmp_deny_stage({ctx, "_scd_deny"}, "scd_pmp_type");
    cover_pmp_deny_stage({ctx, "_thd_deny"}, "thd_pmp_type");
    cover_thd_mbuf_wait_terms({ctx, "_thd_mbuf_wait"});
    cover_pmp_arb_terms({ctx, "_pmp_arb"});

    release_quiet(ctx);
    #(m_post_drain);
  endtask
endclass

`endif
