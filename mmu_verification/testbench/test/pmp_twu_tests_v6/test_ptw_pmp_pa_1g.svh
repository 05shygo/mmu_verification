`ifndef TEST_PTW_PMP_PA_1G_SVH
`define TEST_PTW_PMP_PA_1G_SVH

class test_ptw_pmp_pa_1g extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_pa_1g)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-PTW-PMP-PA-1G-001";
    p12_fid = "F7.NEW.4"; p12_priority = "P0";
    p12_seq_desc = "1G leaf PTW PMP PA alignment";
    p12_checker = "cg_pmp_pa_format"; p12_reviewer = "A+B";
    num_txn = 64; m_post_drain = 800ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_set_pmp_allow_all();
    phase12_map_hugepage_fixture();
    repeat (5) begin
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_4000_0000, 1, 8, LSU_PIPE0, 1'b0, 1'b1);
    end
    #(m_post_drain);
  endtask
endclass

`endif
