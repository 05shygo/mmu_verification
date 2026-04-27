// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-014
// F-ID: F5.NEW.3  Priority: P1  Status: Planned
// Checker: cg_xbar_cold_start  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_014_XBAR_COLD_START_SVH
`define TEST_BUG_014_XBAR_COLD_START_SVH

class test_bug_014_xbar_cold_start extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_014_xbar_cold_start)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "bug_hunt";
    p11_trace_id = "TC-BUG-014";
    p11_fid      = "F5.NEW.3";
    p11_priority = "P1";
    p11_status   = "Planned";
    p11_seq_desc = "mmu_stress_all_ports_vseq";
    p11_checker  = "cg_xbar_cold_start";
    p11_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 800ns;
    m_vseq_names.push_back("mmu_stress_all_ports_vseq");
  endfunction

endclass : test_bug_014_xbar_cold_start

`endif // TEST_BUG_014_XBAR_COLD_START_SVH
