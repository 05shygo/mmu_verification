`ifndef TEST_TWU_PMP_WAIT_STALL_SVH
`define TEST_TWU_PMP_WAIT_STALL_SVH

class test_twu_pmp_wait_stall extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_pmp_wait_stall)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu";
    p12_trace_id = "TC-TWU-PMP-WAIT-STALL-001";
    p12_fid      = "F7.NEW.6";
    p12_priority = "P0";
    p12_seq_desc = "four cold TWU streams under PTW-read PMP deny";
    p12_checker  = "sva_pmp_wait_implies_mask + cg_twu_mask_cause";
    p12_reviewer = "A+B";
    num_txn      = 192;
    m_post_drain = 1200ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_map_four_twu_pressure_window(39'h0_B000_0000, 96, 40'h0_5000_0000);
    phase12_concurrent_four_twus_under_full_pmp_deny(39'h0_B000_0000, 96, 160);
    #(m_post_drain);
  endtask
endclass

`endif
