`ifndef TEST_TWU_PMP_WAIT_LINE_COV_SVH
`define TEST_TWU_PMP_WAIT_LINE_COV_SVH

class test_twu_pmp_wait_line_cov extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_pmp_wait_line_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 1_000_000;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu_code_cov";
    p12_trace_id = "TC-TWU-PMP-WAIT-LINE-COV-001";
    p12_fid      = "PTW-CODE-TWU-LINE";
    p12_priority = "P0";
    p12_seq_desc = "whitebox PMP wait hold on FST/SCD/THD stages";
    p12_checker  = "twu line coverage: fst/scd/thd_pmp_vld wait hold";
    p12_reviewer = "A+B";
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init          = 1'b0;
    m_post_drain             = 100ns;
  endfunction

  protected virtual task release_common_forces(input string ctx);
    phase12_twu_release_value("pmp_grant", ctx);
    phase12_twu_release_value("pmp_mmu_flg", ctx);
    phase12_twu_release_value("mbuf_grant", ctx);
    phase12_twu_release_value("xbar_twu_req", ctx);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
  endtask

  protected virtual task cover_pmp_wait_hold(
    input string stage,
    input string vld_sig,
    input string type_sig
  );
    string ctx;
    ctx = {"twu_pmp_wait_line_cov_", stage};

    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("xbar_twu_req",      uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_force_value("mbuf_grant",        uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_force_value("pmp_mmu_flg",       uvm_hdl_data_t'(4'h7), ctx);
    phase12_twu_force_value("pmp_grant",         uvm_hdl_data_t'(3'b000), ctx);
    phase12_twu_deposit_value(type_sig,          uvm_hdl_data_t'(3'b010), ctx);
    phase12_twu_deposit_value(vld_sig,           uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(4);

    phase12_twu_deposit_value(vld_sig, uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_wait_cycles(2);
    release_common_forces(ctx);
    phase12_twu_wait_cycles(2);
  endtask

  virtual task run_test_body();
    setup_plan();
    #100ns;
    phase12_set_pmp_allow_all();
    cover_pmp_wait_hold("fst", "fst_pmp_vld", "fst_pmp_type");
    cover_pmp_wait_hold("scd", "scd_pmp_vld", "scd_pmp_type");
    cover_pmp_wait_hold("thd", "thd_pmp_vld", "thd_pmp_type");
    #(m_post_drain);
  endtask
endclass

`endif
