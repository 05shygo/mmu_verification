`ifndef TEST_PTW_PMP_DENY_NO_REFILL_SVH
`define TEST_PTW_PMP_DENY_NO_REFILL_SVH

class test_ptw_pmp_deny_no_refill extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_deny_no_refill)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-PTW-PMP-DENY-NO-REFILL-001";
    p12_fid = "F7.NEW.5"; p12_priority = "P0";
    p12_seq_desc = "PMP deny must not generate same-transaction refill";
    p12_checker = "sva_pmp_deny_no_refill";
    p12_reviewer = "A+B";
    num_txn = 128; m_post_drain = 1000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_map_four_twu_pressure_window(39'h0_A800_0000, 64, 40'h0_A800_0000);
    phase12_cp0_tlb_allinv();
    phase12_set_pmp_deny_ptw_reads(4'b0101);
    fork
      phase12_drive_ifu_rr(39'h0_A800_0000, 64, 96, 1'b1);
      phase12_drive_lsu_rr(39'h0_AC00_0000, 64, 96, LSU_PIPE1, 1'b1, 1'b1);
    join
    phase12_set_pmp_allow_all();
    #(m_post_drain);
  endtask
endclass

`endif
