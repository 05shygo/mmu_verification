`ifndef TEST_SYSMAP_PHASE13_DEFAULT_FLAG_SVH
`define TEST_SYSMAP_PHASE13_DEFAULT_FLAG_SVH

class test_sysmap_phase13_default_flag extends phase12_generated_test_base;
  `uvm_component_utils(test_sysmap_phase13_default_flag)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "sysmap_phase13"; p12_trace_id = "TC-SYSMAP-NO-HIT-DEFAULT-FLAG-001";
    p12_fid = "F6.NEW.7"; p12_priority = "P0";
    p12_seq_desc = "SysMap no-hit default flag 5'b10011 propagation";
    p12_checker = "cg_sysmap_default_flag";
    p12_reviewer = "A+B";
    num_txn = 96; m_post_drain = 1000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    start_cp0_seq_by_name("cp0_maee_disable_seq");
    phase12_set_pmp_allow_all();
    phase12_map_4k_window(39'h0_F400_0000, 16, 40'hF1_0000_0000);
    repeat (4) begin
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_F400_0000, 16, 48, LSU_PIPE0, 1'b0, 1'b1);
    end
    #(m_post_drain);
  endtask
endclass

`endif
