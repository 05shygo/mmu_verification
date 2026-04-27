// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-008
// F-ID: F12.NEW.1  Priority: P0  Status: Blocked-Waiting-RTL-Fix
// Checker: sva_pplru_entry0_first_hit  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_008_PPLRU_ENTRY0_FIRST_HIT_SVH
`define TEST_BUG_008_PPLRU_ENTRY0_FIRST_HIT_SVH

class test_bug_008_pplru_entry0_first_hit extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_008_pplru_entry0_first_hit)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "bug_hunt";
    p11_trace_id = "TC-BUG-008";
    p11_fid      = "F12.NEW.1";
    p11_priority = "P0";
    p11_status   = "Blocked-Waiting-RTL-Fix";
    p11_seq_desc = "lsu_back2back_seq + mmu_smoke_vseq";
    p11_checker  = "sva_pplru_entry0_first_hit";
    p11_reviewer = "A+B";
    num_txn      = 48;
    m_post_drain = 500ns;
    m_lsu_seq_names.push_back("lsu_back2back_seq");
    m_vseq_names.push_back("mmu_smoke_vseq");
  endfunction

endclass : test_bug_008_pplru_entry0_first_hit

`endif // TEST_BUG_008_PPLRU_ENTRY0_FIRST_HIT_SVH
