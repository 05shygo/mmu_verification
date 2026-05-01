`ifndef TEST_TWU_MASK_PMP_WAIT_ALL4_SVH
`define TEST_TWU_MASK_PMP_WAIT_ALL4_SVH

class test_twu_mask_pmp_wait_all4 extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_mask_pmp_wait_all4)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-TWU-MASK-PMP-WAIT-ALL4-001";
    p12_fid = "F7.NEW.6"; p12_priority = "P0";
    p12_seq_desc = "all four TWUs masked by PMP wait/deny pressure";
    p12_checker = "cg_twu_mask_cause + cg_sysmap_4twu_concurrent";
    p12_reviewer = "A+B";
    num_txn = 256; m_post_drain = 1400ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_map_four_twu_pressure_window(39'h0_B800_0000, 128, 40'h0_B800_0000);
    phase12_concurrent_four_twus_under_full_pmp_deny(39'h0_B800_0000, 128, 224);
    #(m_post_drain);
  endtask
endclass

`endif
