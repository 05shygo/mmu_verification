// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-006
// F-ID: F3.5  Priority: P0  Status: Blocked-Waiting-RTL-Fix
// Checker: cg_l2_store_dtlb_tag  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_006_L2_IS_DTLB_STORE_SVH
`define TEST_BUG_006_L2_IS_DTLB_STORE_SVH

class test_bug_006_l2_is_dtlb_store extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_006_l2_is_dtlb_store)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "bug_hunt";
    p11_trace_id = "TC-BUG-006";
    p11_fid      = "F3.5";
    p11_priority = "P0";
    p11_status   = "Blocked-Waiting-RTL-Fix";
    p11_seq_desc = "lsu_st_ld_mix_seq + mmu_l2tlb_bank_conflict_vseq";
    p11_checker  = "cg_l2_store_dtlb_tag";
    p11_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 500ns;
    m_lsu_seq_names.push_back("lsu_st_ld_mix_seq");
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
  endfunction

endclass : test_bug_006_l2_is_dtlb_store

`endif // TEST_BUG_006_L2_IS_DTLB_STORE_SVH
