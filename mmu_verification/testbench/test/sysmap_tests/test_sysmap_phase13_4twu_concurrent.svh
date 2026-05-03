`ifndef TEST_SYSMAP_PHASE13_4TWU_CONCURRENT_SVH
`define TEST_SYSMAP_PHASE13_4TWU_CONCURRENT_SVH

class test_sysmap_phase13_4twu_concurrent extends phase12_generated_test_base;
  `uvm_component_utils(test_sysmap_phase13_4twu_concurrent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "sysmap_phase13"; p12_trace_id = "TC-SYSMAP-4TWU-CONCURRENT-001";
    p12_fid = "F6.NEW.6"; p12_priority = "P0";
    p12_seq_desc = "four TWUs issue SysMap CSR probes concurrently";
    p12_checker = "cg_sysmap_4twu_concurrent + cg_sysmap_flg_per_region";
    p12_reviewer = "A+B";
    num_txn = 256; m_post_drain = 1200ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    start_cp0_seq_by_name("cp0_maee_disable_seq");
    phase12_set_pmp_allow_all();
    phase12_concurrent_four_twus_slow_miss_pressure(
      39'h0_E800_0000, 128, 224, 2, 40'h0_E000_0000);
    #(m_post_drain);
  endtask
endclass

`endif
