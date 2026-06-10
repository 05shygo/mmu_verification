`ifndef TEST_MMU_TWU_FOUR_LANE_SLOW_MISS_PRESSURE_SVH
`define TEST_MMU_TWU_FOUR_LANE_SLOW_MISS_PRESSURE_SVH

class test_mmu_twu_four_lane_slow_miss_pressure extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_four_lane_slow_miss_pressure)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "ptw_twu_closure";
    p12_trace_id = "TC-TWU-FOUR-LANE-SLOW-MISS-PRESSURE-001";
    p12_fid      = "F4.COV.1";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "IFU plus LSU0/1/2 cold-miss pressure with slow PTW responses";
    p12_checker  = "translation_sb,credit_sb,ptw_mem_monitor,whitebox_cg,twu_sva";
    p12_reviewer = "A+B";
    num_txn      = 320;
    m_post_drain = 3000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_concurrent_four_twus_slow_miss_pressure(
      39'h0_A000_0000,
      160,
      320,
      3,
      40'h0_1000_0000);

    phase12_pulse_ptw_ready_for_cov(3);
    phase12_wait_for_quiescent("twu_four_lane_slow_miss_pressure_done", 524288, 32);
    #(m_post_drain);
  endtask

endclass : test_mmu_twu_four_lane_slow_miss_pressure

`endif // TEST_MMU_TWU_FOUR_LANE_SLOW_MISS_PRESSURE_SVH
