// =============================================================================
// Phase 12 generated test wrapper for TC-ARB-REFILL-EXCEPT-PRIO-001
// F-ID: F4.NEW.11  Priority: P1  Status: Implemented
// Checker: sva_twu_din_stable_on_grant + cg_arb_grant_type
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_ARB_REFILL_EXCEPT_PRIORITY_SVH
`define TEST_MMU_ARB_REFILL_EXCEPT_PRIORITY_SVH

class test_mmu_arb_refill_except_priority extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_arb_refill_except_priority)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "arb_grant";
    p12_trace_id = "TC-ARB-REFILL-EXCEPT-PRIO-001";
    p12_fid      = "F4.NEW.11";
    p12_priority = "P1";
    p12_status   = "Implemented";
    p12_seq_desc = "pmp_flg_deny_rw_seq + mmu_stress_all_ports_vseq";
    p12_checker  = "sva_twu_din_stable_on_grant + cg_arb_grant_type";
    p12_reviewer = "A+B";
    num_txn      = 128;
    m_post_drain = 900ns;
    m_pmp_seq_names.push_back("pmp_flg_deny_rw_seq");
    m_vseq_names.push_back("mmu_stress_all_ports_vseq");
  endfunction

endclass : test_mmu_arb_refill_except_priority

`endif // TEST_MMU_ARB_REFILL_EXCEPT_PRIORITY_SVH
