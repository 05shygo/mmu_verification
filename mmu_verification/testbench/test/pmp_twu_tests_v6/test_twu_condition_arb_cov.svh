`ifndef TEST_TWU_CONDITION_ARB_COV_SVH
`define TEST_TWU_CONDITION_ARB_COV_SVH

class test_twu_condition_arb_cov extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_condition_arb_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 1_000_000;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu_code_cov";
    p12_trace_id = "TC-TWU-COND-ARB-COV-001";
    p12_fid      = "PTW-CODE-TWU-COND";
    p12_priority = "P0";
    p12_seq_desc = "whitebox TWU exception, CSR, and refill arbiter condition coverage";
    p12_checker  = "twu condition coverage: pgflt/accerr priority, CSR, refill arbiter";
    p12_reviewer = "A+B";
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init          = 1'b0;
    m_post_drain             = 100ns;
  endfunction

  protected virtual task force_quiet(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("pgflt_twu_grant",   uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("acc_err_twu_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("refill_arb_twu_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("cp0_mmu_maee",      uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("twu_l2tlb_ref_pgflt",   uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("twu_l2tlb_ref_acc_err", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("twu_arb_ref_req",       uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("twu_refill_vld",        uvm_hdl_data_t'(1'b0), ctx);
  endtask

  protected virtual task release_quiet(input string ctx);
    phase12_twu_release_value("twu_refill_vld", ctx);
    phase12_twu_release_value("twu_arb_ref_req", ctx);
    phase12_twu_release_value("twu_l2tlb_ref_acc_err", ctx);
    phase12_twu_release_value("twu_l2tlb_ref_pgflt", ctx);
    phase12_twu_release_value("cp0_mmu_maee", ctx);
    phase12_twu_release_value("refill_arb_twu_grant", ctx);
    phase12_twu_release_value("acc_err_twu_grant", ctx);
    phase12_twu_release_value("pgflt_twu_grant", ctx);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
  endtask

  protected virtual task clear_pgflt_sources(input string ctx);
    phase12_twu_force_value("fst_chk_vld",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_chk_vld",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_chk_vld",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("fst_chk_page_flt", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_chk_page_flt", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_chk_page_flt", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("fst_chk_type",     uvm_hdl_data_t'(3'b010), ctx);
    phase12_twu_force_value("scd_chk_type",     uvm_hdl_data_t'(3'b010), ctx);
    phase12_twu_force_value("thd_chk_type",     uvm_hdl_data_t'(3'b010), ctx);
    phase12_twu_force_value("fst_chk_id",       uvm_hdl_data_t'(7'h11), ctx);
    phase12_twu_force_value("scd_chk_id",       uvm_hdl_data_t'(7'h12), ctx);
    phase12_twu_force_value("thd_chk_id",       uvm_hdl_data_t'(7'h13), ctx);
    phase12_twu_force_value("fst_chk_vpn",      uvm_hdl_data_t'(27'h3456789), ctx);
    phase12_twu_force_value("scd_chk_vpn",      uvm_hdl_data_t'(27'h2345678), ctx);
    phase12_twu_force_value("thd_chk_vpn",      uvm_hdl_data_t'(27'h1234567), ctx);
    phase12_twu_force_value("fst_chk_data",     uvm_hdl_data_t'(64'h0), ctx);
    phase12_twu_force_value("scd_chk_data",     uvm_hdl_data_t'(64'h0), ctx);
    phase12_twu_force_value("thd_chk_data",     uvm_hdl_data_t'(64'h0), ctx);
  endtask

  protected virtual task release_pgflt_sources(input string ctx);
    phase12_twu_release_value("thd_chk_data", ctx);
    phase12_twu_release_value("scd_chk_data", ctx);
    phase12_twu_release_value("fst_chk_data", ctx);
    phase12_twu_release_value("thd_chk_vpn", ctx);
    phase12_twu_release_value("scd_chk_vpn", ctx);
    phase12_twu_release_value("fst_chk_vpn", ctx);
    phase12_twu_release_value("thd_chk_id", ctx);
    phase12_twu_release_value("scd_chk_id", ctx);
    phase12_twu_release_value("fst_chk_id", ctx);
    phase12_twu_release_value("thd_chk_type", ctx);
    phase12_twu_release_value("scd_chk_type", ctx);
    phase12_twu_release_value("fst_chk_type", ctx);
    phase12_twu_release_value("thd_chk_page_flt", ctx);
    phase12_twu_release_value("scd_chk_page_flt", ctx);
    phase12_twu_release_value("fst_chk_page_flt", ctx);
    phase12_twu_release_value("thd_chk_vld", ctx);
    phase12_twu_release_value("scd_chk_vld", ctx);
    phase12_twu_release_value("fst_chk_vld", ctx);
  endtask

  protected virtual task cover_pgflt_priority(input string ctx);
    clear_pgflt_sources(ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("twu_pgflt_vld",    uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("pgflt_twu_grant",  uvm_hdl_data_t'(1'b0), ctx);

    phase12_twu_force_value("thd_chk_vld",      uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("thd_chk_page_flt", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_force_value("thd_chk_vld",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_chk_page_flt", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_chk_vld",      uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_chk_page_flt", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_force_value("scd_chk_vld",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_chk_page_flt", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("fst_chk_vld",      uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("fst_chk_page_flt", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_force_value("twu_pgflt_vld",    uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_chk_vld",      uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("thd_chk_page_flt", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_chk_vld",      uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_chk_page_flt", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_force_value("fst_chk_vld",      uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("fst_chk_page_flt", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_release_value("twu_pgflt_vld", ctx);
    release_pgflt_sources(ctx);
    phase12_twu_force_value("pgflt_twu_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task clear_accerr_sources(input string ctx);
    phase12_twu_force_value("fst_pmp_vld",   uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_pmp_vld",   uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_pmp_vld",   uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("fst_pmp_deny",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_pmp_deny",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_pmp_deny",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("fst_pmp_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_pmp_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_pmp_grant", uvm_hdl_data_t'(1'b0), ctx);
  endtask

  protected virtual task release_accerr_sources(input string ctx);
    phase12_twu_release_value("thd_pmp_grant", ctx);
    phase12_twu_release_value("scd_pmp_grant", ctx);
    phase12_twu_release_value("fst_pmp_grant", ctx);
    phase12_twu_release_value("thd_pmp_deny", ctx);
    phase12_twu_release_value("scd_pmp_deny", ctx);
    phase12_twu_release_value("fst_pmp_deny", ctx);
    phase12_twu_release_value("thd_pmp_vld", ctx);
    phase12_twu_release_value("scd_pmp_vld", ctx);
    phase12_twu_release_value("fst_pmp_vld", ctx);
  endtask

  protected virtual task cover_accerr_priority(input string ctx);
    clear_accerr_sources(ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("twu_acc_err_vld",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("acc_err_twu_grant", uvm_hdl_data_t'(1'b0), ctx);

    phase12_twu_force_value("thd_pmp_vld",   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("thd_pmp_deny",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("thd_pmp_grant", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_force_value("thd_pmp_vld",   uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_pmp_deny",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_pmp_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_pmp_vld",   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_pmp_deny",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_pmp_grant", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_force_value("scd_pmp_vld",   uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_pmp_deny",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_pmp_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("fst_pmp_vld",   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("fst_pmp_deny",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("fst_pmp_grant", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_force_value("twu_acc_err_vld", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_pmp_vld",     uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("thd_pmp_deny",    uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("thd_pmp_grant",   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_pmp_vld",     uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_pmp_deny",    uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_pmp_grant",   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_force_value("fst_pmp_vld",   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("fst_pmp_deny",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("fst_pmp_grant", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_release_value("twu_acc_err_vld", ctx);
    release_accerr_sources(ctx);
    phase12_twu_force_value("acc_err_twu_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task cover_accerr_assign_terms(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    clear_accerr_sources(ctx);
    phase12_twu_force_value("twu_acc_err_vld",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("acc_err_twu_grant", uvm_hdl_data_t'(1'b0), ctx);

    phase12_twu_force_value("thd_pmp_vld",   uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_pmp_deny",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("thd_pmp_grant", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("thd_pmp_vld",   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("thd_pmp_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("thd_pmp_grant", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("scd_pmp_vld",   uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_pmp_deny",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_pmp_grant", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("scd_pmp_vld",   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_pmp_grant", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("scd_pmp_grant", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("twu_acc_err_vld",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_release_value("twu_acc_err_vld", ctx);
    phase12_twu_force_value("acc_err_twu_grant", uvm_hdl_data_t'(1'b0), ctx);
    release_accerr_sources(ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task cover_csr_terms(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("fst_chk_csr_req",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_chk_csr_req",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("fst_chk_fetch_type", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_chk_fetch_type", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_release_value("scd_chk_fetch_type", ctx);
    phase12_twu_release_value("fst_chk_fetch_type", ctx);
    phase12_twu_release_value("scd_chk_csr_req", ctx);
    phase12_twu_release_value("fst_chk_csr_req", ctx);

    phase12_twu_force_value("ptw_cur_st", uvm_hdl_data_t'(3'b000), ctx);
    phase12_twu_force_value("csr_req",    uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("csr_grant",  uvm_hdl_data_t'(2'b10), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_force_value("csr_grant",  uvm_hdl_data_t'(2'b01), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_force_value("csr_req",    uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("csr_grant",  uvm_hdl_data_t'(2'b00), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_release_value("csr_grant", ctx);
    phase12_twu_release_value("csr_req", ctx);
    phase12_twu_release_value("ptw_cur_st", ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
  endtask

  protected virtual task cover_cross_refill_terms(input string ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("ptw_cur_st",      uvm_hdl_data_t'(3'b000), ctx);
    phase12_twu_force_value("twu_csr_cross",   uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(3);
    phase12_twu_release_value("twu_csr_cross", ctx);
    phase12_twu_release_value("ptw_cur_st", ctx);

    phase12_twu_force_value("fst_chk_refill_req",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("fst_chk_fetch_type",  uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("scd_chk_refill_req",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_chk_refill_req",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("csr_refill_req",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_release_value("csr_refill_req", ctx);
    phase12_twu_release_value("thd_chk_refill_req", ctx);
    phase12_twu_release_value("scd_chk_refill_req", ctx);
    phase12_twu_release_value("fst_chk_fetch_type", ctx);
    phase12_twu_release_value("fst_chk_refill_req", ctx);

    phase12_twu_force_value("refill_itlb_sel",    uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("csr_refill_req",     uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_chk_refill_req", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_chk_refill_req", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("fst_chk_refill_req", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("refill_itlb_sel",    uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("csr_refill_req",     uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("thd_chk_refill_req", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_chk_refill_req", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("csr_refill_req",     uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("thd_chk_refill_req", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("thd_chk_refill_req", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_chk_refill_req", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(2);

    phase12_twu_force_value("refill_grant",     uvm_hdl_data_t'(4'b0010), ctx);
    phase12_twu_force_value("twu_refill_idle",  uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(3);
    phase12_twu_force_value("refill_grant",     uvm_hdl_data_t'(4'b0100), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_release_value("twu_refill_idle", ctx);
    phase12_twu_release_value("refill_grant", ctx);
    phase12_twu_release_value("fst_chk_refill_req", ctx);
    phase12_twu_release_value("scd_chk_refill_req", ctx);
    phase12_twu_release_value("thd_chk_refill_req", ctx);
    phase12_twu_release_value("csr_refill_req", ctx);
    phase12_twu_release_value("refill_itlb_sel", ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
  endtask

  virtual task run_test_body();
    string ctx;
    setup_plan();
    #100ns;
    ctx = "twu_condition_arb_cov";
    force_quiet(ctx);

    cover_pgflt_priority({ctx, "_pgflt"});
    cover_accerr_assign_terms({ctx, "_accerr_assign"});
    cover_csr_terms({ctx, "_csr"});
    cover_cross_refill_terms({ctx, "_refill"});

    release_quiet(ctx);
    #(m_post_drain);
  endtask
endclass

`endif
