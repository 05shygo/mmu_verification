// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-012
// F-ID: F4.NEW.5  Priority: P1  Status: Planned
// Checker: sva_csr_grant_onehot  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_012_CSR_GRANT_ONEHOT_SVH
`define TEST_BUG_012_CSR_GRANT_ONEHOT_SVH

class test_bug_012_csr_grant_onehot extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_012_csr_grant_onehot)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "bug_hunt";
    p11_trace_id = "TC-BUG-012";
    p11_fid      = "F4.NEW.5";
    p11_priority = "P1";
    p11_status   = "Planned";
    p11_seq_desc = "cp0_satp_switch_seq + ifu_huge_page_fetch_seq + mmu_huge_page_mix_vseq";
    p11_checker  = "sva_csr_grant_onehot";
    p11_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 800ns;
    m_cp0_seq_names.push_back("cp0_satp_switch_seq");
    m_ifu_seq_names.push_back("ifu_huge_page_fetch_seq");
    m_vseq_names.push_back("mmu_huge_page_mix_vseq");
  endfunction

endclass : test_bug_012_csr_grant_onehot

`endif // TEST_BUG_012_CSR_GRANT_ONEHOT_SVH
