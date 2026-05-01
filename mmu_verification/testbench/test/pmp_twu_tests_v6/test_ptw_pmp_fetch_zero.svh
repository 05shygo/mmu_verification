`ifndef TEST_PTW_PMP_FETCH_ZERO_SVH
`define TEST_PTW_PMP_FETCH_ZERO_SVH

class test_ptw_pmp_fetch_zero extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_fetch_zero)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-PTW-PMP-FETCH-ZERO-001";
    p12_fid = "F7.NEW.7";
    p12_priority = "P0";
    p12_seq_desc = "PTW PMP port fetch output remains zero";
    p12_checker = "sva_ptw_pmp_fetch_zero + cg_ptw_pmp_port_map";
    p12_reviewer = "A+B";
    num_txn = 128; m_post_drain = 900ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_set_pmp_allow_all();
    phase12_map_four_twu_pressure_window(39'h0_C800_0000, 96, 40'h0_C000_0000);
    phase12_cp0_tlb_allinv();
    fork
      phase12_drive_ifu_rr(39'h0_C800_0000, 96, 96, 1'b1);
      phase12_drive_lsu_rr(39'h0_CA00_0000, 96, 96, LSU_PIPE0, 1'b0, 1'b1);
      phase12_drive_lsu_rr(39'h0_CC00_0000, 96, 96, LSU_PIPE1, 1'b1, 1'b1);
    join
    #(m_post_drain);
  endtask
endclass

`endif
