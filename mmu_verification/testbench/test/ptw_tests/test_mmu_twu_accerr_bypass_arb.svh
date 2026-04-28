// =============================================================================
// Phase 12 generated test wrapper for TC-TWU-ACCERR-BYPASS-001
// F-ID: F4.NEW.9  Priority: P0  Status: Implemented
// Checker: sva_twu_except_bypasses_arb + cg_twu_except_while_arb_busy
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TWU_ACCERR_BYPASS_ARB_SVH
`define TEST_MMU_TWU_ACCERR_BYPASS_ARB_SVH

class test_mmu_twu_accerr_bypass_arb extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_accerr_bypass_arb)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "except_bypass";
    p12_trace_id = "TC-TWU-ACCERR-BYPASS-001";
    p12_fid      = "F4.NEW.9";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "pmp_flg_deny_rw_seq + mmu_stress_all_ports_vseq";
    p12_checker  = "sva_twu_except_bypasses_arb + cg_twu_except_while_arb_busy";
    p12_reviewer = "A+B";
    num_txn      = 96;
    m_post_drain = 900ns;
    m_pmp_seq_names.push_back("pmp_flg_deny_rw_seq");
    m_vseq_names.push_back("mmu_stress_all_ports_vseq");
  endfunction

endclass : test_mmu_twu_accerr_bypass_arb

`endif // TEST_MMU_TWU_ACCERR_BYPASS_ARB_SVH
