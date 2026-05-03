`ifndef TEST_PTW_PMP_DENY_ACCFLT_SVH
`define TEST_PTW_PMP_DENY_ACCFLT_SVH

class test_ptw_pmp_deny_accflt extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_deny_accflt)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-PTW-PMP-DENY-ACCFLT-001";
    p12_fid = "F7.NEW.5"; p12_priority = "P0";
    p12_seq_desc = "PMP deny converted to PTW access fault";
    p12_checker = "sva_pmp_deny_acc_fault + cg_pmp_deny_by_level";
    p12_reviewer = "A+B";
    num_txn = 128; m_post_drain = 1000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_map_four_twu_pressure_window(39'h0_A400_0000, 64, 40'h0_A000_0000);
    phase12_cp0_tlb_allinv();
    phase12_set_pmp_deny_ptw_reads(4'b1111);
    phase12_drive_lsu_rr(39'h0_A600_0000, 64, 128, LSU_PIPE0, 1'b0, 1'b1);
    phase12_set_pmp_allow_all();
    #(m_post_drain);
  endtask
endclass

`endif
