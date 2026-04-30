// =============================================================================
// Phase 12 generated test wrapper for TC-ARB-GRANT-ONEHOT-001
// F-ID: F4.NEW.11  Priority: P1  Status: Implemented
// Checker: sva_arb_twu_grant_onehot + cg_arb_grant_type
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_ARB_GRANT_ONEHOT_CHECK_SVH
`define TEST_MMU_ARB_GRANT_ONEHOT_CHECK_SVH

class test_mmu_arb_grant_onehot_check extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_arb_grant_onehot_check)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "arb_grant";
    p12_trace_id = "TC-ARB-GRANT-ONEHOT-001";
    p12_fid      = "F4.NEW.11";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "phase12 repeated refill pressure with mixed page sizes";
    p12_checker  = "sva_arb_twu_grant_onehot + cg_arb_grant_type";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 650ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_map_hugepage_fixture();
    phase12_config_ptw_responder(16, 32, 0);

    repeat (4) begin
      phase12_cp0_tlb_allinv();
      fork
        begin
          phase12_drive_ifu_rr(39'h0_4000_0000, 2, 4);
        end
        begin
          phase12_drive_lsu_interleave3(39'h0_3000_1000, 2, 8);
        end
      join
      phase12_drive_lsu_rr(39'h0_2200_0000, 1, 2, LSU_PIPE1, 1'b1);
    end

    #(m_post_drain);
  endtask

endclass : test_mmu_arb_grant_onehot_check

`endif // TEST_MMU_ARB_GRANT_ONEHOT_CHECK_SVH
