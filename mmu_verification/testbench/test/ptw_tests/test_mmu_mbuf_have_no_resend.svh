// =============================================================================
// Phase 12 generated test wrapper for TC-MBUF-HAVE-001
// F-ID: F4.NEW.10  Priority: P1  Status: Implemented
// Checker: sva_mbuf_have_no_resend + cg_twu_data_ready_per_stage
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_MBUF_HAVE_NO_RESEND_SVH
`define TEST_MMU_MBUF_HAVE_NO_RESEND_SVH

class test_mmu_mbuf_have_no_resend extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_mbuf_have_no_resend)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "mbuf_gating";
    p12_trace_id = "TC-MBUF-HAVE-001";
    p12_fid      = "F4.NEW.10";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "mmu_ptw_thrash_vseq";
    p12_checker  = "sva_mbuf_have_no_resend + cg_twu_data_ready_per_stage";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 800ns;
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mmu_mbuf_have_no_resend

`endif // TEST_MMU_MBUF_HAVE_NO_RESEND_SVH
