`ifndef TEST_PTW_PMP_PA_4K_SVH
`define TEST_PTW_PMP_PA_4K_SVH

class test_ptw_pmp_pa_4k extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_pa_4k)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket = "pmp_twu"; p12_trace_id = "TC-PTW-PMP-PA-4K-001";
    p12_fid = "F7.NEW.4"; p12_priority = "P0";
    p12_seq_desc = "4K leaf PTW PMP PA alignment";
    p12_checker = "cg_pmp_pa_format"; p12_reviewer = "A+B";
    num_txn = 96; m_post_drain = 800ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_set_pmp_allow_all();
    phase12_map_4k_window(39'h0_E000_0000, 32, 40'h0_8000_0000);
    repeat (4) begin
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_E000_0000, 32, 64, LSU_PIPE1, 1'b1, 1'b1);
    end
    #(m_post_drain);
  endtask
endclass

`endif
