// =============================================================================
// Phase 12 generated test wrapper for TC-TWU-MAEE-SWITCH-001
// F-ID: F4.NEW.12  Priority: P0  Status: Implemented
// Checker: sva_twu_maee_paths_mutex + cg_maee_path  Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TWU_MAEE_DYNAMIC_SWITCH_SVH
`define TEST_MMU_TWU_MAEE_DYNAMIC_SWITCH_SVH

class test_mmu_twu_maee_dynamic_switch extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_maee_dynamic_switch)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "maee_twu";
    p12_trace_id = "TC-TWU-MAEE-SWITCH-001";
    p12_fid      = "F4.NEW.12";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "cp0_maee_disable_seq -> mmu_huge_page_mix_vseq || cp0_maee_enable_seq";
    p12_checker  = "sva_twu_maee_paths_mutex + cg_maee_path";
    p12_reviewer = "A+B";
    num_txn      = 128;
    m_post_drain = 1000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    `uvm_info(get_type_name(),
      $sformatf("Phase12 dynamic MAEE switch start: trace_id=%s checker=%s reviewer=%s seq=%s",
        p12_trace_id, p12_checker, p12_reviewer, p12_seq_desc),
      UVM_LOW)

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");

    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    start_cp0_seq_by_name("cp0_maee_disable_seq");

    fork
      begin
        start_vseq_by_name("mmu_huge_page_mix_vseq");
      end
      begin
        #200ns;
        start_cp0_seq_by_name("cp0_maee_enable_seq");
        #200ns;
        start_cp0_seq_by_name("cp0_maee_disable_seq");
      end
    join

    #(m_post_drain);
  endtask

endclass : test_mmu_twu_maee_dynamic_switch

`endif // TEST_MMU_TWU_MAEE_DYNAMIC_SWITCH_SVH
