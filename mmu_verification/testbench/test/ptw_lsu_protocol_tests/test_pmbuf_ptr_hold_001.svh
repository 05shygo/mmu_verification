// =============================================================================
// Phase 11 generated test wrapper for TC-PMBUF-PTR-HOLD-001
// F-ID: F4.42c  Priority: P1  Status: Planned
// Checker: sva_mbuf_ptr_only_on_response + cg_mbuf_ptr_hold  Reviewer: A+B
// =============================================================================
`ifndef TEST_PMBUF_PTR_HOLD_001_SVH
`define TEST_PMBUF_PTR_HOLD_001_SVH

class test_pmbuf_ptr_hold_001 extends phase11_generated_test_base;

  `uvm_component_utils(test_pmbuf_ptr_hold_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "ptw_lsu_protocol";
    p11_trace_id = "TC-PMBUF-PTR-HOLD-001";
    p11_fid      = "F4.42c";
    p11_priority = "P1";
    p11_status   = "Planned";
    p11_seq_desc = "ptw_mem_slow_rsp_seq + lsu_01_concurrent_seq";
    p11_checker  = "sva_mbuf_ptr_only_on_response + cg_mbuf_ptr_hold";
    p11_reviewer = "A+B";
    num_txn      = 48;
    m_post_drain = 800ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_lsu_seq_names.push_back("lsu_01_concurrent_seq");
  endfunction

endclass : test_pmbuf_ptr_hold_001

`endif // TEST_PMBUF_PTR_HOLD_001_SVH
