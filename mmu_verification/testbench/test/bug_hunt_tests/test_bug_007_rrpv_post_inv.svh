// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-007
// F-ID: F3.NEW.1  Priority: P0  Status: Blocked-Waiting-RTL-Fix
// Checker: sva_rrpv_inv_state  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_007_RRPV_POST_INV_SVH
`define TEST_BUG_007_RRPV_POST_INV_SVH

class test_bug_007_rrpv_post_inv extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_007_rrpv_post_inv)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "bug_hunt";
    p11_trace_id = "TC-BUG-007";
    p11_fid      = "F3.NEW.1";
    p11_priority = "P0";
    p11_status   = "Blocked-Waiting-RTL-Fix";
    p11_seq_desc = "cp0_tlb_allinv_seq + mmu_rrpv_aging_vseq";
    p11_checker  = "sva_rrpv_inv_state";
    p11_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 500ns;
    m_cp0_seq_names.push_back("cp0_tlb_allinv_seq");
    m_vseq_names.push_back("mmu_rrpv_aging_vseq");
  endfunction

endclass : test_bug_007_rrpv_post_inv

`endif // TEST_BUG_007_RRPV_POST_INV_SVH
