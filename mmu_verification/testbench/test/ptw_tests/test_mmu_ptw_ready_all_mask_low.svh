// =============================================================================
// Phase 12 generated test wrapper for TC-PTW-READY-001
// F-ID: F4.NEW.6  Priority: P0  Status: Implemented
// Checker: sva_ptw_l2tlb_ready_when_all_mask + cg_ptw_ready_transition
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_PTW_READY_ALL_MASK_LOW_SVH
`define TEST_MMU_PTW_READY_ALL_MASK_LOW_SVH

class test_mmu_ptw_ready_all_mask_low extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_ptw_ready_all_mask_low)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "ptw_ready";
    p12_trace_id = "TC-PTW-READY-001";
    p12_fid      = "F4.NEW.6";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 all-PTW-read-deny window + IFU/LSU pressure";
    p12_checker  = "sva_ptw_l2tlb_ready_when_all_mask + cg_ptw_ready_transition";
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

    phase12_set_pmp_deny_ptw_reads(4'b1111);

    fork
      begin
        phase12_drive_ifu_rr(39'h10_1000, 16, 32);
      end
      begin
        phase12_drive_lsu_interleave3(39'h10_1000, 16, 48);
      end
      begin
        #350ns;
        phase12_set_pmp_allow_all();
        phase12_cp0_tlb_allinv();
        phase12_drive_lsu_rr(39'h10_1000, 4, 12, LSU_PIPE0, 1'b0);
      end
    join

    #(m_post_drain);
  endtask

endclass : test_mmu_ptw_ready_all_mask_low

`endif // TEST_MMU_PTW_READY_ALL_MASK_LOW_SVH
