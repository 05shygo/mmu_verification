// =============================================================================
// Phase 12 generated test wrapper for TC-ARB-MULTI-TWU-FAIRNESS-001
// F-ID: F4.NEW.11  Priority: P1  Status: Implemented
// Checker: cg_arb_grant_type
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_ARB_MULTI_TWU_FAIRNESS_SVH
`define TEST_MMU_ARB_MULTI_TWU_FAIRNESS_SVH

class test_mmu_arb_multi_twu_fairness extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_arb_multi_twu_fairness)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "arb_grant";
    p12_trace_id = "TC-ARB-MULTI-TWU-FAIRNESS-001";
    p12_fid      = "F4.NEW.11";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 sustained multi-TWU refill rotation";
    p12_checker  = "cg_arb_grant_type";
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

    phase12_map_hugepage_fixture();
    phase12_config_ptw_responder(20, 40, 0);

    repeat (4) begin
      phase12_cp0_tlb_allinv();
      fork
        begin
          phase12_drive_ifu_rr(39'h0_4000_0000, 2, 4);
        end
        begin
          phase12_drive_lsu_interleave3(39'h0_3000_1000, 2, 10);
        end
      join
      phase12_drive_lsu_rr(39'h0_2600_0000, 1, 2, LSU_PIPE0, 1'b0);
    end

    #(m_post_drain);
  endtask

endclass : test_mmu_arb_multi_twu_fairness

`endif // TEST_MMU_ARB_MULTI_TWU_FAIRNESS_SVH
