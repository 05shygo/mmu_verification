// =============================================================================
// Phase 12 generated test wrapper for TC-TWU-ACCERR-BYPASS-001
// F-ID: F4.NEW.9  Priority: P0  Status: Implemented
// Checker: sva_twu_except_bypasses_arb + cg_twu_except_while_arb_busy
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TWU_ACCERR_BYPASS_ARB_SVH
`define TEST_MMU_TWU_ACCERR_BYPASS_ARB_SVH

class test_mmu_twu_accerr_bypass_arb extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_accerr_bypass_arb)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "except_bypass";
    p12_trace_id = "TC-TWU-ACCERR-BYPASS-001";
    p12_fid      = "F4.NEW.9";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 slow PTW + mid-run PTW PMP read deny";
    p12_checker  = "sva_twu_except_bypasses_arb + cg_twu_except_while_arb_busy";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 1800ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_set_pmp_allow_all();
    phase12_config_ptw_responder(48, 96, 0);

    fork
      begin
        phase12_drive_ifu_rr(39'h10_1000, 16, 48);
      end
      begin
        #400ns;
        phase12_set_pmp_deny_ptw_reads(4'b1111);
      end
      begin
        #450ns;
        repeat (6) begin
          phase12_cp0_tlb_allinv();
          phase12_drive_lsu_rr(39'h10_1000, 1, 1, LSU_PIPE0, 1'b0);
        end
      end
    join

    // Restore the normal PTW path before the drain window so the tail of the
    // injected accerr traffic cannot keep generating fresh deny-side effects.
    phase12_set_pmp_allow_all();
    phase12_config_ptw_responder(1, 4, 0);

    #(m_post_drain);
  endtask

endclass : test_mmu_twu_accerr_bypass_arb

`endif // TEST_MMU_TWU_ACCERR_BYPASS_ARB_SVH
