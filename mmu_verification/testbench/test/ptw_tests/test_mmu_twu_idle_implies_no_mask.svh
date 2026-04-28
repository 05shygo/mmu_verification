// =============================================================================
// Phase 12 generated test wrapper for TC-TWU-IDLE-MASK-001
// F-ID: F4.NEW.7  Priority: P1  Status: Implemented
// Checker: sva_twu_idle_implies_no_mask + cg_twu_idle_vs_mask_state
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TWU_IDLE_IMPLIES_NO_MASK_SVH
`define TEST_MMU_TWU_IDLE_IMPLIES_NO_MASK_SVH

class test_mmu_twu_idle_implies_no_mask extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_idle_implies_no_mask)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "twu_state";
    p12_trace_id = "TC-TWU-IDLE-MASK-001";
    p12_fid      = "F4.NEW.7";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 idle -> have/busy -> masked PTW progression";
    p12_checker  = "sva_twu_idle_implies_no_mask + cg_twu_idle_vs_mask_state";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 700ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    #200ns;
    phase12_config_ptw_responder(48, 96, 0);

    fork
      begin
        phase12_drive_ifu_rr(39'h10_1000, 8, 24);
      end
      begin
        phase12_drive_lsu_rr(39'h10_1000, 1, 16, LSU_PIPE0, 1'b0);
      end
      begin
        phase12_drive_lsu_rr(39'h10_1000, 1, 16, LSU_PIPE1, 1'b1);
      end
      begin
        #250ns;
        phase12_set_pmp_deny_ptw_reads(4'b0011);
        #200ns;
        phase12_set_pmp_allow_all();
      end
    join

    #(m_post_drain);
  endtask

endclass : test_mmu_twu_idle_implies_no_mask

`endif // TEST_MMU_TWU_IDLE_IMPLIES_NO_MASK_SVH
