// =============================================================================
// Phase 12 generated test wrapper for TC-ARB-PGS-MATCH-001
// F-ID: F5.16  Priority: P1  Status: Implemented
// Checker: sva_ptw_arb_vpn_matches_tag + cg_ptw_arb_pgs_type
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_ARB_PGS_BANK_SELECT_SVH
`define TEST_MMU_ARB_PGS_BANK_SELECT_SVH

class test_mmu_arb_pgs_bank_select extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_arb_pgs_bank_select)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "arb_vpn";
    p12_trace_id = "TC-ARB-PGS-MATCH-001";
    p12_fid      = "F5.16";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "lsu_rr_4K_2M_1G + ifu_rr_4K_2M_1G (F5.16 bank/cg_ptw_arb_pgs_type)";
    p12_checker  = "sva_ptw_arb_vpn_matches_tag + cg_ptw_arb_pgs_type";
    p12_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 1200ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_map_hugepage_fixture();

    repeat (4) begin
      phase12_drive_lsu_rr(39'h0_3000_2000, 1, 8, LSU_PIPE1, 1'b1);
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_2600_0000, 1, 8, LSU_PIPE1, 1'b1);
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_8000_0000, 1, 8, LSU_PIPE1, 1'b1);
      phase12_cp0_tlb_allinv();

      phase12_drive_ifu_rr(39'h0_3000_2000, 1, 24);
      phase12_cp0_tlb_allinv();
      phase12_drive_ifu_rr(39'h0_2600_0000, 1, 24);
      phase12_cp0_tlb_allinv();
      phase12_drive_ifu_rr(39'h0_8000_0000, 1, 24);
      phase12_cp0_tlb_allinv();
    end

    #(m_post_drain);
  endtask

endclass : test_mmu_arb_pgs_bank_select

`endif // TEST_MMU_ARB_PGS_BANK_SELECT_SVH
