`ifndef TEST_TWU_FSM_ABORT_COV_SVH
`define TEST_TWU_FSM_ABORT_COV_SVH

class test_twu_fsm_abort_cov extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_fsm_abort_cov)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    num_txn    = 1;
    timeout_ns = 1_000_000;
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu_code_cov";
    p12_trace_id = "TC-TWU-FSM-ABORT-COV-001";
    p12_fid      = "PTW-CODE-TWU-FSM";
    p12_priority = "P0";
    p12_seq_desc = "whitebox TWU 1G/2M crossing states abort to IDLE";
    p12_checker  = "twu FSM coverage: TWU_1G_CRS/TWU_2M_CRS -> TWU_IDLE";
    p12_reviewer = "A+B";
    m_enable_sv39_4k_bringup = 1'b0;
    m_run_misc_init          = 1'b0;
    m_post_drain             = 100ns;
  endfunction

  protected virtual task cover_abort_to_idle(
    input string      arc_name,
    input logic [2:0] state_value
  );
    string ctx;
    ctx = {"twu_fsm_abort_", arc_name};

    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_deposit_value("ptw_cur_st",      uvm_hdl_data_t'(state_value), ctx);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b1), ctx);
    phase12_twu_wait_cycles(4);
    phase12_twu_force_value("tlboper_ptw_abort", uvm_hdl_data_t'(1'b0), ctx);
    phase12_twu_release_value("tlboper_ptw_abort", ctx);
    phase12_twu_wait_cycles(2);
  endtask

  virtual task run_test_body();
    setup_plan();
    #100ns;
    cover_abort_to_idle("1g_crs", 3'b001);
    cover_abort_to_idle("2m_crs", 3'b010);
    #(m_post_drain);
  endtask
endclass

`endif
