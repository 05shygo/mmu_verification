// =============================================================================
// Phase 12 generated test wrapper for TC-TWU-PGFLT-BYPASS-001
// F-ID: F4.NEW.9  Priority: P0  Status: Implemented
// Checker: sva_twu_except_bypasses_arb + cg_twu_except_while_arb_busy
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TWU_PGFLT_BYPASS_ARB_SVH
`define TEST_MMU_TWU_PGFLT_BYPASS_ARB_SVH

class test_mmu_twu_pgflt_bypass_arb extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_pgflt_bypass_arb)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "except_bypass";
    p12_trace_id = "TC-TWU-PGFLT-BYPASS-001";
    p12_fid      = "F4.NEW.9";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "ptw_mem_illegal_pte_seq + mmu_stress_all_ports_vseq";
    p12_checker  = "sva_twu_except_bypasses_arb + cg_twu_except_while_arb_busy";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 900ns;
    m_ptw_seq_names.push_back("ptw_mem_illegal_pte_seq");
    m_vseq_names.push_back("mmu_stress_all_ports_vseq");
  endfunction

endclass : test_mmu_twu_pgflt_bypass_arb

`endif // TEST_MMU_TWU_PGFLT_BYPASS_ARB_SVH
