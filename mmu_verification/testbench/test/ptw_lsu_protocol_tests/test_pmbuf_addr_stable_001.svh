// =============================================================================
// Phase 11 generated test wrapper for TC-PMBUF-ADDR-STABLE-001
// F-ID: F4.42a  Priority: P0  Status: Planned
// Checker: sva_lsu_addr_stable_until_vld + cg_lsu_req_outstanding  Reviewer: A+B
// =============================================================================
`ifndef TEST_PMBUF_ADDR_STABLE_001_SVH
`define TEST_PMBUF_ADDR_STABLE_001_SVH

class test_pmbuf_addr_stable_001 extends phase11_generated_test_base;

  `uvm_component_utils(test_pmbuf_addr_stable_001)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  protected virtual function void setup_phase11_plan();
    p11_bucket   = "ptw_lsu_protocol";
    p11_trace_id = "TC-PMBUF-ADDR-STABLE-001";
    p11_fid      = "F4.42a";
    p11_priority = "P0";
    p11_status   = "Planned";
    p11_seq_desc = "ptw_mem_slow_rsp_seq + lsu_pipe0_only_seq";
    p11_checker  = "sva_lsu_addr_stable_until_vld + cg_lsu_req_outstanding";
    p11_reviewer = "A+B";
    num_txn      = 48;
    m_post_drain = 800ns;
    m_ptw_seq_names.push_back("ptw_mem_slow_rsp_seq");
    m_lsu_seq_names.push_back("lsu_pipe0_only_seq");
  endfunction

endclass : test_pmbuf_addr_stable_001

`endif // TEST_PMBUF_ADDR_STABLE_001_SVH
