// =============================================================================
// Phase 12 generated test wrapper for TC-ARB-VPN-MATCH-001
// F-ID: F5.16  Priority: P1  Status: Implemented
// Checker: sva_ptw_arb_vpn_matches_tag + cg_ptw_arb_pgs_type
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_ARB_VPN_MATCH_TAG_DIN_SVH
`define TEST_MMU_ARB_VPN_MATCH_TAG_DIN_SVH

class test_mmu_arb_vpn_match_tag_din extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_arb_vpn_match_tag_din)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "arb_vpn";
    p12_trace_id = "TC-ARB-VPN-MATCH-001";
    p12_fid      = "F5.16";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "lsu_rr_4K_2M_1G + ifu_rr_4K_2M_1G (F5.16 cg_ptw_arb_pgs_type)";
    p12_checker  = "sva_ptw_arb_vpn_matches_tag + cg_ptw_arb_pgs_type";
    p12_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 900ns;
  endfunction

  virtual task run_test_body();
    setup_plan();

    if (m_run_misc_init)
      start_misc_seq_by_name("misc_init_seq");
    if (m_enable_sv39_4k_bringup)
      do_sv39_4k_bringup();

    phase12_map_hugepage_fixture();

    // Drive cg_ptw_arb_pgs_type: arb_ptw_grant + {4K,2M,1G} pgs — LSU and IFU both refill PTW→arb.
    repeat (2) begin
      phase12_drive_lsu_rr(39'h0_3000_1000, 1, 4, LSU_PIPE0, 1'b0);
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_2200_0000, 1, 4, LSU_PIPE0, 1'b0);
      phase12_cp0_tlb_allinv();
      phase12_drive_lsu_rr(39'h0_4000_0000, 1, 4, LSU_PIPE0, 1'b0);
      phase12_cp0_tlb_allinv();

      phase12_drive_ifu_rr(39'h0_3000_1000, 1, 12);
      phase12_cp0_tlb_allinv();
      phase12_drive_ifu_rr(39'h0_2200_0000, 1, 12);
      phase12_cp0_tlb_allinv();
      phase12_drive_ifu_rr(39'h0_4000_0000, 1, 12);
      phase12_cp0_tlb_allinv();
    end

    #(m_post_drain);
  endtask

endclass : test_mmu_arb_vpn_match_tag_din

`endif // TEST_MMU_ARB_VPN_MATCH_TAG_DIN_SVH
