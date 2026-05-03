`ifndef TEST_TWU_PMP_GRANT_ONEHOT_SVH
`define TEST_TWU_PMP_GRANT_ONEHOT_SVH

class test_twu_pmp_grant_onehot extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_pmp_grant_onehot)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu";
    p12_trace_id = "TC-TWU-PMP-GRANT-ONEHOT-001";
    p12_fid      = "F4.NEW.14";
    p12_priority = "P0";
    p12_seq_desc = "concurrent FST/SCD/THD PMP stages";
    p12_checker  = "sva_pmp_grant_onehot + cg_pmp_grant_level";
    p12_reviewer = "A+B";
    num_txn      = 192;
    m_post_drain = 1000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_set_pmp_allow_all();
    phase12_config_ptw_responder(24, 72, 0);
    phase12_map_four_twu_pressure_window(39'h0_D000_0000, 128, 40'h0_7000_0000);
    phase12_cp0_tlb_allinv();
    fork
      phase12_drive_ifu_rr(39'h0_D000_0000, 128, 160, 1'b1);
      phase12_drive_lsu_rr(39'h0_D200_0000, 128, 160, LSU_PIPE0, 1'b0, 1'b1);
      phase12_drive_lsu_rr(39'h0_D400_0000, 128, 160, LSU_PIPE1, 1'b1, 1'b1);
      phase12_drive_lsu_rr(39'h0_D600_0000, 128, 160, LSU_PIPE2, 1'b0, 1'b1);
    join
    phase12_config_ptw_responder(1, 4, 0);
    #(m_post_drain);
  endtask
endclass

`endif
