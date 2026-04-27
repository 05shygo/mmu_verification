// =============================================================================
// Phase 11 generated test wrapper for TC-BUG-003
// F-ID: F4.NEW.1  Priority: P1  Status: Functional
// Checker: sva_pde_nonleaf_upd positive guard  Reviewer: A+B
// =============================================================================
`ifndef TEST_BUG_003_THD_CHK_LEAF_REFILL_SVH
`define TEST_BUG_003_THD_CHK_LEAF_REFILL_SVH

class test_bug_003_thd_chk_leaf_refill extends phase11_generated_test_base;

  `uvm_component_utils(test_bug_003_thd_chk_leaf_refill)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "positive_guard";
    p11_trace_id = "TC-BUG-003";
    p11_fid      = "F4.NEW.1";
    p11_priority = "P1";
    p11_status   = "Functional";
    p11_seq_desc = "ptw_mem_normal_rsp_seq + mmu_ptw_thrash_vseq";
    p11_checker  = "sva_pde_nonleaf_upd";
    p11_reviewer = "A+B";
    num_txn      = 64;
    m_post_drain = 500ns;
    m_ptw_seq_names.push_back("ptw_mem_normal_rsp_seq");
    m_vseq_names.push_back("mmu_ptw_thrash_vseq");
  endfunction

endclass : test_bug_003_thd_chk_leaf_refill

`endif // TEST_BUG_003_THD_CHK_LEAF_REFILL_SVH
