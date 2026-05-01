`ifndef TEST_PTW_PMP_MMODE_L0_SVH
`define TEST_PTW_PMP_MMODE_L0_SVH

class test_ptw_pmp_mmode_l0 extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_mmode_l0)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-PTW-PMP-MMODE-L0-001";
    p12_fid = "F7.NEW.5"; p12_priority = "P1";
    p12_seq_desc = "M-mode L=0 bypass samples with PTW PMP traffic";
    p12_checker = "cg_pmp_deny_by_level mode coverage proxy";
    p12_reviewer = "A+B";
    num_txn = 96; m_post_drain = 900ns;
    m_cp0_seq_names.push_back("cp0_priv_switch_seq");
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    start_cp0_seq_by_name("cp0_priv_switch_seq");
    phase12_set_pmp_deny_ptw_reads(4'b1111);
    phase12_map_4k_window(39'h0_E200_0000, 32, 40'h0_B000_0000);
    phase12_cp0_tlb_allinv();
    phase12_drive_lsu_rr(39'h0_E200_0000, 32, 96, LSU_PIPE0, 1'b0, 1'b1);
    phase12_set_pmp_allow_all();
    #(m_post_drain);
  endtask
endclass

`endif
