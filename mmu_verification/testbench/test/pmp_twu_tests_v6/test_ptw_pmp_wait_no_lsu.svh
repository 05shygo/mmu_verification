`ifndef TEST_PTW_PMP_WAIT_NO_LSU_SVH
`define TEST_PTW_PMP_WAIT_NO_LSU_SVH

class test_ptw_pmp_wait_no_lsu extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_wait_no_lsu)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-PTW-PMP-WAIT-NO-LSU-001";
    p12_fid = "F7.NEW.6"; p12_priority = "P0";
    p12_seq_desc = "PMP wait blocks PTW memory launch";
    p12_checker = "sva_no_lsu_req_during_pmp_wait"; p12_reviewer = "A+B";
    num_txn = 160; m_post_drain = 1000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_map_four_twu_pressure_window(39'h0_F000_0000, 80, 40'h0_9000_0000);
    phase12_config_ptw_responder(64, 128, 0);
    phase12_concurrent_four_twus_under_full_pmp_deny(39'h0_F000_0000, 80, 128);
    phase12_config_ptw_responder(1, 4, 0);
    #(m_post_drain);
  endtask
endclass

`endif
