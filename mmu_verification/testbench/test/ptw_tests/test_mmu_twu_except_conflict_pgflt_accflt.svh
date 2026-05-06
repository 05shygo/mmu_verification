// =============================================================================
// Phase 12 generated test wrapper for TC-TWU-EXCEPT-CONFLICT-001
// F-ID: F4.NEW.9  Priority: P0  Status: Implemented
// Checker: sva_twu_pgflt_acc_mutex + cg_twu_except_while_arb_busy
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TWU_EXCEPT_CONFLICT_PGFLT_ACCFLT_SVH
`define TEST_MMU_TWU_EXCEPT_CONFLICT_PGFLT_ACCFLT_SVH

class test_mmu_twu_except_conflict_pgflt_accflt extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_except_conflict_pgflt_accflt)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "except_bypass";
    p12_trace_id = "TC-TWU-EXCEPT-CONFLICT-001";
    p12_fid      = "F4.NEW.9";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 mapped IFU pressure plus LSU pgflt/bus-error accerr conflict";
    p12_checker  = "sva_twu_pgflt_acc_mutex + cg_twu_except_while_arb_busy";
    p12_reviewer = "A+B";
    num_txn      = 128;
    m_post_drain = 900ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_map_4k_window(39'h10_0000, 8, 40'h0_2010_0000);
    phase12_map_4k_window(39'h10_8000, 8, 40'h0_2020_0000);
    m_env.m_pt_mem.m_builder.inject_fault(39'h10_0000, "V_OFF");
    phase12_set_pmp_allow_all();

    // Make one deterministic page-fault sample first.  IFU fault requests can
    // be exception-only and do not always produce the pavld handshake that the
    // IFU driver waits for, so use LSU for the fault stream in this conflict
    // test.
    phase12_config_ptw_responder(32, 72, 0);
    phase12_cp0_tlb_allinv();
    fork
      phase12_drive_ifu_rr(39'h10_8000, 8, 16, 1'b1);
      phase12_drive_lsu_rr(39'h10_0000, 1, 1, LSU_PIPE0, 1'b0, 1'b1);
    join
    phase12_wait_for_quiescent("phase12_except_conflict_pgflt_seed");

    phase12_config_ptw_responder(32, 72, 350);
    repeat (4) begin
      phase12_cp0_tlb_allinv();
      fork
        phase12_drive_lsu_rr(39'h10_0000, 1, 1, LSU_PIPE0, 1'b0, 1'b1);
        phase12_drive_lsu_rr(39'h10_1000, 1, 1, LSU_PIPE1, 1'b0, 1'b1);
      join
      phase12_wait_for_quiescent("phase12_except_conflict_iter", 524288, 16);
    end

    phase12_config_ptw_responder(1, 4, 0);
    phase12_wait_for_quiescent("phase12_except_conflict_recover", 524288, 16);

    #(m_post_drain);
  endtask

endclass : test_mmu_twu_except_conflict_pgflt_accflt

`endif // TEST_MMU_TWU_EXCEPT_CONFLICT_PGFLT_ACCFLT_SVH
