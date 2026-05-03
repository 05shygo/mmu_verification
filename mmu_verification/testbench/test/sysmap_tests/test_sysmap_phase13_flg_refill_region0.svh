`ifndef TEST_SYSMAP_PHASE13_FLG_REFILL_REGION0_SVH
`define TEST_SYSMAP_PHASE13_FLG_REFILL_REGION0_SVH

class test_sysmap_phase13_flg_refill_region0 extends phase12_generated_test_base;
  `uvm_component_utils(test_sysmap_phase13_flg_refill_region0)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "sysmap_phase13"; p12_trace_id = "TC-SYSMAP-FLG-REFILL-REGION0-001";
    p12_fid = "F6.NEW.2"; p12_priority = "P0";
    p12_seq_desc = "MAEE0 CSR refill carries SysMap region0 flag";
    p12_checker = "sva_csr_refill_flg_matches_sysmap + cg_sysmap_flg_per_region";
    p12_reviewer = "A+B";
    num_txn = 96; m_post_drain = 900ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    start_cp0_seq_by_name("cp0_maee_disable_seq");
    phase12_set_pmp_allow_all();
    phase12_map_4k_window(39'h0_0010_0000, 16, 40'h0_0010_0000);
    repeat (4) begin
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_0010_0000, 16, 48, LSU_PIPE0, 1'b0, 1'b1);
    end
    #(m_post_drain);
  endtask
endclass

`endif
