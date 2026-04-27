// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-011
// F-ID: F4.NEW.4  Priority: P0  Status: Blocked-Waiting-RTL-Fix
// Checker: sva_twu_2m_cross_data + cg_twu_2m_csr_cross  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_011_TWU_2M_CSR_CROSS_SVH
`define TEST_BUG_011_TWU_2M_CSR_CROSS_SVH

class test_bug_011_twu_2m_csr_cross extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_011_twu_2m_csr_cross)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "bug_hunt";
    p11_trace_id = "TC-BUG-011";
    p11_fid      = "F4.NEW.4";
    p11_priority = "P0";
    p11_status   = "Blocked-Waiting-RTL-Fix";
    p11_seq_desc = "cp0_satp_switch_seq + ifu_huge_page_fetch_seq + mmu_huge_page_mix_vseq";
    p11_checker  = "sva_twu_2m_cross_data + cg_twu_2m_csr_cross";
    p11_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 800ns;
    m_cp0_seq_names.push_back("cp0_satp_switch_seq");
    m_ifu_seq_names.push_back("ifu_huge_page_fetch_seq");
    m_vseq_names.push_back("mmu_huge_page_mix_vseq");
  endfunction

endclass : test_bug_011_twu_2m_csr_cross

`endif // TEST_BUG_011_TWU_2M_CSR_CROSS_SVH
