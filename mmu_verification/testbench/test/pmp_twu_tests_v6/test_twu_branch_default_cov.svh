`ifndef TEST_TWU_BRANCH_DEFAULT_COV_SVH
`define TEST_TWU_BRANCH_DEFAULT_COV_SVH

class test_twu_branch_default_cov extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_branch_default_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 1_000_000;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu_code_cov";
    p12_trace_id = "TC-TWU-BRANCH-DEFAULT-COV-001";
    p12_fid      = "PTW-CODE-TWU-BRANCH";
    p12_priority = "P0";
    p12_seq_desc = "whitebox TWU branch default coverage";
    p12_checker  = "twu branch coverage: pmp clear else and FSM default";
    p12_reviewer = "A+B";
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init          = 1'b0;
    m_post_drain             = 100ns;
  endfunction

  protected virtual task cover_pmp_clear_else(input string stage, input string vld_sig);
    string ctx;
    ctx = {"twu_branch_clear_else_", stage};

    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("xbar_twu_req",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("mbuf_twu_data_vld", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("fst_chk_vld",       uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("scd_chk_vld",       uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("pmp_grant",         uvm_hdl_data_t'(3'b000), ctx);
    phase12_twu_deposit_value(vld_sig,           uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(3);

    phase12_twu_release_value("pmp_grant", ctx);
    phase12_twu_release_value("scd_chk_vld", ctx);
    phase12_twu_release_value("fst_chk_vld", ctx);
    phase12_twu_release_value("mbuf_twu_data_vld", ctx);
    phase12_twu_release_value("xbar_twu_req", ctx);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
    phase12_twu_wait_cycles(2);
  endtask

  protected virtual task cover_fsm_default_branch();
    string ctx;
    ctx = "twu_branch_fsm_default";

    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_deposit_value("ptw_cur_st",      uvm_hdl_data_t'(3'b111), ctx);
    phase12_twu_wait_cycles(2);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
    phase12_twu_wait_cycles(2);
  endtask

  virtual task run_test_body();
    setup_plan();
    #100ns;
    cover_pmp_clear_else("fst", "fst_pmp_vld");
    cover_pmp_clear_else("scd", "scd_pmp_vld");
    cover_pmp_clear_else("thd", "thd_pmp_vld");
    cover_fsm_default_branch();
    #(m_post_drain);
  endtask
endclass

`endif
