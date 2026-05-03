`ifndef TEST_SYSMAP_PHASE13_PA_ALIGN_1G_SVH
`define TEST_SYSMAP_PHASE13_PA_ALIGN_1G_SVH

class test_sysmap_phase13_pa_align_1g extends phase12_generated_test_base;
  `uvm_component_utils(test_sysmap_phase13_pa_align_1g)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "sysmap_phase13"; p12_trace_id = "TC-SYSMAP-PA-ALIGN-1G-001";
    p12_fid = "F6.NEW.5"; p12_priority = "P0";
    p12_seq_desc = "SysMap PA aligns on 1G CSR probe";
    p12_checker = "sva_sysmap_pa_align + cg_sysmap_pa_align";
    p12_reviewer = "A+B";
    num_txn = 64; m_post_drain = 900ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    start_cp0_seq_by_name("cp0_maee_disable_seq");
    phase12_set_pmp_allow_all();
    phase12_map_hugepage_fixture();
    repeat (5) begin
      phase12_cp0_tlb_allinv();
      phase12_drive_ifu_rr(39'h0_4000_0000, 1, 10, 1'b1);
    end
    #(m_post_drain);
  endtask
endclass

`endif
