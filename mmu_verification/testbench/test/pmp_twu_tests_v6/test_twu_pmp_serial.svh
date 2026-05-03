`ifndef TEST_TWU_PMP_SERIAL_SVH
`define TEST_TWU_PMP_SERIAL_SVH

class test_twu_pmp_serial extends phase12_generated_test_base;
  `uvm_component_utils(test_twu_pmp_serial)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "pmp_twu";
    p12_trace_id = "TC-TWU-PMP-SERIAL-001";
    p12_fid      = "F4.NEW.13";
    p12_priority = "P0";
    p12_seq_desc = "allow-all PMP + mixed IFU/LSU cold PTW walks";
    p12_checker  = "sva_pmp_check_before_lsu_req + cg_pmp_per_level_result";
    p12_reviewer = "A+B";
    num_txn      = 160;
    m_post_drain = 900ns;
  endfunction

  virtual task run_test_body();
    setup_plan();
    if (m_run_misc_init) start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup) do_sv39_4k_bringup();
    phase12_set_pmp_allow_all();
    phase12_map_hugepage_fixture();
    repeat (3) begin
      phase12_cp0_tlb_allinv();
      fork
        phase12_drive_ifu_rr(39'h0_4000_0000, 1, 16, 1'b1);
        phase12_drive_lsu_rr(39'h0_2200_0000, 1, 16, LSU_PIPE0, 1'b0, 1'b1);
        phase12_drive_lsu_rr(39'h0_3000_1000, 2, 24, LSU_PIPE1, 1'b1, 1'b1);
      join
    end
    #(m_post_drain);
  endtask
endclass

`endif
