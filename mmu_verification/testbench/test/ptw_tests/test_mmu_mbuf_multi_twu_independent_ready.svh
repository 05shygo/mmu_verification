// =============================================================================
// Phase 12 generated test wrapper for TC-MBUF-MULTI-TWU-READY-001
// F-ID: F4.NEW.10  Priority: P1  Status: Implemented
// Checker: cg_twu_data_ready_per_stage
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_MBUF_MULTI_TWU_INDEPENDENT_READY_SVH
`define TEST_MMU_MBUF_MULTI_TWU_INDEPENDENT_READY_SVH

class test_mmu_mbuf_multi_twu_independent_ready extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_mbuf_multi_twu_independent_ready)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "mbuf_gating";
    p12_trace_id = "TC-MBUF-MULTI-TWU-READY-001";
    p12_fid      = "F4.NEW.10";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 IFU+LSU shared-page pressure across multiple TWUs";
    p12_checker  = "cg_twu_data_ready_per_stage";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 1000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_config_ptw_responder(24, 48, 0);

    repeat (2) begin
      phase12_cp0_tlb_allinv();
      fork
        begin
          phase12_drive_ifu_rr(39'h10_0000, 2, 16);
        end
        begin
          phase12_drive_lsu_interleave3(39'h10_0000, 2, 24);
        end
      join
    end

    phase12_config_ptw_responder(1, 4, 0);

    #(m_post_drain);
  endtask

endclass : test_mmu_mbuf_multi_twu_independent_ready

`endif // TEST_MMU_MBUF_MULTI_TWU_INDEPENDENT_READY_SVH
