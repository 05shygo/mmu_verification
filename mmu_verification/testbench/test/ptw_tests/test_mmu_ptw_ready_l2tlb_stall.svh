// =============================================================================
// Phase 12 generated test wrapper for TC-PTW-READY-003
// F-ID: F4.NEW.6  Priority: P0  Status: Implemented
// Checker: sva_ptw_l2tlb_ready_when_all_mask + cg_ptw_ready_transition
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_PTW_READY_L2TLB_STALL_SVH
`define TEST_MMU_PTW_READY_L2TLB_STALL_SVH

class test_mmu_ptw_ready_l2tlb_stall extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_ptw_ready_l2tlb_stall)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "ptw_ready";
    p12_trace_id = "TC-PTW-READY-003";
    p12_fid      = "F4.NEW.6";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 slow PTW + deny/unblock stall window";
    p12_checker  = "sva_ptw_l2tlb_ready_when_all_mask + cg_ptw_ready_transition";
    p12_reviewer = "A+B";
    num_txn      = 128;
    // Slow PTW plus repeated invalidate can leave a genuine PTW mbuf backlog
    // after direct traffic generation stops. Give the tail enough time to
    // retire cleanly before end-of-sim conservation checks.
    m_post_drain = 3000ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_config_ptw_responder(64, 128, 0);
    phase12_set_pmp_allow_all();

    fork
      begin
        phase12_drive_ifu_rr(39'h10_0000, 24, 64);
      end
      begin
        phase12_drive_lsu_interleave3(39'h10_0000, 24, 96);
      end
      begin
        #200ns;
        phase12_set_pmp_deny_ptw_reads(4'b1111);
        #300ns;
        phase12_set_pmp_allow_all();
        repeat (4)
          phase12_cp0_tlb_allinv();
      end
    join

    // Stop creating new backpressure and switch the responder back to the
    // normal fast mode so any remaining PTW mbuf backlog can drain.
    phase12_set_pmp_allow_all();
    phase12_config_ptw_responder(1, 4, 0);

    phase12_pulse_ptw_ready_for_cov(5);

    #(m_post_drain);
  endtask

endclass : test_mmu_ptw_ready_l2tlb_stall

`endif // TEST_MMU_PTW_READY_L2TLB_STALL_SVH
