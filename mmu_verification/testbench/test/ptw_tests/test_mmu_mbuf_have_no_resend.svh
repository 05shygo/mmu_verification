// =============================================================================
// Phase 12 generated test wrapper for TC-MBUF-HAVE-001
// F-ID: F4.NEW.10  Priority: P1  Status: Implemented
// Checker: sva_mbuf_have_no_resend + cg_twu_data_ready_per_stage
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_MBUF_HAVE_NO_RESEND_SVH
`define TEST_MMU_MBUF_HAVE_NO_RESEND_SVH

class test_mmu_mbuf_have_no_resend extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_mbuf_have_no_resend)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "mbuf_gating";
    p12_trace_id = "TC-MBUF-HAVE-001";
    p12_fid      = "F4.NEW.10";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 same-VA replay under slow PTW to force mbuf_have";
    p12_checker  = "sva_mbuf_have_no_resend + cg_twu_data_ready_per_stage";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 800ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_config_ptw_responder(64, 128, 0);

    repeat (3) begin
      phase12_cp0_tlb_allinv();
      fork
        begin
          phase12_drive_ifu_rr(39'h10_0000, 1, 16);
        end
        begin
          phase12_drive_lsu_rr(39'h10_0000, 1, 16, LSU_PIPE0, 1'b0);
        end
        begin
          phase12_drive_lsu_rr(39'h10_0000, 1, 16, LSU_PIPE1, 1'b1);
        end
      join
    end

    #(m_post_drain);
  endtask

endclass : test_mmu_mbuf_have_no_resend

`endif // TEST_MMU_MBUF_HAVE_NO_RESEND_SVH
