`ifndef TEST_PTW_PMP_PA_ZERO_SVH
`define TEST_PTW_PMP_PA_ZERO_SVH

class test_ptw_pmp_pa_zero extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_pa_zero)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-PTW-PMP-PA-ZERO-001";
    p12_fid = "F7.NEW.4"; p12_priority = "P1";
    p12_seq_desc = "idle PMP grant zeroes PTW PMP PA output";
    p12_checker = "cg_pmp_pa_format idle samples"; p12_reviewer = "A+B";
    num_txn = 32; m_post_drain = 900ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_set_pmp_allow_all();
    #600ns;
    phase12_map_4k_window(39'h0_E100_0000, 8, 40'h0_8100_0000);
    phase12_cp0_tlb_allinv();
    phase12_drive_lsu_rr(39'h0_E100_0000, 8, 16, LSU_PIPE0, 1'b0, 1'b1);
    #600ns;
    #(m_post_drain);
  endtask
endclass

`endif
