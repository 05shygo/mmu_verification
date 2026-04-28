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
    p12_seq_desc = "mmu_ptw_thrash_vseq";
    p12_checker  = "sva_ptw_arb_vpn_matches_tag + cg_ptw_arb_pgs_type";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 800ns;
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mmu_arb_vpn_match_tag_din

`endif // TEST_MMU_ARB_VPN_MATCH_TAG_DIN_SVH
