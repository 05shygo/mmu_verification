// =============================================================================
// Phase 12 generated test wrapper for TC-ARB-REFILL-EXCEPT-PRIO-001
// F-ID: F4.NEW.11  Priority: P1  Status: Implemented
// Checker: sva_twu_din_stable_on_grant + cg_arb_grant_type
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_ARB_REFILL_EXCEPT_PRIORITY_SVH
`define TEST_MMU_ARB_REFILL_EXCEPT_PRIORITY_SVH

class test_mmu_arb_refill_except_priority extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_arb_refill_except_priority)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "arb_grant";
    p12_trace_id = "TC-ARB-REFILL-EXCEPT-PRIO-001";
    p12_fid      = "F4.NEW.11";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 concurrent refill traffic plus pgflt bypass pressure";
    p12_checker  = "sva_twu_din_stable_on_grant + cg_arb_grant_type";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 1200ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_map_hugepage_fixture();
    phase12_map_4k_window(39'h10_0000, 6, 40'h0_2010_0000);
    m_env.m_pt_mem.m_builder.inject_fault(39'h10_0000, "V_OFF");
    phase12_config_ptw_responder(32, 64, 0);

    fork
      begin
        repeat (3) begin
          phase12_cp0_tlb_allinv();
          phase12_drive_ifu_rr(39'h0_4000_0000, 1, 1);
          phase12_drive_lsu_rr(39'h0_2200_0000, 1, 1, LSU_PIPE0, 1'b0);
        end
      end
      begin
        #200ns;
        repeat (3) begin
          phase12_cp0_tlb_allinv();
          phase12_drive_lsu_rr(39'h10_0000, 1, 1, LSU_PIPE1, 1'b1);
        end
      end
    join

    phase12_set_pmp_deny_ptw_reads(4'b1111);
    repeat (3) begin
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h10_1000, 1, 2, LSU_PIPE0, 1'b0);
    end
    phase12_set_pmp_allow_all();

    phase12_config_ptw_responder(1, 4, 0);

    #(m_post_drain);
  endtask

endclass : test_mmu_arb_refill_except_priority

`endif // TEST_MMU_ARB_REFILL_EXCEPT_PRIORITY_SVH
