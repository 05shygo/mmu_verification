`ifndef TEST_SYSMAP_PHASE13_CROSS_2M_DEGRADE_SVH
`define TEST_SYSMAP_PHASE13_CROSS_2M_DEGRADE_SVH

class test_sysmap_phase13_cross_2m_degrade extends phase12_generated_test_base;
  `uvm_component_utils(test_sysmap_phase13_cross_2m_degrade)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "sysmap_phase13"; p12_trace_id = "TC-SYSMAP-CROSS-2M-DEGRADE-001";
    p12_fid = "F6.NEW.3/F6.NEW.4"; p12_priority = "P0";
    p12_seq_desc = "2M SysMap boundary cross degrades CSR refill to 4K";
    p12_checker = "sva_sysmap_cross_degrade_2m + cg_sysmap_cross_2m";
    p12_reviewer = "A+B";
    num_txn = 96; m_post_drain = 1000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    start_cp0_seq_by_name("cp0_maee_disable_seq");
    phase12_set_pmp_allow_all();
    phase12_map_hugepage_fixture();
    repeat (6) begin
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_1200_0000, 1, 16, LSU_PIPE0, 1'b0, 1'b1);
      phase12_drive_lsu_rr(39'h0_1200_1000, 1, 16, LSU_PIPE1, 1'b1, 1'b1);
    end
    #(m_post_drain);
  endtask
endclass

`endif
