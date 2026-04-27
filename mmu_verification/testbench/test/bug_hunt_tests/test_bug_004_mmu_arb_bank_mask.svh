// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-004
// F-ID: F5.NEW.1  Priority: P1  Status: Functional
// Checker: arb bank-mask positive guard  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_004_MMU_ARB_BANK_MASK_SVH
`define TEST_BUG_004_MMU_ARB_BANK_MASK_SVH

class test_bug_004_mmu_arb_bank_mask extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_004_mmu_arb_bank_mask)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "positive_guard";
    p11_trace_id = "TC-BUG-004";
    p11_fid      = "F5.NEW.1";
    p11_priority = "P1";
    p11_status   = "Functional";
    p11_seq_desc = "mmu_l2tlb_bank_conflict_vseq";
    p11_checker  = "mmu_arb_sva positive guard";
    p11_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 500ns;
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
  endfunction

endclass : test_bug_004_mmu_arb_bank_mask

`endif // TEST_BUG_004_MMU_ARB_BANK_MASK_SVH
