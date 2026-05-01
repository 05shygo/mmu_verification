`ifndef TEST_PTW_PMP_PORT_MAP_CONCURRENT_SVH
`define TEST_PTW_PMP_PORT_MAP_CONCURRENT_SVH

class test_ptw_pmp_port_map_concurrent extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_port_map_concurrent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-PTW-PMP-PORT-MAP-CONCURRENT-001";
    p12_fid = "F7.NEW.9";
    p12_priority = "P0";
    p12_seq_desc = "pa3/5/6/7 mapped to twu_one/two/three/four under concurrency";
    p12_checker = "cg_ptw_pmp_port_map + DA-003 mapping";
    p12_reviewer = "A+B";
    num_txn = 256; m_post_drain = 1200ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_set_pmp_allow_all();
    phase12_concurrent_four_twus_slow_miss_pressure(
      39'h0_D800_0000, 128, 224, 2, 40'h0_D000_0000);
    #(m_post_drain);
  endtask
endclass

`endif
