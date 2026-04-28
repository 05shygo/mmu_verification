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
    p12_seq_desc = "ifu_huge_page_fetch_seq + lsu_huge_page_seq";
    p12_checker  = "sva_ptw_arb_vpn_matches_tag + cg_ptw_arb_pgs_type";
    p12_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 900ns;
    m_ifu_seq_names.push_back("ifu_huge_page_fetch_seq");
    m_lsu_seq_names.push_back("lsu_huge_page_seq");
  endfunction

endclass : test_mmu_arb_pgs_bank_select

`endif // TEST_MMU_ARB_PGS_BANK_SELECT_SVH
