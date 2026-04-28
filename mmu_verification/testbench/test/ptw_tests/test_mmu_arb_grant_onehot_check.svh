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
    p12_seq_desc = "mmu_stress_all_ports_vseq";
    p12_checker  = "sva_arb_twu_grant_onehot + cg_arb_grant_type";
    p12_reviewer = "A+B";
    num_txn      = 128;
    m_post_drain = 900ns;
    m_vseq_names.push_back("mmu_stress_all_ports_vseq");
  endfunction

endclass : test_mmu_arb_grant_onehot_check

`endif // TEST_MMU_ARB_GRANT_ONEHOT_CHECK_SVH
