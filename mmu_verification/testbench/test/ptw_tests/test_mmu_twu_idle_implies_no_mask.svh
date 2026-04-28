// =============================================================================
// Phase 12 generated test wrapper for TC-TWU-IDLE-MASK-001
// F-ID: F4.NEW.7  Priority: P1  Status: Implemented
// Checker: sva_twu_idle_implies_no_mask + cg_twu_idle_vs_mask_state
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TWU_IDLE_IMPLIES_NO_MASK_SVH
`define TEST_MMU_TWU_IDLE_IMPLIES_NO_MASK_SVH

class test_mmu_twu_idle_implies_no_mask extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_idle_implies_no_mask)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "twu_state";
    p12_trace_id = "TC-TWU-IDLE-MASK-001";
    p12_fid      = "F4.NEW.7";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "mmu_ptw_thrash_vseq";
    p12_checker  = "sva_twu_idle_implies_no_mask + cg_twu_idle_vs_mask_state";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 700ns;
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mmu_twu_idle_implies_no_mask

`endif // TEST_MMU_TWU_IDLE_IMPLIES_NO_MASK_SVH
