// =============================================================================
// Phase 12 generated test wrapper for TC-TWU-EXCEPT-CONFLICT-001
// F-ID: F4.NEW.9  Priority: P0  Status: Implemented
// Checker: sva_twu_pgflt_acc_mutex + cg_twu_except_while_arb_busy
// Reviewer: A+B
// =============================================================================
`ifndef TEST_MMU_TWU_EXCEPT_CONFLICT_PGFLT_ACCFLT_SVH
`define TEST_MMU_TWU_EXCEPT_CONFLICT_PGFLT_ACCFLT_SVH

class test_mmu_twu_except_conflict_pgflt_accflt extends phase12_generated_test_base;

  `uvm_component_utils(test_mmu_twu_except_conflict_pgflt_accflt)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase12_plan();
    p12_bucket   = "except_bypass";
    p12_trace_id = "TC-TWU-EXCEPT-CONFLICT-001";
    p12_fid      = "F4.NEW.9";
    p12_priority = "P0";
    p12_status   = "Implemented";
    p12_seq_desc = "pmp_flg_deny_rw_seq + ptw_mem_illegal_pte_seq + mmu_ptw_thrash_vseq";
    p12_checker  = "sva_twu_pgflt_acc_mutex + cg_twu_except_while_arb_busy";
    p12_reviewer = "A+B";
    num_txn      = 128;
    m_post_drain = 900ns;
    m_pmp_seq_names.push_back("pmp_flg_deny_rw_seq");
    m_ptw_seq_names.push_back("ptw_mem_illegal_pte_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_mmu_twu_except_conflict_pgflt_accflt

`endif // TEST_MMU_TWU_EXCEPT_CONFLICT_PGFLT_ACCFLT_SVH
