// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-005
// F-ID: F3.4  Priority: P0  Status: Blocked-Waiting-RTL-Fix
// Checker: sva_raw_vld_and_gate  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_005_L2_RAW_VLD_AND_GATE_SVH
`define TEST_BUG_005_L2_RAW_VLD_AND_GATE_SVH

class test_bug_005_l2_raw_vld_and_gate extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_005_l2_raw_vld_and_gate)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "bug_hunt";
    p11_trace_id = "TC-BUG-005";
    p11_fid      = "F3.4";
    p11_priority = "P0";
    p11_status   = "Blocked-Waiting-RTL-Fix";
    p11_seq_desc = "lsu_01_concurrent_seq + mmu_l2tlb_bank_conflict_vseq";
    p11_checker  = "sva_raw_vld_and_gate";
    p11_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 500ns;
    m_lsu_seq_names.push_back("lsu_01_concurrent_seq");
    m_vseq_names.push_back("mmu_l2tlb_bank_conflict_vseq");
  endfunction

endclass : test_bug_005_l2_raw_vld_and_gate

`endif // TEST_BUG_005_L2_RAW_VLD_AND_GATE_SVH
