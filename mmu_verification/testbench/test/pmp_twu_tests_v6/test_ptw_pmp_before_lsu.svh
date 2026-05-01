`ifndef TEST_PTW_PMP_BEFORE_LSU_SVH
`define TEST_PTW_PMP_BEFORE_LSU_SVH

class test_ptw_pmp_before_lsu extends phase12_generated_test_base;
  `uvm_component_utils(test_ptw_pmp_before_lsu)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu";
    p12_trace_id = "TC-PTW-PMP-BEFORE-LSU-001";
    p12_fid      = "F4.NEW.13";
    p12_priority = "P0";
    p12_seq_desc = "PMP allow before PTW memory request";
    p12_checker  = "sva_pmp_check_before_lsu_req";
    p12_reviewer = "A+B";
    num_txn      = 128;
    m_post_drain = 900ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_set_pmp_allow_all();
    phase12_config_ptw_responder(12, 36, 0);
    phase12_map_hugepage_fixture();
    repeat (4) begin
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_2200_0000, 1, 24, LSU_PIPE0, 1'b0, 1'b1);
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_3000_1000, 2, 32, LSU_PIPE1, 1'b1, 1'b1);
    end
    phase12_config_ptw_responder(1, 4, 0);
    #(m_post_drain);
  endtask
endclass

`endif
